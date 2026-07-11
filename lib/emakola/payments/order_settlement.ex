defmodule Emakola.Payments.OrderSettlement do
  @moduledoc """
  Order-aware glue between a placed order and the payment split engine.

  Loads an order's line items, decides how the customer's charge is split, and
  exposes:

    * `prepare/2` — `{:split, %{total, allocations, shares, mode}}` or
      `{:no_split, reason}`. Two split modes:
        - `:dropship_split` (SP5) — trustless margin split across wholesaler(s) +
          dropshipper when every party has a verified subaccount.
        - `:platform_fee` — a normal own-stock order: the merchant's net goes to
          their verified subaccount, the platform keeps its transaction fee.
      `shares` is the gateway-ready list of `%{subaccount, share}` for
      `initiate_payment`; the platform's cut is never a share (it stays in the
      platform main account as the split remainder).
    * `record_splits!/2` — persists one `PaymentSplit` per allocation once the
      payment record exists.
  """

  require Ash.Query

  alias Emakola.Payments.DropshipSettlement
  alias Emakola.Payments.PlatformFee
  alias Emakola.Payments.RefundLiability

  def prepare(order_id, store_id) do
    order = Ash.get!(Emakola.Orders.Order, order_id, authorize?: false, tenant: store_id)
    line_items = load_line_items(order_id, store_id)

    case DropshipSettlement.prepare(line_items, store_id, fee_rate_bps: fee_rate_bps()) do
      {:split, %{allocations: allocations}} ->
        # The split is computed on the subtotal; the customer is charged the
        # order total. Delivery (minus any discount) belongs to the dropshipper,
        # so fold it into their share — otherwise that money would fall to the
        # platform's main account as the split remainder.
        adjustment = (order.delivery_fee || 0) - (order.discount_amount || 0)

        allocations = adjust_dropshipper(allocations, adjustment)

        if valid_shares?(allocations) do
          allocations =
            allocations
            |> Emakola.Suppliers.PartnerCredit.carve_sales_proceeds(store_id)
            |> RefundLiability.reserve!()

          {:split,
           %{
             total: order.total,
             allocations: allocations,
             shares: gateway_shares(allocations),
             mode: :dropship_split
           }}
        else
          {:no_split, :unrepresentable_split}
        end

      # A normal own-stock order: take the platform's transaction fee and route
      # the merchant their net via their verified subaccount (same split-remainder
      # model — the platform's fee stays in the main account).
      {:no_split, :no_dropship_items} ->
        prepare_platform_fee(order, store_id)

      {:no_split, reason} ->
        {:no_split, reason}
    end
  end

  defp prepare_platform_fee(order, store_id) do
    case verified_subaccount(store_id) do
      {:ok, code} ->
        %{fee: fee, net: net} = PlatformFee.calculate(order.total, platform_fee_rate_bps())

        if net > 0 do
          allocations =
            [
              %{
                role: :merchant,
                recipient_store_id: store_id,
                amount: net,
                subaccount_code: code
              },
              %{role: :platform, recipient_store_id: nil, amount: fee, subaccount_code: nil}
            ]
            |> Emakola.Suppliers.PartnerCredit.carve_sales_proceeds(store_id)
            |> RefundLiability.reserve!()

          {:split,
           %{
             total: order.total,
             allocations: allocations,
             shares: gateway_shares(allocations),
             mode: :platform_fee
           }}
        else
          {:no_split, :unrepresentable_split}
        end

      {:error, :payout_unverified} ->
        {:no_split, :payout_unverified}
    end
  end

  # Mirrors DropshipSettlement's notion of a usable payout account.
  defp verified_subaccount(store_id) do
    case Emakola.Stores.get_payout_account(store_id, authorize?: false) do
      {:ok, %{verification_status: :verified, subaccount_code: code}} when is_binary(code) ->
        {:ok, code}

      _ ->
        {:error, :payout_unverified}
    end
  end

  def record_splits!(payment, allocations) do
    Enum.each(allocations, fn alloc ->
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
          recovery_amount: Map.get(alloc, :recovery_amount, 0),
          recovery_breakdown: Map.get(alloc, :recovery_breakdown, %{"items" => []})
        },
        authorize?: false
      )
    end)
  end

  def release_recovery_reservations!(allocations), do: RefundLiability.release!(allocations)

  defp adjust_dropshipper(allocations, 0), do: allocations

  defp adjust_dropshipper(allocations, adjustment) do
    Enum.map(allocations, fn
      %{role: :dropshipper} = alloc -> %{alloc | amount: alloc.amount + adjustment}
      alloc -> alloc
    end)
  end

  # Paystack rejects negative or zero flat shares; if an aggressive discount
  # drives the dropshipper's share non-positive, fall back to the manual ledger.
  defp valid_shares?(allocations) do
    allocations
    |> Enum.filter(& &1[:subaccount_code])
    |> Enum.all?(&(&1.amount > 0))
  end

  # Only allocations with a subaccount become gateway shares. The platform's
  # cut is the unassigned remainder, kept by the main account.
  defp gateway_shares(allocations) do
    allocations
    |> Enum.filter(&(&1[:subaccount_code] && &1.amount > 0))
    |> Enum.map(&%{subaccount: &1.subaccount_code, share: &1.amount})
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
