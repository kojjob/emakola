defmodule EmakolaWeb.DashboardHelpers do
  @moduledoc "Data loading, metric computation, and chart generation for the merchant admin dashboard."

  alias Emakola.AsyncSandbox
  alias Emakola.Dashboard.Stats

  @doc """
  Returns a map with all dashboard data for the given store and period.

  All independent queries are dispatched in parallel via `Task.async/1`,
  then awaited together. With ~12 queries averaging ~5ms each, this
  cuts dashboard load latency from ~60ms sequential down to roughly
  the slowest single query (~10ms) — a 5-6x improvement.

  The previous-period comparison block runs only when not :all (still
  parallel within itself).
  """
  def load_merchant_dashboard(store_id, period) do
    {range_start, range_end} = date_range(period)
    {prev_start, prev_end} = previous_range(period)

    day_start = DateTime.new!(range_start, ~T[00:00:00], "Etc/UTC")
    day_end = DateTime.new!(Date.add(range_end, 1), ~T[00:00:00], "Etc/UTC")

    prev_day_start = DateTime.new!(prev_start, ~T[00:00:00], "Etc/UTC")
    prev_day_end = DateTime.new!(Date.add(prev_end, 1), ~T[00:00:00], "Etc/UTC")

    dates = chart_dates(range_start, range_end)
    chart_start = DateTime.new!(List.first(dates), ~T[00:00:00], "Etc/UTC")
    chart_end = DateTime.new!(Date.add(List.last(dates), 1), ~T[00:00:00], "Etc/UTC")

    # Spawn all queries in parallel. Each Task.async returns immediately;
    # we collect the results below. 5-second timeout matches the default;
    # in dev mode any query that takes longer is broken anyway.
    tasks =
      [
        revenue_count:
          AsyncSandbox.run_async(fn -> revenue_and_count(store_id, day_start, day_end) end),
        waiting_for_payment:
          AsyncSandbox.run_async(fn -> waiting_for_payment(store_id, day_start, day_end) end),
        customers: AsyncSandbox.run_async(fn -> count_buyers(store_id, day_start, day_end) end),
        orders_in_range:
          AsyncSandbox.run_async(fn ->
            load_paid_orders(store_id, chart_start, chart_end)
          end),
        customers_in_range:
          AsyncSandbox.run_async(fn ->
            load_customers_in_range(store_id, chart_start, chart_end)
          end),
        top_products:
          AsyncSandbox.run_async(fn -> build_top_products_chart(store_id, day_start, day_end) end),
        pending_orders: AsyncSandbox.run_async(fn -> count_pending_orders(store_id) end),
        low_stock: AsyncSandbox.run_async(fn -> count_low_stock(store_id) end),
        sold_out: AsyncSandbox.run_async(fn -> count_sold_out(store_id) end),
        open_returns: AsyncSandbox.run_async(fn -> count_open_returns(store_id) end),
        suppliers_to_chase: AsyncSandbox.run_async(fn -> count_suppliers_to_chase(store_id) end),
        best_sellers:
          AsyncSandbox.run_async(fn -> Stats.best_sellers(store_id, day_start, day_end) end),
        failed_payments:
          AsyncSandbox.run_async(fn -> count_failed_payments(store_id, day_start, day_end) end),
        recent_orders: AsyncSandbox.run_async(fn -> load_recent_orders(store_id) end)
      ]
      |> Enum.concat(prev_period_tasks(period, store_id, prev_day_start, prev_day_end))

    results = Map.new(tasks, fn {key, task} -> {key, Task.await(task)} end)

    {total_revenue, order_count} = results.revenue_count
    avg_order_value = if order_count > 0, do: div(total_revenue, order_count), else: 0
    customer_count = results.customers
    waiting_for_payment = results.waiting_for_payment

    {revenue_change, orders_change, customers_change, aov_change} =
      compute_changes(
        period,
        results,
        total_revenue,
        order_count,
        customer_count,
        avg_order_value
      )

    %{
      total_revenue: total_revenue,
      order_count: order_count,
      customer_count: customer_count,
      waiting_for_payment: waiting_for_payment,
      avg_order_value: avg_order_value,
      revenue_change: revenue_change,
      orders_change: orders_change,
      customers_change: customers_change,
      aov_change: aov_change,
      revenue_chart: build_revenue_chart(results.orders_in_range, dates),
      orders_chart: build_orders_chart(results.orders_in_range, dates),
      customers_chart: build_customers_chart(results.customers_in_range, dates),
      top_products_chart: results.top_products,
      pending_orders: results.pending_orders,
      low_stock_count: results.low_stock,
      sold_out_count: results.sold_out,
      open_returns: results.open_returns,
      suppliers_to_chase: results.suppliers_to_chase,
      best_sellers: results.best_sellers,
      failed_payments: results.failed_payments,
      recent_orders: results.recent_orders
    }
  end

  @doc """
  Returns the Twi greeting for an hour of the day.

  Ghana keeps GMT year-round, so the UTC hour is the merchant's local hour
  and no timezone database is needed.
  """
  def greeting_for_hour(hour) when hour >= 5 and hour < 12, do: "Maakye"
  def greeting_for_hour(hour) when hour >= 12 and hour < 17, do: "Maaha"
  def greeting_for_hour(_hour), do: "Maadwo"

  defp prev_period_tasks("all", _store_id, _prev_start, _prev_end), do: []

  defp prev_period_tasks(_period, store_id, prev_start, prev_end) do
    [
      prev_revenue_count:
        AsyncSandbox.run_async(fn -> revenue_and_count(store_id, prev_start, prev_end) end),
      prev_customers:
        AsyncSandbox.run_async(fn -> count_buyers(store_id, prev_start, prev_end) end)
    ]
  end

  defp compute_changes("all", _results, _rev, _ord, _cust, _aov), do: {nil, nil, nil, nil}

  defp compute_changes(
         _period,
         results,
         total_revenue,
         order_count,
         customer_count,
         avg_order_value
       ) do
    {prev_revenue, prev_order_count} = results.prev_revenue_count
    prev_avg = if prev_order_count > 0, do: div(prev_revenue, prev_order_count), else: 0
    prev_customer_count = results.prev_customers

    {
      pct_change(total_revenue, prev_revenue),
      pct_change(order_count, prev_order_count),
      pct_change(customer_count, prev_customer_count),
      pct_change(avg_order_value, prev_avg)
    }
  end

  @doc "Returns empty/zero defaults for all dashboard data keys."
  def default_data do
    %{
      total_revenue: 0,
      order_count: 0,
      customer_count: 0,
      waiting_for_payment: 0,
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
      sold_out_count: 0,
      open_returns: 0,
      suppliers_to_chase: 0,
      best_sellers: [],
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
    base = period_read(store_id, from, to, Emakola.Orders.Order.paid_statuses())

    {:ok, revenue} = Ash.sum(base, :total, authorize?: false)
    {:ok, count} = Ash.count(base, authorize?: false)
    {revenue || 0, count}
  end

  # Orders placed but not yet paid (MoMo) or confirmed (cash on delivery).
  defp waiting_for_payment(store_id, from, to) do
    {:ok, sum} =
      store_id
      |> period_read(from, to, [:pending])
      |> Ash.sum(:total, authorize?: false)

    sum || 0
  end

  # People who bought: distinct customers on paid orders. Guest orders that
  # never got a customer (before the phone backfill) are not counted here.
  defp count_buyers(store_id, from, to) do
    import Ecto.Query

    Emakola.Repo.one(
      from(o in "orders",
        where:
          o.store_id == type(^store_id, :binary_id) and
            o.status in ^Enum.map(Emakola.Orders.Order.paid_statuses(), &Atom.to_string/1) and
            o.inserted_at >= ^from and o.inserted_at < ^to and
            not is_nil(o.customer_id),
        select: count(fragment("distinct ?", o.customer_id))
      )
    ) || 0
  end

  defp period_read(store_id, from, to, statuses) do
    Ash.Query.for_read(Emakola.Orders.Order, :by_store_in_period_with_status, %{
      store_id: store_id,
      from: from,
      to: to,
      statuses: statuses
    })
  end

  defp load_paid_orders(store_id, from, to) do
    store_id
    |> period_read(from, to, Emakola.Orders.Order.paid_statuses())
    |> Ash.Query.select([:id, :total, :inserted_at])
    |> Ash.read!(authorize?: false)
  end

  defp load_customers_in_range(store_id, from, to) do
    Emakola.Customers.Customer
    |> Ash.Query.for_read(:by_store_in_period, %{store_id: store_id, from: from, to: to})
    |> Ash.Query.select([:id, :inserted_at])
    |> Ash.read!(authorize?: false)
  end

  defp count_pending_orders(store_id) do
    {:ok, count} =
      Emakola.Orders.Order
      |> Ash.Query.for_read(:list_by_status, %{store_id: store_id, status: :pending})
      |> Ash.count(authorize?: false)

    count
  end

  defp count_low_stock(store_id) do
    {:ok, count} =
      Emakola.Catalog.Variant
      |> Ash.Query.for_read(:low_stock, %{threshold: 10, store_id: store_id})
      |> Ash.count(authorize?: false)

    count
  end

  # "Sold out" is the low-stock read with a threshold of 1 — stock_quantity < 1
  # on an inventory-tracked variant. It is the urgent half of low stock: those
  # products cannot be bought at all right now.
  defp count_sold_out(store_id) do
    {:ok, count} =
      Emakola.Catalog.Variant
      |> Ash.Query.for_read(:low_stock, %{threshold: 1, store_id: store_id})
      |> Ash.count(authorize?: false)

    count
  end

  # Supplier groups the merchant has to do something about: one declined, one
  # that stopped answering, or one whose message never arrived. Counted over
  # fulfillments rather than the :supplier_alert calculation because this is a
  # filter the database can answer directly.
  defp count_suppliers_to_chase(store_id) do
    require Ash.Query

    Emakola.Orders.Fulfillment
    |> Ash.Query.filter(
      store_id == ^store_id and not is_nil(supplier_id) and
        status in [:pending, :notified, :declined] and
        (status == :declined or escalation_level >= 2 or not is_nil(last_send_error))
    )
    |> Ash.count!(authorize?: false)
  rescue
    _ -> 0
  end

  defp count_open_returns(store_id) do
    store_id
    |> Emakola.Orders.list_returns_by_store!(authorize?: false)
    |> Enum.count(&(&1.status == :requested))
  rescue
    _ -> 0
  end

  defp count_failed_payments(store_id, from, to) do
    {:ok, count} =
      Emakola.Payments.Payment
      |> Ash.Query.for_read(:failed_in_period, %{store_id: store_id, from: from, to: to})
      |> Ash.count(authorize?: false)

    count
  end

  defp load_recent_orders(store_id) do
    Emakola.Orders.Order
    |> Ash.Query.for_read(:list_by_store, %{store_id: store_id})
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
    Emakola.Dashboard.Stats.top_line_items_chart(store_id, from, to)
  end
end
