# Dashboard Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generic SaaS dashboard with a merchant-focused analytics dashboard showing real order/revenue/customer data with interactive Chart.js charts.

**Architecture:** Rewrite `DashboardLive` and its helpers to query store-scoped order, customer, and payment data. A shared `ChartHook` LiveView hook renders all Chart.js instances. Period toggle (Today/7 Days/30 Days/All Time) applies globally, with `push_event` updating charts on period change.

**Tech Stack:** Elixir/Phoenix LiveView, Ash queries, Chart.js (npm), TailwindCSS

---

### Task 1: Install Chart.js and Create the ChartHook

**Files:**
- Create: `assets/js/hooks/chart_hook.js`
- Modify: `assets/js/app.js`

- [ ] **Step 1: Install Chart.js npm package**

Run:
```bash
cd assets && npm install chart.js --save
```
Expected: `chart.js` added to `assets/node_modules/` and `assets/package.json`

- [ ] **Step 2: Create the ChartHook**

Create `assets/js/hooks/chart_hook.js`:

```javascript
import { Chart, registerables } from "chart.js"
Chart.register(...registerables)

const CHART_CONFIGS = {
  "revenue-bar": (data) => ({
    type: "bar",
    data: {
      labels: data.labels,
      datasets: [{
        data: data.values,
        backgroundColor: "rgba(59, 130, 246, 0.8)",
        borderRadius: 6,
        borderSkipped: false,
        maxBarThickness: 40
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 600 },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: (items) => items[0].label,
            label: (item) => `GHS ${(item.raw / 100).toFixed(2)}`
          }
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { font: { size: 11 } } },
        y: {
          grid: { color: "rgba(0,0,0,0.05)" },
          ticks: {
            font: { size: 11 },
            callback: (v) => `GHS ${(v / 100).toFixed(0)}`
          }
        }
      }
    }
  }),

  "orders-line": (data) => ({
    type: "line",
    data: {
      labels: data.labels,
      datasets: [{
        data: data.values,
        borderColor: "rgba(16, 185, 129, 0.9)",
        backgroundColor: "rgba(16, 185, 129, 0.1)",
        fill: true,
        tension: 0.3,
        pointRadius: 4,
        pointHoverRadius: 6
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 600 },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: (items) => items[0].label,
            label: (item) => `${item.raw} orders`
          }
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { font: { size: 11 } } },
        y: {
          grid: { color: "rgba(0,0,0,0.05)" },
          beginAtZero: true,
          ticks: { font: { size: 11 }, stepSize: 1 }
        }
      }
    }
  }),

  "top-products-horizontal": (data) => ({
    type: "bar",
    data: {
      labels: data.labels,
      datasets: [{
        data: data.values,
        backgroundColor: [
          "rgba(59, 130, 246, 0.8)",
          "rgba(16, 185, 129, 0.8)",
          "rgba(245, 158, 11, 0.8)",
          "rgba(139, 92, 246, 0.8)",
          "rgba(236, 72, 153, 0.8)"
        ],
        borderRadius: 4,
        borderSkipped: false
      }]
    },
    options: {
      indexAxis: "y",
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 600 },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: (item) => `${item.raw} units sold`
          }
        }
      },
      scales: {
        x: { grid: { color: "rgba(0,0,0,0.05)" }, ticks: { font: { size: 11 }, stepSize: 1 } },
        y: { grid: { display: false }, ticks: { font: { size: 11 } } }
      }
    }
  }),

  "customers-line": (data) => ({
    type: "line",
    data: {
      labels: data.labels,
      datasets: [{
        data: data.values,
        borderColor: "rgba(139, 92, 246, 0.9)",
        backgroundColor: "rgba(139, 92, 246, 0.1)",
        fill: true,
        tension: 0.3,
        pointRadius: 4,
        pointHoverRadius: 6
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 600 },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: (items) => items[0].label,
            label: (item) => `${item.raw} new customers`
          }
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { font: { size: 11 } } },
        y: {
          grid: { color: "rgba(0,0,0,0.05)" },
          beginAtZero: true,
          ticks: { font: { size: 11 }, stepSize: 1 }
        }
      }
    }
  })
}

const ChartHook = {
  mounted() {
    const chartType = this.el.dataset.chartType
    const initialData = JSON.parse(this.el.dataset.chartData || '{"labels":[],"values":[]}')
    const configFn = CHART_CONFIGS[chartType]

    if (configFn) {
      this.chart = new Chart(this.el, configFn(initialData))
    }

    this.handleEvent(`chart-data:${this.el.id}`, ({ data }) => {
      if (this.chart && data) {
        this.chart.data.labels = data.labels
        this.chart.data.datasets[0].data = data.values
        this.chart.update("active")
      }
    })
  },

  updated() {
    const chartType = this.el.dataset.chartType
    const newData = JSON.parse(this.el.dataset.chartData || '{"labels":[],"values":[]}')
    if (this.chart && newData) {
      this.chart.data.labels = newData.labels
      this.chart.data.datasets[0].data = newData.values
      this.chart.update("active")
    }
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}

export default ChartHook
```

- [ ] **Step 3: Register ChartHook in app.js**

In `assets/js/app.js`, add the import and register the hook:

Add after the existing hook imports:
```javascript
import ChartHook from "./hooks/chart_hook"
```

Add `ChartHook` to the hooks object in the `LiveSocket` constructor:
```javascript
hooks: {ThemeToggle, Analytics, ScrollReveal, AutoDismiss, ThemeSettings, ScrollGlass, AddToBag, AtelierNavScroll, ChartHook},
```

- [ ] **Step 4: Verify the asset pipeline compiles**

Run:
```bash
cd /Users/kojo/Desktop/saas/emakola && mix assets.build 2>&1 | tail -5
```
Expected: Build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
git add assets/js/hooks/chart_hook.js assets/js/app.js assets/package.json assets/package-lock.json
git commit -m "feat(web): add Chart.js hook for interactive dashboard charts"
```

---

### Task 2: Rewrite DashboardHelpers with Store-Scoped Queries

**Files:**
- Modify: `lib/emakola_web/live/dashboard/dashboard_helpers.ex`
- Create: `test/emakola_web/live/dashboard/dashboard_helpers_test.exs`

- [ ] **Step 1: Write failing tests for the new helpers**

Create `test/emakola_web/live/dashboard/dashboard_helpers_test.exs`:

```elixir
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

    # Create an order with a line item
    order =
      Factory.create_order!(store, %{
        customer_id: customer.id,
        total: 10_000,
        subtotal: 10_000,
        status: :confirmed
      })

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: 2
    })
    |> Ash.create!()

    # Create a failed payment in the current store
    Factory.create_payment!(store, %{status: :failed, amount: 5_000})

    # Create order in OTHER store (should never appear)
    other_customer = Factory.create_customer!(other_store)

    Factory.create_order!(other_store, %{
      customer_id: other_customer.id,
      total: 99_999,
      subtotal: 99_999
    })

    %{store: store, other_store: other_store, order: order, customer: customer, product: product}
  end

  describe "load_merchant_dashboard/2" do
    test "returns all dashboard data scoped to store", %{store: store} do
      data = DashboardHelpers.load_merchant_dashboard(store.id, "month")

      assert is_integer(data.total_revenue)
      assert data.total_revenue == 10_000
      assert data.order_count == 1
      assert data.customer_count >= 1
      assert is_number(data.avg_order_value)
    end

    test "does not include data from other stores", %{store: store} do
      data = DashboardHelpers.load_merchant_dashboard(store.id, "month")

      # The other store's order with total 99_999 should not be included
      assert data.total_revenue == 10_000
    end

    test "returns chart data with labels and values", %{store: store} do
      data = DashboardHelpers.load_merchant_dashboard(store.id, "month")

      assert is_list(data.revenue_chart.labels)
      assert is_list(data.revenue_chart.values)
      assert length(data.revenue_chart.labels) == length(data.revenue_chart.values)

      assert is_list(data.orders_chart.labels)
      assert is_list(data.orders_chart.values)

      assert is_list(data.customers_chart.labels)
      assert is_list(data.customers_chart.values)
    end

    test "returns top products sorted by units sold", %{store: store} do
      data = DashboardHelpers.load_merchant_dashboard(store.id, "month")

      assert is_list(data.top_products_chart.labels)
      assert is_list(data.top_products_chart.values)
    end

    test "returns alerts with correct counts", %{store: store} do
      data = DashboardHelpers.load_merchant_dashboard(store.id, "month")

      assert is_integer(data.pending_orders)
      assert is_integer(data.low_stock_count)
      assert data.failed_payments == 1
    end

    test "returns recent orders list", %{store: store} do
      data = DashboardHelpers.load_merchant_dashboard(store.id, "month")

      assert is_list(data.recent_orders)
      assert length(data.recent_orders) <= 5
    end

    test "returns percentage changes", %{store: store} do
      data = DashboardHelpers.load_merchant_dashboard(store.id, "month")

      # pct_change can be nil (no previous data) or a float
      assert is_nil(data.revenue_change) or is_number(data.revenue_change)
      assert is_nil(data.orders_change) or is_number(data.orders_change)
      assert is_nil(data.customers_change) or is_number(data.customers_change)
      assert is_nil(data.aov_change) or is_number(data.aov_change)
    end

    test "handles today period", %{store: store} do
      data = DashboardHelpers.load_merchant_dashboard(store.id, "today")
      assert is_integer(data.total_revenue)
    end

    test "handles all-time period", %{store: store} do
      data = DashboardHelpers.load_merchant_dashboard(store.id, "all")
      assert is_integer(data.total_revenue)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
mix test test/emakola_web/live/dashboard/dashboard_helpers_test.exs -v
```
Expected: All tests FAIL because `load_merchant_dashboard/2` does not exist yet.

- [ ] **Step 3: Rewrite DashboardHelpers with store-scoped queries**

Replace the entire content of `lib/emakola_web/live/dashboard/dashboard_helpers.ex`:

```elixir
defmodule EmakolaWeb.DashboardHelpers do
  @moduledoc """
  Data loading and metric computation for the merchant analytics dashboard.
  All queries are scoped to a specific store_id.
  """

  require Ash.Query

  @periods ~w(today week month all)

  def valid_period?(period), do: period in @periods

  @doc """
  Loads all dashboard data for a given store and period.
  Returns a map with KPIs, chart data, alerts, and recent orders.
  """
  def load_merchant_dashboard(store_id, period) when period in @periods do
    {start_date, end_date} = date_range(period)
    {prev_start, prev_end} = previous_date_range(period)

    # Current period stats
    {order_count, total_revenue} = order_stats(store_id, start_date, end_date)
    customer_count = customer_count(store_id, start_date, end_date)
    avg_order_value = if order_count > 0, do: div(total_revenue, order_count), else: 0

    # Previous period stats for comparison
    {prev_order_count, prev_revenue} = order_stats(store_id, prev_start, prev_end)
    prev_customer_count = customer_count(store_id, prev_start, prev_end)
    prev_aov = if prev_order_count > 0, do: div(prev_revenue, prev_order_count), else: 0

    %{
      # KPIs
      total_revenue: total_revenue,
      order_count: order_count,
      customer_count: customer_count,
      avg_order_value: avg_order_value,

      # Percentage changes
      revenue_change: pct_change(total_revenue, prev_revenue),
      orders_change: pct_change(order_count, prev_order_count),
      customers_change: pct_change(customer_count, prev_customer_count),
      aov_change: pct_change(avg_order_value, prev_aov),

      # Chart data (labels + values for Chart.js)
      revenue_chart: daily_revenue_chart(store_id, start_date, end_date),
      orders_chart: daily_orders_chart(store_id, start_date, end_date),
      customers_chart: daily_customers_chart(store_id, start_date, end_date),
      top_products_chart: top_products_chart(store_id, start_date, end_date),

      # Alerts
      pending_orders: count_by_status(store_id, :pending),
      low_stock_count: low_stock_count(store_id),
      failed_payments: failed_payment_count(store_id, start_date, end_date),

      # Recent orders
      recent_orders: recent_orders(store_id)
    }
  end

  def load_merchant_dashboard(_store_id, _period), do: default_data()

  @doc "Returns default empty dashboard data."
  def default_data do
    %{
      total_revenue: 0,
      order_count: 0,
      customer_count: 0,
      avg_order_value: 0,
      revenue_change: nil,
      orders_change: nil,
      customers_change: nil,
      aov_change: nil,
      revenue_chart: %{labels: [], values: []},
      orders_chart: %{labels: [], values: []},
      customers_chart: %{labels: [], values: []},
      top_products_chart: %{labels: [], values: []},
      pending_orders: 0,
      low_stock_count: 0,
      failed_payments: 0,
      recent_orders: []
    }
  end

  # ── Date Ranges ──

  defp date_range("today") do
    today = Date.utc_today()
    {today, today}
  end

  defp date_range("week"), do: {Date.add(Date.utc_today(), -6), Date.utc_today()}
  defp date_range("month"), do: {Date.add(Date.utc_today(), -29), Date.utc_today()}
  defp date_range("all"), do: {~D[2020-01-01], Date.utc_today()}

  defp previous_date_range("today") do
    yesterday = Date.add(Date.utc_today(), -1)
    {yesterday, yesterday}
  end

  defp previous_date_range("week") do
    {Date.add(Date.utc_today(), -13), Date.add(Date.utc_today(), -7)}
  end

  defp previous_date_range("month") do
    {Date.add(Date.utc_today(), -59), Date.add(Date.utc_today(), -30)}
  end

  defp previous_date_range("all"), do: {~D[2020-01-01], Date.utc_today()}

  # ── Order Stats ──

  defp order_stats(store_id, start_date, end_date) do
    start_dt = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(Date.add(end_date, 1), ~T[00:00:00], "Etc/UTC")

    orders =
      Emakola.Orders.Order
      |> Ash.Query.filter(
        store_id == ^store_id and
          status != :cancelled and
          inserted_at >= ^start_dt and
          inserted_at < ^end_dt
      )
      |> Ash.read!(authorize?: false)

    count = length(orders)
    revenue = Enum.sum(Enum.map(orders, & &1.total))
    {count, revenue}
  end

  # ── Customer Stats ──

  defp customer_count(store_id, start_date, end_date) do
    start_dt = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(Date.add(end_date, 1), ~T[00:00:00], "Etc/UTC")

    case Emakola.Customers.Customer
         |> Ash.Query.filter(
           store_id == ^store_id and
             inserted_at >= ^start_dt and
             inserted_at < ^end_dt
         )
         |> Ash.count(authorize?: false) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  # ── Daily Chart Data ──

  defp daily_revenue_chart(store_id, start_date, end_date) do
    days = Date.range(start_date, end_date) |> Enum.to_list()
    # Limit to max 30 data points for readability
    days = if length(days) > 30, do: Enum.take(days, -30), else: days

    values =
      Enum.map(days, fn day ->
        day_start = DateTime.new!(day, ~T[00:00:00], "Etc/UTC")
        day_end = DateTime.new!(Date.add(day, 1), ~T[00:00:00], "Etc/UTC")

        orders =
          Emakola.Orders.Order
          |> Ash.Query.filter(
            store_id == ^store_id and
              status != :cancelled and
              inserted_at >= ^day_start and
              inserted_at < ^day_end
          )
          |> Ash.read!(authorize?: false)

        Enum.sum(Enum.map(orders, & &1.total))
      end)

    %{
      labels: Enum.map(days, &Calendar.strftime(&1, "%b %d")),
      values: values
    }
  end

  defp daily_orders_chart(store_id, start_date, end_date) do
    days = Date.range(start_date, end_date) |> Enum.to_list()
    days = if length(days) > 30, do: Enum.take(days, -30), else: days

    values =
      Enum.map(days, fn day ->
        day_start = DateTime.new!(day, ~T[00:00:00], "Etc/UTC")
        day_end = DateTime.new!(Date.add(day, 1), ~T[00:00:00], "Etc/UTC")

        case Emakola.Orders.Order
             |> Ash.Query.filter(
               store_id == ^store_id and
                 inserted_at >= ^day_start and
                 inserted_at < ^day_end
             )
             |> Ash.count(authorize?: false) do
          {:ok, count} -> count
          _ -> 0
        end
      end)

    %{
      labels: Enum.map(days, &Calendar.strftime(&1, "%b %d")),
      values: values
    }
  end

  defp daily_customers_chart(store_id, start_date, end_date) do
    days = Date.range(start_date, end_date) |> Enum.to_list()
    days = if length(days) > 30, do: Enum.take(days, -30), else: days

    values =
      Enum.map(days, fn day ->
        day_start = DateTime.new!(day, ~T[00:00:00], "Etc/UTC")
        day_end = DateTime.new!(Date.add(day, 1), ~T[00:00:00], "Etc/UTC")

        case Emakola.Customers.Customer
             |> Ash.Query.filter(
               store_id == ^store_id and
                 inserted_at >= ^day_start and
                 inserted_at < ^day_end
             )
             |> Ash.count(authorize?: false) do
          {:ok, count} -> count
          _ -> 0
        end
      end)

    %{
      labels: Enum.map(days, &Calendar.strftime(&1, "%b %d")),
      values: values
    }
  end

  # ── Top Products ──

  defp top_products_chart(store_id, start_date, end_date) do
    start_dt = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(Date.add(end_date, 1), ~T[00:00:00], "Etc/UTC")

    line_items =
      Emakola.Orders.LineItem
      |> Ash.Query.filter(
        store_id == ^store_id and
          inserted_at >= ^start_dt and
          inserted_at < ^end_dt
      )
      |> Ash.read!(authorize?: false)

    top =
      line_items
      |> Enum.group_by(& &1.product_title)
      |> Enum.map(fn {title, items} ->
        {title, Enum.sum(Enum.map(items, & &1.quantity))}
      end)
      |> Enum.sort_by(fn {_title, qty} -> qty end, :desc)
      |> Enum.take(5)

    %{
      labels: Enum.map(top, fn {title, _} -> truncate(title, 20) end),
      values: Enum.map(top, fn {_, qty} -> qty end)
    }
  end

  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max - 1) <> "..."

  # ── Alerts ──

  defp count_by_status(store_id, status) do
    case Emakola.Orders.Order
         |> Ash.Query.filter(store_id == ^store_id and status == ^status)
         |> Ash.count(authorize?: false) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp low_stock_count(store_id) do
    case Emakola.Catalog.Variant
         |> Ash.Query.filter(
           store_id == ^store_id and
             track_inventory == true and
             stock_quantity < 10
         )
         |> Ash.count(authorize?: false) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp failed_payment_count(store_id, start_date, end_date) do
    start_dt = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(Date.add(end_date, 1), ~T[00:00:00], "Etc/UTC")

    case Emakola.Payments.Payment
         |> Ash.Query.filter(
           store_id == ^store_id and
             status == :failed and
             inserted_at >= ^start_dt and
             inserted_at < ^end_dt
         )
         |> Ash.count(authorize?: false) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  # ── Recent Orders ──

  defp recent_orders(store_id) do
    Emakola.Orders.Order
    |> Ash.Query.filter(store_id == ^store_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(5)
    |> Ash.Query.load([:customer])
    |> Ash.read!(authorize?: false)
  end

  # ── Helpers ──

  defp pct_change(_current, 0), do: nil

  defp pct_change(current, previous) do
    Float.round((current - previous) / previous * 100, 1)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
mix test test/emakola_web/live/dashboard/dashboard_helpers_test.exs -v
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola_web/live/dashboard/dashboard_helpers.ex test/emakola_web/live/dashboard/dashboard_helpers_test.exs
git commit -m "feat(dashboard): rewrite helpers with store-scoped merchant queries"
```

---

### Task 3: Rewrite Dashboard Components

**Files:**
- Modify: `lib/emakola_web/live/dashboard/dashboard_components.ex`
- Modify: `lib/emakola_web/live/dashboard/metric_components.ex`

- [ ] **Step 1: Rewrite dashboard_components.ex**

Replace the entire content of `lib/emakola_web/live/dashboard/dashboard_components.ex`:

```elixir
defmodule EmakolaWeb.DashboardComponents do
  @moduledoc """
  Layout and UI components for the merchant analytics dashboard:
  page header with period toggle, alerts panel, and recent orders table.
  """

  use Phoenix.Component

  attr :period, :string, required: true
  attr :periods, :list, required: true

  def dashboard_header(assigns) do
    ~H"""
    <section class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">Dashboard</h1>
        <p class="text-sm text-slate-500 mt-1">Your store at a glance</p>
      </div>
      <div class="flex items-center gap-3">
        <div class="flex bg-slate-100 rounded-xl p-1">
          <button
            :for={p <- @periods}
            phx-click="change_period"
            phx-value-period={p}
            class={[
              "px-3 py-1.5 rounded-lg text-xs font-medium cursor-pointer transition-all",
              if(@period == p,
                do: "bg-blue-600 text-white shadow-sm",
                else: "text-slate-500 hover:text-slate-700"
              )
            ]}
          >
            {period_label(p)}
          </button>
        </div>
        <button
          phx-click="refresh_data"
          class="p-2 text-slate-400 hover:text-blue-600 transition-colors rounded-lg hover:bg-slate-50"
          title="Refresh"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182M20.938 14.828v4.992"
            />
          </svg>
        </button>
      </div>
    </section>
    """
  end

  defp period_label("today"), do: "Today"
  defp period_label("week"), do: "7 Days"
  defp period_label("month"), do: "30 Days"
  defp period_label("all"), do: "All Time"
  defp period_label(other), do: other

  attr :pending_orders, :integer, required: true
  attr :low_stock_count, :integer, required: true
  attr :failed_payments, :integer, required: true

  def alerts_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-slate-200 p-6">
      <h3 class="text-sm font-semibold text-slate-900 mb-4">Needs Attention</h3>
      <div class="space-y-3">
        <.alert_row
          icon="shopping_bag"
          label="Pending Orders"
          count={@pending_orders}
          href="/admin/orders?status=pending"
          color="amber"
        />
        <.alert_row
          icon="inventory_2"
          label="Low Stock Items"
          count={@low_stock_count}
          href="/admin/products"
          color="red"
        />
        <.alert_row
          icon="error"
          label="Failed Payments"
          count={@failed_payments}
          href="/admin/payments?status=failed"
          color="rose"
        />
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :href, :string, required: true
  attr :color, :string, required: true

  defp alert_row(assigns) do
    ~H"""
    <a href={@href} class="flex items-center justify-between p-3 rounded-xl hover:bg-slate-50 transition-colors group">
      <div class="flex items-center gap-3">
        <div class={[
          "w-9 h-9 rounded-lg flex items-center justify-center",
          alert_bg(@color)
        ]}>
          <span class={"material-symbols-outlined text-lg #{alert_text(@color)}"}>{@icon}</span>
        </div>
        <span class="text-sm text-slate-700">{@label}</span>
      </div>
      <span class={[
        "text-sm font-bold tabular-nums",
        if(@count > 0, do: alert_text(@color), else: "text-slate-400")
      ]}>
        {@count}
      </span>
    </a>
    """
  end

  defp alert_bg("amber"), do: "bg-amber-50"
  defp alert_bg("red"), do: "bg-red-50"
  defp alert_bg("rose"), do: "bg-rose-50"
  defp alert_bg(_), do: "bg-slate-50"

  defp alert_text("amber"), do: "text-amber-600"
  defp alert_text("red"), do: "text-red-600"
  defp alert_text("rose"), do: "text-rose-600"
  defp alert_text(_), do: "text-slate-600"

  attr :recent_orders, :list, required: true

  def recent_orders_table(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-slate-200">
      <div class="flex items-center justify-between p-6 pb-4">
        <h3 class="text-sm font-semibold text-slate-900">Recent Orders</h3>
        <a href="/admin/orders" class="text-xs font-medium text-blue-600 hover:text-blue-700">
          View All
        </a>
      </div>
      <%= if @recent_orders == [] do %>
        <div class="px-6 pb-8 text-center">
          <span class="material-symbols-outlined text-4xl text-slate-200 mb-2 block">receipt_long</span>
          <p class="text-sm text-slate-400">No orders yet</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="border-t border-slate-100">
                <th class="text-left text-xs font-medium text-slate-400 uppercase tracking-wider px-6 py-3">
                  Order
                </th>
                <th class="text-left text-xs font-medium text-slate-400 uppercase tracking-wider px-6 py-3">
                  Customer
                </th>
                <th class="text-right text-xs font-medium text-slate-400 uppercase tracking-wider px-6 py-3">
                  Total
                </th>
                <th class="text-center text-xs font-medium text-slate-400 uppercase tracking-wider px-6 py-3">
                  Status
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={order <- @recent_orders}
                class="border-t border-slate-50 hover:bg-slate-50/50 transition-colors"
              >
                <td class="px-6 py-3">
                  <a
                    href={"/admin/orders/#{order.id}"}
                    class="text-sm font-medium text-blue-600 hover:text-blue-700"
                  >
                    {order.order_number}
                  </a>
                </td>
                <td class="px-6 py-3 text-sm text-slate-600">
                  {customer_name(order)}
                </td>
                <td class="px-6 py-3 text-sm font-medium text-slate-900 text-right tabular-nums">
                  {format_money(order.total, order.currency)}
                </td>
                <td class="px-6 py-3 text-center">
                  <.status_badge status={order.status} />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp customer_name(order) do
    case order do
      %{customer: %{name: name}} when is_binary(name) and name != "" -> name
      %{customer: %{email: email}} when not is_nil(email) -> to_string(email)
      _ -> "Guest"
    end
  end

  defp format_money(amount_pesewas, currency) do
    major = div(amount_pesewas, 100)
    minor = rem(abs(amount_pesewas), 100)
    formatted = Number.Delimit.number_to_delimited(major, precision: 0)
    "#{currency} #{formatted}.#{String.pad_leading(to_string(minor), 2, "0")}"
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-semibold",
      status_classes(@status)
    ]}>
      <span class={["w-1.5 h-1.5 rounded-full", status_dot(@status)]}></span>
      {status_label(@status)}
    </span>
    """
  end

  defp status_classes(:pending), do: "bg-amber-50 text-amber-700"
  defp status_classes(:confirmed), do: "bg-blue-50 text-blue-700"
  defp status_classes(:processing), do: "bg-indigo-50 text-indigo-700"
  defp status_classes(:shipped), do: "bg-purple-50 text-purple-700"
  defp status_classes(:delivered), do: "bg-emerald-50 text-emerald-700"
  defp status_classes(:cancelled), do: "bg-red-50 text-red-700"
  defp status_classes(_), do: "bg-slate-50 text-slate-700"

  defp status_dot(:pending), do: "bg-amber-500"
  defp status_dot(:confirmed), do: "bg-blue-500"
  defp status_dot(:processing), do: "bg-indigo-500"
  defp status_dot(:shipped), do: "bg-purple-500"
  defp status_dot(:delivered), do: "bg-emerald-500"
  defp status_dot(:cancelled), do: "bg-red-500"
  defp status_dot(_), do: "bg-slate-500"

  defp status_label(:pending), do: "Pending"
  defp status_label(:confirmed), do: "Confirmed"
  defp status_label(:processing), do: "Processing"
  defp status_label(:shipped), do: "Shipped"
  defp status_label(:delivered), do: "Delivered"
  defp status_label(:cancelled), do: "Cancelled"
  defp status_label(s), do: s |> to_string() |> String.capitalize()
end
```

- [ ] **Step 2: Rewrite metric_components.ex with KPI cards and chart canvases**

Replace the entire content of `lib/emakola_web/live/dashboard/metric_components.ex`:

```elixir
defmodule EmakolaWeb.DashboardMetricComponents do
  @moduledoc """
  KPI cards and chart canvas components for the merchant analytics dashboard.
  Chart canvases render with phx-hook="ChartHook" for Chart.js interactivity.
  """

  use Phoenix.Component

  attr :total_revenue, :integer, required: true
  attr :revenue_change, :any, default: nil
  attr :order_count, :integer, required: true
  attr :orders_change, :any, default: nil
  attr :customer_count, :integer, required: true
  attr :customers_change, :any, default: nil
  attr :avg_order_value, :integer, required: true
  attr :aov_change, :any, default: nil

  def kpi_cards(assigns) do
    ~H"""
    <section class="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <.kpi_card
        label="Revenue"
        value={format_money(@total_revenue)}
        change={@revenue_change}
        icon="payments"
      />
      <.kpi_card
        label="Orders"
        value={to_string(@order_count)}
        change={@orders_change}
        icon="shopping_cart"
      />
      <.kpi_card
        label="Customers"
        value={to_string(@customer_count)}
        change={@customers_change}
        icon="group"
      />
      <.kpi_card
        label="Avg Order"
        value={format_money(@avg_order_value)}
        change={@aov_change}
        icon="trending_up"
      />
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :change, :any, default: nil
  attr :icon, :string, required: true

  defp kpi_card(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-slate-200 p-5">
      <div class="flex items-center justify-between mb-3">
        <span class="text-xs font-medium text-slate-400 uppercase tracking-wider">{@label}</span>
        <span class="material-symbols-outlined text-lg text-slate-300">{@icon}</span>
      </div>
      <p class="text-2xl font-bold text-slate-900 tabular-nums">{@value}</p>
      <.change_indicator change={@change} />
    </div>
    """
  end

  attr :change, :any, default: nil

  defp change_indicator(assigns) do
    ~H"""
    <div :if={@change != nil} class="flex items-center gap-1 mt-2">
      <span :if={@change >= 0} class="text-xs font-medium text-emerald-600 flex items-center gap-0.5">
        <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 19.5l15-15m0 0H8.25m11.25 0v11.25" />
        </svg>
        {abs(@change)}%
      </span>
      <span :if={@change < 0} class="text-xs font-medium text-red-500 flex items-center gap-0.5">
        <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 4.5l15 15m0 0V8.25m0 11.25H8.25" />
        </svg>
        {abs(@change)}%
      </span>
      <span class="text-xs text-slate-400">vs prev period</span>
    </div>
    <div :if={@change == nil} class="mt-2">
      <span class="text-xs text-slate-300">No previous data</span>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :chart_type, :string, required: true
  attr :chart_data, :map, required: true
  attr :height, :string, default: "h-64"

  def chart_card(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-slate-200 p-6">
      <h3 class="text-sm font-semibold text-slate-900 mb-4">{@title}</h3>
      <div class={@height}>
        <canvas
          id={@id}
          phx-hook="ChartHook"
          data-chart-type={@chart_type}
          data-chart-data={Jason.encode!(@chart_data)}
          phx-update="ignore"
        >
        </canvas>
      </div>
    </div>
    """
  end

  defp format_money(amount_pesewas) do
    major = div(amount_pesewas, 100)
    minor = rem(abs(amount_pesewas), 100)

    formatted =
      major
      |> abs()
      |> Integer.to_string()
      |> String.reverse()
      |> String.replace(~r/.{3}(?=.)/, "\\0,")
      |> String.reverse()

    sign = if amount_pesewas < 0, do: "-", else: ""
    "#{sign}GHS #{formatted}.#{String.pad_leading(to_string(minor), 2, "0")}"
  end
end
```

- [ ] **Step 3: Verify formatting**

Run:
```bash
mix format lib/emakola_web/live/dashboard/dashboard_components.ex lib/emakola_web/live/dashboard/metric_components.ex
```

- [ ] **Step 4: Commit**

```bash
git add lib/emakola_web/live/dashboard/dashboard_components.ex lib/emakola_web/live/dashboard/metric_components.ex
git commit -m "feat(dashboard): rewrite components for merchant analytics UI"
```

---

### Task 4: Rewrite DashboardLive

**Files:**
- Modify: `lib/emakola_web/live/dashboard_live.ex`

- [ ] **Step 1: Rewrite DashboardLive**

Replace the entire content of `lib/emakola_web/live/dashboard_live.ex`:

```elixir
defmodule EmakolaWeb.DashboardLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.DashboardComponents
  import EmakolaWeb.DashboardMetricComponents

  alias EmakolaWeb.DashboardHelpers

  @refresh_interval 30_000
  @periods ~w(today week month all)

  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    if connected?(socket) do
      Process.send_after(self(), :refresh, @refresh_interval)

      if store_id do
        Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{store_id}:orders")
      end
    end

    socket =
      socket
      |> assign(
        active_nav: :dashboard,
        page_title: "Dashboard",
        store_id: store_id,
        period: "week",
        periods: @periods
      )
      |> load_dashboard_data()

    {:ok, socket}
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, load_dashboard_data(socket)}
  end

  def handle_info({:order_created, _}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  def handle_info({:order_updated, _}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  def handle_event("change_period", %{"period" => period}, socket) when period in @periods do
    socket =
      socket
      |> assign(period: period)
      |> load_dashboard_data()
      |> push_chart_events()

    {:noreply, socket}
  end

  def handle_event("change_period", _params, socket), do: {:noreply, socket}

  def handle_event("refresh_data", _, socket) do
    socket =
      socket
      |> load_dashboard_data()
      |> push_chart_events()
      |> put_flash(:info, "Dashboard refreshed")

    {:noreply, socket}
  end

  defp load_dashboard_data(socket) do
    store_id = socket.assigns.store_id
    period = socket.assigns.period

    data =
      if store_id do
        try do
          DashboardHelpers.load_merchant_dashboard(store_id, period)
        rescue
          _ -> DashboardHelpers.default_data()
        end
      else
        DashboardHelpers.default_data()
      end

    assign(socket, data)
  end

  defp push_chart_events(socket) do
    socket
    |> push_event("chart-data:revenue-chart", %{data: socket.assigns.revenue_chart})
    |> push_event("chart-data:orders-chart", %{data: socket.assigns.orders_chart})
    |> push_event("chart-data:customers-chart", %{data: socket.assigns.customers_chart})
    |> push_event("chart-data:top-products-chart", %{data: socket.assigns.top_products_chart})
  end

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.dashboard_header period={@period} periods={@periods} />

      <.kpi_cards
        total_revenue={@total_revenue}
        revenue_change={@revenue_change}
        order_count={@order_count}
        orders_change={@orders_change}
        customer_count={@customer_count}
        customers_change={@customers_change}
        avg_order_value={@avg_order_value}
        aov_change={@aov_change}
      />

      <%!-- Charts + Sidebar Grid --%>
      <section class="grid grid-cols-1 lg:grid-cols-12 gap-6">
        <%!-- Left: Charts --%>
        <div class="lg:col-span-8 space-y-6">
          <.chart_card
            id="revenue-chart"
            title="Revenue"
            chart_type="revenue-bar"
            chart_data={@revenue_chart}
          />
          <.chart_card
            id="orders-chart"
            title="Orders"
            chart_type="orders-line"
            chart_data={@orders_chart}
          />
        </div>

        <%!-- Right: Alerts + Top Products + Customer Growth --%>
        <div class="lg:col-span-4 space-y-6">
          <.alerts_panel
            pending_orders={@pending_orders}
            low_stock_count={@low_stock_count}
            failed_payments={@failed_payments}
          />
          <.chart_card
            id="top-products-chart"
            title="Top Products"
            chart_type="top-products-horizontal"
            chart_data={@top_products_chart}
            height="h-48"
          />
          <.chart_card
            id="customers-chart"
            title="New Customers"
            chart_type="customers-line"
            chart_data={@customers_chart}
            height="h-48"
          />
        </div>
      </section>

      <%!-- Recent Orders --%>
      <.recent_orders_table recent_orders={@recent_orders} />
    </div>
    """
  end
end
```

- [ ] **Step 2: Format and verify compilation**

Run:
```bash
mix format lib/emakola_web/live/dashboard_live.ex && mix compile --warnings-as-errors 2>&1 | tail -5
```
Expected: Compiles without errors.

- [ ] **Step 3: Commit**

```bash
git add lib/emakola_web/live/dashboard_live.ex
git commit -m "feat(dashboard): rewrite LiveView for merchant analytics with Chart.js"
```

---

### Task 5: Write LiveView Integration Tests

**Files:**
- Create: `test/emakola_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write the LiveView test file**

Create `test/emakola_web/live/dashboard_live_test.exs`:

```elixir
defmodule EmakolaWeb.DashboardLiveTest do
  use EmakolaWeb.ConnCase, async: true
  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)

    # Create some seed data
    customer = Factory.create_customer!(store)
    product = Factory.create_product!(store, status: :active)
    variant = Factory.create_variant!(product, store, price: 15_000, stock_quantity: 5)

    order =
      Factory.create_order!(store, %{
        customer_id: customer.id,
        total: 15_000,
        subtotal: 15_000,
        status: :confirmed
      })

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: 1
    })
    |> Ash.create!()

    %{conn: conn, merchant: merchant, store: store, order: order, customer: customer}
  end

  describe "dashboard page" do
    test "mounts and renders KPI cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Dashboard"
      assert html =~ "Revenue"
      assert html =~ "Orders"
      assert html =~ "Customers"
      assert html =~ "Avg Order"
    end

    test "renders period toggle with default selection", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Today"
      assert html =~ "7 Days"
      assert html =~ "30 Days"
      assert html =~ "All Time"
    end

    test "renders chart canvases with hooks", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "phx-hook=\"ChartHook\""
      assert html =~ "revenue-chart"
      assert html =~ "orders-chart"
      assert html =~ "customers-chart"
      assert html =~ "top-products-chart"
    end

    test "renders alerts panel", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Needs Attention"
      assert html =~ "Pending Orders"
      assert html =~ "Low Stock Items"
      assert html =~ "Failed Payments"
    end

    test "renders recent orders table with order data", %{conn: conn, order: order} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Recent Orders"
      assert html =~ order.order_number
    end

    test "shows correct order total formatted as currency", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # 15_000 pesewas = GHS 150.00
      assert html =~ "150.00"
    end

    test "period toggle updates data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      html =
        view
        |> element("button", "30 Days")
        |> render_click()

      assert html =~ "Dashboard"
    end

    test "refresh button works", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      html =
        view
        |> element("button[phx-click=\"refresh_data\"]")
        |> render_click()

      assert html =~ "Dashboard refreshed"
    end

    test "shows low stock alert for variant with stock < 10", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # The variant has stock_quantity: 5, so low_stock_count should be >= 1
      assert html =~ "Low Stock Items"
    end

    test "shows customer name in recent orders", %{conn: conn, customer: customer} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ customer.name
    end
  end

  describe "multi-tenant isolation" do
    test "does not show orders from another store", %{conn: conn} do
      {_other_merchant, other_store} = Factory.create_merchant_with_store!()
      other_customer = Factory.create_customer!(other_store)

      Factory.create_order!(other_store, %{
        customer_id: other_customer.id,
        total: 999_999,
        subtotal: 999_999
      })

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # GHS 9,999.99 should NOT appear
      refute html =~ "9,999.99"
    end
  end

  describe "empty state" do
    test "handles store with no orders gracefully", %{conn: conn} do
      # Create a fresh merchant with empty store
      {conn2, _merchant2, _store2} = setup_authenticated_merchant(build_conn())

      {:ok, _view, html} = live(conn2, ~p"/dashboard")

      assert html =~ "Dashboard"
      assert html =~ "No orders yet"
      assert html =~ "GHS 0.00"
    end
  end
end
```

- [ ] **Step 2: Run the tests**

Run:
```bash
mix test test/emakola_web/live/dashboard_live_test.exs -v
```
Expected: All tests PASS.

- [ ] **Step 3: Run full test suite to check for regressions**

Run:
```bash
mix test 2>&1 | tail -5
```
Expected: All tests pass, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add test/emakola_web/live/dashboard_live_test.exs
git commit -m "test(dashboard): add LiveView integration tests for merchant analytics"
```

---

### Task 6: Handle Number.Delimit Dependency

The `format_money` function in `dashboard_components.ex` uses `Number.Delimit.number_to_delimited/2`. Check if the `number` package is already a dependency. If not, use the inline formatting (already provided in `metric_components.ex` as a fallback).

**Files:**
- Modify: `lib/emakola_web/live/dashboard/dashboard_components.ex` (if needed)

- [ ] **Step 1: Check if Number is available**

Run:
```bash
cd /Users/kojo/Desktop/saas/emakola && grep -r "number" mix.exs | grep dep
```

If `{:number, "~> 1.0"}` is NOT in deps, update the `format_money` function in `dashboard_components.ex` to use inline formatting:

```elixir
defp format_money(amount_pesewas, currency) do
  major = div(amount_pesewas, 100)
  minor = rem(abs(amount_pesewas), 100)

  formatted =
    major
    |> abs()
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/.{3}(?=.)/, "\\0,")
    |> String.reverse()

  sign = if amount_pesewas < 0, do: "-", else: ""
  "#{sign}#{currency} #{formatted}.#{String.pad_leading(to_string(minor), 2, "0")}"
end
```

- [ ] **Step 2: Verify compilation**

Run:
```bash
mix compile --warnings-as-errors 2>&1 | tail -3
```
Expected: Compiles cleanly.

- [ ] **Step 3: Commit if changes were needed**

```bash
git add lib/emakola_web/live/dashboard/dashboard_components.ex
git commit -m "fix(dashboard): use inline money formatting, remove Number dependency"
```

---

### Task 7: Final Verification

- [ ] **Step 1: Format all changed files**

Run:
```bash
mix format
```

- [ ] **Step 2: Run credo**

Run:
```bash
mix credo --strict 2>&1 | tail -10
```
Expected: No issues or only pre-existing ones.

- [ ] **Step 3: Run full test suite**

Run:
```bash
mix test 2>&1 | tail -5
```
Expected: All tests pass, 0 failures.

- [ ] **Step 4: Final commit if any formatting changes**

```bash
git add -A && git status
```

If there are formatting changes:
```bash
git commit -m "chore: format dashboard analytics code"
```
