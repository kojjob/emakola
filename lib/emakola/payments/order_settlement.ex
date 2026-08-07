defmodule Emakola.Payments.OrderSettlement do
  @moduledoc """
  Order-aware glue between a placed order and the payment ledger.

  Single rail (P1, spec 2026-08-07): every charge settles to the platform
  account. `prepare/2` returns:

    * `{:split, %{total, allocations, shares: [], mode: :internal}}` — the
      normal outcome for own-stock AND dropship orders alike. Allocation math
      (fees, delivery fold, dispatch fees, partner-credit carve, refund
      reserve) is unchanged from the gateway era; only the settlement changed.
    * `{:hold, :buyer_protection}` (TC-2) — own-stock only; the charge is
      payout-held and gains no rows until release (rows-at-charge is P2).
    * `{:no_split, reason}` — pathological escapes (allocation_sum_mismatch,
      unrepresentable_split) kept as the legacy fail-safe.

  `record_splits!/2` and `persist_payment/2` are unchanged.
  """

  require Ash.Query
  require Logger

  alias Emakola.Payments.DropshipSettlement
  alias Emakola.Payments.PlatformFee
  alias Emakola.Payments.RefundLiability

  def prepare(order_id, store_id) do
    order = Ash.get!(Emakola.Orders.Order, order_id, authorize?: false, tenant: store_id)
    line_items = load_line_items(order_id, store_id)
    dispatch_fees = load_dispatch_fees(order_id)

    case DropshipSettlement.prepare(line_items, store_id,
           fee_rate_bps: fee_rate_bps(),
           dispatch_fees: dispatch_fees
         ) do
      {:split, _gateway} ->
        # Single rail (P1): the gateway computed a valid dropship split, which
        # proves this is a dropship order — but nothing settles at the gateway
        # any more. prepare_internal re-runs the SAME allocation math
        # (delivery-fee fold, dispatch fees, carve, reserve) on the internal
        # rail. P3 removes this double computation with the gateway path itself.
        prepare_internal(order_id, store_id)

      # A normal own-stock order (no dropship items — dropship always wins,
      # matched above): buyer protection (TC-2), if it applies, still wins —
      # the charge settles with no allocation rows and the payment is flagged
      # payout_held for a later release. Everything else settles internal
      # (single rail, P1): same fee math, rows on the ledger, paid out by
      # MoMo transfer — verification no longer selects a settlement path.
      {:no_split, :no_dropship_items} ->
        if protected?(order, store_id) do
          {:hold, :buyer_protection}
        else
          prepare_internal(order_id, store_id)
        end

      # Verification failures route to the internal rail: the charge settles
      # to the platform account, allocations (incl. the platform fee) are
      # recorded on the ledger, and parties are paid by MoMo transfer once
      # they add a destination. Genuine split failures still fall through to
      # the legacy :none path (no rows, escrow-compatible). Own-stock orders
      # never reach this guard at all (P1): the {:no_split, :no_dropship_items}
      # clause above calls prepare_internal/2 unconditionally now — verification
      # no longer gates it. `:payout_unverified` here is defense-in-depth only
      # — DropshipSettlement remaps it to :dropshipper_payout_unverified at
      # dropship_settlement.ex:56, so it's unreachable in this clause.
      {:no_split, reason}
      when reason in [
             :payout_unverified,
             :dropshipper_payout_unverified,
             :wholesaler_payout_unverified,
             :supplier_not_linked
           ] ->
        prepare_internal(order_id, store_id)

      {:no_split, reason} ->
        {:no_split, reason}
    end
  end

  @doc """
  Internal-rail settlement for a charge that cannot be split at the gateway
  (unverified parties, unlinked suppliers). Same allocation math and fee rates
  as the gateway rail; every allocation is tagged `settlement_method:
  :internal_hold` with no subaccount, and a `:platform` row is always present.
  Returns `shares: []` — nothing is attached to the gateway charge. Routed to
  by `prepare/2`'s verification-failure fallbacks since Phase 3.
  """
  def prepare_internal(order_id, store_id) do
    order = Ash.get!(Emakola.Orders.Order, order_id, authorize?: false, tenant: store_id)
    line_items = load_line_items(order_id, store_id)
    dispatch_fees = load_dispatch_fees(order_id)

    case DropshipSettlement.prepare_internal(line_items, store_id,
           fee_rate_bps: fee_rate_bps(),
           dispatch_fees: dispatch_fees
         ) do
      {:split, %{allocations: allocations}} ->
        # Same delivery-fee fold as the gateway dropship rail.
        adjustment = (order.delivery_fee || 0) - (order.discount_amount || 0)
        finalize_internal(order, store_id, adjust_dropshipper(allocations, adjustment))

      {:no_split, :no_dropship_items} ->
        %{fee: fee, net: net} = PlatformFee.calculate(order.total, platform_fee_rate_bps())

        finalize_internal(order, store_id, [
          %{role: :merchant, recipient_store_id: store_id, amount: net, subaccount_code: nil},
          %{role: :platform, recipient_store_id: nil, amount: fee, subaccount_code: nil}
        ])
    end
  end

  defp finalize_internal(order, store_id, allocations) do
    carved = Emakola.Suppliers.PartnerCredit.carve_sales_proceeds(allocations, store_id)

    cond do
      # An aggressive discount can drive a non-platform allocation negative;
      # the payable ledger must stay non-negative. Checked BEFORE reserve!
      # runs, so a reject here has zero side effects — no stranded
      # reservation. Deliberately `< 0`, not `<= 0`: a zero-amount
      # internal_hold allocation is harmless here — payable_internal's
      # `amount > reversed_amount` filter already excludes it.
      Enum.any?(carved, &(&1.role != :platform and &1.amount < 0)) ->
        {:no_split, :unrepresentable_split}

      not sum_matches_total?(order, carved) ->
        {:no_split, :allocation_sum_mismatch}

      true ->
        reserved = RefundLiability.reserve!(carved)
        allocations = Enum.map(reserved, &internal_hold/1)

        # Backstop only: reserve! cannot itself create negatives (recovery <=
        # amount) or break the sum invariant, so this should never fire. If it
        # somehow does, release what reserve! just persisted rather than
        # stranding the reservation.
        if sum_matches_total?(order, allocations) do
          {:split, %{total: order.total, allocations: allocations, shares: [], mode: :internal}}
        else
          release_recovery_reservations!(reserved)
          {:no_split, :allocation_sum_mismatch}
        end
    end
  end

  # The internal rail holds everything in the platform account: no allocation
  # carries a subaccount (this also overrides the partner-credit carve, which
  # sets the creditor's subaccount unconditionally).
  defp internal_hold(alloc) do
    Map.merge(alloc, %{settlement_method: :internal_hold, subaccount_code: nil})
  end

  # TC-2 Buyer Protection: order has a pay link → the link's `protected`
  # field governs; otherwise the store's `buyer_protection_enabled` setting
  # governs. Same lookup pattern as PayLinkClaim.claim_for_order/1 (no
  # tenant needed — PayLink is global?: true).
  defp protected?(order, store_id) do
    store = Ash.get!(Emakola.Stores.Store, store_id, authorize?: false)

    pay_link =
      order.pay_link_id &&
        Ash.get!(Emakola.Orders.PayLink, order.pay_link_id, authorize?: false)

    Emakola.Payments.Protection.applies?(store, pay_link)
  end

  # Platform rows are always :internal_hold (spec §3 — that money stays in the
  # main account on both rails); every other role defaults to the gateway rail
  # unless the caller sets settlement_method explicitly.
  defp default_settlement_method(:platform), do: :internal_hold
  defp default_settlement_method(_role), do: :gateway_share

  # Idempotent: a retry (checkout crash between payment creation and here, or a
  # partial write) records only the allocations that are missing, keyed the same
  # way as the DB's unique_allocation constraint — so the invariant "splits sum
  # to the charge" survives a crash mid-loop. The constraint itself backstops
  # concurrent double-calls this read-then-write cannot see.
  def record_splits!(payment, allocations) do
    {:ok, existing} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)

    recorded =
      MapSet.new(existing, fn split ->
        {split.role, split.supplier_id, split.credit_agreement_id}
      end)

    allocations
    |> Enum.reject(fn alloc ->
      key = {alloc.role, Map.get(alloc, :supplier_id), Map.get(alloc, :credit_agreement_id)}
      MapSet.member?(recorded, key)
    end)
    |> Enum.each(fn alloc ->
      Emakola.Payments.create_payment_split!(
        %{
          store_id: payment.store_id,
          payment_id: payment.id,
          role: alloc.role,
          recipient_store_id: Map.get(alloc, :recipient_store_id),
          supplier_id: Map.get(alloc, :supplier_id),
          credit_agreement_id: Map.get(alloc, :credit_agreement_id),
          subaccount_code: Map.get(alloc, :subaccount_code),
          amount: alloc.amount,
          settlement_method:
            Map.get(alloc, :settlement_method, default_settlement_method(alloc.role)),
          currency: payment.currency,
          recovery_amount: Map.get(alloc, :recovery_amount, 0),
          recovery_breakdown: Map.get(alloc, :recovery_breakdown, %{"items" => []})
        },
        authorize?: false
      )
    end)
  end

  @doc """
  Creates the payment and records its allocation rows in ONE transaction, so
  the ledger can never observe a payment without its splits (or vice versa).
  Split-less settlements (`{:no_split, _}`, `{:hold, _}`) just create the
  payment. Returns `{:ok, payment}` or `{:error, reason}`.
  """
  def persist_payment(payment_attrs, settlement) do
    Emakola.Repo.transaction(fn ->
      case Emakola.Payments.create_payment(payment_attrs, authorize?: false) do
        {:ok, payment} ->
          persist_allocations!(payment, settlement)
          payment

        {:error, reason} ->
          Emakola.Repo.rollback(reason)
      end
    end)
  end

  defp persist_allocations!(payment, {:split, %{allocations: allocations}}),
    do: record_splits!(payment, allocations)

  defp persist_allocations!(_payment, _settlement), do: :ok

  def release_recovery_reservations!(allocations), do: RefundLiability.release!(allocations)

  # Runtime backstop for the "allocations sum to the charge" invariant, which
  # is otherwise only guaranteed by construction (see SplitCalculator's
  # dispatch_fees docstring for how it can drift). A dispatch fee keyed to a
  # supplier absent from the order's line items is the known way this fires.
  @doc false
  def sum_matches_total?(order, allocations) do
    sum = Enum.sum(Enum.map(allocations, & &1.amount))

    if sum == order.total do
      true
    else
      Logger.error(
        "OrderSettlement allocation sum mismatch for order #{order.id}: " <>
          "allocations sum to #{sum}, order.total is #{order.total}"
      )

      false
    end
  end

  defp adjust_dropshipper(allocations, 0), do: allocations

  defp adjust_dropshipper(allocations, adjustment) do
    Enum.map(allocations, fn
      %{role: :dropshipper} = alloc -> %{alloc | amount: alloc.amount + adjustment}
      alloc -> alloc
    end)
  end

  # Dispatch fee snapshots recorded per supplier at checkout (Task 2), keyed
  # for SplitCalculator to fold into each wholesaler's allocation.
  defp load_dispatch_fees(order_id) do
    for f <- Emakola.Orders.list_fulfillments_by_order!(order_id, authorize?: false),
        f.supplier_id,
        into: %{},
        do: {f.supplier_id, f.dispatch_fee}
  end

  defp load_line_items(order_id, store_id) do
    Emakola.Orders.LineItem
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.Query.load(:fulfillment)
    |> Ash.read!(authorize?: false, tenant: store_id)
    |> Enum.map(fn li ->
      %{
        unit_price: li.unit_price,
        cost_price: li.cost_price,
        quantity: li.quantity,
        supplier_id: li.fulfillment && li.fulfillment.supplier_id
      }
    end)
  end

  defp fee_rate_bps do
    Application.get_env(:emakola, :dropship_fee_rate_bps, 1000)
  end

  defp platform_fee_rate_bps do
    Application.get_env(:emakola, :platform_fee_rate_bps, 200)
  end
end
