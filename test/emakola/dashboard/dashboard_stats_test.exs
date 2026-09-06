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

  describe "count_buyers/3" do
    test "counts distinct customers on paid orders, not signups or other stores", %{
      store: store,
      other_store: other_store
    } do
      buyer = Factory.create_customer!(store)
      non_buyer = Factory.create_customer!(store)

      Factory.create_order!(store,
        customer_id: buyer.id,
        total: 10_000,
        subtotal: 10_000,
        status: :confirmed
      )

      Factory.create_order!(store,
        customer_id: buyer.id,
        total: 5_000,
        subtotal: 5_000,
        status: :confirmed
      )

      Factory.create_order!(store,
        customer_id: non_buyer.id,
        total: 7_000,
        subtotal: 7_000,
        status: :pending
      )

      other_customer = Factory.create_customer!(other_store)

      Factory.create_order!(other_store,
        customer_id: other_customer.id,
        total: 20_000,
        subtotal: 20_000,
        status: :confirmed
      )

      from = DateTime.add(DateTime.utc_now(), -1, :day)
      to = DateTime.add(DateTime.utc_now(), 1, :day)

      assert Stats.count_buyers(store.id, from, to) == 1
    end
  end

  defp line_item!(order, store, variant, quantity) do
    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: quantity
    })
    |> Ash.create!(authorize?: false)
  end

  describe "top_line_items_chart/3" do
    test "counts units from paid orders only, not pending or cancelled", %{store: store} do
      product = Factory.create_product!(store, %{title: "Widget"})
      variant = Factory.create_variant!(product, store)

      cancelled = Factory.create_order!(store, %{total: 10_000, status: :cancelled})
      pending = Factory.create_order!(store, %{total: 10_000, status: :pending})
      confirmed = Factory.create_order!(store, %{total: 10_000, status: :confirmed})

      # The cancelled and pending quantities are the biggest by far, so if
      # either counted, the chart's total would be far more than 3.
      line_item!(cancelled, store, variant, 50)
      line_item!(pending, store, variant, 7)
      line_item!(confirmed, store, variant, 3)

      from = DateTime.add(DateTime.utc_now(), -1, :day)
      to = DateTime.add(DateTime.utc_now(), 1, :day)

      chart = Stats.top_line_items_chart(store.id, from, to)

      assert chart.labels == ["Widget"]
      assert chart.values == [3]
    end
  end

  describe "best_sellers/4" do
    test "counts units from paid orders only, not pending or cancelled", %{store: store} do
      product = Factory.create_product!(store, %{title: "Widget"})
      variant = Factory.create_variant!(product, store)

      cancelled = Factory.create_order!(store, %{total: 10_000, status: :cancelled})
      pending = Factory.create_order!(store, %{total: 10_000, status: :pending})
      confirmed = Factory.create_order!(store, %{total: 10_000, status: :confirmed})

      line_item!(cancelled, store, variant, 50)
      line_item!(pending, store, variant, 7)
      line_item!(confirmed, store, variant, 3)

      from = DateTime.add(DateTime.utc_now(), -1, :day)
      to = DateTime.add(DateTime.utc_now(), 1, :day)

      assert [%{title: "Widget", quantity: 3}] = Stats.best_sellers(store.id, from, to)
    end
  end
end
