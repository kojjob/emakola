defmodule Emakola.Orders.Workers.SupplierSlaWorker do
  @moduledoc """
  Chases a supplier who has not answered, so the merchant does not have to.

  Named for the supplier rather than the fulfilment because
  `Emakola.Workers.FulfillmentWorker` already exists — the two would otherwise
  sit one word apart in every grep and stack trace.

  Queue `:default`, not `:notifications`: this worker stamps and enqueues, it
  never sends, so it keeps the five-wide notifications queue free.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    # MUST stay strictly below the cron interval. Copying ProtectionSweepWorker's
    # 3600 onto a half-hourly cron silently swallows every second run, and no
    # test would catch it because tests call perform/1 directly. 1800 sits
    # exactly on the boundary, which is the epoch-bucket flake this codebase has
    # already been bitten by; 1500 leaves five minutes either side.
    # states: :incomplete rather than an explicit list — spelling it out omits
    # :retryable and :suspended, so a job mid-backoff would not block a
    # duplicate insert.
    unique: [period: 1500, fields: [:args], states: :incomplete]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Workers.SupplierNotificationWorker
  alias Emakola.Orders.Fulfillment

  @respond_hours 6

  # Waiting on the SUPPLIER. An accepted fulfilment leaves the ladder even
  # though its status is still :notified — hence is_nil(accepted_at) rather than
  # a status check alone. :declined and :shipped have answered; :cancelled is
  # over.
  @awaiting [:pending, :notified]

  @doc """
  Hours a supplier has to answer before the first chase.

  Single source, also read by `Emakola.Orders.Changes.StampSupplierRespondBy`
  when it starts the clock — the same shape as
  `ProtectionSweepWorker.release_days/0`.
  """
  def respond_hours, do: @respond_hours

  # Cooldowns between rungs. Short enough that a merchant hears about a stuck
  # order the same day, long enough that a supplier who is simply asleep is not
  # escalated past.
  @merchant_alert_after_hours 6
  @terminal_after_hours 12

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    escalate_all(rung_one_due(), 1, &chase_supplier/1)
    escalate_all(rung_two_due(), 2, &alert_merchant/1)
    escalate_all(rung_three_due(), 3, &alert_merchant/1)
    :ok
  end

  # ── Candidates ──────────────────────────────────────────────────
  #
  # Three queries rather than one: the cooldown differs per rung, so a single
  # expression cannot say it cleanly and filtering in Elixir would pull the
  # whole table. All three share the awaiting/accepted/supplier guards.

  defp rung_one_due do
    now = DateTime.utc_now()

    awaiting()
    |> Ash.Query.filter(escalation_level == 0 and not is_nil(respond_by) and respond_by < ^now)
    |> Ash.read!(authorize?: false)
  end

  defp rung_two_due do
    cutoff = DateTime.add(DateTime.utc_now(), -@merchant_alert_after_hours, :hour)

    awaiting()
    |> Ash.Query.filter(escalation_level == 1 and escalated_at < ^cutoff)
    |> Ash.read!(authorize?: false)
  end

  defp rung_three_due do
    cutoff = DateTime.add(DateTime.utc_now(), -@terminal_after_hours, :hour)

    awaiting()
    |> Ash.Query.filter(escalation_level == 2 and escalated_at < ^cutoff)
    |> Ash.read!(authorize?: false)
  end

  defp awaiting do
    Fulfillment
    |> Ash.Query.filter(status in ^@awaiting and is_nil(accepted_at) and not is_nil(supplier_id))
    |> Ash.Query.load([:supplier, :order])
    |> Ash.Query.limit(200)
  end

  # ── Escalation ──────────────────────────────────────────────────

  defp escalate_all(fulfillments, to_level, action) do
    Enum.each(fulfillments, fn fulfillment ->
      case Emakola.Orders.escalate_fulfillment(fulfillment, %{to_level: to_level},
             authorize?: false
           ) do
        {:ok, escalated} ->
          action.(escalated)

        # Someone else got there first — an Oban retry overlapping the next
        # tick. The row already moved, so there is nothing to send.
        {:error, _reason} ->
          :ok
      end
    end)
  end

  # Bell and PubSub only — see Dispatcher.dispatch_supplier_overdue/2 for why
  # there is no SMS rung.
  defp alert_merchant(%{order: order} = fulfillment) when not is_nil(order) do
    Emakola.Notifications.Dispatcher.dispatch_supplier_overdue(order, supplier_name(fulfillment))
  end

  defp alert_merchant(_fulfillment), do: :ok

  defp supplier_name(%{supplier: %{name: name}}) when is_binary(name), do: name
  defp supplier_name(_fulfillment), do: "Your supplier"

  # The "escalation" arg is a real value rather than the nonce the merchant's
  # manual resend uses to DEFEAT uniqueness: here we want
  # SupplierNotificationWorker's own unique window to collapse duplicates.
  defp chase_supplier(fulfillment) do
    %{"fulfillment_id" => fulfillment.id, "escalation" => 1}
    |> SupplierNotificationWorker.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "[supplier_sla] could not enqueue chase for #{fulfillment.id}: #{inspect(reason)}"
        )

        :ok
    end
  end
end
