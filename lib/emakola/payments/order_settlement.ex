defmodule Emakola.Payments.OrderSettlement do
  @moduledoc """
  Order-aware glue between a placed order and the dropship split engine (SP5).

  Loads an order's line items (with their fulfillment's supplier), asks
  `DropshipSettlement` for a split, and exposes:

    * `prepare/2` — `{:split, %{total, allocations, shares}}` or `{:no_split, reason}`.
      `shares` is the gateway-ready list of `%{subaccount, share}` for
      `initiate_payment`; the platform's cut is never a share (it stays in the
      platform main account).
    * `record_splits!/2` — persists one `PaymentSplit` per allocation once the
      payment record exists.
  """

  require Ash.Query

  alias Emakola.Payments.DropshipSettlement

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
          {:split,
           %{total: order.total, allocations: allocations, shares: gateway_shares(allocations)}}
        else
          {:no_split, :unrepresentable_split}
        end

      {:no_split, reason} ->
        {:no_split, reason}
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
          subaccount_code: Map.get(alloc, :subaccount_code),
          amount: alloc.amount
        },
        authorize?: false
      )
    end)
  end

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
    |> Enum.filter(& &1[:subaccount_code])
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
end
