defmodule Emakola.Orders.Calculations.Margin do
  @moduledoc """
  Additive calculation deriving an order's gross margin from its line items.

  Returns the integer (minor units) sum of `(unit_price - cost_price) * quantity`
  across all line items, treating a nil `cost_price` (own-stock) as zero cost.
  An order with no line items has a margin of 0.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [line_items: Ash.Query.select(Emakola.Orders.LineItem, [:unit_price, :cost_price, :quantity])]
  end

  @impl true
  def calculate(orders, _opts, _context) do
    Enum.map(orders, fn order -> margin(order.line_items) end)
  end

  defp margin(line_items) do
    Enum.reduce(line_items, 0, fn li, acc ->
      acc + (li.unit_price - (li.cost_price || 0)) * li.quantity
    end)
  end
end
