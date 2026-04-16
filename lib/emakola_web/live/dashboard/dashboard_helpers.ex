defmodule EmakolaWeb.DashboardHelpers do
  @moduledoc "Data loading, metric computation, and chart generation for the merchant admin dashboard."

  require Ash.Query

  @doc "Returns a map with all dashboard data for the given store and period."
  def load_merchant_dashboard(store_id, period) do
    {range_start, range_end} = date_range(period)
    {prev_start, prev_end} = previous_range(period)

    day_start = DateTime.new!(range_start, ~T[00:00:00], "Etc/UTC")
    day_end = DateTime.new!(Date.add(range_end, 1), ~T[00:00:00], "Etc/UTC")

    prev_day_start = DateTime.new!(prev_start, ~T[00:00:00], "Etc/UTC")
    prev_day_end = DateTime.new!(Date.add(prev_end, 1), ~T[00:00:00], "Etc/UTC")

    # Current period metrics — use aggregates instead of loading full rows
    {total_revenue, order_count} = revenue_and_count(store_id, day_start, day_end)
    avg_order_value = if order_count > 0, do: div(total_revenue, order_count), else: 0

    customer_count = count_customers(store_id, day_start, day_end)

    # Previous period metrics (for comparison)
    {revenue_change, orders_change, customers_change, aov_change} =
      if period == "all" do
        {nil, nil, nil, nil}
      else
        {prev_revenue, prev_order_count} =
          revenue_and_count(store_id, prev_day_start, prev_day_end)

        prev_avg = if prev_order_count > 0, do: div(prev_revenue, prev_order_count), else: 0
        prev_customer_count = count_customers(store_id, prev_day_start, prev_day_end)

        {
          pct_change(total_revenue, prev_revenue),
          pct_change(order_count, prev_order_count),
          pct_change(customer_count, prev_customer_count),
          pct_change(avg_order_value, prev_avg)
        }
      end

    # Charts — single bulk query per chart, grouped by date in Elixir
    dates = chart_dates(range_start, range_end)
    chart_start = DateTime.new!(List.first(dates), ~T[00:00:00], "Etc/UTC")
    chart_end = DateTime.new!(Date.add(List.last(dates), 1), ~T[00:00:00], "Etc/UTC")

    orders_in_range = load_non_cancelled_orders(store_id, chart_start, chart_end)
    customers_in_range = load_customers_in_range(store_id, chart_start, chart_end)

    revenue_chart = build_revenue_chart(orders_in_range, dates)
    orders_chart = build_orders_chart(orders_in_range, dates)
    customers_chart = build_customers_chart(customers_in_range, dates)
    top_products_chart = build_top_products_chart(store_id, day_start, day_end)

    # Alerts
    pending_orders = count_pending_orders(store_id)
    low_stock_count = count_low_stock(store_id)
    failed_payments = count_failed_payments(store_id, day_start, day_end)

    # Recent orders
    recent_orders = load_recent_orders(store_id)

    %{
      total_revenue: total_revenue,
      order_count: order_count,
      customer_count: customer_count,
      avg_order_value: avg_order_value,
      revenue_change: revenue_change,
      orders_change: orders_change,
      customers_change: customers_change,
      aov_change: aov_change,
      revenue_chart: revenue_chart,
      orders_chart: orders_chart,
      customers_chart: customers_chart,
      top_products_chart: top_products_chart,
      pending_orders: pending_orders,
      low_stock_count: low_stock_count,
      failed_payments: failed_payments,
      recent_orders: recent_orders
    }
  end

  @doc "Returns empty/zero defaults for all dashboard data keys."
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

  defp date_range("today"), do: {Date.utc_today(), Date.utc_today()}
  defp date_range("week"), do: {Date.add(Date.utc_today(), -6), Date.utc_today()}
  defp date_range("month"), do: {Date.add(Date.utc_today(), -29), Date.utc_today()}
  defp date_range("all"), do: {~D[2020-01-01], Date.utc_today()}

  defp previous_range("today") do
    yesterday = Date.add(Date.utc_today(), -1)
    {yesterday, yesterday}
  end

  defp previous_range("week") do
    {Date.add(Date.utc_today(), -13), Date.add(Date.utc_today(), -7)}
  end

  defp previous_range("month") do
    {Date.add(Date.utc_today(), -59), Date.add(Date.utc_today(), -30)}
  end

  defp previous_range("all"), do: {~D[2020-01-01], Date.utc_today()}

  # ── Percentage Change ──

  defp pct_change(_current, 0), do: nil

  defp pct_change(current, previous),
    do: Float.round((current - previous) / previous * 100, 1)

  # ── Data Loaders ──

  defp revenue_and_count(store_id, from, to) do
    base =
      Emakola.Orders.Order
      |> Ash.Query.filter(
        store_id == ^store_id and
          status != :cancelled and
          inserted_at >= ^from and
          inserted_at < ^to
      )

    {:ok, revenue} = Ash.sum(base, :total, authorize?: false)
    {:ok, count} = Ash.count(base, authorize?: false)
    {revenue || 0, count}
  end

  defp load_non_cancelled_orders(store_id, from, to) do
    Emakola.Orders.Order
    |> Ash.Query.filter(
      store_id == ^store_id and
        status != :cancelled and
        inserted_at >= ^from and
        inserted_at < ^to
    )
    |> Ash.Query.select([:id, :total, :inserted_at])
    |> Ash.read!(authorize?: false)
  end

  defp load_customers_in_range(store_id, from, to) do
    Emakola.Customers.Customer
    |> Ash.Query.filter(
      store_id == ^store_id and
        inserted_at >= ^from and
        inserted_at < ^to
    )
    |> Ash.Query.select([:id, :inserted_at])
    |> Ash.read!(authorize?: false)
  end

  defp count_customers(store_id, from, to) do
    {:ok, count} =
      Emakola.Customers.Customer
      |> Ash.Query.filter(
        store_id == ^store_id and
          inserted_at >= ^from and
          inserted_at < ^to
      )
      |> Ash.count(authorize?: false)

    count
  end

  defp count_pending_orders(store_id) do
    {:ok, count} =
      Emakola.Orders.Order
      |> Ash.Query.filter(store_id == ^store_id and status == :pending)
      |> Ash.count(authorize?: false)

    count
  end

  defp count_low_stock(store_id) do
    {:ok, count} =
      Emakola.Catalog.Variant
      |> Ash.Query.filter(
        store_id == ^store_id and
          track_inventory == true and
          stock_quantity < 10
      )
      |> Ash.count(authorize?: false)

    count
  end

  defp count_failed_payments(store_id, from, to) do
    {:ok, count} =
      Emakola.Payments.Payment
      |> Ash.Query.filter(
        store_id == ^store_id and
          status == :failed and
          inserted_at >= ^from and
          inserted_at < ^to
      )
      |> Ash.count(authorize?: false)

    count
  end

  defp load_recent_orders(store_id) do
    Emakola.Orders.Order
    |> Ash.Query.filter(store_id == ^store_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(5)
    |> Ash.Query.load([:customer])
    |> Ash.read!(authorize?: false)
  end

  # ── Chart Builders ──

  defp chart_dates(range_start, range_end) do
    dates = Date.range(range_start, range_end) |> Enum.to_list()

    if length(dates) > 30 do
      Enum.take(dates, -30)
    else
      dates
    end
  end

  defp build_revenue_chart(orders, dates) do
    by_date = Enum.group_by(orders, fn o -> DateTime.to_date(o.inserted_at) end)
    labels = Enum.map(dates, &Calendar.strftime(&1, "%b %d"))

    values =
      Enum.map(dates, fn date ->
        Map.get(by_date, date, []) |> Enum.map(& &1.total) |> Enum.sum()
      end)

    %{labels: labels, values: values}
  end

  defp build_orders_chart(orders, dates) do
    by_date = Enum.group_by(orders, fn o -> DateTime.to_date(o.inserted_at) end)
    labels = Enum.map(dates, &Calendar.strftime(&1, "%b %d"))
    values = Enum.map(dates, fn date -> length(Map.get(by_date, date, [])) end)
    %{labels: labels, values: values}
  end

  defp build_customers_chart(customers, dates) do
    by_date = Enum.group_by(customers, fn c -> DateTime.to_date(c.inserted_at) end)
    labels = Enum.map(dates, &Calendar.strftime(&1, "%b %d"))
    values = Enum.map(dates, fn date -> length(Map.get(by_date, date, [])) end)
    %{labels: labels, values: values}
  end

  defp build_top_products_chart(store_id, from, to) do
    line_items =
      Emakola.Orders.LineItem
      |> Ash.Query.filter(
        store_id == ^store_id and
          inserted_at >= ^from and
          inserted_at < ^to
      )
      |> Ash.read!(authorize?: false)

    grouped =
      line_items
      |> Enum.group_by(& &1.product_title)
      |> Enum.map(fn {title, items} ->
        total_qty = items |> Enum.map(& &1.quantity) |> Enum.sum()
        {String.slice(title, 0, 20), total_qty}
      end)
      |> Enum.sort_by(fn {_title, qty} -> qty end, :desc)
      |> Enum.take(5)

    labels = Enum.map(grouped, fn {title, _qty} -> title end)
    values = Enum.map(grouped, fn {_title, qty} -> qty end)

    %{labels: labels, values: values}
  end
end
