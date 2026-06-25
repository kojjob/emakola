defmodule Emakola.Payments.Workers.PaystackWebhookHandler do
  @moduledoc """
  Oban worker that processes Paystack webhook events — the single authority
  for Paystack webhook handling. Enqueued by `EmakolaWeb.WebhookController`
  after HMAC verification by `Emakola.Payments.Gateways.Paystack`.

  Handles:
  - charge.success — marks payment success, confirms order, settles dropship
    splits, broadcasts to polling LiveViews
  - charge.failed — marks payment failed, broadcasts
  - refund.processed — marks payment refunded, reverses splits, broadcasts
  - transfer.success / transfer.failed / transfer.reversed — finalizes merchant payouts

  Idempotent: deduplicated at insert time (24h unique window) and guarded by a
  terminal-state check inside `perform/1`.
  """

  use Oban.Worker,
    queue: :webhooks,
    max_attempts: 5,
    # Paystack replays the same payload on retry. Deduplicate at insert
    # time within a 24h window — `Oban.insert!/1` returns the existing
    # job rather than creating a duplicate. The terminal-state guard
    # inside perform/1 remains as defense-in-depth for non-identical
    # jobs that happen to converge on the same payment.
    unique: [period: 86_400, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Payments.Payment

  @terminal_states [:success, :failed, :refunded]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => event, "data" => data}}) do
    case event do
      "charge.success" ->
        handle_charge_success(data)

      "charge.failed" ->
        handle_charge_failed(data)

      "refund.processed" ->
        handle_refund_processed(data)

      "transfer.success" ->
        finalize_payout(data, :paid)

      "transfer.failed" ->
        finalize_payout(data, :failed)

      "transfer.reversed" ->
        finalize_payout(data, :failed)

      _unknown ->
        Logger.warning("[paystack_webhook] unhandled event: #{inspect(event)}")
        :ok
    end
  end

  # Finalize a merchant payout from a transfer webhook. `data["reference"]` is the
  # payout's transfer_reference. Unknown references (transfers not initiated by us)
  # are ignored.
  defp finalize_payout(data, outcome) do
    case Emakola.Payments.get_payout_by_transfer_reference(data["reference"],
           authorize?: false,
           not_found_error?: false
         ) do
      {:ok, %{status: :paid}} ->
        :ok

      {:ok, %{} = payout} when outcome == :paid ->
        {:ok, _} =
          Emakola.Payments.mark_payout_paid(payout, %{gateway_response: data}, authorize?: false)

        Emakola.Notifications.Workers.PayoutNotificationWorker.enqueue(payout.id)
        :ok

      {:ok, %{} = payout} ->
        {:ok, _} =
          Emakola.Payments.mark_payout_failed(
            payout,
            %{failure_reason: data["status"] || "transfer failed", gateway_response: data},
            authorize?: false
          )

        :ok

      _ ->
        :ok
    end
  end

  defp handle_charge_success(data) do
    reference = data["reference"]

    with {:ok, payment} <- find_payment(reference),
         false <- terminal?(payment) do
      updated =
        payment
        |> Ash.Changeset.for_update(:mark_success, %{gateway_response: data})
        |> Ash.update!(authorize?: false)

      # Confirm the associated order if present
      maybe_confirm_order(payment.order_id)

      # Settle any dropship split allocations — the gateway has applied the
      # split, so record each as settled.
      settle_splits(payment)

      # Notify any LiveView still polling on this reference so the
      # customer sees confirmation immediately rather than waiting up
      # to 3s for the next poll cycle.
      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        "payment:#{reference}",
        {:payment_succeeded, reference, updated}
      )

      :ok
    else
      true -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_charge_failed(data) do
    reference = data["reference"]

    with {:ok, payment} <- find_payment(reference),
         false <- terminal?(payment) do
      updated =
        payment
        |> Ash.Changeset.for_update(:mark_failed, %{gateway_response: data})
        |> Ash.update!(authorize?: false)

      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        "payment:#{reference}",
        {:payment_failed, reference, updated}
      )

      :ok
    else
      true -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_refund_processed(data) do
    reference = get_in(data, ["transaction", "reference"])
    refund_amount = data["amount"]

    with {:ok, payment} <- find_payment(reference),
         false <- payment.status == :refunded,
         {:ok, updated} <-
           payment
           |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: refund_amount})
           |> Ash.update(authorize?: false) do
      # Reverse the split allocations so a clawback can recover each party's
      # share against future payouts.
      reverse_splits(payment)

      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        "payment:#{reference}",
        {:payment_refunded, reference, updated}
      )

      :ok
    else
      # Already refunded — idempotent success
      true ->
        :ok

      # Refund rejected by business rules (payment not :success, or amount
      # exceeds original). The money already moved at the gateway, so log
      # loudly — retrying won't fix a validation failure.
      {:error, %Ash.Error.Invalid{} = error} ->
        Logger.warning(
          "refund.processed rejected for payment #{reference}: #{Exception.message(error)}"
        )

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp settle_splits(payment) do
    payment
    |> payment_splits()
    |> Enum.filter(&(&1.status == :pending))
    |> Enum.each(fn split ->
      split
      |> Ash.Changeset.for_update(:mark_settled, %{})
      |> Ash.update!(authorize?: false)
    end)
  end

  defp reverse_splits(payment) do
    payment
    |> payment_splits()
    |> Enum.reject(&(&1.status == :reversed))
    |> Enum.each(fn split ->
      split
      |> Ash.Changeset.for_update(:mark_reversed, %{})
      |> Ash.update!(authorize?: false)
    end)
  end

  defp payment_splits(payment) do
    {:ok, splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)
    splits
  end

  defp find_payment(reference) do
    case Payment
         |> Ash.Query.filter(gateway_reference == ^reference)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> {:error, :payment_not_found}
      {:ok, payment} -> {:ok, payment}
      {:error, reason} -> {:error, reason}
    end
  end

  defp terminal?(%{status: status}) when status in @terminal_states, do: true
  defp terminal?(_), do: false

  defp maybe_confirm_order(nil), do: :ok

  defp maybe_confirm_order(order_id) do
    case Emakola.Orders.Order
         |> Ash.Query.filter(id == ^order_id)
         |> Ash.read_one(authorize?: false) do
      {:ok, %{status: :pending} = order} ->
        result =
          order
          |> Ash.Changeset.for_update(:confirm, %{})
          |> Ash.update(authorize?: false)

        case result do
          {:ok, confirmed_order} ->
            try do
              Emakola.Notifications.Dispatcher.dispatch(confirmed_order, :order_confirmed)
            rescue
              _ -> :ok
            end

            {:ok, confirmed_order}

          error ->
            error
        end

      _ ->
        :ok
    end
  end
end
