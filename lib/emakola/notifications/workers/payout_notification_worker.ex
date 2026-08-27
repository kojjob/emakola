defmodule Emakola.Notifications.Workers.PayoutNotificationWorker do
  @moduledoc """
  Notifies a merchant when their payout has been paid out.

  Sends an SMS to the store's `contact_phone` and a plain-text email to its
  `contact_email`, skipping whichever channel the store hasn't filled in. Mirrors
  `StoreStatusNotificationWorker`.

  Keyed on `payout_id` so two payouts to the same store don't deduplicate each
  other and a re-fired `transfer.success` webhook can't double-notify within the
  unique window.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 600, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Templates

  @doc """
  Enqueues a payout-paid notification. Never raises — a notification failure must
  not break the webhook/transfer flow that triggered it.
  """
  @spec enqueue(binary()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(payout_id) when is_binary(payout_id) do
    %{"payout_id" => payout_id}
    |> new()
    |> Oban.insert()
  rescue
    exception ->
      Logger.error("[PayoutNotificationWorker] enqueue raised: #{Exception.message(exception)}")
      {:error, {:enqueue_raised, Exception.message(exception)}}
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"payout_id" => payout_id}, attempt: attempt}) do
    with {:ok, payout} when not is_nil(payout) <- get_payout(payout_id),
         {:ok, store} <- load_store(payout.store_id) do
      # Attempt both channels; fail the job only if an ATTEMPTED send errored so
      # Oban retries a transient outage. A skipped channel returns :ok.
      # The bell first: free, instant, and it does not depend on the merchant
      # having a phone number or an SMS provider being configured. First
      # attempt only — the :notify create has no uniqueness, so a retry after
      # a failed send would mint the bell row again.
      if attempt <= 1 do
        Emakola.Notifications.notify_store(store.id, :payout_sent, %{
          title: "Payout sent",
          action_url: "/admin/payouts"
        })
      end

      results = [maybe_send_sms(store, payout), maybe_send_email(store, payout)]

      if Enum.any?(results, &match?({:error, _}, &1)) do
        Logger.error(
          "[PayoutNotificationWorker] delivery failed for payout #{payout_id}: #{inspect(results)}"
        )

        {:error, :notification_delivery_failed}
      else
        :ok
      end
    else
      # Payout or store gone — nothing to notify.
      _ -> :ok
    end
  end

  # ── Private ─────────────────────────────────────────────────────

  defp get_payout(id) do
    Emakola.Payments.get_payout(id, authorize?: false, not_found_error?: false)
  end

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

  defp maybe_send_sms(%{contact_phone: phone} = store, payout)
       when is_binary(phone) and phone != "" do
    sms_provider().send_sms(phone, Templates.payout_paid_merchant_sms(payout, store),
      store_id: store.id
    )
  end

  defp maybe_send_sms(store, _payout) do
    Logger.info("[PayoutNotificationWorker] no contact_phone for store #{store.id}")
    :ok
  end

  defp maybe_send_email(%{contact_email: email} = store, payout)
       when is_binary(email) and email != "" do
    Swoosh.Email.new()
    |> Swoosh.Email.to({store.name || "", email})
    |> Swoosh.Email.from(Emakola.Mailer.from_address("Makola"))
    |> Swoosh.Email.subject("Your Makola payout is complete")
    |> Swoosh.Email.text_body(Templates.payout_paid_merchant_sms(payout, store))
    |> Emakola.Mailer.deliver()
  end

  defp maybe_send_email(_store, _payout), do: :ok

  defp sms_provider do
    Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)
  end
end
