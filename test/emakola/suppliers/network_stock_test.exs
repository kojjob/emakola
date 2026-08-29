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

  test "two line items on different reseller variants mapping to the SAME source variant: " <>
         "shortfalls are summed and decremented once",
       ctx do
    %{source_variant: source, reseller_variant: reseller_variant_1, offer: offer} =
      import_variant!(ctx, stock_quantity: 20, track_inventory: true)

    reseller_variant_2 = import_into_second_reseller!(ctx, offer)

    order = create_order!(ctx.reseller, %{})
    create_line_item!(order, ctx.reseller, reseller_variant_1, 3)
    create_line_item!(order, ctx.reseller, reseller_variant_2, 4)

    assert :ok = NetworkStock.decrement_for_order(order.id, ctx.reseller.id)

    # 20 - (3 + 4) == 13 — a single decrement for the summed shortfall, not two
    # independent per-line decrements (which the idempotency guard would have
    # otherwise silently undercounted to just -3).
    assert reload_variant(source).stock_quantity == 13

    assert [%{reason: :network_sale, delta: -7, order_id: order_id}] =
             network_sale_movements_for(source.id)

    assert order_id == order.id
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

  test "multi-location supplier: the clamp cascades across locations instead of failing " <>
         "on the default alone",
       ctx do
    %{source_variant: source, reseller_variant: reseller_variant} =
      import_variant!(ctx, stock_quantity: 10, track_inventory: true)

    main = Emakola.Inventory.ensure_default_location!(ctx.wholesaler.id)

    {:ok, warehouse} =
      Emakola.Inventory.create_location(ctx.wholesaler_actor, ctx.wholesaler.id, %{
        name: "Warehouse"
      })

    # Move 8 of the 10 units off the default location: Main 2 / Warehouse 8.
    assert {:ok, _} = Emakola.Inventory.transfer(source.id, main.id, warehouse.id, 8)

    order = create_order!(ctx.reseller, %{})
    create_line_item!(order, ctx.reseller, reseller_variant, 5)

    assert :ok = NetworkStock.decrement_for_order(order.id, ctx.reseller.id)

    # Default-location-first cascade: Main (2) drains first, the remaining
    # 3 comes from Warehouse — not a failed attempt to take all 5 from Main.
    assert reload_variant(source).stock_quantity == 5
    assert level_quantity(source.id, main.id) == 0
    assert level_quantity(source.id, warehouse.id) == 5

    movements = source.id |> network_sale_movements_for() |> Enum.sort_by(& &1.delta)

    assert [%{delta: -3, location_id: warehouse_location_id}, %{delta: -2, location_id: main_id}] =
             movements

    assert warehouse_location_id == warehouse.id
    assert main_id == main.id

    # Replay is still a no-op.
    assert :ok = NetworkStock.decrement_for_order(order.id, ctx.reseller.id)
    assert reload_variant(source).stock_quantity == 5
    assert length(network_sale_movements_for(source.id)) == 2
  end

  test "a raise while decrementing one supplier's source variant does not abort " <>
         "another supplier's decrement in the same order",
       ctx do
    ghost_reseller_variant = mapping_with_missing_source_variant!(ctx)

    %{source_variant: healthy_source, reseller_variant: healthy_reseller_variant} =
      import_variant!(ctx, stock_quantity: 8, track_inventory: true)

    order = create_order!(ctx.reseller, %{})
    create_line_item!(order, ctx.reseller, ghost_reseller_variant, 2)
    create_line_item!(order, ctx.reseller, healthy_reseller_variant, 3)

    assert :ok = NetworkStock.decrement_for_order(order.id, ctx.reseller.id)

    # The ghost mapping's raise is caught and logged per-variant; the other
    # supplier's variant still decrements normally.
    assert reload_variant(healthy_source).stock_quantity == 5
    assert [%{reason: :network_sale, delta: -3}] = network_sale_movements_for(healthy_source.id)
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

    %{
      source_variant: source_variant,
      terms: terms,
      reseller_variant: reseller_variant,
      offer: offer
    }
  end

  # A second, independent reseller connecting to the same wholesaler and
  # importing the SAME published offer — the only way two distinct
  # ResellerListingVariant rows can legitimately point at the same
  # SupplierOfferVariant (and therefore the same source variant): SupplierOffer
  # enforces one offer per (wholesaler, product), so the same offer can't be
  # re-published a second time for the first reseller, but a different
  # reseller store importing it is a completely ordinary, real flow.
  defp import_into_second_reseller!(ctx, offer) do
    {second_actor, second_reseller} = create_merchant_with_store!(%{name: "Second reseller"})

    {:ok, connection} =
      Network.request(ctx.wholesaler_actor, %{
        wholesaler_store_id: ctx.wholesaler.id,
        reseller_store_id: second_reseller.id,
        requested_by_store_id: ctx.wholesaler.id
      })

    {:ok, _active} = Network.approve(second_actor, connection)

    {:ok, listing} = ListingImporter.import(second_actor, second_reseller.id, offer)

    [reseller_variant | _] = listing.reseller_product.variants
    reseller_variant
  end

  # Structurally, an actively-imported source variant can never actually
  # vanish: `reseller_listing_variants.offer_variant_id` is ON DELETE
  # RESTRICT and `supplier_offer_variants.source_variant_id` is ON DELETE
  # CASCADE (verified against the live schema via information_schema), so
  # deleting a mapped source variant is always rejected by Postgres — the
  # cascade toward the variant would have to remove the very
  # ResellerListingVariant row that restricts it. To exercise NetworkStock's
  # defence against this theoretically "impossible" state anyway (e.g. a
  # future data-migration bug), briefly suspend FK enforcement for this
  # session only, to seed a mapping whose source variant never existed.
  defp mapping_with_missing_source_variant!(ctx) do
    ghost_product = create_product!(ctx.wholesaler, status: :active, title: "Ghost product")

    {:ok, offer} =
      Offers.create_draft(ctx.wholesaler_actor, %{
        wholesaler_store_id: ctx.wholesaler.id,
        source_product_id: ghost_product.id,
        earning_model: :markup
      })

    Emakola.Repo.query!("SET LOCAL session_replication_role = replica")

    offer_variant =
      Emakola.Suppliers.SupplierOfferVariant
      |> Ash.Changeset.for_create(:create, %{
        offer_id: offer.id,
        wholesaler_store_id: ctx.wholesaler.id,
        source_variant_id: "00000000-0000-0000-0000-000000000000",
        supplier_price: 4_000,
        suggested_retail_price: 5_000
      })
      |> Ash.create!(authorize?: false)

    Emakola.Repo.query!("SET LOCAL session_replication_role = DEFAULT")

    reseller_product = create_product!(ctx.reseller, status: :active, title: "Ghost listing")
    reseller_variant = create_variant!(reseller_product, ctx.reseller, stock_quantity: 10)
    supplier = create_supplier!(ctx.wholesaler)

    listing =
      Emakola.Suppliers.ResellerListing
      |> Ash.Changeset.for_create(:create, %{
        offer_id: offer.id,
        reseller_store_id: ctx.reseller.id,
        reseller_product_id: reseller_product.id,
        supplier_id: supplier.id
      })
      |> Ash.create!(authorize?: false)

    Emakola.Suppliers.ResellerListingVariant
    |> Ash.Changeset.for_create(:create, %{
      listing_id: listing.id,
      offer_variant_id: offer_variant.id,
      reseller_variant_id: reseller_variant.id,
      retail_price: 5_400
    })
    |> Ash.create!(authorize?: false)

    reseller_variant
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

  defp level_quantity(variant_id, location_id) do
    Emakola.Inventory.StockLevel
    |> Ash.Query.filter(variant_id == ^variant_id and location_id == ^location_id)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> nil
      level -> level.quantity
    end
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
