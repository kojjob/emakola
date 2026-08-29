defmodule EmakolaWeb.Admin.ReportLive.Index do
  @moduledoc """
  Admin reports.

      /admin/reports

  The page shipped 1,035 lines with **zero data access** — every figure was a
  template literal and every chart a hand-plotted SVG. Real merchants were
  shown an invented revenue trend, invented top products, and three "AI
  Insights" paragraphs describing a shop that does not exist.

  What it reports now comes from this store's orders, on the same
  definitions the rest of the admin uses.

  ## What was removed, and why it could not be wired

  There is no visit or session tracking anywhere in this codebase. So:

    * **Conversion rate** has no denominator — you cannot divide orders by
      visits you never counted.
    * **Sales by Channel** (Instagram 45%, TikTok 4% …) has no numerator.
      The only attribution data is `Order.attribution`'s UTM tags, which
      counts ORDERS, not traffic — a different claim wearing the same words.
    * **Per-region conversion** fails for both reasons at once.

  Rebuilding those as orders-by-source would answer a question nobody asked
  while looking like the question they did. They were gone until something
  actually measured traffic.

  ## What came back, and on what basis

  `Emakola.Analytics.StoreVisits` now counts storefront visits, so two of the
  three are honest again:

    * **Conversion rate** is orders ÷ distinct *visitors* — not pageviews. One
      person browsing five pages is one visitor; dividing by pageviews would
      understate every merchant's rate while looking like the same sum.
    * **Traffic by channel** counts visits by source, which is the claim the
      words make. It is not orders-by-UTM wearing the same label.

  ## Per-region conversion is not coming back, and this is why

  Not a TODO. It was looked at properly and turned down.

  Orders carry a region because the buyer typed a shipping address. A *visitor*
  has no such source, so a per-region rate needs IP geolocation — and in this
  market that cannot produce an honest answer. Ghanaian storefront traffic is
  overwhelmingly mobile, and mobile carrier IPs resolve to the carrier's
  gateway rather than the person: MTN's traffic would file under Accra whether
  the shopper is in Kumasi, Tamale or Takoradi.

  So the figure would not measure where customers are. It would measure a
  carrier's network topology while wearing the word "region", carry a decimal
  point, and be wrong in a direction no merchant could detect. A trader who
  stopped advertising in Kumasi because "Kumasi does not convert" — when
  Kumasi's traffic was silently filed under Accra — would have been harmed by
  a number this page handed them.

  That is the same failure the invented figures caused, in a worse form: those
  were at least obviously invented.

  Orders and revenue by region stay, because a typed shipping address is real.
  They simply cannot carry a rate, since the denominator would be fiction.
  """
  use EmakolaWeb, :live_view

  require Ash.Query
  require Logger

  alias Emakola.Analytics.StoreVisits
  alias Emakola.Dashboard.Stats
  alias Emakola.Orders.Order

  # Windows the pills offer. "custom" silently meant 30 days and there was no
  # date picker anywhere in the file, so it is not offered.
  @ranges %{"7d" => 7, "30d" => 30, "90d" => 90, "12m" => 365}
  @default_range "30d"

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Reports",
        active_nav: :reports,
        store_id: get_store_id(socket),
        date_range: @default_range
      )
      |> load_report()

    {:ok, socket}
  end

  @impl true
  def handle_event("set_date_range", %{"range" => range}, socket)
      when is_map_key(@ranges, range) do
    {:noreply, socket |> assign(date_range: range) |> load_report()}
  end

  def handle_event("set_date_range", _params, socket), do: {:noreply, socket}

  # ── Loading ─────────────────────────────────────────────────────────
  #
  # One read of the window, then every figure is derived from it, so no two
  # numbers on the page can disagree about the same orders.

  defp load_report(socket) do
    %{store_id: store_id, date_range: range} = socket.assigns
    {from, to} = window(range)

    orders = fetch_orders(store_id, from, to)
    visitors = count_visitors(store_id, range)
    counted = Enum.reject(orders, &(&1.status == :cancelled))
    revenue = counted |> Enum.map(&(&1.total || 0)) |> Enum.sum()
    count = length(counted)

    assign(socket,
      start_date: DateTime.to_date(from),
      end_date: DateTime.to_date(to),
      revenue: revenue,
      order_count: count,
      avg_order_value: if(count > 0, do: div(revenue, count), else: 0),
      revenue_chart: build_revenue_chart(counted, from, to),
      status_breakdown: build_status_breakdown(orders),
      top_products: top_products(store_id, from, to),
      regions: build_regions(counted),
      visitors: visitors,
      conversion_rate: conversion_rate(count, visitors),
      traffic_sources: traffic_sources(store_id, range)
    )
  end

  defp count_visitors(nil, _range), do: 0
  defp count_visitors(store_id, range), do: StoreVisits.visitors(store_id, @ranges[range])

  defp traffic_sources(nil, _range), do: %{}
  defp traffic_sources(store_id, range), do: StoreVisits.by_source(store_id, @ranges[range])

  # Percent to one decimal, already rendered as a string.
  #
  # float_to_binary rather than interpolation: `Float.to_string/1` emits the
  # shortest round-trip form, so 1500.0 comes out "1.5e3" while 714.3 and
  # 3333.3 render fine — the bug only appears once the number gets large.
  #
  # No visitors means no rate rather than a divide: a store nobody visited has
  # not converted 0%, it has no rate to report.
  defp conversion_rate(_orders, 0), do: nil

  # More orders than visitors means the denominator is short, not that the
  # store converts above 100%. Orders are counted from the store's whole
  # history; visits only from the day counting shipped. Every merchant starts
  # in that state, so this is the ordinary early case, not a freak one — and
  # "1500% of them bought" answers no question a merchant has.
  defp conversion_rate(orders, visitors) when orders > visitors, do: nil

  defp conversion_rate(orders, visitors),
    do: :erlang.float_to_binary(orders / visitors * 100, decimals: 1)

  defp fetch_orders(nil, _from, _to), do: []

  defp fetch_orders(store_id, from, to) do
    Order
    |> Ash.Query.filter(store_id == ^store_id and inserted_at >= ^from and inserted_at < ^to)
    |> Ash.read!(authorize?: false)
  rescue
    exception ->
      Logger.error("[report_live] loading orders raised: #{Exception.message(exception)}")
      []
  end

  defp top_products(nil, _from, _to), do: %{labels: [], values: []}

  defp top_products(store_id, from, to) do
    Stats.top_line_items_chart(store_id, from, to)
  rescue
    exception ->
      Logger.error("[report_live] top products raised: #{Exception.message(exception)}")
      %{labels: [], values: []}
  end

  defp window(range) do
    days = Map.fetch!(@ranges, range)
    to = Date.utc_today() |> Date.add(1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    from = Date.utc_today() |> Date.add(-(days - 1)) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    {from, to}
  end

  # Weekly buckets past 45 days, so a year-long window stays readable without
  # dropping anything from the total the tiles report.
  defp build_revenue_chart(orders, from, _to) do
    today = Date.utc_today()
    start_date = DateTime.to_date(from)
    step = if Date.diff(today, start_date) > 45, do: 7, else: 1

    by_date = Enum.group_by(orders, &DateTime.to_date(&1.inserted_at))

    start_date
    |> Date.range(today, step)
    |> Enum.map(fn bucket_start ->
      bucket_end = Date.add(bucket_start, step - 1)

      total =
        by_date
        |> Enum.filter(fn {date, _rows} ->
          Date.compare(date, bucket_start) != :lt and Date.compare(date, bucket_end) != :gt
        end)
        |> Enum.flat_map(fn {_date, rows} -> Enum.map(rows, &(&1.total || 0)) end)
        |> Enum.sum()

      {Calendar.strftime(bucket_start, "%b %d"), total}
    end)
    |> Enum.unzip()
    |> then(fn {labels, values} -> %{labels: labels, values: values} end)
  end

  @status_order [:pending, :confirmed, :processing, :shipped, :delivered, :cancelled]

  defp build_status_breakdown(orders) do
    counts = Enum.frequencies_by(orders, & &1.status)

    @status_order
    |> Enum.map(fn status -> %{status: status, count: Map.get(counts, status, 0)} end)
    |> Enum.reject(&(&1.count == 0))
  end

  # Region comes off the order's shipping address. Orders without one are
  # counted as "Not given" rather than dropped, so the rows still sum to the
  # order count above them.
  defp build_regions(orders) do
    orders
    |> Enum.group_by(&region_of/1)
    |> Enum.map(fn {region, rows} ->
      %{
        region: region,
        orders: length(rows),
        revenue: rows |> Enum.map(&(&1.total || 0)) |> Enum.sum()
      }
    end)
    |> Enum.sort_by(& &1.revenue, :desc)
    |> Enum.take(8)
  end

  # Addresses carry the region however checkout stored it — "greater_accra"
  # from a select, "Greater Accra" typed by hand. Merchants should never see
  # the storage key.
  defp region_of(%{shipping_address: %{"region" => region}})
       when is_binary(region) and region != "",
       do: humanise_region(region)

  defp region_of(_order), do: "Not given"

  defp humanise_region(region) do
    region
    |> String.replace("_", " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  # ── Render ──────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header
        icon="hero-presentation-chart-line"
        title="Reports"
        subtitle="What your orders say"
      >
        <div class="flex bg-slate-100 rounded-control p-1">
          <button
            :for={range <- ~w(7d 30d 90d 12m)}
            phx-click="set_date_range"
            phx-value-range={range}
            class={[
              "px-3 py-1.5 rounded-lg text-xs font-semibold cursor-pointer transition-all",
              if(@date_range == range,
                do: "bg-surface text-primary shadow-sm",
                else: "text-slate-500 hover:text-slate-700"
              )
            ]}
          >
            {range_label(range)}
          </button>
        </div>
        <.link
          href={
            ~p"/admin/export/analytics.pdf?start_date=#{Date.to_iso8601(@start_date)}&end_date=#{Date.to_iso8601(@end_date)}"
          }
          class="inline-flex items-center gap-2 px-4 py-2.5 rounded-control border border-border bg-surface text-sm font-semibold text-text hover:bg-surface-subtle transition-colors"
        >
          <.icon name="hero-arrow-down-tray" class="size-5" /> Export PDF
        </.link>
      </.admin_page_header>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <.stat_card
          id="stat-reports-revenue"
          label="Money from orders"
          value={format_cedis(@revenue)}
          tone={:accent}
        >
          <:icon><.icon name="hero-banknotes" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">Cancelled orders not counted</p>
          </:delta>
        </.stat_card>

        <.stat_card
          id="stat-reports-orders"
          label="Orders"
          value={Integer.to_string(@order_count)}
          tone={:success}
        >
          <:icon><.icon name="hero-shopping-bag" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">In this period</p>
          </:delta>
        </.stat_card>

        <.stat_card
          id="stat-reports-aov"
          label="Average order"
          value={format_cedis(@avg_order_value)}
          tone={:info}
        >
          <:icon><.icon name="hero-calculator" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">Money divided by orders</p>
          </:delta>
        </.stat_card>

        <.stat_card
          id="stat-reports-visitors"
          label="People who looked"
          value={to_string(@visitors)}
          tone={:neutral}
        >
          <:icon><.icon name="hero-users" class="size-7" /></:icon>
          <:delta>
            <%!-- Three states, not two. A store nobody visited has no rate to
                  report — "0%" would be a claim about conversion rather than
                  about traffic. And more orders than visitors means the
                  denominator is still short, which is every store's first
                  weeks, so it says so instead of claiming 1500%. --%>
            <p :if={@conversion_rate} class="text-sm text-slate-500">
              {@conversion_rate}% of them bought
            </p>
            <p :if={is_nil(@conversion_rate) and @visitors == 0} class="text-sm text-slate-500">
              No visits yet
            </p>
            <p :if={is_nil(@conversion_rate) and @visitors > 0} class="text-sm text-slate-500">
              Still counting visits
            </p>
          </:delta>
        </.stat_card>
      </div>

      <.admin_card padding={:none} class="p-5">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-arrow-trending-up" class="size-5 text-primary" />
          <h2 class="text-base font-bold text-slate-800">Money over time</h2>
        </div>
        <div class="h-64">
          <canvas
            id="reports-revenue-chart"
            phx-hook="ChartHook"
            phx-update="ignore"
            data-chart-type="gmv-line"
            data-chart-data={Jason.encode!(@revenue_chart)}
            class="w-full h-full"
          />
        </div>
      </.admin_card>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <.admin_card padding={:none} class="p-5">
          <div class="flex items-center gap-2 mb-4">
            <.icon name="hero-trophy" class="size-5 text-primary" />
            <h2 class="text-base font-bold text-slate-800">Best sellers</h2>
          </div>

          <.empty_state
            :if={@top_products.labels == []}
            icon="hero-cube"
            title="Nothing sold yet"
            description="Your best sellers show here"
          />

          <div :if={@top_products.labels != []} class="h-64">
            <canvas
              id="reports-top-products-chart"
              phx-hook="ChartHook"
              phx-update="ignore"
              data-chart-type="top-products-horizontal"
              data-chart-data={Jason.encode!(@top_products)}
              class="w-full h-full"
            />
          </div>
        </.admin_card>

        <.admin_card padding={:none} class="p-5">
          <div class="flex items-center gap-2 mb-4">
            <.icon name="hero-chart-pie" class="size-5 text-primary" />
            <h2 class="text-base font-bold text-slate-800">Where orders stand</h2>
          </div>

          <.empty_state
            :if={@status_breakdown == []}
            icon="hero-shopping-bag"
            title="No orders yet"
            description="Orders show here as they come"
          />

          <div :if={@status_breakdown != []} class="divide-y divide-slate-100">
            <div :for={row <- @status_breakdown} class="flex items-center gap-3 py-3">
              <.status_badge status={row.status} variant={:order} />
              <span class="flex-1"></span>
              <p class="text-sm font-bold text-slate-900 tabular-nums">{row.count}</p>
            </div>
          </div>
        </.admin_card>
      </div>

      <.admin_card :if={@regions != []} padding={:none} class="p-5">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-map-pin" class="size-5 text-primary" />
          <h2 class="text-base font-bold text-slate-800">Where your buyers are</h2>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-slate-100">
            <thead>
              <tr class="text-left text-xs font-semibold uppercase tracking-wide text-slate-400">
                <th class="px-3 py-3">Region</th>
                <th class="px-3 py-3">Orders</th>
                <th class="px-3 py-3">Money</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr :for={row <- @regions}>
                <td class="px-3 py-3 text-sm font-medium text-slate-800">{row.region}</td>
                <td class="px-3 py-3 text-sm text-slate-600 tabular-nums">{row.orders}</td>
                <td class="px-3 py-3 text-sm font-semibold text-slate-900 tabular-nums">
                  {format_cedis(row.revenue)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </.admin_card>
    </div>
    """
  end

  defp range_label("7d"), do: "7D"
  defp range_label("30d"), do: "30D"
  defp range_label("90d"), do: "90D"
  defp range_label("12m"), do: "12M"

  defp format_cedis(amount) when is_integer(amount) do
    major = amount |> div(100) |> abs() |> Emakola.Money.group_thousands()
    minor = rem(abs(amount), 100)
    sign = if amount < 0, do: "-", else: ""

    "GH₵ #{sign}#{major}.#{String.pad_leading(to_string(minor), 2, "0")}"
  end

  defp format_cedis(_), do: "GH₵ 0.00"
end
