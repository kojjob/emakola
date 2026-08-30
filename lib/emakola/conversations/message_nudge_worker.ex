defmodule Emakola.Conversations.MessageNudgeWorker do
  @moduledoc """
  Tells someone by SMS that they have an unread message — but only if it is
  *still* unread when this runs.

  This is the piece that decides whether in-house messaging saves money or
  quietly costs more than it saves. A notification on every message would
  mean each free in-app message triggers a paid SMS, which is worse than not
  building the feature at all. Three rules keep that from happening:

    * **Delay.** The job is scheduled `@delay_seconds` out, so someone who
      reads their inbox in the next few minutes is never charged for.
    * **Re-check.** Read state is checked at run time, not at post time. A
      message read in the meantime sends nothing.
    * **Debounce.** Oban uniqueness per thread and side means a burst of ten
      messages is one nudge, not ten.

  Platform staff are never nudged: they work in the dashboard, and an SMS to
  Makola costs a merchant nothing but tells us nothing either.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    # One nudge per thread per side per window. The window matches the delay,
    # so a conversation running back and forth cannot bill per message.
    #
    # Every incomplete state counts, not just available+scheduled: a nudge
    # that is executing or awaiting retry has not been delivered yet, and
    # letting a second one enqueue alongside it would bill the merchant for
    # two SMS about the same conversation.
    unique: [
      period: 900,
      keys: [:thread_id, :side],
      states: [:available, :scheduled, :executing, :retryable, :suspended]
    ]

  require Ash.Query

  alias Emakola.Conversations
  alias Emakola.Notifications.Preferences

  @delay_seconds 600

  @doc "Seconds a message is left unread before anyone is told about it."
  def delay_seconds, do: @delay_seconds

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"thread_id" => thread_id, "side" => side} = args}) do
    with {:ok, side} <- cast_side(side),
         true <- Conversations.unread_count(thread_id, side) > 0,
         {:ok, person} <- recipient(thread_id, side) do
      now = parse_at(args["at"])

      if Preferences.quiet?(person, :new_message, now) do
        hold_until_morning(thread_id, side, person, now)
      else
        nudge(person, side)
      end
    else
      # Read already, unknown side, or nobody to tell — all fine, all silent.
      _ -> :ok
    end
  end

  # Held, never dropped. Someone who set quiet hours asked not to be woken,
  # not to be kept in the dark — the same message goes out when the window
  # ends.
  #
  # `replace` is load-bearing. This worker's uniqueness covers :scheduled over
  # a 900s window, so a plain insert here conflicts with the nudge that is
  # already in flight and is silently discarded — the merchant would then hear
  # nothing at all, which is the opposite of holding. Replacing moves the
  # existing job's clock instead.
  defp hold_until_morning(thread_id, side, person, now) do
    resume_at = Preferences.quiet_until(person, now)

    %{"thread_id" => thread_id, "side" => to_string(side)}
    |> new(scheduled_at: resume_at, replace: [scheduled: [:scheduled_at]])
    |> Oban.insert()

    :ok
  end

  # The clock is an argument so a quiet-hours test does not have to run at 2am.
  defp parse_at(nil), do: DateTime.utc_now()

  defp parse_at(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, at, _offset} -> at
      _ -> DateTime.utc_now()
    end
  end

  defp nudge(person, _side) do
    # Preferences rather than Reach alone: this is the one notification that
    # costs the merchant money on every send, fired by the chattiest event in
    # the system, so "I do not want an SMS for every message" has to mean it.
    # Preferences already intersects with Reach, so a phone is still required.
    if :sms in Preferences.channels_for(person, :new_message) do
      sms_provider().send_sms(
        person.phone,
        "You have a new message on Makola. Open your shop to read it.",
        []
      )
    end

    :ok
  end

  defp recipient(thread_id, side) do
    case Ash.get(Conversations.Thread, thread_id, authorize?: false) do
      {:ok, thread} -> load_side(thread, side)
      _ -> :error
    end
  end

  defp load_side(%{merchant_id: merchant_id}, :merchant) when not is_nil(merchant_id) do
    fetch(Emakola.Accounts.Merchant, merchant_id)
  end

  defp load_side(%{store_id: store_id}, :merchant) when not is_nil(store_id) do
    # A shop thread's merchant is whoever the store belongs to, via the
    # membership bridge. Owner first — a shop with staff should nudge the
    # person who owns it, not whoever happened to be added first.
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(store_id == ^store_id)
    |> Ash.Query.sort(role: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %{merchant_id: merchant_id}} -> fetch(Emakola.Accounts.Merchant, merchant_id)
      _ -> :error
    end
  end

  defp load_side(%{customer_id: customer_id}, :customer) when not is_nil(customer_id) do
    fetch(Emakola.Customers.Customer, customer_id)
  end

  # Staff read the dashboard; there is nobody to SMS.
  defp load_side(_thread, _side), do: :error

  defp fetch(resource, id) do
    case Ash.get(resource, id, authorize?: false) do
      {:ok, record} -> {:ok, record}
      _ -> :error
    end
  end

  # The side arrives as a string from the job args — never String.to_atom on
  # anything that reached us from outside.
  defp cast_side("merchant"), do: {:ok, :merchant}
  defp cast_side("customer"), do: {:ok, :customer}
  defp cast_side(_other), do: :error

  defp sms_provider do
    Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Channels.SMS)
  end
end
