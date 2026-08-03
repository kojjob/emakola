defmodule Emakola.Suppliers.NetworkStock do
  @moduledoc """
  Decrements supplier source-variant stock for confirmed network (dropship)
  sales — the units a reseller sold out of the supplier's inventory.

  Called from the payment webhook handlers immediately AFTER
  `InventoryReservations.consume_for_order/2` (consumption rows must be final:
  reservation-covered units were already removed from supplier stock at
  reserve time, so only the shortfall decrements here).

  Line items are aggregated by source variant BEFORE any decrement happens:
  two different reseller variants (even across two different reseller
  listings/stores) can map to the same underlying supplier source variant, so
  summing each line's shortfall per source variant first — then decrementing
  once — is required. Decrementing per line item independently would
  undercount, because the per-(variant, order) idempotency guard below would
  see the first line's movement and skip every subsequent line touching the
  same source variant.

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
    Emakola.Orders.LineItem
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.read!(authorize?: false, tenant: store_id)
    |> Enum.reduce(%{}, &accumulate_shortfall/2)
    |> Enum.each(fn {source_variant_id, shortfall} ->
      decrement_source(source_variant_id, shortfall, order_id)
    end)

    :ok
  rescue
    exception ->
      Logger.error(
        "[NetworkStock] decrement failed for order #{order_id}: " <>
          Exception.message(exception)
      )

      :ok
  end

  defp accumulate_shortfall(line_item, shortfalls_by_source_variant) do
    mapping =
      Emakola.Suppliers.ResellerListingVariant
      |> Ash.Query.filter(reseller_variant_id == ^line_item.variant_id)
      |> Ash.Query.load(:offer_variant)
      |> Ash.read_one!(authorize?: false)

    if mapping do
      shortfall = line_item.quantity - consumed_quantity(line_item.id)

      if shortfall > 0 do
        Map.update(
          shortfalls_by_source_variant,
          mapping.offer_variant.source_variant_id,
          shortfall,
          &(&1 + shortfall)
        )
      else
        shortfalls_by_source_variant
      end
    else
      shortfalls_by_source_variant
    end
  end

  defp consumed_quantity(line_item_id) do
    Emakola.Suppliers.InventoryReservationConsumption
    |> Ash.Query.filter(line_item_id == ^line_item_id)
    |> Ash.read!(authorize?: false)
    |> Enum.reduce(0, &(&1.quantity + &2))
  end

  defp decrement_source(source_variant_id, shortfall, order_id) do
    Emakola.Repo.transaction(fn ->
      source = locked_variant!(source_variant_id)

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
