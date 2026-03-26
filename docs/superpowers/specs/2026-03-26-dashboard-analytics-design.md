# Dashboard Analytics Design

## Overview

Replace the generic SaaS "command center" dashboard with a merchant-focused analytics dashboard. The dashboard answers two questions: "How is my business doing?" (KPIs + charts) and "What needs my attention?" (alerts + recent orders).

All charts are interactive using Chart.js via a shared LiveView hook, with hover tooltips, smooth animations, and live updates when the period filter changes.

## Architecture

### Files to Create
- `assets/js/hooks/chart_hook.js` -- Chart.js LiveView hook, handles all chart types
- `test/emakola_web/live/dashboard_live_test.exs` -- Dashboard tests

### Files to Modify
- `lib/emakola_web/live/dashboard_live.ex` -- Rewrite render + mount for merchant analytics
- `lib/emakola_web/live/dashboard/dashboard_helpers.ex` -- Replace with store-scoped merchant queries
- `lib/emakola_web/live/dashboard/dashboard_components.ex` -- New merchant dashboard components
- `lib/emakola_web/live/dashboard/metric_components.ex` -- New KPI card + chart components
- `assets/js/app.js` -- Register ChartHook

### Dependencies
- `chart.js` npm package added to `assets/package.json`

## UI Layout

### Global Period Toggle
A period selector at the top-right applies to all KPIs and charts:
- Today, 7 Days, 30 Days, All Time
- Changing period triggers `handle_event("change_period", ...)` which reloads all data and pushes updated chart data via `push_event`

### KPI Cards Row (4 cards, equal width)

| Card | Primary Value | Subtext |
|------|--------------|---------|
| Revenue | GHS total (formatted from pesewas) | % change vs previous period, green/red arrow |
| Orders | Order count | % change vs previous period |
| Customers | Unique customer count | "X new" this period |
| Avg Order Value | Revenue / Orders | % change vs previous period |

Percentage change compares current period to the equivalent previous period (e.g., this week vs last week).

### Main Content Area (grid: 8 cols left, 4 cols right)

#### Left Column (8 cols)

**Revenue Chart (Chart.js bar chart)**
- Daily revenue bars for the selected period
- Hover tooltip: date + exact GHS amount
- Animated transitions when period changes
- Bar color: theme primary color
- Canvas element with `phx-hook="ChartHook"` and `data-chart-type="revenue-bar"`

**Orders Chart (Chart.js line chart)**
- Daily order count trend line with filled area
- Hover tooltip: date + order count
- Line color: theme secondary color
- Canvas element with `data-chart-type="orders-line"`

**Recent Orders Table**
- Last 5 orders: order number, customer name, total (GHS), status badge, relative time
- Status badges: pending (amber), confirmed (blue), processing (indigo), shipped (purple), delivered (green), cancelled (red)
- "View All Orders" link to `/admin/orders`

#### Right Column (4 cols)

**Alerts Panel**
- Pending Orders: count of orders with status `:pending`, links to orders page
- Low Stock: count of product variants where `stock_quantity < 10`, links to products
- Failed Payments: count of payments with status `:failed` in current period

**Top Products (Chart.js horizontal bar chart)**
- Top 5 products by units sold in period
- Hover tooltip: product name + units + revenue
- Canvas element with `data-chart-type="top-products-horizontal"`

**Customer Growth (Chart.js line chart)**
- New customers per day over selected period
- Hover tooltip: date + count
- Canvas element with `data-chart-type="customers-line"`

## Data Layer

### DashboardHelpers Rewrite

Replace `load_dashboard_data(user)` with `load_merchant_dashboard(store_id, period)`.

All queries are scoped to `store_id` using `Ash.Query.filter(store_id == ^store_id)`.

#### Core Query Functions

```elixir
# Returns %{count: integer, revenue: integer (pesewas)}
defp order_stats(store_id, date_range)

# Returns %{count: integer, previous_count: integer}
defp customer_stats(store_id, date_range)

# Returns list of %{date: Date, revenue: integer} for chart
defp daily_revenue(store_id, date_range)

# Returns list of %{date: Date, count: integer} for chart
defp daily_orders(store_id, date_range)

# Returns list of %{date: Date, count: integer} for chart
defp daily_customers(store_id, date_range)

# Returns list of %{product_title: string, units: integer, revenue: integer}
defp top_products(store_id, date_range, limit \\ 5)

# Returns %{pending_orders: integer, low_stock: integer, failed_payments: integer}
defp alerts(store_id, date_range)

# Returns list of recent Order structs with preloaded line_items and customer
defp recent_orders(store_id, limit \\ 5)
```

#### Period Date Ranges

```elixir
defp date_range("today"), do: {Date.utc_today(), Date.utc_today()}
defp date_range("week"), do: {Date.add(Date.utc_today(), -6), Date.utc_today()}
defp date_range("month"), do: {Date.add(Date.utc_today(), -29), Date.utc_today()}
defp date_range("all"), do: {~D[2020-01-01], Date.utc_today()}
```

Previous period for comparison:
- "today" compares to yesterday
- "week" compares to previous 7 days
- "month" compares to previous 30 days
- "all" shows no comparison

#### Percentage Change Calculation

```elixir
defp pct_change(_current, 0), do: nil
defp pct_change(current, previous), do: Float.round((current - previous) / previous * 100, 1)
```

## Chart.js Hook

### Hook Design (`assets/js/hooks/chart_hook.js`)

A single hook handles all chart instances:

```javascript
// Pseudocode structure
ChartHook = {
  mounted() {
    this.chart = createChart(this.el, this.el.dataset.chartType, initialData)
    this.handleEvent("chart-data:" + this.el.id, ({data}) => {
      updateChart(this.chart, data)
    })
  },
  destroyed() {
    this.chart.destroy()
  }
}
```

Each canvas element has:
- `id` -- unique identifier (e.g., "revenue-chart")
- `phx-hook="ChartHook"`
- `data-chart-type` -- determines chart configuration (bar, line, horizontal-bar)
- `data-chart-data` -- JSON-encoded initial data passed as a data attribute

When period changes, the server calls `push_event("chart-data:revenue-chart", %{data: ...})` for each chart. The hook updates the chart with animation.

### Chart Configurations

**Revenue Bar**: vertical bars, primary color, GHS formatting on tooltip
**Orders Line**: line with fill, secondary color, integer formatting
**Top Products Horizontal Bar**: horizontal bars, gradient colors, product labels on y-axis
**Customer Growth Line**: line with fill, tertiary color, integer formatting

### Chart.js Options (shared)
- `responsive: true`
- `maintainAspectRatio: false`
- `animation.duration: 600`
- `plugins.tooltip.enabled: true`
- `plugins.legend.display: false`
- No grid lines on x-axis, light grid on y-axis
- Font: inherit from page (system font stack)

## Money Formatting

All monetary values stored as integers in pesewas. Display formatting:
- `format_money(5000, "GHS")` -> "GHS 50.00"
- `format_money(125050, "GHS")` -> "GHS 1,250.50"

Formatting happens only in the presentation layer (components and chart tooltip callbacks).

## LiveView Flow

1. `mount/3`: get `store_id` from `socket.assigns.current_store`, default period to "week", load all data, assign to socket
2. `render/1`: render KPI cards, chart canvases (with `data-chart-data` for initial load), alerts, recent orders, top products
3. `handle_event("change_period", %{"period" => p})`: update period, reload all data, `push_event` new chart data to each chart hook
4. `handle_info(:refresh, socket)`: auto-refresh every 30s, reload data, push updated charts
5. PubSub subscription on `"store:#{store_id}:orders"` for real-time order updates

## Testing Strategy

### Unit Tests (DashboardHelpers)
- `order_stats/2` returns correct count and revenue for date range
- `daily_revenue/2` returns correct daily breakdown
- `top_products/2` returns products sorted by units sold
- `alerts/2` returns correct counts for pending, low stock, failed
- `pct_change/2` handles zero, positive, negative changes
- All queries scoped to store_id (no cross-tenant data leakage)

### LiveView Tests
- Dashboard mounts and renders KPI cards with correct values
- Period toggle updates assigns
- Recent orders table shows orders with correct formatting
- Alerts panel shows correct counts
- Empty state: new store with no orders shows zeros gracefully
- Chart canvases render with correct hook and data attributes

### Multi-tenant Isolation
- Create orders for two different stores, verify dashboard only shows data for the current store
