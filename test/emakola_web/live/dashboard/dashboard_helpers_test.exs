defmodule EmakolaWeb.DashboardHelpersTest do
  use Emakola.DataCase, async: true

  alias EmakolaWeb.DashboardHelpers
  alias Emakola.Factory

  setup do
    {_merchant, store} = Factory.create_merchant_with_store!()
    {_merchant2, other_store} = Factory.create_merchant_with_store!()

    customer = Factory.create_customer!(store)
    product = Factory.create_product!(store, status: :active)
    variant = Factory.create_variant!(product, store, price: 10_000, stock_quantity: 50)

    # Create a second product for top products chart
    product2 = Factory.create_product!(store, status: :active)
    variant2 = Factory.create_variant!(product2, store, price: 5_000, stock_quantity: 20)

    %{
      store: store,
      other_store: other_store,
      customer: customer,
      product: product,
      variant: variant,
      product2: product2,
      variant2: variant2
    }
  end

  describe "default_data/0" do
    test "returns a map with all required keys and zero/empty defaults" do
      data = DashboardHelpers.default_data()

      assert data.total_revenue == 0
      assert data.order_count == 0
      assert data.customer_count == 0
      assert data.waiting_for_payment == 0
      assert data.avg_order_value == 0
      assert data.revenue_change == nil
      assert data.orders_change == nil
      assert data.customers_change == nil
      assert data.aov_change == nil
      assert data.revenue_chart == %{labels: [], values: []}
      assert data.orders_chart == %{labels: [], values: []}
      assert data.customers_chart == %{labels: [], values: []}
      assert data.top_products_chart == %{labels: [], values: []}
      assert data.pending_orders == 0
      assert data.low_stock_count == 0
      assert data.failed_payments == 0
      assert data.recent_orders == []
    end
  end

  describe "load_merchant_dashboard/2" do
    test "returns correct revenue and order count for paid orders", %{
      store: store,
      customer: customer
    } do
      Factory.create_order!(store,
        customer_id: customer.id,
        total: 20_000,
        subtotal: 20_000,
        status: :confirmed
      )

      Factory.create_order!(store,
        customer_id: customer.id,
        total: 30_000,
        subtotal: 30_000,
        status: :confirmed
      )

      # Cancelled order should not count
      Factory.create_order!(store,
        customer_id: customer.id,
        total: 10_000,
        subtotal: 10_000,
        status: :cancelled
      )

      data = DashboardHelpers.load_merchant_dashboard(store.id, "today")

      assert data.total_revenue == 50_000
      assert data.order_count == 2
      assert data.avg_order_value == 25_000
    end

    test "customer_count counts distinct buyers on paid orders, not signups", %{
      store: store,
      customer: customer
    } do
      # The setup already created one customer; create another who never buys.
      Factory.create_customer!(store)

      Factory.create_order!(store,
        customer_id: customer.id,
        total: 5_000,
        subtotal: 5_000,
        status: :confirmed
      )

      data = DashboardHelpers.load_merchant_dashboard(store.id, "today")

      assert data.customer_count == 1
    end

    test "does NOT include data from another store (multi-tenant isolation)", %{
      store: store,
      other_store: other_store,
      customer: customer
    } do
      # Create order in our store
      Factory.create_order!(store,
        customer_id: customer.id,
        total: 20_000,
        subtotal: 20_000,
        status: :confirmed
      )

      # Create order in other store
      other_customer = Factory.create_customer!(other_store)

      Factory.create_order!(other_store,
        customer_id: other_customer.id,
        total: 99_000,
        subtotal: 99_000,
        status: :confirmed
      )

      data = DashboardHelpers.load_merchant_dashboard(store.id, "today")

      # Should only see our store's order
      assert data.total_revenue == 20_000
      assert data.order_count == 1
    end

    test "returns chart data with labels and values lists", %{
      store: store,
      customer: customer
    } do
      Factory.create_order!(store, customer_id: customer.id, total: 15_000, subtotal: 15_000)

      data = DashboardHelpers.load_merchant_dashboard(store.id, "week")

      assert is_list(data.revenue_chart.labels)
      assert is_list(data.revenue_chart.values)
      assert length(data.revenue_chart.labels) == length(data.revenue_chart.values)
      assert length(data.revenue_chart.labels) == 7

      assert is_list(data.orders_chart.labels)
      assert is_list(data.orders_chart.values)

      assert is_list(data.customers_chart.labels)
      assert is_list(data.customers_chart.values)
    end

    test "returns top products sorted by units sold", %{
      store: store,
      customer: customer,
      variant: variant,
      variant2: variant2
    } do
      order =
        Factory.create_order!(store, customer_id: customer.id, total: 30_000, subtotal: 30_000)

      # variant gets 5 units, variant2 gets 2 units
      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: variant.id,
        quantity: 5
      })
      |> Ash.create!(authorize?: false)

      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: variant2.id,
        quantity: 2
      })
      |> Ash.create!(authorize?: false)

      data = DashboardHelpers.load_merchant_dashboard(store.id, "today")

      assert is_list(data.top_products_chart.labels)
      assert is_list(data.top_products_chart.values)
      assert length(data.top_products_chart.labels) <= 5

      # First product should have more units sold
      [first_qty | _] = data.top_products_chart.values
      assert first_qty == 5
    end

    test "returns correct alert counts (pending orders, low stock, failed payments)", %{
      store: store,
      customer: customer,
      product: product
    } do
      # Create pending orders
      Factory.create_order!(store, customer_id: customer.id, total: 1000, subtotal: 1000)
      Factory.create_order!(store, customer_id: customer.id, total: 2000, subtotal: 2000)

      # Create a confirmed order (should not count as pending)
      Factory.create_order!(store,
        customer_id: customer.id,
        total: 3000,
        subtotal: 3000,
        status: :confirmed
      )

      # Create low stock variant (stock < 10)
      Factory.create_variant!(product, store,
        price: 1000,
        stock_quantity: 5,
        track_inventory: true
      )

      # Create failed payment (create then mark_failed, since :create doesn't accept status)
      payment = Factory.create_payment!(store)

      payment
      |> Ash.Changeset.for_update(:mark_failed, %{})
      |> Ash.update!(authorize?: false)

      data = DashboardHelpers.load_merchant_dashboard(store.id, "today")

      assert data.pending_orders == 2
      assert data.low_stock_count == 1
      assert data.failed_payments == 1
    end

    test "returns recent orders list (max 5)", %{store: store, customer: customer} do
      for _ <- 1..7 do
        Factory.create_order!(store, customer_id: customer.id, total: 1000, subtotal: 1000)
      end

      data = DashboardHelpers.load_merchant_dashboard(store.id, "today")

      assert is_list(data.recent_orders)
      assert length(data.recent_orders) == 5
    end

    test "returns percentage changes (can be nil or number)", %{
      store: store,
      customer: customer
    } do
      Factory.create_order!(store, customer_id: customer.id, total: 10_000, subtotal: 10_000)

      data = DashboardHelpers.load_merchant_dashboard(store.id, "today")

      # Changes can be nil (no previous period data) or a float
      assert is_nil(data.revenue_change) or is_float(data.revenue_change)
      assert is_nil(data.orders_change) or is_float(data.orders_change)
      assert is_nil(data.customers_change) or is_float(data.customers_change)
      assert is_nil(data.aov_change) or is_float(data.aov_change)
    end

    test "handles 'today' period correctly", %{store: store, customer: customer} do
      Factory.create_order!(store,
        customer_id: customer.id,
        total: 10_000,
        subtotal: 10_000,
        status: :confirmed
      )

      data = DashboardHelpers.load_merchant_dashboard(store.id, "today")

      assert data.order_count == 1
      assert data.total_revenue == 10_000

      # Chart for today should have 1 data point
      assert length(data.revenue_chart.labels) == 1
    end

    test "handles 'all' period correctly", %{store: store, customer: customer} do
      Factory.create_order!(store,
        customer_id: customer.id,
        total: 10_000,
        subtotal: 10_000,
        status: :confirmed
      )

      data = DashboardHelpers.load_merchant_dashboard(store.id, "all")

      assert data.order_count == 1
      assert data.total_revenue == 10_000

      # "all" period should have nil for changes (no comparison)
      assert is_nil(data.revenue_change)
      assert is_nil(data.orders_change)
      assert is_nil(data.customers_change)
      assert is_nil(data.aov_change)
    end
  end
end
