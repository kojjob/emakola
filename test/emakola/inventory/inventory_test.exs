defmodule Emakola.InventoryTest do
  @moduledoc """
  Tests for `Emakola.Inventory` — the read-side service module that
  classifies stock levels and finds low-stock variants.
  """

  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Inventory

  describe "stock_status/1" do
    test "returns :in_stock for healthy quantity" do
      assert :in_stock = Inventory.stock_status(%{stock_quantity: 50, track_inventory: true})
    end

    test "returns :low at threshold boundary" do
      assert :low = Inventory.stock_status(%{stock_quantity: 9, track_inventory: true})
      assert :low = Inventory.stock_status(%{stock_quantity: 1, track_inventory: true})
    end

    test "returns :out at zero" do
      assert :out = Inventory.stock_status(%{stock_quantity: 0, track_inventory: true})
    end

    test "returns :out for negative quantity (treats as out)" do
      assert :out = Inventory.stock_status(%{stock_quantity: -1, track_inventory: true})
    end

    test "returns :in_stock when variant doesn't track inventory regardless of quantity" do
      assert :in_stock = Inventory.stock_status(%{stock_quantity: 0, track_inventory: false})
      assert :in_stock = Inventory.stock_status(%{stock_quantity: -100, track_inventory: false})
    end

    test "dropshipped variant returns :out when not available" do
      assert :out =
               Inventory.stock_status(%{
                 supplier_id: Ash.UUID.generate(),
                 available: false,
                 stock_quantity: 0,
                 track_inventory: false
               })
    end

    test "dropshipped variant returns :in_stock when available" do
      assert :in_stock =
               Inventory.stock_status(%{
                 supplier_id: Ash.UUID.generate(),
                 available: true,
                 stock_quantity: 0,
                 track_inventory: false
               })
    end
  end

  describe "out_of_stock?/1" do
    test "true at zero stock with tracking on" do
      assert Inventory.out_of_stock?(%{stock_quantity: 0, track_inventory: true})
    end

    test "false at low stock" do
      refute Inventory.out_of_stock?(%{stock_quantity: 5, track_inventory: true})
    end

    test "false when not tracking inventory (treats as always available)" do
      refute Inventory.out_of_stock?(%{stock_quantity: 0, track_inventory: false})
    end
  end

  describe "list_low_stock/2" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      product = create_product!(store)
      %{store: store, product: product}
    end

    test "returns variants below threshold sorted by quantity ascending", ctx do
      _ok_variant =
        create_variant!(ctx.product, ctx.store, stock_quantity: 100, track_inventory: true)

      low_5 = create_variant!(ctx.product, ctx.store, stock_quantity: 5, track_inventory: true)
      low_2 = create_variant!(ctx.product, ctx.store, stock_quantity: 2, track_inventory: true)

      results = Inventory.list_low_stock(ctx.store.id)
      ids = Enum.map(results, & &1.id)

      # Both low-stock variants returned, sorted ascending
      assert low_2.id in ids
      assert low_5.id in ids

      assert Enum.find_index(ids, &(&1 == low_2.id)) <
               Enum.find_index(ids, &(&1 == low_5.id))
    end

    test "skips variants that don't track inventory", ctx do
      _untracked =
        create_variant!(ctx.product, ctx.store, stock_quantity: 1, track_inventory: false)

      assert Inventory.list_low_stock(ctx.store.id) == []
    end

    test "respects custom threshold", ctx do
      _at_50 =
        create_variant!(ctx.product, ctx.store, stock_quantity: 50, track_inventory: true)

      # Default threshold (10) — empty
      assert Inventory.list_low_stock(ctx.store.id) == []

      # Threshold 100 — picks up the variant
      results = Inventory.list_low_stock(ctx.store.id, 100)
      assert length(results) == 1
    end

    test "scoped to store_id (does not leak cross-tenant)", ctx do
      {_other_merchant, other_store} = create_merchant_with_store!()
      other_product = create_product!(other_store)

      _other_low =
        create_variant!(other_product, other_store, stock_quantity: 1, track_inventory: true)

      _own_low = create_variant!(ctx.product, ctx.store, stock_quantity: 1, track_inventory: true)

      our_results = Inventory.list_low_stock(ctx.store.id)
      assert length(our_results) == 1
    end

    test "returns empty list on read failure rather than raising" do
      # Invalid UUID — Ash returns a query error; we want [] not a crash.
      assert Inventory.list_low_stock("not-a-uuid") == []
    end
  end
end
