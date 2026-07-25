defmodule Emakola.Payments.RefundService do
  @moduledoc """
  Merchant-initiated refunds against the order's original charge.

  The service only ASKS the gateway. It never writes `payment.refunded_amount`:
  gateway refunds are asynchronous (Paystack accepts the request, then delivers
  `refund.processed` later), and that webhook is the single writer of the refund
  ledger. Writing the ledger here too would double-count every refund.

  The webhook writes payment ledger state ONLY — it does not touch the Return.
  An approved return therefore stays `:approved` until the merchant confirms the
  money landed and presses "Mark as Refunded" on the returns page.

  Approving claims the Return row `FOR UPDATE` and re-reads its status from the
  database before the gateway is asked, so two merchants (or two tabs, or a
  double click) holding the same stale struct cannot refund a customer twice.
  The claim, the approval and the gateway call share one transaction: if the
  gateway refuses, nothing moves.

  The approval is written BEFORE the gateway is asked, and rolled back if the
  gateway refuses. The reverse order looks safer but is not: a refund the
  gateway accepted cannot be un-asked, so a failing approve after acceptance
  (an over-long `admin_notes` is enough) would roll the return back to
  `:requested` with the customer's money already moving, and the merchant's
  natural retry would refund them a second time. Only the DB write can be
  undone, so it runs first and the irreversible step runs last.

  On acceptance the return is approved, recording the amount, the merchant's
  notes and whether the supplier is at fault (`refund_dispatch_fee?`, which
  waives dispatch-fee protection when the splits are reversed).

  Cash-on-delivery orders never created a Payment, so there is no charge to
  reverse: the return is approved with no gateway call and the merchant hands
  the cash back out of band.
  """

  require Ash.Query

  alias Emakola.Orders.Return
  alias Emakola.Payments.Gateways

  @approve_fields [:admin_notes, :refund_amount, :refund_dispatch_fee?]

  @doc """
  Requests a refund of `refund_amount` pesewas for `return`'s order, then
  approves the return.

  Returns `{:ok, return}`, or `{:error, reason}` where reason is
  `:no_return_selected`, `:return_not_found`, `:already_processed`,
  `:payment_not_found`, `:invalid_amount`, `:amount_exceeds_refundable`,
  `:gateway_unsupported`, or whatever the gateway refused with. Nothing is
  approved and no ledger state moves unless the gateway accepts.
  """
  def issue(actor, return, params, gateway \\ nil)

  def issue(_actor, nil, _params, _gateway), do: {:error, :no_return_selected}

  def issue(actor, return, params, gateway) do
    Emakola.Repo.transaction(fn ->
      with {:ok, claimed} <- claim(return.id),
           {:ok, payment} <- payment_for(actor, claimed),
           :ok <- validate_amount(payment, params[:refund_amount]),
           {:ok, approved} <- approve(actor, claimed, params),
           :ok <- request_refund(payment, params[:refund_amount], gateway) do
        approved
      else
        {:error, reason} -> Emakola.Repo.rollback(reason)
      end
    end)
  end

  # The caller's struct is whatever their page last rendered, so the status
  # guard has to run against the row itself. `FOR UPDATE` holds it for the rest
  # of the transaction — a concurrent approve blocks here, then re-reads and
  # finds the return already approved instead of refunding the customer again.
  defp claim(return_id) do
    Return
    |> Ash.Query.filter(id == ^return_id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %Return{status: :requested} = fresh} -> {:ok, fresh}
      {:ok, %Return{}} -> {:error, :already_processed}
      _ -> {:error, :return_not_found}
    end
  end

  @doc """
  The charge a refund for `order_id` would reverse, or `nil` when the order was
  never captured (cash on delivery).

  Public so the returns page can show the merchant the same charge — and the
  same refundable balance — the service will act on.
  """
  def captured_payment(order_id, opts) do
    case Emakola.Payments.list_captured_payments_by_order(order_id, opts) do
      # `:captured_by_order` sorts oldest first, so this is the charge that
      # settled the order. An order should never hold two captured charges;
      # if a double charge ever does, refunding the settling one keeps the
      # refund aligned with the splits the webhook reverses.
      {:ok, payments} -> {:ok, List.first(payments)}
      {:error, reason} -> {:error, reason}
    end
  end

  # An order can hold more than one Payment row — a failed attempt leaves its
  # row behind when the customer retries checkout — so the refund targets the
  # order's captured charge rather than assuming a single row. The read runs as
  # the merchant against the return's store, so a merchant without a membership
  # there never learns whether the charge exists. `{:ok, nil}` is the ordinary
  # cash-on-delivery case; only a failed read is `:payment_not_found`.
  defp payment_for(actor, return) do
    case captured_payment(return.order_id, actor: actor, tenant: return.store_id) do
      {:ok, payment} -> {:ok, payment}
      _ -> {:error, :payment_not_found}
    end
  end

  defp validate_amount(_payment, amount) when not is_integer(amount) or amount <= 0,
    do: {:error, :invalid_amount}

  # No charge means no refundable balance to measure the amount against.
  defp validate_amount(nil, _amount), do: :ok

  defp validate_amount(payment, amount) do
    refundable = payment.amount - (payment.refunded_amount || 0)

    if amount <= refundable, do: :ok, else: {:error, :amount_exceeds_refundable}
  end

  defp request_refund(nil, _amount, _gateway), do: :ok

  defp request_refund(payment, amount, gateway) do
    module = gateway || gateway_for(payment)

    case module.process_refund(payment.gateway_reference, amount) do
      {:ok, _response} -> :ok
      # Hubtel has no refund API — the merchant has to issue it in the
      # provider's own dashboard.
      {:error, :not_supported} -> {:error, :gateway_unsupported}
      {:error, reason} -> {:error, reason}
    end
  end

  defp approve(actor, return, params) do
    Emakola.Orders.approve_return(return, Map.take(params, @approve_fields),
      actor: actor,
      tenant: return.store_id
    )
  end

  # The refund goes back through the gateway that took the money — a Hubtel
  # charge cannot be reversed through Paystack. Public so the routing decision
  # is testable without a live gateway.
  @doc false
  def gateway_for(%{gateway: :hubtel}), do: Gateways.Hubtel

  def gateway_for(_payment),
    do: Application.get_env(:emakola, :payment_gateway, Gateways.Paystack)
end
