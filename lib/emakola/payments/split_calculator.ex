defmodule Emakola.Payments.SplitCalculator do
  @moduledoc """
  Pure computation of a trustless dropship payment split (SP5).

  Given the line items of an order, the platform fee rate, and a resolution of
  each wholesaler supplier to a payout subaccount, returns the integer (minor
  unit) allocations that route a single customer charge to three destinations:

    * each **wholesaler** receives their cost (`cost_price × quantity`)
    * the **platform** receives `fee_rate` of the dropship margin
    * the **dropshipper** receives own-stock revenue plus net dropship margin

  The cardinal invariant: allocations sum **exactly** to the order total. No
  money is created or lost. All arithmetic is integer; `fee_rate` is expressed
  in basis points (e.g. `1_000` = 10%) so no floats ever touch money.

  This module is pure — it takes plain maps and returns a plain map, so the
  settlement math can be exhaustively unit-tested without a database or gateway.
  """

  @bps_denominator 10_000

  @doc """
  Compute the split for `line_items` under `opts`.

  `line_items` is a list of maps with `:unit_price`, `:cost_price` (nil for
  own-stock), `:quantity`, and `:supplier_id` (nil for own-stock).

  Options:
    * `:fee_rate_bps` — platform fee on dropship margin, in basis points
    * `:subaccounts` — map of `supplier_id => subaccount_code`
    * `:dropshipper_subaccount` — the dropshipper store's subaccount code
    * `:dispatch_fees` — map of `supplier_id => pesewas` (default `%{}`); each
      fee is added to that wholesaler's allocation and to the returned `total`
  """
  def calculate(line_items, opts) do
    fee_rate_bps = Keyword.fetch!(opts, :fee_rate_bps)
    subaccounts = Keyword.fetch!(opts, :subaccounts)
    dropshipper_subaccount = Keyword.fetch!(opts, :dropshipper_subaccount)
    dispatch_fees = Keyword.get(opts, :dispatch_fees, %{})

    parts = Enum.map(line_items, &line_part(&1, fee_rate_bps))

    %{
      total: Enum.sum(Enum.map(parts, & &1.retail)) + Enum.sum(Map.values(dispatch_fees)),
      allocations:
        wholesaler_allocations(parts, subaccounts, dispatch_fees) ++
          [platform_allocation(parts), dropshipper_allocation(parts, dropshipper_subaccount)]
    }
  end

  # Per-line breakdown into cost / platform-fee / dropshipper-net.
  defp line_part(%{supplier_id: supplier_id} = item, fee_rate_bps) when not is_nil(supplier_id) do
    retail = item.unit_price * item.quantity
    cost = (item.cost_price || 0) * item.quantity
    margin = retail - cost
    # Floor the dropshipper's share so the rounding remainder accrues to the platform.
    dropshipper_net = div(margin * (@bps_denominator - fee_rate_bps), @bps_denominator)
    platform_fee = margin - dropshipper_net

    %{
      supplier_id: supplier_id,
      retail: retail,
      cost: cost,
      platform_fee: platform_fee,
      dropshipper_net: dropshipper_net
    }
  end

  defp line_part(item, _fee_rate_bps) do
    retail = item.unit_price * item.quantity
    # Own-stock: full retail to the dropshipper, nothing to wholesaler or platform.
    %{supplier_id: nil, retail: retail, cost: 0, platform_fee: 0, dropshipper_net: retail}
  end

  defp wholesaler_allocations(parts, subaccounts, dispatch_fees) do
    parts
    |> Enum.reject(&is_nil(&1.supplier_id))
    |> Enum.group_by(& &1.supplier_id)
    |> Enum.map(fn {supplier_id, supplier_parts} ->
      %{
        role: :wholesaler,
        supplier_id: supplier_id,
        subaccount_code: Map.get(subaccounts, supplier_id),
        amount:
          Enum.sum(Enum.map(supplier_parts, & &1.cost)) + Map.get(dispatch_fees, supplier_id, 0)
      }
    end)
  end

  defp platform_allocation(parts) do
    %{role: :platform, amount: Enum.sum(Enum.map(parts, & &1.platform_fee))}
  end

  defp dropshipper_allocation(parts, subaccount_code) do
    %{
      role: :dropshipper,
      subaccount_code: subaccount_code,
      amount: Enum.sum(Enum.map(parts, & &1.dropshipper_net))
    }
  end
end
