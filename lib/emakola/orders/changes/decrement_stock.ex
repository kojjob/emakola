defmodule Emakola.Orders.Changes.DecrementStock do
  @moduledoc """
  Decrements stock for an order's line items once payment is confirmed.

  Stock is reserved nowhere at checkout, so abandoned/unpaid orders never bleed
  inventory; it is decremented here, when an order transitions to `:confirmed`
  on payment success. The `:confirm` action is guarded `from: [:pending]`, so a
  redelivered webhook re-runs confirm, fails the guard, and never double-counts.

  Runs `after_transaction` — after the `:confirm` transaction has committed — so
  a per-variant stock CHECK violation (a concurrent sale oversold the item
  between order placement and payment) is logged and the already-paid order
  still stands for manual fulfilment, rather than rolling back the confirmation.
  """

  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, order} ->
        decrement(order)
        {:ok, order}

      _changeset, other ->
        other
    end)
  end

  defp decrement(order) do
    order = Ash.load!(order, [line_items: [:variant]], authorize?: false)

    Enum.each(order.line_items, fn line_item ->
      variant = line_item.variant

      if variant && variant.track_inventory do
        decrement_variant(order, variant, line_item.quantity)
      end
    end)
  end

  defp decrement_variant(order, variant, quantity) do
    # Funnels through the Inventory domain: default location first, then a
    # cascade across active locations, with the variant total kept in sync
    # and a :sale movement recorded — same oversell contract as before
    # (raises Ash.Error.Invalid, nothing committed).
    Emakola.Inventory.decrement_for_sale!(variant.id, order.store_id, quantity, order.id)
  rescue
    e in Ash.Error.Invalid ->
      Logger.error(
        "[order.confirm] stock decrement failed for order=#{order.id} variant=#{variant.id} " <>
          "(likely oversold between order and payment); order stays confirmed for manual " <>
          "fulfilment: #{Exception.message(e)}"
      )
  end
end
