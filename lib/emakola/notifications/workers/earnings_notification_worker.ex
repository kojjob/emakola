defmodule Emakola.Notifications.Workers.EarningsNotificationWorker do
  @moduledoc """
  Oban worker for the `:earnings_accrued` notification (money-surfaces PR-2
  Task 3) — tells a merchant money arrived without them opening the admin.

  Enqueued by `Emakola.Notifications.Dispatcher.dispatch_earnings/2`, once
  per (payment, recipient store) pair whose `PaymentSplit` this call settled
  fresh — see `Emakola.Payments.Workers.PaystackWebhookHandler.settle_splits/1`.

  Loads the payment and recipient store fresh at send time (mirroring
  `SusuNotificationWorker`'s discipline) and computes the net amount via
  `PaymentSplit.frozen_paid_amount/1` — THE single formula authority — at
  that moment, so a delayed Oban run still reports the final, post-recovery
  net rather than a value stashed at enqueue time.

  SMS-only, matching every other merchant-facing accrual/payout notification
  in this module.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 86_400, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Templates
  alias Emakola.Payments
  alias Emakola.Payments.PaymentSplit
  alias Emakola.Payments.PayoutService
  alias Emakola.Payments.Payment
  alias Emakola.Stores.Store

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"payment_id" => payment_id, "recipient_store_id" => recipient_store_id}
      }) do
    with {:ok, payment} <- load_payment(payment_id),
         {:ok, store} <- load_store(recipient_store_id) do
      send_sms(payment, store, recipient_store_id)
      :ok
    else
      {:error, reason} ->
        Logger.error(
          "[EarningsNotificationWorker] failed for payment #{payment_id} / " <>
            "recipient #{recipient_store_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # ── Private ─────────────────────────────────────────────────────

  defp load_payment(payment_id) do
    Payment
    |> Ash.Query.filter(id == ^payment_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :payment_not_found}
      {:ok, payment} -> {:ok, payment}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_store(store_id) do
    Store
    |> Ash.Query.filter(id == ^store_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :store_not_found}
      {:ok, store} -> {:ok, store}
      {:error, reason} -> {:error, reason}
    end
  end

  defp send_sms(payment, %{contact_phone: phone} = store, recipient_store_id)
       when is_binary(phone) and phone != "" do
    net_amount = net_amount(payment.id, recipient_store_id)
    source = source_description(payment, recipient_store_id)
    momo_ready? = PayoutService.momo_destination?(recipient_store_id)

    message = Templates.earnings_accrued_sms(store, net_amount, source, momo_ready?)
    sms_provider().send_sms(phone, message, store_id: recipient_store_id)
  end

  defp send_sms(_payment, store, _recipient_store_id) do
    Logger.info("[EarningsNotificationWorker] no contact_phone for store #{store.id}, skipping")
  end

  # The net actually paid to this recipient for this payment — summed over
  # every split matching (payment, recipient), via the frozen formula, not
  # raw `amount` (a prior reversal/recovery must be reflected).
  defp net_amount(payment_id, recipient_store_id) do
    {:ok, splits} = Payments.list_payment_splits(payment_id, authorize?: false)

    splits
    |> Enum.filter(&(&1.recipient_store_id == recipient_store_id))
    |> Enum.map(&PaymentSplit.frozen_paid_amount/1)
    |> Enum.sum()
  end

  defp source_description(%{store_id: source_store_id}, recipient_store_id)
       when source_store_id == recipient_store_id do
    "your sale"
  end

  defp source_description(%{store_id: source_store_id}, _recipient_store_id) do
    case load_store(source_store_id) do
      {:ok, source_store} -> "resale via #{source_store.name}"
      _ -> "resale via another store"
    end
  end

  defp sms_provider do
    Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)
  end
end
