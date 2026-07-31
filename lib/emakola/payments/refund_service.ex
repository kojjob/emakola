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

  ## Buyer-protection hold

  The gateway accepting a refund request is NOT proof the refund succeeded:
  Paystack refund-create normally returns immediately with the refund still
  `pending`, resolving asynchronously — and can still fail. This service
  therefore never closes a `ProtectionHold` itself (mirrors the "don't
  double-write the ledger" discipline above). When this request would fully
  refund a payment carrying a `:held` hold (exhausts the remaining
  refundable balance), it stashes `resolution` onto
  `payment.metadata["protection_resolution"]` — intent, not the close. Only
  `PaystackWebhookHandler.handle_refund_processed/1`, once `refund.processed`
  confirms the cumulative refund reached the full amount, actually closes
  the hold, reading the stashed resolution back out. `resolution` (opt,
  default `:merchant_refunded`) is Task 12's seam: pass
  `resolution: :refunded_by_staff` for a staff-initiated refund through this
  same service.

  Task 12's other seam: `Return`/`Payment` policies only grant a `Merchant`
  actor with store access (or a `Customer` on their own row) — the platform
  staff actor (`Emakola.Accounts.User`) matches neither, so it hits the same
  default-deny an unrelated merchant would. Pass `authorize?: false` (opt,
  default `true` — the merchant flow is unaffected) for a staff-initiated
  refund, matching the `authorize?: false` convention every other
  platform-staff action in this codebase uses at its call site.
  """

  require Ash.Query

  alias Emakola.Orders.Return
  alias Emakola.Payments.Gateways
  alias Emakola.Payments.ProtectionHolds

  @approve_fields [:admin_notes, :refund_amount, :refund_dispatch_fee?]

  @doc """
  Requests a refund of `refund_amount` pesewas for `return`'s order, then
  approves the return.

  Returns `{:ok, return}`, or `{:error, reason}` where reason is
  `:no_return_selected`, `:return_not_found`, `:already_processed`,
  `:payment_not_found`, `:invalid_amount`, `:amount_exceeds_refundable`,
  `:gateway_unsupported`, or whatever the gateway refused with. Nothing is
  approved and no ledger state moves unless the gateway accepts.

  `opts[:resolution]` (default `:merchant_refunded`) is the resolution
  later stamped on a buyer-protection hold this refund fully covers, once
  the webhook confirms it — see the moduledoc's "Buyer-protection hold"
  section.

  `opts[:authorize?]` (default `true`) is forwarded to the internal
  `Payment`/`Return` reads and writes — pass `false` for a platform-staff
  actor, which has no Ash policy grant on either resource (see the
  moduledoc's "Task 12's other seam").
  """
  def issue(actor, return, params, gateway \\ nil, opts \\ [])

  def issue(_actor, nil, _params, _gateway, _opts), do: {:error, :no_return_selected}

  def issue(actor, return, params, gateway, opts) do
    resolution = Keyword.get(opts, :resolution, :merchant_refunded)
    authorize? = Keyword.get(opts, :authorize?, true)

    Emakola.Repo.transaction(fn ->
      with {:ok, claimed} <- claim(return.id),
           {:ok, payment} <- payment_for(actor, claimed, authorize?),
           :ok <- validate_amount(payment, params[:refund_amount]),
           {:ok, approved} <- approve(actor, claimed, params, authorize?),
           :ok <- request_refund(payment, params[:refund_amount], gateway) do
        stash_protection_resolution(payment, params[:refund_amount], resolution)
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
  defp payment_for(actor, return, authorize?) do
    case captured_payment(return.order_id,
           actor: actor,
           tenant: return.store_id,
           authorize?: authorize?
         ) do
      {:ok, payment} -> {:ok, payment}
      _ -> {:error, :payment_not_found}
    end
  end

  defp validate_amount(_payment, amount) when not is_integer(amount) or amount <= 0,
    do: {:error, :invalid_amount}

  # No charge means no refundable balance to measure the amount against.
  defp validate_amount(nil, _amount), do: :ok

  defp validate_amount(payment, amount) do
    if amount <= refundable_balance(payment), do: :ok, else: {:error, :amount_exceeds_refundable}
  end

  defp refundable_balance(payment), do: payment.amount - (payment.refunded_amount || 0)

  # A cash-on-delivery order has no Payment, hence no hold to stash intent on.
  defp stash_protection_resolution(nil, _amount, _resolution), do: :ok

  # "Full" means this request exhausts the remaining refundable balance —
  # already validated as `amount <= refundable_balance(payment)` above, so
  # equality here means nothing is left to refund after this request. Only
  # worth stashing when there's a `:held` hold to eventually close —
  # `ProtectionHolds.stash_refund_resolution/2` checks that.
  defp stash_protection_resolution(payment, amount, resolution) do
    if amount == refundable_balance(payment) do
      ProtectionHolds.stash_refund_resolution(payment, resolution)
    else
      :ok
    end
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

  defp approve(actor, return, params, authorize?) do
    Emakola.Orders.approve_return(return, Map.take(params, @approve_fields),
      actor: actor,
      tenant: return.store_id,
      authorize?: authorize?
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
