defmodule Emakola.Orders.Calculations.FulfillmentStatus do
  @moduledoc """
  Additive calculation deriving an order's aggregate fulfillment status from
  its per-supplier fulfillments WITHOUT touching the stored `status` field.

  Returns:
    * `nil` — when the order has no fulfillments (legacy orders fall back to
      the stored `status`).
    * `:delivered` — when every fulfillment is delivered.
    * `:cancelled` — when every fulfillment is cancelled.
    * otherwise the least-progressed status among the NON-cancelled
      fulfillments, using the progress order
      `[:declined, :pending, :notified, :shipped, :delivered]`.

  `:declined` sits at the HEAD of that order on purpose. A supplier saying "no
  stock" is the loudest thing an order can carry — someone must re-source or
  refund — so it outranks anything still in flight rather than being averaged
  away behind a sibling group that happens to be less far along.

  The lookup below RAISES on a status it has never heard of, which is
  deliberate: this calculation is loaded by every order view, so a silently
  mis-sorted new status would be far worse than a loud failure in test. Any
  addition to `Fulfillment.status` must be added to `@progress` in the same
  commit.
  """
  use Ash.Resource.Calculation

  @progress [:declined, :pending, :notified, :shipped, :delivered]

  @impl true
  def load(_query, _opts, _context) do
    [fulfillments: Ash.Query.select(Emakola.Orders.Fulfillment, [:status])]
  end

  @impl true
  def calculate(orders, _opts, _context) do
    Enum.map(orders, fn order -> aggregate(order.fulfillments) end)
  end

  defp aggregate([]), do: nil

  defp aggregate(fulfillments) do
    statuses = Enum.map(fulfillments, & &1.status)

    cond do
      Enum.all?(statuses, &(&1 == :delivered)) ->
        :delivered

      Enum.all?(statuses, &(&1 == :cancelled)) ->
        :cancelled

      true ->
        statuses
        |> Enum.reject(&(&1 == :cancelled))
        |> Enum.min_by(fn status ->
          Enum.find_index(@progress, &(&1 == status)) ||
            raise "FulfillmentStatus: unexpected status #{inspect(status)} not in #{inspect(@progress)}"
        end)
    end
  end
end
