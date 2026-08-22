defmodule EmakolaWeb.Admin.PaymentsLive do
  @moduledoc """
  Payment reconciliation dashboard for the merchant admin.

  Displays summary cards (total revenue, successful/pending/failed counts)
  and a filterable table of all payments for the current store.
  Amounts stored in pesewas are displayed as GHS.
  """
  use EmakolaWeb, :live_view

  require Ash.Query
  require Logger

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

  @statuses [:all, :success, :pending, :failed]
  @ranges ~w(today week month all)

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Payments",
        active_nav: :payments,
        store_id: store_id,
        status_filter: :all,
        range: "week",
        ranges: @ranges,
        payments: [],
        summary: empty_summary(),
        volume_chart: %{labels: [], values: []},
        status_chart: %{labels: [], values: []},
        providers: [],
        statuses: @statuses
      )
      |> load_payments()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_range", %{"range" => range}, socket) when range in @ranges do
    {:noreply, socket |> assign(range: range) |> load_payments()}
  end

  @impl true
  def handle_event("filter_range", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("refresh_data", _params, socket) do
    {:noreply, socket |> load_payments() |> put_flash(:info, "Payments refreshed")}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom =
      case status do
        "all" -> :all
        "success" -> :success
        "pending" -> :pending
        "failed" -> :failed
        _ -> :all
      end

    socket =
      socket
      |> assign(status_filter: status_atom)
      |> load_payments()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header
        title="Payments"
        subtitle="Track and reconcile all payment transactions"
        icon="hero-credit-card"
      />

      <%!-- Date range + refresh --%>
      <div class="flex flex-wrap items-center justify-between gap-3">
        <.filter_tabs
          id="payments-range-tabs"
          event="filter_range"
          param="range"
          current={@range}
          tabs={Enum.map(@ranges, fn r -> %{key: r, label: range_label(r), count: nil} end)}
        />
        <button
          phx-click="refresh_data"
          class="inline-flex items-center gap-2 px-4 py-2.5 rounded-control border border-border bg-surface text-sm font-semibold text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
        >
          <.icon name="hero-arrow-path" class="size-4" /> Refresh
        </button>
      </div>

      <%!-- Five tiles, each tinted for its meaning --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">
        <.stat_card
          id="stat-payments-volume"
          label="Money in"
          value={format_price(@summary.total_volume, "GHS")}
          tone={:accent}
        >
          <:icon><.icon name="hero-banknotes" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">From payments that went through</p>
          </:delta>
        </.stat_card>

        <.stat_card
          id="stat-payments-count"
          label="Payments"
          value={Integer.to_string(@summary.transaction_count)}
          tone={:success}
        >
          <:icon><.icon name="hero-credit-card" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">{@summary.success_count} went through</p>
          </:delta>
        </.stat_card>

        <.stat_card
          id="stat-payments-rate"
          label="Went through"
          value={"#{@summary.success_rate}%"}
          tone={:info}
        >
          <:icon><.icon name="hero-chart-bar" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">Payment health</p>
          </:delta>
        </.stat_card>

        <.stat_card
          id="stat-payments-failed"
          label="Did not go through"
          value={Integer.to_string(@summary.failed_count)}
          tone={:danger}
        >
          <:icon><.icon name="hero-exclamation-triangle" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">{@summary.pending_count} still waiting</p>
          </:delta>
        </.stat_card>

        <.stat_card
          id="stat-payments-refunded"
          label="Sent back"
          value={format_price(@summary.refunded_total, "GHS")}
          tone={:cyan}
        >
          <:icon><.icon name="hero-arrow-uturn-left" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">Money returned to buyers</p>
          </:delta>
        </.stat_card>
      </div>

      <%!-- Charts: money over time, how payments ended, who processed them --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div class="lg:col-span-2">
          <.admin_card padding={:none} class="p-5">
            <div class="flex items-center gap-2 mb-4">
              <.icon name="hero-arrow-trending-up" class="size-5 text-primary" />
              <h2 class="text-base font-bold text-slate-800">Money over time</h2>
            </div>
            <div class="h-64">
              <canvas
                id="payments-volume-chart"
                phx-hook="ChartHook"
                phx-update="ignore"
                data-chart-type="gmv-line"
                data-chart-data={Jason.encode!(@volume_chart)}
                class="w-full h-full"
              />
            </div>
          </.admin_card>
        </div>

        <.admin_card padding={:none} class="p-5">
          <div class="flex items-center gap-2 mb-4">
            <.icon name="hero-chart-bar" class="size-5 text-primary" />
            <h2 class="text-base font-bold text-slate-800">How they ended</h2>
          </div>
          <div class="h-64">
            <canvas
              id="payments-status-chart"
              phx-hook="ChartHook"
              phx-update="ignore"
              data-chart-type="status-bar"
              data-chart-data={Jason.encode!(@status_chart)}
              class="w-full h-full"
            />
          </div>
        </.admin_card>
      </div>

      <%!-- Provider ring: the total sits in the middle as markup, with the
            legend beside it carrying each provider's amount. --%>
      <.admin_card :if={@providers != []} padding={:none} class="p-5">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-chart-pie" class="size-5 text-primary" />
          <h2 class="text-base font-bold text-slate-800">Who processed the money</h2>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6 items-center">
          <div class="relative h-56">
            <canvas
              id="payments-provider-chart"
              phx-hook="ChartHook"
              phx-update="ignore"
              data-chart-type="provider-donut"
              data-chart-data={Jason.encode!(provider_chart(@providers))}
              class="w-full h-full"
            />
            <div class="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
              <p
                id="payments-provider-total"
                class="text-2xl font-bold text-slate-900 tabular-nums"
              >
                {format_price(provider_total(@providers), "GHS")}
              </p>
              <p class="text-xs font-semibold uppercase tracking-wider text-slate-400 mt-1">
                Total
              </p>
            </div>
          </div>

          <div class="divide-y divide-slate-100">
            <div
              :for={{provider, index} <- Enum.with_index(@providers)}
              class="flex items-center gap-3 py-3"
            >
              <span class={["w-3 h-3 rounded-full shrink-0", provider_dot(index)]} />
              <p class="flex-1 text-sm font-semibold text-slate-900">{provider.label}</p>
              <p class="text-sm font-bold text-slate-900 tabular-nums">
                {format_price(provider.total, "GHS")}
              </p>
            </div>
          </div>
        </div>
      </.admin_card>

      <%!-- Status Filter Tabs --%>
      <div class="flex flex-wrap items-center gap-3">
        <div class="flex gap-1 bg-slate-100 rounded-xl p-1">
          <.status_tab :for={status <- @statuses} status={status} current={@status_filter} />
        </div>
      </div>

      <%!-- Payments Table --%>
      <%= if @payments == [] do %>
        <div class="text-center py-16 bg-white rounded-2xl shadow-sm">
          <svg
            class="w-12 h-12 mx-auto text-slate-300 mb-3"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z"
            />
          </svg>
          <p class="text-slate-600 font-medium">No payments found</p>
          <p class="text-sm text-slate-400 mt-1">
            <%= if @status_filter != :all do %>
              Try adjusting your filters
            <% else %>
              Payments will appear here when customers complete transactions
            <% end %>
          </p>
        </div>
      <% else %>
        <%!-- Desktop Table --%>
        <div class="hidden md:block bg-white rounded-2xl shadow-sm overflow-hidden">
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-200 bg-slate-50/50">
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Date
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Order
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Customer
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Amount
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Method
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Reference
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr
                  :for={payment <- @payments}
                  class="hover:bg-slate-50 transition-colors"
                >
                  <td class="px-4 py-3.5 text-slate-500 whitespace-nowrap">
                    {format_datetime(payment.inserted_at)}
                  </td>
                  <td class="px-4 py-3.5">
                    <%= if payment.order do %>
                      <.link
                        navigate={~p"/admin/orders/#{payment.order_id}"}
                        class="font-mono text-xs font-medium text-emerald-600 hover:text-emerald-700"
                      >
                        {payment.order.order_number}
                      </.link>
                    <% else %>
                      <span class="text-slate-400 text-xs">—</span>
                    <% end %>
                  </td>
                  <td class="px-4 py-3.5 text-slate-700">
                    {payment.customer_email || "—"}
                  </td>
                  <td class="px-4 py-3.5 font-mono text-sm font-medium text-slate-800">
                    {format_price(payment.amount, payment.currency)}
                  </td>
                  <td class="px-4 py-3.5">
                    <span class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium bg-slate-100 text-slate-700 capitalize">
                      {gateway_label(payment.gateway)}
                    </span>
                  </td>
                  <td class="px-4 py-3.5">
                    <.payment_status_badge status={payment.status} />
                  </td>
                  <td class="px-4 py-3.5 font-mono text-xs text-slate-500">
                    {payment.gateway_reference || "—"}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Mobile Cards --%>
        <div class="md:hidden space-y-3">
          <div
            :for={payment <- @payments}
            class="bg-white rounded-2xl shadow-sm p-4"
          >
            <div class="flex items-start justify-between gap-3 mb-3">
              <div>
                <p class="text-xs text-slate-400">{format_datetime(payment.inserted_at)}</p>
                <p class="font-mono text-sm font-semibold text-slate-800 mt-1">
                  {format_price(payment.amount, payment.currency)}
                </p>
              </div>
              <.payment_status_badge status={payment.status} />
            </div>
            <div class="space-y-1 text-sm">
              <p class="text-slate-500">
                <span class="text-slate-400">Customer:</span> {payment.customer_email || "—"}
              </p>
              <p class="text-slate-500">
                <span class="text-slate-400">Method:</span> {gateway_label(payment.gateway)}
              </p>
              <p class="text-slate-500 font-mono text-xs">
                <span class="font-sans text-slate-400">Ref:</span> {payment.gateway_reference || "—"}
              </p>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Components ──

  defp range_label("today"), do: "Today"
  defp range_label("week"), do: "7 Days"
  defp range_label("month"), do: "30 Days"
  defp range_label("all"), do: "All Time"

  attr :status, :atom, required: true
  attr :current, :atom, required: true

  defp status_tab(assigns) do
    ~H"""
    <button
      phx-click="filter_status"
      phx-value-status={@status}
      class={[
        "px-3 py-1.5 text-sm font-medium rounded-lg transition-colors whitespace-nowrap",
        if(@status == @current,
          do: "bg-white text-slate-900 shadow-sm",
          else: "text-slate-500 hover:text-slate-700"
        )
      ]}
    >
      {status_label(@status)}
    </button>
    """
  end

  attr :status, :atom, required: true

  defp payment_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold",
      status_badge_class(@status)
    ]}>
      {status_label(@status)}
    </span>
    """
  end

  # ── Data Loading ──

  # Cap the rows materialised for the table; the summary is computed from
  # DB aggregates so totals stay accurate regardless of this cap.
  @payments_page_limit 200

  defp load_payments(socket) do
    %{store_id: store_id, status_filter: status, range: range} = socket.assigns

    # One read of the range, then every tile and chart is derived in Elixir.
    # Five separate aggregate queries for figures that must agree with each
    # other is how a dashboard starts contradicting itself.
    in_range = fetch_in_range(store_id, range)

    assign(socket,
      payments: fetch_payments(store_id, status),
      summary: summarise(in_range),
      volume_chart: build_volume_chart(in_range, range),
      status_chart: build_status_chart(in_range),
      providers: build_providers(in_range)
    )
  end

  # ── Charts ──

  @chart_days %{"today" => 1, "week" => 7, "month" => 30}

  # Successful money over the range, gaps filled so a quiet day reads as a zero
  # rather than closing the line across it.
  #
  # The window must cover everything the tiles counted. Capping it at 30 days
  # silently dropped older money, so an "All time" chart summed to zero beside
  # a tile reading GH₵ 2,450 — the chart contradicting its own headline. Long
  # spans bucket by week instead, which keeps the axis readable without
  # hiding anything.
  defp build_volume_chart(payments, range) do
    days = Map.get(@chart_days, range) || spanned_days(payments)
    step = if days > 45, do: 7, else: 1

    today = Date.utc_today()
    start_date = Date.add(today, -(days - 1))

    by_date =
      payments
      |> Enum.filter(&(&1.status == :success))
      |> Enum.group_by(&DateTime.to_date(&1.inserted_at))

    start_date
    |> Date.range(today, step)
    |> Enum.map(fn bucket_start ->
      bucket_end = Date.add(bucket_start, step - 1)

      total =
        by_date
        |> Enum.filter(fn {date, _} ->
          Date.compare(date, bucket_start) != :lt and Date.compare(date, bucket_end) != :gt
        end)
        |> Enum.flat_map(fn {_, rows} -> Enum.map(rows, & &1.amount) end)
        |> Enum.sum()

      {Calendar.strftime(bucket_start, "%b %d"), total}
    end)
    |> Enum.unzip()
    |> then(fn {labels, values} -> %{labels: labels, values: values} end)
  end

  # "All time" has no fixed window: span from the oldest payment. No upper cap
  # — the weekly bucketing above keeps a long span readable.
  defp spanned_days([]), do: 7

  defp spanned_days(payments) do
    oldest = payments |> Enum.map(&DateTime.to_date(&1.inserted_at)) |> Enum.min(Date)
    Date.diff(Date.utc_today(), oldest) |> Kernel.+(1) |> max(7)
  end

  # Fixed order — the bar colours in chart_hook.js are positional.
  @status_order [:success, :pending, :failed, :refunded]
  @status_labels %{
    success: "Paid",
    pending: "Waiting",
    failed: "Failed",
    refunded: "Sent back"
  }

  defp build_status_chart(payments) do
    counts = Enum.frequencies_by(payments, & &1.status)

    %{
      labels: Enum.map(@status_order, &@status_labels[&1]),
      values: Enum.map(@status_order, &Map.get(counts, &1, 0))
    }
  end

  # Successful volume per gateway, biggest first. The donut's total and legend
  # are rendered as markup, so this carries the amounts they both read.
  defp build_providers(payments) do
    payments
    |> Enum.filter(&(&1.status == :success))
    |> Enum.group_by(& &1.gateway)
    |> Enum.map(fn {gateway, rows} ->
      %{
        gateway: gateway,
        label: gateway_label(gateway),
        total: Enum.sum(Enum.map(rows, & &1.amount))
      }
    end)
    |> Enum.sort_by(& &1.total, :desc)
  end

  defp provider_chart(providers) do
    %{
      labels: Enum.map(providers, & &1.label),
      values: Enum.map(providers, & &1.total)
    }
  end

  defp provider_total(providers), do: providers |> Enum.map(& &1.total) |> Enum.sum()

  # Legend swatches, positionally matched to PROVIDER_COLORS in chart_hook.js.
  defp provider_dot(0), do: "bg-primary"
  defp provider_dot(1), do: "bg-info"
  defp provider_dot(2), do: "bg-warning"
  defp provider_dot(_), do: "bg-slate-500"

  defp fetch_in_range(nil, _range), do: []

  defp fetch_in_range(store_id, range) do
    Emakola.Payments.Payment
    |> Ash.Query.filter(store_id == ^store_id)
    |> range_filter(range)
    |> Ash.read!(authorize?: false)
  rescue
    exception ->
      Logger.error(
        "[payments_live] fetch_in_range loading payments raised: #{Exception.message(exception)}"
      )

      []
  end

  defp range_filter(query, "all"), do: query

  defp range_filter(query, range) do
    since = range_start(range)
    Ash.Query.filter(query, inserted_at >= ^since)
  end

  # Same vocabulary as the dashboard's period toggle, so "7 days" means the
  # same span wherever a merchant sees it.
  defp range_start("today"), do: start_of_day(0)
  defp range_start("month"), do: start_of_day(29)
  defp range_start(_week), do: start_of_day(6)

  defp start_of_day(days_ago) do
    Date.utc_today()
    |> Date.add(-days_ago)
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp empty_summary do
    %{
      total_volume: 0,
      transaction_count: 0,
      success_rate: 0,
      success_count: 0,
      pending_count: 0,
      failed_count: 0,
      refunded_total: 0
    }
  end

  defp summarise(payments) do
    total = length(payments)
    by_status = Enum.frequencies_by(payments, & &1.status)
    success = Map.get(by_status, :success, 0)

    %{
      total_volume:
        payments |> Enum.filter(&(&1.status == :success)) |> Enum.map(& &1.amount) |> Enum.sum(),
      transaction_count: total,
      # Guard the divide: a store with no payments yet is the common case,
      # not an error.
      success_rate: if(total > 0, do: round(success * 100 / total), else: 0),
      success_count: success,
      pending_count: Map.get(by_status, :pending, 0),
      failed_count: Map.get(by_status, :failed, 0),
      refunded_total: payments |> Enum.map(&(&1.refunded_amount || 0)) |> Enum.sum()
    }
  end

  defp fetch_payments(store_id, status) do
    status_arg = if status == :all, do: nil, else: status

    Ash.Query.for_read(
      Emakola.Payments.Payment,
      :by_store_with_status,
      %{store_id: store_id, status: status_arg}
    )
    |> Ash.Query.limit(@payments_page_limit)
    |> Ash.read!(authorize?: false)
  rescue
    exception ->
      Logger.error(
        "[payments_live] fetch_payments loading payments raised: #{Exception.message(exception)}"
      )

      []
  end

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp status_label(:all), do: "All"
  defp status_label(:success), do: "Paid"
  defp status_label(:pending), do: "Pending"
  defp status_label(:failed), do: "Failed"
  defp status_label(:refunded), do: "Refunded"
  defp status_label(_), do: "Unknown"

  defp status_badge_class(:success), do: "bg-emerald-50 text-emerald-700"
  defp status_badge_class(:pending), do: "bg-amber-50 text-amber-700"
  defp status_badge_class(:failed), do: "bg-red-50 text-red-700"
  defp status_badge_class(:refunded), do: "bg-purple-50 text-purple-700"
  defp status_badge_class(_), do: "bg-slate-50 text-slate-700"

  defp gateway_label(:paystack), do: "Paystack"
  defp gateway_label(:hubtel), do: "Hubtel"
  defp gateway_label(other), do: to_string(other)

  defp format_datetime(nil), do: ""

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  end

  defp format_datetime(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  end

  defp format_datetime(_), do: ""
end
