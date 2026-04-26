defmodule Emakola.Dashboard.StatsTest do
  @moduledoc "Tests for dashboard statistics module."
  use Emakola.DataCase, async: true

  alias Emakola.Dashboard.Stats
  alias Emakola.Factory

  setup do
    {merchant, store} = Factory.create_merchant_with_store!()
    {_other_merchant, other_store} = Factory.create_merchant_with_store!()
    %{store: store, other_store: other_store, merchant: merchant}
  end

  # Helper to create payment and set its status via the proper Ash actions
  defp create_payment_with_status!(store, attrs, status) do
    payment = Factory.create_payment!(store, Map.drop(attrs, [:status]))

    case status do
      :success ->
        payment
        |> Ash.Changeset.for_update(:mark_success, %{})
        |> Ash.update!(authorize?: false)

      :failed ->
        payment
        |> Ash.Changeset.for_update(:mark_failed, %{})
        |> Ash.update!(authorize?: false)

      :pending ->
        payment

      _ ->
        payment
    end
  end

  describe "total_revenue/1" do
    test "sums only successful payment amounts for the store", %{store: store} do
      # Successful payments
      create_payment_with_status!(store, %{amount: 10_000}, :success)
      create_payment_with_status!(store, %{amount: 25_000}, :success)

      # Non-successful payments (should be excluded)
      create_payment_with_status!(store, %{amount: 50_000}, :pending)
      create_payment_with_status!(store, %{amount: 30_000}, :failed)

      stats = Stats.load_stats(store.id)
      assert stats.total_revenue == 35_000
    end

    test "returns 0 when no successful payments exist", %{store: store} do
      create_payment_with_status!(store, %{amount: 10_000}, :pending)
      stats = Stats.load_stats(store.id)
      assert stats.total_revenue == 0
    end

    test "excludes payments from other stores", %{store: store, other_store: other_store} do
      create_payment_with_status!(store, %{amount: 10_000}, :success)
      create_payment_with_status!(other_store, %{amount: 99_999}, :success)

      stats = Stats.load_stats(store.id)
      assert stats.total_revenue == 10_000
    end
  end

  describe "order_count/1" do
    test "counts orders for the store", %{store: store} do
      Factory.create_order!(store)
      Factory.create_order!(store)
      Factory.create_order!(store)

      stats = Stats.load_stats(store.id)
      assert stats.order_count == 3
    end

    test "returns 0 when no orders exist", %{store: store} do
      stats = Stats.load_stats(store.id)
      assert stats.order_count == 0
    end

    test "excludes orders from other stores", %{store: store, other_store: other_store} do
      Factory.create_order!(store)
      Factory.create_order!(other_store)

      stats = Stats.load_stats(store.id)
      assert stats.order_count == 1
    end
  end

  describe "active_products/1" do
    test "counts only active products", %{store: store} do
      # Create active products (need variant to activate)
      p1 = Factory.create_product!(store)
      Factory.create_variant!(p1, store)

      p1
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

      p2 = Factory.create_product!(store)
      Factory.create_variant!(p2, store)

      p2
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

      # Draft product (should be excluded)
      Factory.create_product!(store)

      stats = Stats.load_stats(store.id)
      assert stats.active_products == 2
    end

    test "excludes draft and archived products", %{store: store} do
      # Draft
      Factory.create_product!(store)

      # Archived
      p = Factory.create_product!(store)
      Factory.create_variant!(p, store)

      p =
        p
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!(authorize?: false)

      p
      |> Ash.Changeset.for_update(:archive, %{})
      |> Ash.update!(authorize?: false)

      stats = Stats.load_stats(store.id)
      assert stats.active_products == 0
    end
  end

  describe "customer_count/1" do
    test "counts customers for the store", %{store: store} do
      Factory.create_customer!(store)
      Factory.create_customer!(store)

      stats = Stats.load_stats(store.id)
      assert stats.customer_count == 2
    end

    test "excludes customers from other stores", %{store: store, other_store: other_store} do
      Factory.create_customer!(store)
      Factory.create_customer!(other_store)
      Factory.create_customer!(other_store)

      stats = Stats.load_stats(store.id)
      assert stats.customer_count == 1
    end
  end

  describe "recent_orders/1" do
    test "returns latest 10 orders sorted by date descending", %{store: store} do
      # Create 12 orders
      for _i <- 1..12 do
        Factory.create_order!(store)
      end

      stats = Stats.load_stats(store.id)
      assert length(stats.recent_orders) == 10

      # Should be sorted newest first
      dates = Enum.map(stats.recent_orders, & &1.inserted_at)
      assert dates == Enum.sort(dates, {:desc, DateTime})
    end

    test "returns empty list when no orders", %{store: store} do
      stats = Stats.load_stats(store.id)
      assert stats.recent_orders == []
    end

    test "excludes orders from other stores", %{store: store, other_store: other_store} do
      Factory.create_order!(store)
      Factory.create_order!(other_store)

      stats = Stats.load_stats(store.id)
      assert length(stats.recent_orders) == 1
    end
  end

  describe "low_stock_variants/1" do
    test "returns variants with stock below threshold that track inventory", %{store: store} do
      product = Factory.create_product!(store)

      # Low stock, tracking inventory
      Factory.create_variant!(product, store, %{
        stock_quantity: 5,
        track_inventory: true,
        sku: "LOW-1"
      })

      # Low stock, NOT tracking inventory (should be excluded)
      Factory.create_variant!(product, store, %{
        stock_quantity: 3,
        track_inventory: false,
        sku: "NO-TRACK"
      })

      # Adequate stock (should be excluded)
      Factory.create_variant!(product, store, %{
        stock_quantity: 50,
        track_inventory: true,
        sku: "GOOD"
      })

      stats = Stats.load_stats(store.id)
      assert length(stats.low_stock) == 1
      assert hd(stats.low_stock).sku == "LOW-1"
    end

    test "returns empty list when no low stock variants", %{store: store} do
      product = Factory.create_product!(store)

      Factory.create_variant!(product, store, %{
        stock_quantity: 100,
        track_inventory: true,
        sku: "OK"
      })

      stats = Stats.load_stats(store.id)
      assert stats.low_stock == []
    end
  end

  describe "top_products/1" do
    test "returns top 5 products ordered by variant count", %{store: store} do
      # Product with 3 variants
      p1 = Factory.create_product!(store, %{title: "Top Product"})
      Factory.create_variant!(p1, store, %{sku: "TP-1"})
      Factory.create_variant!(p1, store, %{sku: "TP-2"})
      Factory.create_variant!(p1, store, %{sku: "TP-3"})

      # Product with 1 variant
      p2 = Factory.create_product!(store, %{title: "Second Product"})
      Factory.create_variant!(p2, store, %{sku: "SP-1"})

      stats = Stats.load_stats(store.id)
      assert length(stats.top_products) <= 5
      # First product should have most variants
      first = hd(stats.top_products)
      assert first.title == "Top Product"
      assert first.variant_count == 3
    end

    test "returns empty list when no products", %{store: store} do
      stats = Stats.load_stats(store.id)
      assert stats.top_products == []
    end
  end
end
