defmodule Emakola.Suppliers.NetworkStockTest do
  @moduledoc """
  Task 1 (supplier-stock-truth): `NetworkStock.decrement_for_order/2` is
  called from the payment webhook handlers immediately after
  `InventoryReservations.consume_for_order/2` so a confirmed network
  (dropship) sale decrements the supplier's real source-variant stock —
  the units a reseller sold out of the supplier's inventory that weren't
  already covered by an active reservation hold.
  """

  use Emakola.DataCase, async: true

  import Emakola.Factory
  require Ash.Query

  alias Emakola.Suppliers.{InventoryReservations, ListingImporter, Network, NetworkStock, Offers}

  setup do
    {wholesaler_actor, wholesaler} = create_merchant_with_store!(%{name: "Stock wholesaler"})
    {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Stock reseller"})

    {:ok, connection} =
      Network.request(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: wholesaler.id
      })

    {:ok, _active} = Network.approve(reseller_actor, connection)

    %{
      wholesaler_actor: wholesaler_actor,
      wholesaler: wholesaler,
      reseller_actor: reseller_actor,
      reseller: reseller
    }
  end

  test "happy path: decrements source stock and records one network_sale movement", ctx do
    %{source_variant: source, reseller_variant: reseller_variant} =
      import_variant!(ctx, stock_quantity: 8, track_inventory: true)

    order = create_order!(ctx.reseller, %{})
    create_line_item!(order, ctx.reseller, reseller_variant, 3)

    assert :ok = NetworkStock.decrement_for_order(order.id, ctx.reseller.id)

    assert reload_variant(source).stock_quantity == 5

    assert [%{reason: :network_sale, order_id: order_id, delta: -3}] = movements_for(source.id)
    assert order_id == order.id

    assert_total_matches_levels(source)
  end

  test "replay idempotency: a second call does not double-decrement", ctx do
    %{source_variant: source, reseller_variant: reseller_variant} =
      import_variant!(ctx, stock_quantity: 8, track_inventory: true)

    order = create_order!(ctx.reseller, %{})
    create_line_item!(order, ctx.reseller, reseller_variant, 3)

    assert :ok = NetworkStock.decrement_for_order(order.id, ctx.reseller.id)
    assert :ok = NetworkStock.decrement_for_order(order.id, ctx.reseller.id)

    assert reload_variant(source).stock_quantity == 5
    assert length(movements_for(source.id)) == 1
  end

  test "reservation-covered units are never double-decremented — only the shortfall decrements",
       ctx do
    %{source_variant: source, terms: terms, reseller_variant: reseller_variant} =
      import_variant!(ctx, stock_quantity: 8, track_inventory: true)

    {:ok, policy} =
      InventoryReservations.create_policy(ctx.wholesaler_actor, ctx.wholesaler.id, terms.id, %{
        minimum_tier: :starter,
        max_quantity_per_reseller: 10,
        reservation_hours: 24
      })

    assert {:ok, _reservation} =
             InventoryReservations.reserve(ctx.reseller_actor, ctx.reseller.id, policy.id, 2)

    # Reservation hold already took 2 units from supplier stock: 8 -> 6.
    assert reload_variant(source).stock_quantity == 6

    order = create_order!(ctx.reseller, %{})
    create_line_item!(order, ctx.reseller, reseller_variant, 3)

    # Mirrors the real webhook call order: consume the reservation first,
    # then let NetworkStock decrement only the shortfall.
    assert :ok = InventoryReservations.consume_for_order(order.id, ctx.reseller.id)
    assert :ok = NetworkStock.decrement_for_order(order.id, ctx.reseller.id)

    assert reload_variant(source).stock_quantity == 5
    assert [%{reason: :network_sale, delta: -1}] = network_sale_movements_for(source.id)
  end

  test "clamp: shortfall exceeds available stock — clamps to zero, never raises", ctx do
    %{source_variant: source, reseller_variant: reseller_variant} =
      import_variant!(ctx, stock_quantity: 2, track_inventory: true)

    order = create_order!(ctx.reseller, %{})
    create_line_item!(order, ctx.reseller, reseller_variant, 5)

    assert :ok = NetworkStock.decrement_for_order(order.id, ctx.reseller.id)

    assert reload_variant(source).stock_quantity == 0
    assert [%{reason: :network_sale, delta: -2}] = movements_for(source.id)
  end

  test "unmapped variant — no ResellerListingVariant row — is a no-op", ctx do
    product = create_product!(ctx.reseller, status: :active)
    supplier = create_supplier!(ctx.reseller)

    orphan_variant =
      create_variant!(product, ctx.reseller, stock_quantity: 10, supplier_id: supplier.id)

    order = create_order!(ctx.reseller, %{})
    create_line_item!(order, ctx.reseller, orphan_variant, 2)

    assert :ok = NetworkStock.decrement_for_order(order.id, ctx.reseller.id)

    assert reload_variant(orphan_variant).stock_quantity == 10
    assert movements_for(orphan_variant.id) == []
  end

  test "untracked source variant is a no-op", ctx do
    %{source_variant: source, reseller_variant: reseller_variant} =
      import_variant!(ctx, stock_quantity: 8, track_inventory: false)

    order = create_order!(ctx.reseller, %{})
    create_line_item!(order, ctx.reseller, reseller_variant, 3)

    assert :ok = NetworkStock.decrement_for_order(order.id, ctx.reseller.id)

    assert reload_variant(source).stock_quantity == 8
    assert movements_for(source.id) == []
  end

  test "nil order id is a no-op", ctx do
    assert :ok = NetworkStock.decrement_for_order(nil, ctx.reseller.id)
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp import_variant!(ctx, variant_attrs) do
    product = create_product!(ctx.wholesaler, status: :active, title: "Kente sandals")

    source_variant =
      create_variant!(
        product,
        ctx.wholesaler,
        Map.merge(
          %{price: 6_000, sku: "SANDAL-#{System.unique_integer([:positive])}"},
          Map.new(variant_attrs)
        )
      )

    {:ok, offer} =
      Offers.create_draft(ctx.wholesaler_actor, %{
        wholesaler_store_id: ctx.wholesaler.id,
        source_product_id: product.id,
        earning_model: :markup
      })

    {:ok, terms} =
      Offers.add_variant(ctx.wholesaler_actor, offer, %{
        source_variant_id: source_variant.id,
        supplier_price: 4_000,
        suggested_retail_price: 5_000,
        max_retail_price: 5_800
      })

    {:ok, offer} = Offers.publish(ctx.wholesaler_actor, offer)

    {:ok, listing} = ListingImporter.import(ctx.reseller_actor, ctx.reseller.id, offer)

    [reseller_variant | _] = listing.reseller_product.variants

    %{source_variant: source_variant, terms: terms, reseller_variant: reseller_variant}
  end

  defp create_line_item!(order, store, variant, quantity) do
    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: quantity
    })
    |> Ash.create!(authorize?: false)
  end

  defp reload_variant(variant),
    do: Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)

  defp movements_for(variant_id) do
    Emakola.Inventory.StockMovement
    |> Ash.Query.filter(variant_id == ^variant_id)
    |> Ash.read!(authorize?: false)
  end

  defp network_sale_movements_for(variant_id) do
    Emakola.Inventory.StockMovement
    |> Ash.Query.filter(variant_id == ^variant_id and reason == :network_sale)
    |> Ash.read!(authorize?: false)
  end

  defp assert_total_matches_levels(variant) do
    total = reload_variant(variant).stock_quantity
    level_sum = variant.id |> Emakola.Inventory.levels() |> Enum.reduce(0, &(&1.quantity + &2))
    assert total == level_sum
  end
end
