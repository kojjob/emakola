defmodule EmakolaWeb.Admin.RevenueLive.Index do
  @moduledoc """
  Revenue analytics page for the merchant admin dashboard.
  Displays gross/net revenue, platform fees, pending payouts,
  daily revenue chart, category and payment method breakdowns,
  recent transactions, and payout history.
  Pixel-matched to design/prototypes/emakola-admin-revenue.html.
  """
  use EmakolaWeb, :live_view

  @periods ~w(today week month year)

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Revenue",
        active_nav: :revenue,
        store_id: store_id,
        period: "month",
        periods: @periods
      )
      |> assign_placeholder_data()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) when period in @periods do
    {:noreply, assign(socket, period: period)}
  end

  def handle_event("change_period", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Page Header --%>
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">Revenue</h1>
        <p class="text-sm text-slate-500 mt-1">Track your earnings and payouts</p>
      </div>
      <div class="flex items-center gap-3">
        <%!-- Period Toggle --%>
        <div class="flex bg-slate-100 rounded-xl p-1">
          <button
            :for={p <- @periods}
            phx-click="change_period"
            phx-value-period={p}
            class={[
              "px-3 py-1.5 rounded-lg text-xs font-medium cursor-pointer focus-visible:ring-2 focus-visible:ring-emerald-500 transition-all",
              if(@period == p,
                do: "bg-emerald-600 text-white",
                else: "text-slate-500 hover:text-slate-700"
              )
            ]}
          >
            {period_label(p)}
          </button>
        </div>
        <button class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-emerald-500">
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
            />
          </svg>
          Export
        </button>
      </div>
    </div>

    <%!-- KPI Cards --%>
    <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4 mb-8">
      <%!-- Gross Revenue --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Gross Revenue
          </span>
          <div class="w-9 h-9 bg-emerald-50 rounded-xl flex items-center justify-center">
            <svg
              class="w-[18px] h-[18px] text-emerald-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">
          {format_cedis(@kpi.gross_revenue)}
        </p>
        <div class="flex items-center gap-1.5 mt-2">
          <span class="inline-flex items-center gap-0.5 text-xs font-semibold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full">
            <svg
              class="w-3 h-3"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M4.5 19.5l15-15m0 0H8.25m11.25 0v11.25"
              />
            </svg>
            +15.3%
          </span>
          <span class="text-xs text-slate-400">vs last month</span>
        </div>
      </div>
      <%!-- Net Revenue --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Net Revenue
          </span>
          <div class="w-9 h-9 bg-emerald-50 rounded-xl flex items-center justify-center">
            <svg
              class="w-[18px] h-[18px] text-emerald-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">
          {format_cedis(@kpi.net_revenue)}
        </p>
        <p class="text-xs text-slate-400 mt-2">After fees</p>
      </div>
      <%!-- Platform Fees --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Platform Fees
          </span>
          <div class="w-9 h-9 bg-amber-50 rounded-xl flex items-center justify-center">
            <svg
              class="w-[18px] h-[18px] text-amber-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15.75 15.75V18m-7.5-6.75h.008v.008H8.25v-.008zm0 2.25h.008v.008H8.25V13.5zm0 2.25h.008v.008H8.25v-.008zm0 2.25h.008v.008H8.25V18zm2.498-6.75h.007v.008h-.007v-.008zm0 2.25h.007v.008h-.007V13.5zm0 2.25h.007v.008h-.007v-.008zm0 2.25h.007v.008h-.007V18zm2.504-6.75h.008v.008h-.008v-.008zm0 2.25h.008v.008h-.008V13.5zm0 2.25h.008v.008h-.008v-.008zm0 2.25h.008v.008h-.008V18zm2.498-6.75h.008v.008h-.008v-.008zm0 2.25h.008v.008h-.008V13.5zM8.25 6h7.5v2.25h-7.5V6zM12 2.25c-1.892 0-3.758.11-5.593.322C5.307 2.7 4.5 3.65 4.5 4.757V19.5a2.25 2.25 0 002.25 2.25h10.5a2.25 2.25 0 002.25-2.25V4.757c0-1.108-.806-2.057-1.907-2.185A48.507 48.507 0 0012 2.25z"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">
          {format_cedis(@kpi.platform_fees)}
        </p>
        <p class="text-xs text-slate-400 mt-2">2% transaction fee</p>
      </div>
      <%!-- Pending Payouts --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Pending Payouts
          </span>
          <div class="w-9 h-9 bg-violet-50 rounded-xl flex items-center justify-center">
            <svg
              class="w-[18px] h-[18px] text-violet-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">
          {format_cedis(@kpi.pending_payouts)}
        </p>
        <p class="text-xs text-slate-400 mt-2">Next payout: 22 Mar</p>
      </div>
    </div>

    <%!-- Daily Revenue Chart --%>
    <div class="bg-white rounded-2xl border border-slate-200 p-6 mb-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h2 class="text-base font-bold text-slate-900">Daily Revenue</h2>
          <p class="text-xs text-slate-400 mt-0.5">March 1 &ndash; 21, 2026</p>
        </div>
        <div class="flex items-center gap-2">
          <span class="flex items-center gap-1.5 text-xs font-medium text-slate-500">
            <span class="w-3 h-1.5 rounded-full bg-emerald-500"></span> Revenue
          </span>
        </div>
      </div>

      <div class="relative" style="height: 320px;">
        <svg viewBox="0 0 840 300" class="w-full h-full" preserveAspectRatio="none">
          <defs>
            <linearGradient id="revenueGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="#059669" stop-opacity="0.25" />
              <stop offset="100%" stop-color="#059669" stop-opacity="0.02" />
            </linearGradient>
          </defs>
          <%!-- Grid lines --%>
          <line x1="60" y1="30" x2="820" y2="30" stroke="#E2E8F0" stroke-width="0.5" />
          <line x1="60" y1="97.5" x2="820" y2="97.5" stroke="#E2E8F0" stroke-width="0.5" />
          <line x1="60" y1="165" x2="820" y2="165" stroke="#E2E8F0" stroke-width="0.5" />
          <line x1="60" y1="232.5" x2="820" y2="232.5" stroke="#E2E8F0" stroke-width="0.5" />
          <line x1="60" y1="270" x2="820" y2="270" stroke="#E2E8F0" stroke-width="1" />
          <%!-- Y-axis labels --%>
          <text
            x="50"
            y="34"
            text-anchor="end"
            class="fill-slate-400"
            font-family="monospace"
            font-size="10"
          >
            3,000
          </text>
          <text
            x="50"
            y="101"
            text-anchor="end"
            class="fill-slate-400"
            font-family="monospace"
            font-size="10"
          >
            2,250
          </text>
          <text
            x="50"
            y="169"
            text-anchor="end"
            class="fill-slate-400"
            font-family="monospace"
            font-size="10"
          >
            1,500
          </text>
          <text
            x="50"
            y="236"
            text-anchor="end"
            class="fill-slate-400"
            font-family="monospace"
            font-size="10"
          >
            750
          </text>
          <text
            x="50"
            y="274"
            text-anchor="end"
            class="fill-slate-400"
            font-family="monospace"
            font-size="10"
          >
            0
          </text>
          <%!-- Area fill --%>
          <path
            d="M96 162 L132 126 L168 150 L204 96 L240 138 L276 114 L312 78 L348 102 L384 66 L420 90 L456 54 L492 78 L528 42 L564 66 L600 54 L636 90 L672 78 L708 102 L744 66 L780 42 L780 270 L96 270 Z"
            fill="url(#revenueGradient)"
          />
          <%!-- Line --%>
          <path
            d="M96 162 L132 126 L168 150 L204 96 L240 138 L276 114 L312 78 L348 102 L384 66 L420 90 L456 54 L492 78 L528 42 L564 66 L600 54 L636 90 L672 78 L708 102 L744 66 L780 42"
            fill="none"
            stroke="#059669"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <%!-- Data points --%>
          <circle cx="96" cy="162" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="132" cy="126" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="168" cy="150" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="204" cy="96" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="240" cy="138" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="276" cy="114" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="312" cy="78" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="348" cy="102" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="384" cy="66" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="420" cy="90" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="456" cy="54" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="492" cy="78" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="528" cy="42" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="564" cy="66" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="600" cy="54" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="636" cy="90" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="672" cy="78" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="708" cy="102" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="744" cy="66" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <circle cx="780" cy="42" r="4" fill="#059669" stroke="white" stroke-width="2" />
          <%!-- X-axis labels --%>
          <text x="96" y="292" text-anchor="middle" font-size="10" class="fill-slate-400">
            1
          </text>
          <text x="168" y="292" text-anchor="middle" font-size="10" class="fill-slate-400">
            3
          </text>
          <text x="240" y="292" text-anchor="middle" font-size="10" class="fill-slate-400">
            5
          </text>
          <text x="312" y="292" text-anchor="middle" font-size="10" class="fill-slate-400">
            7
          </text>
          <text x="384" y="292" text-anchor="middle" font-size="10" class="fill-slate-400">
            9
          </text>
          <text x="456" y="292" text-anchor="middle" font-size="10" class="fill-slate-400">
            11
          </text>
          <text x="528" y="292" text-anchor="middle" font-size="10" class="fill-slate-400">
            13
          </text>
          <text x="600" y="292" text-anchor="middle" font-size="10" class="fill-slate-400">
            15
          </text>
          <text x="672" y="292" text-anchor="middle" font-size="10" class="fill-slate-400">
            17
          </text>
          <text x="744" y="292" text-anchor="middle" font-size="10" class="fill-slate-400">
            19
          </text>
          <text x="780" y="292" text-anchor="middle" font-size="10" class="fill-slate-400">
            21
          </text>
        </svg>
      </div>
    </div>

    <%!-- Revenue Breakdown --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
      <%!-- Revenue by Category (Donut) --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
        <h2 class="text-base font-bold text-slate-900 mb-6">Revenue by Category</h2>
        <div class="flex justify-center mb-6">
          <svg viewBox="0 0 200 200" width="200" height="200">
            <%!-- Dresses 42% --%>
            <circle
              cx="100"
              cy="100"
              r="70"
              fill="none"
              stroke="#059669"
              stroke-width="28"
              stroke-dasharray="184.73 254.47"
              stroke-dashoffset="0"
              transform="rotate(-90 100 100)"
            />
            <%!-- Bags 24% --%>
            <circle
              cx="100"
              cy="100"
              r="70"
              fill="none"
              stroke="#10B981"
              stroke-width="28"
              stroke-dasharray="105.56 333.64"
              stroke-dashoffset="-184.73"
              transform="rotate(-90 100 100)"
            />
            <%!-- Accessories 20% --%>
            <circle
              cx="100"
              cy="100"
              r="70"
              fill="none"
              stroke="#6EE7B7"
              stroke-width="28"
              stroke-dasharray="87.96 351.24"
              stroke-dashoffset="-290.29"
              transform="rotate(-90 100 100)"
            />
            <%!-- Beauty 14% --%>
            <circle
              cx="100"
              cy="100"
              r="70"
              fill="none"
              stroke="#A7F3D0"
              stroke-width="28"
              stroke-dasharray="61.58 377.62"
              stroke-dashoffset="-378.25"
              transform="rotate(-90 100 100)"
            />
            <%!-- Center circle --%>
            <circle cx="100" cy="100" r="56" fill="white" />
            <text
              x="100"
              y="95"
              text-anchor="middle"
              font-family="monospace"
              font-weight="700"
              font-size="16"
              fill="#0F172A"
            >
              GH&#8373;
            </text>
            <text
              x="100"
              y="115"
              text-anchor="middle"
              font-family="monospace"
              font-weight="700"
              font-size="14"
              fill="#0F172A"
            >
              38,470
            </text>
          </svg>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <.category_legend color="bg-emerald-600" name="Dresses" pct="42%" amount="GH&#8373; 16,157" />
          <.category_legend color="bg-emerald-500" name="Bags" pct="24%" amount="GH&#8373; 9,233" />
          <.category_legend
            color="bg-emerald-300"
            name="Accessories"
            pct="20%"
            amount="GH&#8373; 7,694"
          />
          <.category_legend color="bg-emerald-200" name="Beauty" pct="14%" amount="GH&#8373; 5,386" />
        </div>
      </div>
      <%!-- Revenue by Payment Method --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
        <h2 class="text-base font-bold text-slate-900 mb-6">Revenue by Payment Method</h2>
        <div class="space-y-5">
          <.payment_bar
            name="MTN MoMo"
            amount="GH&#8373; 20,004"
            pct="52%"
            bar_color="bg-yellow-400"
            dot_color="bg-yellow-400"
          />
          <.payment_bar
            name="Vodafone Cash"
            amount="GH&#8373; 6,925"
            pct="18%"
            bar_color="bg-red-500"
            dot_color="bg-red-600"
          />
          <.payment_bar
            name="Card"
            amount="GH&#8373; 6,155"
            pct="16%"
            bar_color="bg-blue-500"
            dot_color="bg-blue-600"
          />
          <.payment_bar
            name="Cash on Delivery"
            amount="GH&#8373; 5,386"
            pct="14%"
            bar_color="bg-slate-400"
            dot_color="bg-slate-400"
          />
        </div>
      </div>
    </div>

    <%!-- Recent Transactions Table --%>
    <div class="bg-white rounded-2xl border border-slate-200 mb-8">
      <div class="px-6 py-5 border-b border-slate-100">
        <h2 class="text-base font-bold text-slate-900">Recent Transactions</h2>
        <p class="text-xs text-slate-400 mt-0.5">Latest revenue transactions</p>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-slate-100">
              <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                Date
              </th>
              <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                Order #
              </th>
              <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                Customer
              </th>
              <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                Amount
              </th>
              <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 hidden md:table-cell">
                Payment
              </th>
              <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 hidden lg:table-cell">
                Fee
              </th>
              <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 hidden lg:table-cell">
                Net
              </th>
              <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                Status
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={txn <- @transactions}
              class="border-b border-slate-50 hover:bg-slate-50 transition-colors"
            >
              <td class="px-6 py-4 text-xs text-slate-500">{txn.date}</td>
              <td class="px-6 py-4 font-mono text-xs text-emerald-600 font-medium">
                {txn.order_number}
              </td>
              <td class="px-6 py-4 font-medium text-slate-800">{txn.customer}</td>
              <td class="px-6 py-4 text-right font-mono font-semibold text-slate-800">
                {format_cedis(txn.amount)}
              </td>
              <td class="px-6 py-4 hidden md:table-cell">
                <.payment_method_badge method={txn.payment_method} />
              </td>
              <td class="px-6 py-4 text-right font-mono text-xs text-slate-400 hidden lg:table-cell">
                {format_cedis(txn.fee)}
              </td>
              <td class="px-6 py-4 text-right font-mono text-xs font-medium text-slate-700 hidden lg:table-cell">
                {format_cedis(txn.net)}
              </td>
              <td class="px-6 py-4">
                <.txn_status_badge status={txn.status} />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <%!-- Payout History --%>
    <div class="bg-white rounded-2xl border border-slate-200 p-6">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h2 class="text-base font-bold text-slate-900">Payout History</h2>
          <p class="text-xs text-slate-400 mt-0.5">
            Your payouts are settled to MTN MoMo +233 24 XXX XXXX
          </p>
        </div>
        <div class="w-9 h-9 bg-yellow-50 rounded-xl flex items-center justify-center">
          <svg
            class="w-[18px] h-[18px] text-yellow-600"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M7.5 21L3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5"
            />
          </svg>
        </div>
      </div>

      <div class="space-y-3 mb-6">
        <div
          :for={payout <- @payouts}
          class="flex items-center justify-between p-4 bg-slate-50 rounded-xl"
        >
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 bg-emerald-50 rounded-lg flex items-center justify-center">
              <svg
                class="w-4 h-4 text-emerald-600"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
              </svg>
            </div>
            <div>
              <p class="text-sm font-medium text-slate-800">{payout.date}</p>
              <p class="text-xs text-slate-400">Settled to MTN MoMo</p>
            </div>
          </div>
          <div class="text-right">
            <p class="text-sm font-mono font-bold text-slate-800">
              {format_cedis(payout.amount)}
            </p>
            <span class="inline-flex items-center gap-1 text-[11px] font-semibold text-emerald-700">
              <svg
                class="w-3 h-3"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
              </svg>
              Completed
            </span>
          </div>
        </div>
      </div>

      <%!-- Next Payout --%>
      <div class="flex items-center gap-3 p-4 bg-emerald-50 border border-emerald-200 rounded-xl">
        <div class="w-9 h-9 bg-emerald-100 rounded-lg flex items-center justify-center">
          <svg
            class="w-4 h-4 text-emerald-700"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
        </div>
        <div class="flex-1">
          <p class="text-sm font-semibold text-emerald-800">
            Next payout: <span class="font-mono">{format_cedis(@kpi.pending_payouts)}</span>
          </p>
          <p class="text-xs text-emerald-600">Scheduled for 22/03/2026</p>
        </div>
      </div>
    </div>
    """
  end

  # ── Components ──

  attr :color, :string, required: true
  attr :name, :string, required: true
  attr :pct, :string, required: true
  attr :amount, :string, required: true

  defp category_legend(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <span class={["w-3 h-3 rounded-full shrink-0", @color]}></span>
      <div class="min-w-0">
        <p class="text-sm font-medium text-slate-700 truncate">{@name}</p>
        <p class="text-xs text-slate-400 font-mono">
          {@pct} &middot; {@amount}
        </p>
      </div>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :amount, :string, required: true
  attr :pct, :string, required: true
  attr :bar_color, :string, required: true
  attr :dot_color, :string, required: true

  defp payment_bar(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center gap-2">
          <span class={["w-5 h-5 rounded-full shrink-0", @dot_color]}></span>
          <span class="text-sm font-medium text-slate-700">{@name}</span>
        </div>
        <div class="text-right">
          <span class="text-sm font-mono font-semibold text-slate-800">{@amount}</span>
          <span class="text-xs text-slate-400 ml-2">{@pct}</span>
        </div>
      </div>
      <div class="h-2.5 bg-slate-100 rounded-full overflow-hidden">
        <div class={["h-full rounded-full", @bar_color]} style={"width: #{@pct}"}></div>
      </div>
    </div>
    """
  end

  attr :method, :string, required: true

  defp payment_method_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 text-xs font-medium">
      <span class={["w-4 h-4 rounded-full flex items-center justify-center", method_dot(@method)]}>
      </span>
      {method_label(@method)}
    </span>
    """
  end

  attr :status, :atom, required: true

  defp txn_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-full",
      txn_status_class(@status)
    ]}>
      <span class={["w-1.5 h-1.5 rounded-full", txn_dot_class(@status)]}></span>
      {txn_status_label(@status)}
    </span>
    """
  end

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp period_label("today"), do: "Today"
  defp period_label("week"), do: "This Week"
  defp period_label("month"), do: "This Month"
  defp period_label("year"), do: "This Year"
  defp period_label(_), do: ""

  defp format_cedis(amount_pesewas) when is_integer(amount_pesewas) do
    major = div(amount_pesewas, 100)

    formatted =
      major
      |> Integer.to_string()
      |> format_with_commas()

    minor = amount_pesewas |> rem(100) |> abs()
    minor_str = minor |> Integer.to_string() |> String.pad_leading(2, "0")
    "GH\u20B5 #{formatted}.#{minor_str}"
  end

  defp format_cedis(_), do: "GH\u20B5 0.00"

  defp format_with_commas(str) when byte_size(str) <= 3, do: str

  defp format_with_commas(str) do
    {head, tail} = String.split_at(str, rem(byte_size(str) - 1, 3) + 1)

    tail
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> then(fn chunks -> [head | chunks] end)
    |> Enum.join(",")
  end

  defp method_dot("momo"), do: "bg-yellow-400"
  defp method_dot("vodafone"), do: "bg-red-600"
  defp method_dot("card"), do: "bg-blue-600"
  defp method_dot("cod"), do: "bg-slate-400"
  defp method_dot(_), do: "bg-slate-400"

  defp method_label("momo"), do: "MoMo"
  defp method_label("vodafone"), do: "Vodafone"
  defp method_label("card"), do: "Card"
  defp method_label("cod"), do: "COD"
  defp method_label(_), do: "Other"

  defp txn_status_class(:completed), do: "text-emerald-700 bg-emerald-50"
  defp txn_status_class(:pending), do: "text-amber-700 bg-amber-50"
  defp txn_status_class(_), do: "text-slate-700 bg-slate-50"

  defp txn_dot_class(:completed), do: "bg-emerald-500"
  defp txn_dot_class(:pending), do: "bg-amber-500"
  defp txn_dot_class(_), do: "bg-slate-400"

  defp txn_status_label(:completed), do: "Completed"
  defp txn_status_label(:pending), do: "Pending"
  defp txn_status_label(_), do: "Unknown"

  # ── Placeholder Data ──

  defp assign_placeholder_data(socket) do
    assign(socket,
      kpi: %{
        gross_revenue: 3_847_000,
        net_revenue: 3_462_300,
        platform_fees: 76_940,
        pending_payouts: 428_000
      },
      transactions: [
        %{
          date: "21/03/2026",
          order_number: "EM-4821",
          customer: "Ama Mensah",
          amount: 38_000,
          payment_method: "momo",
          fee: 760,
          net: 37_240,
          status: :completed
        },
        %{
          date: "21/03/2026",
          order_number: "EM-4820",
          customer: "Kofi Adjei",
          amount: 124_000,
          payment_method: "card",
          fee: 2480,
          net: 121_520,
          status: :completed
        },
        %{
          date: "20/03/2026",
          order_number: "EM-4819",
          customer: "Akua Owusu",
          amount: 52_000,
          payment_method: "momo",
          fee: 1040,
          net: 50_960,
          status: :pending
        },
        %{
          date: "20/03/2026",
          order_number: "EM-4818",
          customer: "Yaw Boateng",
          amount: 21_000,
          payment_method: "vodafone",
          fee: 420,
          net: 20_580,
          status: :completed
        },
        %{
          date: "19/03/2026",
          order_number: "EM-4817",
          customer: "Efua Darko",
          amount: 89_000,
          payment_method: "momo",
          fee: 1780,
          net: 87_220,
          status: :completed
        },
        %{
          date: "19/03/2026",
          order_number: "EM-4816",
          customer: "Nana Osei",
          amount: 67_500,
          payment_method: "cod",
          fee: 1350,
          net: 66_150,
          status: :pending
        }
      ],
      payouts: [
        %{date: "15/03/2026", amount: 1_248_000},
        %{date: "08/03/2026", amount: 1_024_000},
        %{date: "01/03/2026", amount: 1_190_300}
      ]
    )
  end
end
