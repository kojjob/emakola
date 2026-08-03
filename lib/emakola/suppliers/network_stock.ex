defmodule Emakola.Suppliers.NetworkStock do
  @moduledoc """
  Decrements supplier source-variant stock for confirmed network (dropship)
  sales — the units a reseller sold out of the supplier's inventory.

  Called from the payment webhook handlers immediately AFTER
  `InventoryReservations.consume_for_order/2` (consumption rows must be final:
  reservation-covered units were already removed from supplier stock at
  reserve time, so only the shortfall decrements here).

  Contract: always returns `:ok`; never raises into the webhook. Supplier
  stock short → clamp to zero and log (the paid order stands for manual
  fulfilment — same discipline as `Orders.Changes.DecrementStock`). A
  zero-clamped line leaves no movement marker, so a webhook redelivery after
  a restock WILL take the still-owed units — deliberate: the sale happened.
  """
  require Ash.Query
  require Logger

  def decrement_for_order(nil, _store_id), do: :ok

  def decrement_for_order(order_id, store_id) do
    line_items =
      Emakola.Orders.LineItem
      |> Ash.Query.filter(order_id == ^order_id)
      |> Ash.read!(authorize?: false, tenant: store_id)

    Enum.each(line_items, &decrement_line(&1, order_id))
    :ok
  rescue
    exception ->
      Logger.error(
        "[NetworkStock] decrement failed for order #{order_id}: " <>
          Exception.message(exception)
      )

      :ok
  end

  defp decrement_line(line_item, order_id) do
    mapping =
      Emakola.Suppliers.ResellerListingVariant
      |> Ash.Query.filter(reseller_variant_id == ^line_item.variant_id)
      |> Ash.Query.load(:offer_variant)
      |> Ash.read_one!(authorize?: false)

    if mapping do
      consumed = consumed_quantity(line_item.id)
      shortfall = line_item.quantity - consumed

      if shortfall > 0 do
        decrement_source(mapping.offer_variant, shortfall, order_id)
      end
    end
  end

  defp consumed_quantity(line_item_id) do
    Emakola.Suppliers.InventoryReservationConsumption
    |> Ash.Query.filter(line_item_id == ^line_item_id)
    |> Ash.read!(authorize?: false)
    |> Enum.reduce(0, &(&1.quantity + &2))
  end

  defp decrement_source(offer_variant, shortfall, order_id) do
    Emakola.Repo.transaction(fn ->
      source = locked_variant!(offer_variant.source_variant_id)

      cond do
        not source.track_inventory ->
          :ok

        already_decremented?(source, order_id) ->
          :ok

        true ->
          take = min(shortfall, max(source.stock_quantity, 0))

          if take < shortfall do
            Logger.warning(
              "[NetworkStock] clamped decrement for order #{order_id} " <>
                "variant #{source.id}: wanted #{shortfall}, took #{take}"
            )
          end

          if take > 0 do
            location = Emakola.Inventory.ensure_default_location!(source.store_id)

            {:ok, _} =
              Emakola.Inventory.adjust(source.id, location.id, -take, :network_sale,
                order_id: order_id
              )
          end

          :ok
      end
    end)
  end

  defp already_decremented?(source, order_id) do
    Emakola.Inventory.StockMovement
    |> Ash.Query.filter(
      variant_id == ^source.id and order_id == ^order_id and reason == :network_sale
    )
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false, tenant: source.store_id)
    |> Enum.any?()
  end

  defp locked_variant!(id) do
    Emakola.Catalog.Variant
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end
end
