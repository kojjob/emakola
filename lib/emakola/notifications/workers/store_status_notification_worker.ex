defmodule Emakola.Notifications.Workers.StoreStatusNotificationWorker do
  @moduledoc """
  Oban worker that notifies a merchant when the PLATFORM changes their store's
  lifecycle status (suspended / blocked / archived / reactivated).

  Sends an SMS to the store's `contact_phone` and a plain-text email to its
  `contact_email`, skipping whichever channel the store hasn't filled in. The
  merchant also sees the reason on the lockout screen at next sign-in — this is
  the proactive heads-up.

  Idempotent: re-running re-sends (acceptable for SMS/email), and the `unique`
  window absorbs retry storms and a double-clicked admin action.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 600, fields: [:args]]

  require Ash.Query
  require Logger

  @events [:store_suspended, :store_blocked, :store_archived, :store_reactivated]

  @doc """
  Enqueues a status-change notification. Never raises — a notification failure
  must not break the admin action that triggered it.
  """
  @spec enqueue(binary(), atom()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(store_id, event) when is_binary(store_id) and event in @events do
    %{"store_id" => store_id, "event" => Atom.to_string(event)}
    |> new()
    |> Oban.insert()
  rescue
    exception ->
      Logger.error(
        "[StoreStatusNotificationWorker] enqueue raised: #{Exception.message(exception)}"
      )

      {:error, {:enqueue_raised, Exception.message(exception)}}
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"store_id" => store_id, "event" => event_string}}) do
    event = Emakola.SafeAtom.to_atom_in(event_string, @events, :store_suspended)

    case load_store(store_id) do
      {:ok, store} ->
        maybe_send_sms(store, event)
        maybe_send_email(store, event)
        :ok

      {:error, reason} ->
        Logger.error("[StoreStatusNotificationWorker] store #{store_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ── Private ─────────────────────────────────────────────────────

  defp load_store(store_id) do
    Emakola.Stores.Store
    |> Ash.Query.filter(id == ^store_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :store_not_found}
      {:ok, store} -> {:ok, store}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_send_sms(%{contact_phone: phone} = store, event)
       when is_binary(phone) and phone != "" do
    sms_provider().send_sms(phone, message(store, event), store_id: store.id)
  end

  defp maybe_send_sms(store, _event) do
    Logger.info("[StoreStatusNotificationWorker] no contact_phone for store #{store.id}")
    :ok
  end

  defp maybe_send_email(%{contact_email: email} = store, event)
       when is_binary(email) and email != "" do
    Swoosh.Email.new()
    |> Swoosh.Email.to({store.name || "", email})
    |> Swoosh.Email.from(Emakola.Mailer.from_address("Makola"))
    |> Swoosh.Email.subject(subject(event))
    |> Swoosh.Email.text_body(message(store, event))
    |> Emakola.Mailer.deliver()

    :ok
  end

  defp maybe_send_email(_store, _event), do: :ok

  defp subject(:store_reactivated), do: "Your Makola store is active again"
  defp subject(_event), do: "Your Makola store is unavailable"

  defp message(store, :store_suspended),
    do:
      "#{store.name}: your Makola store has been temporarily suspended and is hidden from customers. Contact support@makola.io for details."

  defp message(store, :store_blocked),
    do:
      "#{store.name}: your Makola store has been blocked and is hidden from customers. Contact support@makola.io."

  defp message(store, :store_archived),
    do: "#{store.name}: your Makola store has been removed. Contact support@makola.io."

  defp message(store, :store_reactivated),
    do: "#{store.name}: your Makola store is active again and visible to customers."

  defp sms_provider do
    Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)
  end
end
