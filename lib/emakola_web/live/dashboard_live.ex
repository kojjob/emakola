defmodule EmakolaWeb.DashboardLive do
  use EmakolaWeb, :live_view

  @refresh_interval 30_000

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    user = socket.assigns[:current_user]

    user_name =
      if user && user.name, do: user.name |> String.split() |> List.first(), else: "there"

    socket =
      socket
      |> assign(
        active_nav: :dashboard,
        page_title: "Dashboard",
        user_name: user_name,
        # KPI data
        revenue: "GH\u20B5 12,847",
        revenue_change: "+15.3%",
        revenue_up: true,
        orders_count: "284",
        orders_change: "+8.2%",
        orders_up: true,
        customers_count: "1,842",
        customers_change: "+22.4%",
        customers_up: true,
        conversion_rate: "4.12%",
        conversion_change: "-0.3%",
        conversion_up: false,
        # Chart period
        chart_period: "monthly",
        # Recent orders
        recent_orders: sample_orders(),
        # Top products
        top_products: sample_products(),
        # Activity feed
        recent_activity: sample_activity()
      )

    {:ok, socket}
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  def handle_event("set_chart_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, chart_period: period)}
  end

  def render(assigns) do
    ~H"""
    <%!-- Header --%>
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">Dashboard</h1>
        <p class="text-sm text-slate-500 mt-1">
          Welcome back, {@user_name}. Here's your store today.
        </p>
      </div>
      <div class="flex gap-2">
        <button class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer">
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
        <a
          href="/admin/products/new"
          class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
        >
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          Add Product
        </a>
      </div>
    </div>

    <%!-- ═══════════════════════════════════════ --%>
    <%!-- KPI CARDS                                --%>
    <%!-- ═══════════════════════════════════════ --%>
    <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4 mb-8">
      <%!-- Revenue --%>
      <div class="fade-in bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300 cursor-default">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Revenue</span>
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
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">{@revenue}</p>
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
            {@revenue_change}
          </span>
          <span class="text-xs text-slate-400">vs last month</span>
        </div>
      </div>

      <%!-- Orders --%>
      <div class="fade-in bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300 cursor-default">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Orders</span>
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
                d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">{@orders_count}</p>
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
            {@orders_change}
          </span>
          <span class="text-xs text-slate-400">vs last month</span>
        </div>
      </div>

      <%!-- Customers --%>
      <div class="fade-in bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300 cursor-default">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Customers</span>
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
                d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">{@customers_count}</p>
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
            {@customers_change}
          </span>
          <span class="text-xs text-slate-400">vs last month</span>
        </div>
      </div>

      <%!-- Conversion --%>
      <div class="fade-in bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300 cursor-default">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Conversion
          </span>
          <div class="w-9 h-9 bg-rose-50 rounded-xl flex items-center justify-center">
            <svg
              class="w-[18px] h-[18px] text-rose-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M2.25 18L9 11.25l4.306 4.307a11.95 11.95 0 015.814-5.519l2.74-1.22m0 0l-5.94-2.28m5.94 2.28l-2.28 5.941"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">{@conversion_rate}</p>
        <div class="flex items-center gap-1.5 mt-2">
          <span class="inline-flex items-center gap-0.5 text-xs font-semibold text-red-600 bg-red-50 px-2 py-0.5 rounded-full">
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
                d="M4.5 4.5l15 15m0 0V8.25m0 11.25H8.25"
              />
            </svg>
            {@conversion_change}
          </span>
          <span class="text-xs text-slate-400">vs last month</span>
        </div>
      </div>
    </div>

    <%!-- ═══════════════════════════════════════ --%>
    <%!-- REVENUE CHART + SALES BY CATEGORY       --%>
    <%!-- ═══════════════════════════════════════ --%>
    <div class="grid xl:grid-cols-3 gap-4 mb-8">
      <%!-- Revenue Chart --%>
      <div class="xl:col-span-2 bg-white rounded-2xl border border-slate-200 p-6">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h2 class="text-base font-bold text-slate-900">Revenue Overview</h2>
            <p class="text-xs text-slate-400 mt-0.5">Monthly revenue for the last 12 months</p>
          </div>
          <div class="flex gap-1 bg-slate-100 rounded-lg p-0.5">
            <button
              phx-click="set_chart_period"
              phx-value-period="monthly"
              class={"px-3 py-1.5 text-xs font-medium rounded-md cursor-pointer " <> if(@chart_period == "monthly", do: "bg-white text-slate-800 shadow-sm", else: "text-slate-500 hover:text-slate-700")}
            >
              Monthly
            </button>
            <button
              phx-click="set_chart_period"
              phx-value-period="weekly"
              class={"px-3 py-1.5 text-xs font-medium rounded-md cursor-pointer " <> if(@chart_period == "weekly", do: "bg-white text-slate-800 shadow-sm", else: "text-slate-500 hover:text-slate-700")}
            >
              Weekly
            </button>
            <button
              phx-click="set_chart_period"
              phx-value-period="daily"
              class={"px-3 py-1.5 text-xs font-medium rounded-md cursor-pointer " <> if(@chart_period == "daily", do: "bg-white text-slate-800 shadow-sm", else: "text-slate-500 hover:text-slate-700")}
            >
              Daily
            </button>
          </div>
        </div>

        <%!-- SVG Area Chart --%>
        <div class="relative" style="height: 280px;">
          <svg
            viewBox="0 0 720 280"
            class="w-full h-full"
            preserveAspectRatio="none"
            aria-label="Revenue chart showing upward trend over 12 months"
            role="img"
          >
            <defs>
              <linearGradient id="areaGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#059669" stop-opacity="0.2" />
                <stop offset="100%" stop-color="#059669" stop-opacity="0" />
              </linearGradient>
              <linearGradient id="lineGrad" x1="0" y1="0" x2="1" y2="0">
                <stop offset="0%" stop-color="#34D399" />
                <stop offset="100%" stop-color="#064E3B" />
              </linearGradient>
            </defs>
            <%!-- Grid lines --%>
            <line x1="40" y1="40" x2="700" y2="40" stroke="#F1F5F9" stroke-width="1" />
            <line x1="40" y1="100" x2="700" y2="100" stroke="#F1F5F9" stroke-width="1" />
            <line x1="40" y1="160" x2="700" y2="160" stroke="#F1F5F9" stroke-width="1" />
            <line x1="40" y1="220" x2="700" y2="220" stroke="#F1F5F9" stroke-width="1" />
            <%!-- Y axis labels --%>
            <text
              x="30"
              y="44"
              text-anchor="end"
              class="text-[10px] fill-slate-400"
              font-family="JetBrains Mono"
            >
              GH&#8373;20k
            </text>
            <text
              x="30"
              y="104"
              text-anchor="end"
              class="text-[10px] fill-slate-400"
              font-family="JetBrains Mono"
            >
              GH&#8373;15k
            </text>
            <text
              x="30"
              y="164"
              text-anchor="end"
              class="text-[10px] fill-slate-400"
              font-family="JetBrains Mono"
            >
              GH&#8373;10k
            </text>
            <text
              x="30"
              y="224"
              text-anchor="end"
              class="text-[10px] fill-slate-400"
              font-family="JetBrains Mono"
            >
              GH&#8373;5k
            </text>
            <%!-- Area fill --%>
            <polygon
              points="60,210 115,195 170,200 225,175 280,168 335,155 390,148 445,125 500,135 555,110 610,90 665,65 665,250 60,250"
              fill="url(#areaGrad)"
            />
            <%!-- Line --%>
            <polyline
              points="60,210 115,195 170,200 225,175 280,168 335,155 390,148 445,125 500,135 555,110 610,90 665,65"
              fill="none"
              stroke="url(#lineGrad)"
              stroke-width="2.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
            <%!-- Data dots --%>
            <circle
              cx="60"
              cy="210"
              r="4"
              fill="white"
              stroke="#059669"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <circle
              cx="115"
              cy="195"
              r="4"
              fill="white"
              stroke="#059669"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <circle
              cx="170"
              cy="200"
              r="4"
              fill="white"
              stroke="#059669"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <circle
              cx="225"
              cy="175"
              r="4"
              fill="white"
              stroke="#059669"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <circle
              cx="280"
              cy="168"
              r="4"
              fill="white"
              stroke="#059669"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <circle
              cx="335"
              cy="155"
              r="4"
              fill="white"
              stroke="#059669"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <circle
              cx="390"
              cy="148"
              r="4"
              fill="white"
              stroke="#059669"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <circle
              cx="445"
              cy="125"
              r="4"
              fill="white"
              stroke="#059669"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <circle
              cx="500"
              cy="135"
              r="4"
              fill="white"
              stroke="#059669"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <circle
              cx="555"
              cy="110"
              r="4"
              fill="white"
              stroke="#059669"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <circle
              cx="610"
              cy="90"
              r="4"
              fill="white"
              stroke="#059669"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <circle
              cx="665"
              cy="65"
              r="5"
              fill="#064E3B"
              stroke="white"
              stroke-width="2"
              class="chart-dot cursor-pointer"
            />
            <%!-- X axis labels --%>
            <text
              x="60"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400"
              font-family="Inter"
            >
              Apr
            </text>
            <text
              x="115"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400"
              font-family="Inter"
            >
              May
            </text>
            <text
              x="170"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400"
              font-family="Inter"
            >
              Jun
            </text>
            <text
              x="225"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400"
              font-family="Inter"
            >
              Jul
            </text>
            <text
              x="280"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400"
              font-family="Inter"
            >
              Aug
            </text>
            <text
              x="335"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400"
              font-family="Inter"
            >
              Sep
            </text>
            <text
              x="390"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400"
              font-family="Inter"
            >
              Oct
            </text>
            <text
              x="445"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400"
              font-family="Inter"
            >
              Nov
            </text>
            <text
              x="500"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400"
              font-family="Inter"
            >
              Dec
            </text>
            <text
              x="555"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400"
              font-family="Inter"
            >
              Jan
            </text>
            <text
              x="610"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400"
              font-family="Inter"
            >
              Feb
            </text>
            <text
              x="665"
              y="270"
              text-anchor="middle"
              class="text-[10px] fill-slate-400 font-semibold"
              font-family="Inter"
            >
              Mar
            </text>
          </svg>
        </div>
      </div>

      <%!-- Sales by Category (Donut) --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
        <h2 class="text-base font-bold text-slate-900 mb-1">Sales by Category</h2>
        <p class="text-xs text-slate-400 mb-6">Revenue distribution this month</p>

        <div class="flex justify-center mb-6">
          <svg
            viewBox="0 0 200 200"
            class="w-48 h-48"
            aria-label="Donut chart showing sales distribution"
            role="img"
          >
            <circle cx="100" cy="100" r="70" fill="none" stroke="#ECFDF5" stroke-width="28" />
            <circle
              cx="100"
              cy="100"
              r="70"
              fill="none"
              stroke="#064E3B"
              stroke-width="28"
              stroke-dasharray="184.72 255.10"
              stroke-dashoffset="110"
              stroke-linecap="round"
              class="transition-all duration-500 hover:stroke-[32px] cursor-pointer"
            />
            <circle
              cx="100"
              cy="100"
              r="70"
              fill="none"
              stroke="#059669"
              stroke-width="28"
              stroke-dasharray="123.15 316.67"
              stroke-dashoffset="-74.72"
              stroke-linecap="round"
              class="transition-all duration-500 hover:stroke-[32px] cursor-pointer"
            />
            <circle
              cx="100"
              cy="100"
              r="70"
              fill="none"
              stroke="#34D399"
              stroke-width="28"
              stroke-dasharray="79.17 360.65"
              stroke-dashoffset="-197.87"
              stroke-linecap="round"
              class="transition-all duration-500 hover:stroke-[32px] cursor-pointer"
            />
            <circle
              cx="100"
              cy="100"
              r="70"
              fill="none"
              stroke="#A7F3D0"
              stroke-width="28"
              stroke-dasharray="52.78 387.04"
              stroke-dashoffset="-277.04"
              stroke-linecap="round"
              class="transition-all duration-500 hover:stroke-[32px] cursor-pointer"
            />
            <text
              x="100"
              y="94"
              text-anchor="middle"
              class="text-lg font-bold fill-slate-900"
              font-family="JetBrains Mono"
            >
              GH&#8373;12.8K
            </text>
            <text
              x="100"
              y="114"
              text-anchor="middle"
              class="text-[11px] fill-slate-400"
              font-family="Inter"
            >
              Total Revenue
            </text>
          </svg>
        </div>

        <%!-- Legend --%>
        <div class="space-y-3">
          <div class="flex items-center justify-between text-sm">
            <div class="flex items-center gap-2.5">
              <span class="w-3 h-3 rounded-full bg-emerald-900"></span>
              <span class="text-slate-600">Fashion</span>
            </div>
            <span class="font-mono font-semibold text-slate-800">42%</span>
          </div>
          <div class="flex items-center justify-between text-sm">
            <div class="flex items-center gap-2.5">
              <span class="w-3 h-3 rounded-full bg-emerald-600"></span>
              <span class="text-slate-600">Accessories</span>
            </div>
            <span class="font-mono font-semibold text-slate-800">28%</span>
          </div>
          <div class="flex items-center justify-between text-sm">
            <div class="flex items-center gap-2.5">
              <span class="w-3 h-3 rounded-full bg-emerald-400"></span>
              <span class="text-slate-600">Bags</span>
            </div>
            <span class="font-mono font-semibold text-slate-800">18%</span>
          </div>
          <div class="flex items-center justify-between text-sm">
            <div class="flex items-center gap-2.5">
              <span class="w-3 h-3 rounded-full bg-emerald-200"></span>
              <span class="text-slate-600">Other</span>
            </div>
            <span class="font-mono font-semibold text-slate-800">12%</span>
          </div>
        </div>
      </div>
    </div>

    <%!-- ═══════════════════════════════════════ --%>
    <%!-- RECENT ORDERS + TOP PRODUCTS             --%>
    <%!-- ═══════════════════════════════════════ --%>
    <div class="grid xl:grid-cols-3 gap-4 mb-8">
      <%!-- Recent Orders Table --%>
      <div class="xl:col-span-2 bg-white rounded-2xl border border-slate-200 overflow-hidden">
        <div class="flex items-center justify-between px-6 py-5 border-b border-slate-100">
          <div>
            <h2 class="text-base font-bold text-slate-900">Recent Orders</h2>
            <p class="text-xs text-slate-400 mt-0.5">Last 24 hours</p>
          </div>
          <a
            href="/admin/orders"
            class="text-xs font-semibold text-emerald-600 hover:text-emerald-700 transition-colors cursor-pointer"
          >
            View all
          </a>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full text-sm" role="table">
            <thead>
              <tr class="border-b border-slate-100">
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                  Order
                </th>
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                  Customer
                </th>
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 hidden sm:table-cell">
                  Product
                </th>
                <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                  Amount
                </th>
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 hidden md:table-cell">
                  Payment
                </th>
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                  Status
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={order <- @recent_orders}
                class="table-row border-b border-slate-50 cursor-pointer"
              >
                <td class="px-6 py-4 font-mono text-xs text-emerald-600 font-medium">{order.id}</td>
                <td class="px-6 py-4">
                  <div class="flex items-center gap-3">
                    <div class="w-8 h-8 rounded-full bg-slate-200 flex items-center justify-center text-xs font-semibold text-slate-600 shrink-0">
                      {String.first(order.customer)}
                    </div>
                    <div>
                      <p class="font-medium text-slate-800">{order.customer}</p>
                      <p class="text-[11px] text-slate-400">{order.city}</p>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 text-slate-600 hidden sm:table-cell">{order.product}</td>
                <td class="px-6 py-4 text-right font-mono font-semibold text-slate-800">
                  {order.amount}
                </td>
                <td class="px-6 py-4 hidden md:table-cell">
                  <span class="inline-flex items-center gap-1.5 text-xs font-medium">
                    <span class={"w-5 h-5 rounded-full flex items-center justify-center " <> order.payment_bg}>
                      <svg
                        class={"w-3 h-3 " <> order.payment_icon_color}
                        fill="currentColor"
                        viewBox="0 0 24 24"
                        aria-hidden="true"
                      >
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z" />
                      </svg>
                    </span>
                    {order.payment_method}
                  </span>
                </td>
                <td class="px-6 py-4">
                  <span class={"inline-flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-full " <> order.status_class}>
                    <span class={"w-1.5 h-1.5 rounded-full " <> order.status_dot}></span>
                    {order.status}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Top Products --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h2 class="text-base font-bold text-slate-900">Top Products</h2>
            <p class="text-xs text-slate-400 mt-0.5">Best sellers this month</p>
          </div>
          <a
            href="/admin/products"
            class="text-xs font-semibold text-emerald-600 hover:text-emerald-700 transition-colors cursor-pointer"
          >
            View all
          </a>
        </div>

        <div class="space-y-4">
          <div
            :for={product <- @top_products}
            class="flex items-center gap-4 p-3 rounded-xl hover:bg-slate-50 transition-colors cursor-pointer group"
          >
            <div class="w-14 h-14 rounded-xl bg-slate-100 flex items-center justify-center text-lg shrink-0 ring-1 ring-slate-200 group-hover:ring-emerald-200 transition-colors overflow-hidden">
              <span class="text-slate-400">{String.first(product.name)}</span>
            </div>
            <div class="flex-1 min-w-0">
              <p class="font-semibold text-slate-800 text-sm truncate">{product.name}</p>
              <p class="text-xs text-slate-400 mt-0.5">{product.category}</p>
              <div class="flex items-center gap-2 mt-2">
                <div class="flex-1 h-1.5 bg-slate-100 rounded-full overflow-hidden">
                  <div
                    class={"progress-fill h-full rounded-full " <> product.bar_color}
                    style={"width: #{product.pct}%"}
                  >
                  </div>
                </div>
                <span class="text-[11px] font-mono font-medium text-slate-500">{product.pct}%</span>
              </div>
            </div>
            <p class="font-mono font-bold text-slate-800 text-sm">{product.revenue}</p>
          </div>
        </div>
      </div>
    </div>

    <%!-- ═══════════════════════════════════════ --%>
    <%!-- ACTIVITY FEED                             --%>
    <%!-- ═══════════════════════════════════════ --%>
    <div class="bg-white rounded-2xl border border-slate-200 p-6 mb-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h2 class="text-base font-bold text-slate-900">Recent Activity</h2>
          <p class="text-xs text-slate-400 mt-0.5">Real-time store events</p>
        </div>
        <span class="flex items-center gap-1.5 text-[11px] font-medium text-emerald-600">
          <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span> Live
        </span>
      </div>

      <div class="space-y-0">
        <div
          :for={activity <- @recent_activity}
          class={"flex gap-4 py-3 " <> if(activity != List.last(@recent_activity), do: "border-b border-slate-50", else: "")}
        >
          <div class={"w-9 h-9 rounded-full flex items-center justify-center shrink-0 " <> activity.icon_bg}>
            <svg
              class={"w-4 h-4 " <> activity.icon_color}
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d={activity.icon_path} />
            </svg>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm text-slate-800">
              <span class="font-semibold">{activity.title}</span>
              {activity.description}
            </p>
            <p class="text-xs text-slate-400 mt-1">{activity.time}</p>
          </div>
          <%= if activity[:amount] do %>
            <span class="text-sm font-mono font-semibold text-emerald-600 shrink-0">
              {activity.amount}
            </span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ── Sample Data ──

  defp sample_orders do
    [
      %{
        id: "EM-4821",
        customer: "Ama Mensah",
        city: "Accra",
        product: "Kente Wrap Dress",
        amount: "GH\u20B5 380",
        payment_method: "MTN MoMo",
        payment_bg: "bg-yellow-400",
        payment_icon_color: "text-yellow-900",
        status: "Delivered",
        status_class: "text-emerald-700 bg-emerald-50",
        status_dot: "bg-emerald-500"
      },
      %{
        id: "EM-4820",
        customer: "Kofi Adjei",
        city: "Kumasi",
        product: "Beaded Necklace Set",
        amount: "GH\u20B5 145",
        payment_method: "Vodafone Cash",
        payment_bg: "bg-red-600",
        payment_icon_color: "text-white",
        status: "Shipping",
        status_class: "text-amber-700 bg-amber-50",
        status_dot: "bg-amber-500"
      },
      %{
        id: "EM-4819",
        customer: "Akua Owusu",
        city: "Tema",
        product: "Leather Crossbody Bag",
        amount: "GH\u20B5 520",
        payment_method: "Card",
        payment_bg: "bg-blue-600",
        payment_icon_color: "text-white",
        status: "Delivered",
        status_class: "text-emerald-700 bg-emerald-50",
        status_dot: "bg-emerald-500"
      },
      %{
        id: "EM-4818",
        customer: "Yaw Boateng",
        city: "Takoradi",
        product: "Ankara Shirt (2pc)",
        amount: "GH\u20B5 210",
        payment_method: "MTN MoMo",
        payment_bg: "bg-yellow-400",
        payment_icon_color: "text-yellow-900",
        status: "Processing",
        status_class: "text-blue-700 bg-blue-50",
        status_dot: "bg-blue-500"
      },
      %{
        id: "EM-4817",
        customer: "Abena Serwaa",
        city: "Accra",
        product: "Shea Butter Gift Set",
        amount: "GH\u20B5 95",
        payment_method: "COD",
        payment_bg: "bg-slate-400",
        payment_icon_color: "text-white",
        status: "Pending",
        status_class: "text-amber-700 bg-amber-50",
        status_dot: "bg-amber-500"
      }
    ]
  end

  defp sample_products do
    [
      %{
        name: "Kente Wrap Dress",
        category: "Fashion",
        pct: 88,
        revenue: "GH\u20B5 3.4K",
        bar_color: "bg-emerald-600"
      },
      %{
        name: "Beaded Necklace Set",
        category: "Accessories",
        pct: 72,
        revenue: "GH\u20B5 2.8K",
        bar_color: "bg-emerald-600"
      },
      %{
        name: "Leather Crossbody Bag",
        category: "Bags",
        pct: 56,
        revenue: "GH\u20B5 2.1K",
        bar_color: "bg-amber-500"
      },
      %{
        name: "Ankara Print Dress",
        category: "Fashion",
        pct: 43,
        revenue: "GH\u20B5 1.6K",
        bar_color: "bg-emerald-500"
      },
      %{
        name: "Shea Butter Gift Set",
        category: "Beauty",
        pct: 31,
        revenue: "GH\u20B5 1.2K",
        bar_color: "bg-violet-500"
      }
    ]
  end

  defp sample_activity do
    [
      %{
        title: "New order",
        description: " EM-4821 placed by Ama Mensah",
        time: "2 minutes ago",
        amount: "+GH\u20B5 380",
        icon_bg: "bg-emerald-50",
        icon_color: "text-emerald-600",
        icon_path:
          "M2.25 3h1.386c.51 0 .955.343 1.087.835l.383 1.437M7.5 14.25a3 3 0 00-3 3h15.75m-12.75-3h11.218c1.121-2.3 2.1-4.684 2.924-7.138a60.114 60.114 0 00-16.536-1.84M7.5 14.25L5.106 5.272M6 20.25a.75.75 0 11-1.5 0 .75.75 0 011.5 0zm12.75 0a.75.75 0 11-1.5 0 .75.75 0 011.5 0z"
      },
      %{
        title: "Payment received",
        description: " via MTN MoMo for EM-4818",
        time: "15 minutes ago",
        amount: "+GH\u20B5 210",
        icon_bg: "bg-yellow-50",
        icon_color: "text-yellow-600",
        icon_path: "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      },
      %{
        title: "New customer",
        description: " Efua Darko signed up from Instagram",
        time: "42 minutes ago",
        icon_bg: "bg-blue-50",
        icon_color: "text-blue-600",
        icon_path:
          "M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z"
      },
      %{
        title: "Order shipped",
        description: " EM-4815 dispatched to Kumasi via GPost",
        time: "1 hour ago",
        icon_bg: "bg-violet-50",
        icon_color: "text-violet-600",
        icon_path:
          "M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0H6.375c-.621 0-1.125-.504-1.125-1.125V14.25m17.25 0V6.375c0-.621-.504-1.125-1.125-1.125H6.75c-.621 0-1.125.504-1.125 1.125v7.875m12.75 0h1.5c.621 0 1.125-.504 1.125-1.125V11.25c0-.621-.504-1.125-1.125-1.125h-2.672a1.125 1.125 0 01-.922-.485l-.654-.982a1.125 1.125 0 00-.922-.485H11.25"
      },
      %{
        title: "Low stock alert",
        description: " Kente Wrap Dress -- only 3 units remaining",
        time: "2 hours ago",
        icon_bg: "bg-red-50",
        icon_color: "text-red-600",
        icon_path:
          "M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
      }
    ]
  end
end
