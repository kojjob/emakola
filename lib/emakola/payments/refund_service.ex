defmodule Emakola.Payments.RefundService do
  @moduledoc """
  Merchant-initiated refunds against the order's original charge.

  The service only ASKS the gateway. It never writes `payment.refunded_amount`:
  gateway refunds are asynchronous (Paystack accepts the request, then delivers
  `refund.processed` later), and that webhook is the single writer of the refund
  ledger — including moving the return to `:refunded`. Writing the ledger here
  too would double-count every refund.

  On acceptance the return is approved, recording the amount, the merchant's
  notes and whether the supplier is at fault (`refund_dispatch_fee?`, which
  waives dispatch-fee protection when the splits are reversed).
  """

  alias Emakola.Payments.Gateways

  @approve_fields [:admin_notes, :refund_amount, :refund_dispatch_fee?]

  @doc """
  Requests a refund of `refund_amount` pesewas for `return`'s order, then
  approves the return.

  Returns `{:ok, return}`, or `{:error, reason}` where reason is
  `:payment_not_found`, `:invalid_amount`, `:amount_exceeds_refundable`,
  `:gateway_unsupported`, or whatever the gateway refused with. Nothing is
  approved and no ledger state moves unless the gateway accepts.
  """
  def issue(actor, return, params, gateway \\ nil) do
    with {:ok, payment} <- payment_for(actor, return),
         :ok <- validate_amount(payment, params[:refund_amount]),
         :ok <- request_refund(gateway || gateway_for(payment), payment, params[:refund_amount]) do
      Emakola.Orders.approve_return(return, Map.take(params, @approve_fields),
        actor: actor,
        tenant: return.store_id
      )
    end
  end

  # A merchant order is paid by exactly one charge, found by order_id. The read
  # runs as the merchant against the return's store, so a merchant without a
  # membership there never learns whether the charge exists.
  defp payment_for(actor, return) do
    case Emakola.Payments.get_payment_by_order(return.order_id,
           actor: actor,
           tenant: return.store_id
         ) do
      {:ok, payment} when not is_nil(payment) -> {:ok, payment}
      _ -> {:error, :payment_not_found}
    end
  end

  defp validate_amount(payment, amount) when is_integer(amount) and amount > 0 do
    refundable = payment.amount - (payment.refunded_amount || 0)

    if amount <= refundable, do: :ok, else: {:error, :amount_exceeds_refundable}
  end

  defp validate_amount(_payment, _amount), do: {:error, :invalid_amount}

  defp request_refund(gateway, payment, amount) do
    case gateway.process_refund(payment.gateway_reference, amount) do
      {:ok, _response} -> :ok
      # Hubtel has no refund API — the merchant has to issue it in the
      # provider's own dashboard.
      {:error, :not_supported} -> {:error, :gateway_unsupported}
      {:error, reason} -> {:error, reason}
    end
  end

  # The refund goes back through the gateway that took the money — a Hubtel
  # charge cannot be reversed through Paystack.
  defp gateway_for(%{gateway: :hubtel}), do: Gateways.Hubtel

  defp gateway_for(_payment),
    do: Application.get_env(:emakola, :payment_gateway, Gateways.Paystack)
end
