defmodule EmakolaWeb.Admin.ReportLive.Index do
  @moduledoc """
  Admin reports page with KPI summary strip, revenue trend chart,
  sales by channel donut, top products bar chart, customer acquisition,
  payment methods, order status breakdown, sales by region table,
  and AI insights section.
  Pixel-matched to design/prototypes/emakola-admin-reports.html.
  """
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    {start_date, end_date} = date_range_to_dates("30d")

    socket =
      socket
      |> assign(
        page_title: "Reports",
        active_nav: :reports,
        store_id: store_id,
        date_range: "30d",
        start_date: start_date,
        end_date: end_date,
        compare_previous: true
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("set_date_range", %{"range" => range}, socket) do
    {start_date, end_date} = date_range_to_dates(range)
    {:noreply, assign(socket, date_range: range, start_date: start_date, end_date: end_date)}
  end

  @impl true
  def handle_event("toggle_compare", _params, socket) do
    {:noreply, assign(socket, compare_previous: !socket.assigns.compare_previous)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Page Header --%>
    <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 mb-8">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">Reports</h1>
        <p class="text-sm text-slate-500 mt-1">Detailed analytics and insights for your store</p>
      </div>
      <div class="flex flex-wrap items-center gap-3">
        <%!-- Date range pill toggle --%>
        <div class="flex gap-0.5 bg-slate-100 rounded-lg p-0.5">
          <button
            :for={
              {label, value} <- [
                {"7D", "7d"},
                {"30D", "30d"},
                {"90D", "90d"},
                {"12M", "12m"},
                {"Custom", "custom"}
              ]
            }
            phx-click="set_date_range"
            phx-value-range={value}
            class={[
              "px-3 py-1.5 text-xs font-medium rounded-md cursor-pointer transition-all",
              if(@date_range == value,
                do: "bg-white text-slate-900 shadow-sm",
                else: "text-slate-500 hover:text-slate-700"
              )
            ]}
          >
            {label}
          </button>
        </div>
        <%!-- Export buttons --%>
        <a
          href={"/admin/export/analytics.pdf?start_date=#{@start_date}&end_date=#{@end_date}"}
          class="inline-flex items-center gap-2 px-3.5 py-2 bg-stone-900 text-white rounded-xl text-xs font-medium hover:bg-stone-800 transition-colors cursor-pointer"
        >
          <svg
            class="w-3.5 h-3.5"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
            />
          </svg>
          Export PDF
        </a>
        <button class="inline-flex items-center gap-2 px-3.5 py-2 bg-white border border-slate-200 rounded-xl text-xs font-medium text-slate-600 hover:bg-slate-50 transition-colors cursor-pointer">
          <svg
            class="w-3.5 h-3.5"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
            />
          </svg>
          Export CSV
        </button>
        <%!-- Compare toggle --%>
        <label class="inline-flex items-center gap-2 cursor-pointer">
          <div class="relative">
            <input
              type="checkbox"
              class="sr-only peer"
              checked={@compare_previous}
              phx-click="toggle_compare"
            />
            <div class="w-9 h-5 bg-slate-200 rounded-full peer-checked:bg-emerald-600 transition-colors">
            </div>
            <div class="absolute left-0.5 top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform peer-checked:translate-x-4">
            </div>
          </div>
          <span class="text-xs font-medium text-slate-500">vs previous period</span>
        </label>
      </div>
    </div>

    <%!-- ROW 1: KPI Summary Strip --%>
    <div class="bg-white rounded-2xl shadow-sm p-6 mb-6">
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-6 lg:gap-0 lg:divide-x lg:divide-slate-200">
        <.kpi_item
          label="Total Revenue"
          value="GH₵ 38,470"
          change="+15.3%"
          trend={:up}
          sparkline="0,12 5,10 10,8 15,9 20,5 25,3 30,1"
        />
        <.kpi_item
          label="Orders"
          value="284"
          change="+8.2%"
          trend={:up}
          sparkline="0,11 5,10 10,9 15,10 20,7 25,4 30,2"
        />
        <.kpi_item label="Avg. Order Value" value="GH₵ 135.46" change="+6.1%" trend={:up} />
        <.kpi_item label="Conversion Rate" value="4.12%" change="-0.3%" trend={:down} />
        <.kpi_item label="Returning Customers" value="34.2%" change="+2.8%" trend={:up} />
      </div>
    </div>

    <%!-- ROW 2: Revenue Trend Chart --%>
    <div class="bg-white rounded-2xl shadow-sm p-6 mb-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6">
        <div>
          <h2 class="text-base font-bold text-slate-900">Revenue Trend</h2>
          <p class="text-xs text-slate-400 mt-0.5">Daily revenue &mdash; last 30 days</p>
        </div>
        <div class="flex items-center gap-5 text-xs mt-3 sm:mt-0">
          <div class="flex items-center gap-1.5">
            <span class="w-4 h-0.5 bg-emerald-600 rounded block"></span>
            <span class="text-slate-500">This period</span>
          </div>
          <div class="flex items-center gap-1.5">
            <span class="w-4 h-0 border-b-2 border-dashed border-slate-300 block"></span>
            <span class="text-slate-500">Previous period</span>
          </div>
        </div>
      </div>

      <div class="relative" style="height: 320px;">
        <svg
          viewBox="0 0 760 320"
          class="w-full h-full"
          preserveAspectRatio="none"
          aria-label="Area chart showing daily revenue trend over 30 days"
          role="img"
        >
          <defs>
            <linearGradient id="revenueGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="#059669" stop-opacity="0.18" />
              <stop offset="100%" stop-color="#059669" stop-opacity="0" />
            </linearGradient>
          </defs>
          <%!-- Horizontal grid lines --%>
          <line
            :for={y <- [40, 100, 160, 220, 280]}
            x1="55"
            y1={y}
            x2="740"
            y2={y}
            stroke="#F1F5F9"
            stroke-width="1"
          />
          <%!-- Y axis labels --%>
          <text
            :for={
              {label, y} <- [
                {"GH₵3,000", 44},
                {"GH₵2,250", 104},
                {"GH₵1,500", 164},
                {"GH₵750", 224},
                {"GH₵0", 284}
              ]
            }
            x="48"
            y={y}
            text-anchor="end"
            class="text-[10px] fill-slate-400"
            style="font-family: monospace"
          >
            {label}
          </text>
          <%!-- Previous period (dashed) --%>
          <polyline
            points="65,210 88,218 111,198 134,225 157,205 180,215 203,195 226,208 249,188 272,200 295,180 318,195 341,175 364,190 387,168 410,182 433,162 456,178 479,155 502,170 525,148 548,165 571,142 594,158 617,132 640,150 663,125 686,142 709,115 732,130"
            fill="none"
            stroke="#CBD5E1"
            stroke-width="1.5"
            stroke-dasharray="6 4"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <%!-- Current period area fill --%>
          <polygon
            points="65,195 88,178 111,186 134,165 157,172 180,152 203,160 226,142 249,155 272,138 295,148 318,128 341,140 364,122 387,132 410,112 433,125 456,105 479,118 502,96 525,108 548,90 571,102 582,88 594,95 617,78 640,88 663,68 686,80 709,58 732,48 732,280 65,280"
            fill="url(#revenueGrad)"
          />
          <%!-- Current period line --%>
          <polyline
            points="65,195 88,178 111,186 134,165 157,172 180,152 203,160 226,142 249,155 272,138 295,148 318,128 341,140 364,122 387,132 410,112 433,125 456,105 479,118 502,96 525,108 548,90 571,102 582,88 594,95 617,78 640,88 663,68 686,80 709,58 732,48"
            fill="none"
            stroke="#059669"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <%!-- Interactive dots --%>
          <circle
            :for={
              {cx, cy} <- [
                {65, 195},
                {157, 172},
                {249, 155},
                {341, 140},
                {433, 125},
                {525, 108},
                {617, 78}
              ]
            }
            cx={cx}
            cy={cy}
            r="3"
            fill="white"
            stroke="#059669"
            stroke-width="2"
            class="cursor-pointer"
          />
          <circle cx="732" cy="48" r="4.5" fill="#064E3B" stroke="white" stroke-width="2" />
          <%!-- X axis labels --%>
          <text
            :for={
              {label, x, bold} <- [
                {"Feb 20", 65, false},
                {"Feb 25", 180, false},
                {"Mar 1", 295, false},
                {"Mar 6", 410, false},
                {"Mar 11", 525, false},
                {"Mar 16", 640, false},
                {"Mar 21", 732, true}
              ]
            }
            x={x}
            y="300"
            text-anchor="middle"
            class={["text-[10px] fill-slate-400", if(bold, do: "font-semibold", else: "")]}
          >
            {label}
          </text>
        </svg>
      </div>
    </div>

    <%!-- ROW 3: Sales by Channel + Top Products --%>
    <div class="grid xl:grid-cols-2 gap-6 mb-6">
      <%!-- Sales by Channel (Donut) --%>
      <div class="bg-white rounded-2xl shadow-sm p-6">
        <h2 class="text-base font-bold text-slate-900 mb-1">Sales by Channel</h2>
        <p class="text-xs text-slate-400 mb-6">Traffic source distribution this period</p>

        <div class="flex flex-col sm:flex-row items-center gap-8">
          <%!-- Donut Chart --%>
          <div class="relative shrink-0">
            <svg
              viewBox="0 0 200 200"
              class="w-40 h-40"
              aria-label="Donut chart: Instagram 45%, WhatsApp 28%, Direct 15%, Google 8%, TikTok 4%"
              role="img"
            >
              <circle cx="100" cy="100" r="70" fill="none" stroke="#F1F5F9" stroke-width="26" />
              <%!-- Instagram 45% --%>
              <circle
                cx="100"
                cy="100"
                r="70"
                fill="none"
                stroke="#E1306C"
                stroke-width="26"
                stroke-dasharray="197.92 241.90"
                stroke-dashoffset="110"
                stroke-linecap="round"
                class="transition-all duration-300 cursor-pointer"
              />
              <%!-- WhatsApp 28% --%>
              <circle
                cx="100"
                cy="100"
                r="70"
                fill="none"
                stroke="#25D366"
                stroke-width="26"
                stroke-dasharray="123.15 316.67"
                stroke-dashoffset="-87.92"
                stroke-linecap="round"
                class="transition-all duration-300 cursor-pointer"
              />
              <%!-- Direct 15% --%>
              <circle
                cx="100"
                cy="100"
                r="70"
                fill="none"
                stroke="#3B82F6"
                stroke-width="26"
                stroke-dasharray="65.97 373.85"
                stroke-dashoffset="-211.07"
                stroke-linecap="round"
                class="transition-all duration-300 cursor-pointer"
              />
              <%!-- Google 8% --%>
              <circle
                cx="100"
                cy="100"
                r="70"
                fill="none"
                stroke="#EA4335"
                stroke-width="26"
                stroke-dasharray="35.19 404.63"
                stroke-dashoffset="-277.04"
                stroke-linecap="round"
                class="transition-all duration-300 cursor-pointer"
              />
              <%!-- TikTok 4% --%>
              <circle
                cx="100"
                cy="100"
                r="70"
                fill="none"
                stroke="#0F172A"
                stroke-width="26"
                stroke-dasharray="17.59 422.23"
                stroke-dashoffset="-312.23"
                stroke-linecap="round"
                class="transition-all duration-300 cursor-pointer"
              />
            </svg>
            <div class="absolute inset-0 flex flex-col items-center justify-center">
              <span class="text-xl font-bold text-slate-900 font-mono">2,787</span>
              <span class="text-[10px] text-slate-400 font-medium">total visits</span>
            </div>
          </div>

          <%!-- Legend --%>
          <div class="flex-1 space-y-3 min-w-0">
            <.channel_row color="#E1306C" name="Instagram" visits="1,254" pct="45%" trend={:up} />
            <.channel_row color="#25D366" name="WhatsApp" visits="780" pct="28%" trend={:up} />
            <.channel_row color="#3B82F6" name="Direct" visits="418" pct="15%" trend={:flat} />
            <.channel_row color="#EA4335" name="Google" visits="223" pct="8%" trend={:up} />
            <.channel_row color="#0F172A" name="TikTok" visits="112" pct="4%" trend={:up} />
          </div>
        </div>

        <%!-- Insight callout --%>
        <div class="mt-5 flex items-start gap-2.5 p-3.5 bg-emerald-50 rounded-xl border border-emerald-100">
          <svg
            class="w-4 h-4 text-emerald-600 mt-0.5 shrink-0"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 10-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
            />
          </svg>
          <p class="text-xs text-emerald-700 leading-relaxed">
            Instagram drives 45% of traffic. Consider increasing Instagram product posts and stories to boost conversion further.
          </p>
        </div>
      </div>

      <%!-- Top Products (Horizontal Bar Chart) --%>
      <div class="bg-white rounded-2xl shadow-sm p-6">
        <h2 class="text-base font-bold text-slate-900 mb-1">Top Products</h2>
        <p class="text-xs text-slate-400 mb-6">Best sellers by revenue this period</p>

        <div class="space-y-5">
          <.product_bar name="Kente Wrap Dress" revenue="GH₵ 8,400" pct={86} shade="bg-emerald-600" />
          <.product_bar name="Ankara Tote Bag" revenue="GH₵ 5,640" pct={68} shade="bg-emerald-500" />
          <.product_bar name="Beaded Choker" revenue="GH₵ 4,250" pct={52} shade="bg-emerald-400" />
          <.product_bar name="Shea Butter Set" revenue="GH₵ 3,120" pct={38} shade="bg-emerald-300" />
          <.product_bar name="Gold Ear Cuffs" revenue="GH₵ 2,890" pct={35} shade="bg-emerald-200" />
        </div>
      </div>
    </div>

    <%!-- ROW 4: Customer Acquisition + Payments + Order Status --%>
    <div class="grid lg:grid-cols-3 gap-6 mb-6">
      <%!-- Customer Acquisition --%>
      <div class="bg-white rounded-2xl shadow-sm p-6">
        <h2 class="text-base font-bold text-slate-900 mb-1">Customer Acquisition</h2>
        <p class="text-xs text-slate-400 mb-4">New customers per week (12 weeks)</p>

        <div class="relative" style="height: 180px;">
          <svg
            viewBox="0 0 340 180"
            class="w-full h-full"
            preserveAspectRatio="none"
            aria-label="Area chart showing new customer acquisition over 12 weeks"
            role="img"
          >
            <defs>
              <linearGradient id="custGrad2" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#059669" stop-opacity="0.2" />
                <stop offset="100%" stop-color="#059669" stop-opacity="0" />
              </linearGradient>
            </defs>
            <line
              :for={y <- [30, 70, 110]}
              x1="20"
              y1={y}
              x2="320"
              y2={y}
              stroke="#F1F5F9"
              stroke-width="1"
            />
            <polygon
              points="30,130 57,120 84,115 111,105 138,110 165,95 192,85 219,90 246,75 273,65 300,70 327,50 327,155 30,155"
              fill="url(#custGrad2)"
            />
            <polyline
              points="30,130 57,120 84,115 111,105 138,110 165,95 192,85 219,90 246,75 273,65 300,70 327,50"
              fill="none"
              stroke="#059669"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
            <circle cx="327" cy="50" r="3.5" fill="#064E3B" stroke="white" stroke-width="2" />
          </svg>
        </div>

        <div class="mt-4 pt-4 border-t border-slate-100 space-y-2">
          <p class="text-sm font-semibold text-slate-800">128 new customers this month</p>
          <div class="flex items-center gap-2">
            <span class="inline-flex items-center gap-0.5 text-xs font-semibold text-emerald-600 bg-emerald-50 px-1.5 py-0.5 rounded-md">
              +24% from referrals
            </span>
          </div>
          <p class="text-xs text-slate-400">Top source: Instagram</p>
        </div>
      </div>

      <%!-- Payment Methods --%>
      <div class="bg-white rounded-2xl shadow-sm p-6">
        <h2 class="text-base font-bold text-slate-900 mb-1">Payment Methods</h2>
        <p class="text-xs text-slate-400 mb-4">Distribution and success rates</p>

        <%!-- Stacked horizontal bar --%>
        <div class="w-full h-7 rounded-full overflow-hidden flex mb-5">
          <div class="h-full" style="width:52%; background:#FFC107;" title="MTN MoMo 52%"></div>
          <div class="h-full" style="width:18%; background:#E60000;" title="Vodafone Cash 18%"></div>
          <div class="h-full" style="width:16%; background:#3B82F6;" title="Card 16%"></div>
          <div class="h-full" style="width:14%; background:#94A3B8;" title="COD 14%"></div>
        </div>

        <div class="space-y-3.5">
          <.payment_row color="#FFC107" name="MTN MoMo" rate="96.2%" count="148" trend={:up} />
          <.payment_row color="#E60000" name="Vodafone Cash" rate="94.8%" count="51" trend={:flat} />
          <.payment_row color="#3B82F6" name="Card" rate="98.1%" count="45" trend={:up} />
          <.payment_row color="#94A3B8" name="Cash on Delivery" rate="100%" count="40" trend={:down} />
        </div>
      </div>

      <%!-- Order Status Breakdown --%>
      <div class="bg-white rounded-2xl shadow-sm p-6">
        <h2 class="text-base font-bold text-slate-900 mb-1">Order Status</h2>
        <p class="text-xs text-slate-400 mb-4">Breakdown for this period</p>

        <div class="flex justify-center mb-5">
          <div class="relative">
            <svg
              viewBox="0 0 160 160"
              class="w-[120px] h-[120px]"
              aria-label="Donut chart: Order statuses"
              role="img"
            >
              <circle cx="80" cy="80" r="55" fill="none" stroke="#F1F5F9" stroke-width="22" />
              <%!-- Delivered 72% --%>
              <circle
                cx="80"
                cy="80"
                r="55"
                fill="none"
                stroke="#059669"
                stroke-width="22"
                stroke-dasharray="248.81 96.76"
                stroke-dashoffset="86.4"
                stroke-linecap="round"
                class="transition-all duration-300 cursor-pointer"
              />
              <%!-- Shipped 15% --%>
              <circle
                cx="80"
                cy="80"
                r="55"
                fill="none"
                stroke="#8B5CF6"
                stroke-width="22"
                stroke-dasharray="51.84 293.73"
                stroke-dashoffset="-162.41"
                stroke-linecap="round"
                class="transition-all duration-300 cursor-pointer"
              />
              <%!-- Processing 8% --%>
              <circle
                cx="80"
                cy="80"
                r="55"
                fill="none"
                stroke="#3B82F6"
                stroke-width="22"
                stroke-dasharray="27.65 317.92"
                stroke-dashoffset="-214.25"
                stroke-linecap="round"
                class="transition-all duration-300 cursor-pointer"
              />
              <%!-- Cancelled 3% --%>
              <circle
                cx="80"
                cy="80"
                r="55"
                fill="none"
                stroke="#EF4444"
                stroke-width="22"
                stroke-dasharray="10.37 335.20"
                stroke-dashoffset="-241.90"
                stroke-linecap="round"
                class="transition-all duration-300 cursor-pointer"
              />
              <%!-- Refunded 2% --%>
              <circle
                cx="80"
                cy="80"
                r="55"
                fill="none"
                stroke="#F59E0B"
                stroke-width="22"
                stroke-dasharray="6.91 338.66"
                stroke-dashoffset="-252.27"
                stroke-linecap="round"
                class="transition-all duration-300 cursor-pointer"
              />
            </svg>
            <div class="absolute inset-0 flex flex-col items-center justify-center">
              <span class="text-lg font-bold text-slate-900 font-mono">284</span>
              <span class="text-[9px] text-slate-400 font-medium">orders</span>
            </div>
          </div>
        </div>

        <div class="space-y-2.5">
          <.status_row color="bg-emerald-600" label="Delivered" count="204" pct="72%" />
          <.status_row color="bg-violet-500" label="Shipped" count="43" pct="15%" />
          <.status_row color="bg-blue-500" label="Processing" count="23" pct="8%" />
          <.status_row color="bg-red-500" label="Cancelled" count="8" pct="3%" />
          <.status_row color="bg-amber-500" label="Refunded" count="6" pct="2%" />
        </div>
      </div>
    </div>

    <%!-- ROW 5: Sales by Region Table --%>
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden mb-6">
      <div class="px-6 py-5 border-b border-slate-100">
        <h2 class="text-base font-bold text-slate-900">Sales by Region</h2>
        <p class="text-xs text-slate-400 mt-0.5">Top performing regions this period</p>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full text-sm" role="table">
          <thead>
            <tr class="border-b border-slate-100">
              <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 w-10">
                #
              </th>
              <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                Region
              </th>
              <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                Orders
              </th>
              <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                Revenue
              </th>
              <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                Avg. Order
              </th>
              <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                Conv. Rate
              </th>
              <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 min-w-[140px]">
                % of Total
              </th>
            </tr>
          </thead>
          <tbody>
            <.region_row
              :for={{row, idx} <- Enum.with_index(regions(), 1)}
              rank={idx}
              name={row.name}
              orders={row.orders}
              revenue={row.revenue}
              avg_order={row.avg_order}
              conv_rate={row.conv_rate}
              pct_total={row.pct_total}
              bar_width={row.bar_width}
              bar_shade={row.bar_shade}
              last={idx == length(regions())}
            />
          </tbody>
        </table>
      </div>
    </div>

    <%!-- ROW 6: AI Insights & Recommendations --%>
    <div class="bg-white rounded-2xl shadow-sm p-6 mb-8">
      <div class="flex items-center gap-2.5 mb-5">
        <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-emerald-500 to-emerald-700 flex items-center justify-center">
          <svg
            class="w-4 h-4 text-white"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z"
            />
          </svg>
        </div>
        <div>
          <h2 class="text-base font-bold text-slate-900">AI Insights</h2>
          <p class="text-xs text-slate-400">Automated recommendations based on your data</p>
        </div>
      </div>

      <div class="grid md:grid-cols-3 gap-4">
        <.insight_card type={:growth} title="Growth">
          Revenue is up 15.3% vs last month. Your Instagram traffic is driving most growth.
        </.insight_card>
        <.insight_card type={:opportunity} title="Opportunity">
          Beaded Choker has high traffic but low conversion. Consider lowering the price or adding customer reviews.
        </.insight_card>
        <.insight_card type={:payments} title="Payments">
          34% of orders are Cash on Delivery. Offering a MoMo discount could improve payment conversion.
        </.insight_card>
      </div>
    </div>
    """
  end

  # ── Components ──

  defp kpi_item(assigns) do
    assigns = assign_new(assigns, :sparkline, fn -> nil end)

    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 lg:px-6 first:lg:pl-0 last:lg:pr-0">
      <p class="text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-1.5">
        {@label}
      </p>
      <p class="text-2xl font-bold text-slate-900 font-mono">{@value}</p>
      <div class="flex items-center gap-2 mt-1.5">
        <span class={[
          "inline-flex items-center gap-0.5 text-xs font-semibold px-1.5 py-0.5 rounded-md",
          if(@trend == :up, do: "text-emerald-600 bg-emerald-50", else: "text-red-600 bg-red-50")
        ]}>
          <svg
            :if={@trend == :up}
            class="w-3 h-3"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M4.5 19.5l15-15m0 0H8.25m11.25 0v11.25"
            />
          </svg>
          <svg
            :if={@trend == :down}
            class="w-3 h-3"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M19.5 4.5l-15 15m0 0h11.25M4.5 19.5V8.25"
            />
          </svg>
          {@change}
        </span>
        <svg
          :if={@sparkline}
          class="w-[30px] h-[14px]"
          viewBox="0 0 30 14"
          fill="none"
        >
          <polyline
            points={@sparkline}
            stroke="#059669"
            stroke-width="1.5"
            fill="none"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </div>
    </div>
    """
  end

  defp channel_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3 text-sm">
      <span class="w-2.5 h-2.5 rounded-full shrink-0" style={"background:#{@color}"}></span>
      <span class="text-slate-700 font-medium flex-1">{@name}</span>
      <span class="font-mono text-slate-500 text-xs">{@visits}</span>
      <span class="font-mono font-semibold text-slate-800 w-10 text-right">{@pct}</span>
      <svg
        :if={@trend == :up}
        class="w-3 h-3 text-emerald-500"
        fill="none"
        stroke="currentColor"
        stroke-width="2.5"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M4.5 19.5l15-15m0 0H8.25m11.25 0v11.25"
        />
      </svg>
      <svg
        :if={@trend == :flat}
        class="w-3 h-3 text-slate-300"
        fill="none"
        stroke="currentColor"
        stroke-width="2.5"
        viewBox="0 0 24 24"
      >
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12h15" />
      </svg>
    </div>
    """
  end

  defp product_bar(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <div class="w-8 h-8 rounded-lg bg-slate-100 shrink-0 flex items-center justify-center">
        <svg
          class="w-4 h-4 text-slate-400"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"
          />
        </svg>
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between mb-1.5">
          <span class="text-sm font-medium text-slate-800 truncate">{@name}</span>
          <span class="text-sm font-bold text-slate-900 font-mono ml-3 shrink-0">{@revenue}</span>
        </div>
        <div class="w-full bg-slate-100 rounded-full h-2.5">
          <div class={[@shade, "h-2.5 rounded-full"]} style={"width: #{@pct}%;"}></div>
        </div>
      </div>
    </div>
    """
  end

  defp payment_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <span class="w-3 h-3 rounded-full shrink-0" style={"background:#{@color};"}></span>
      <span class="text-sm font-medium text-slate-700 flex-1">{@name}</span>
      <span class="text-xs text-emerald-600 font-semibold">{@rate}</span>
      <span class="text-xs text-slate-400 font-mono w-8 text-right">{@count}</span>
      <svg
        :if={@trend == :up}
        class="w-3 h-3 text-emerald-500"
        fill="none"
        stroke="currentColor"
        stroke-width="2.5"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M4.5 19.5l15-15m0 0H8.25m11.25 0v11.25"
        />
      </svg>
      <svg
        :if={@trend == :flat}
        class="w-3 h-3 text-slate-300"
        fill="none"
        stroke="currentColor"
        stroke-width="2.5"
        viewBox="0 0 24 24"
      >
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12h15" />
      </svg>
      <svg
        :if={@trend == :down}
        class="w-3 h-3 text-red-400"
        fill="none"
        stroke="currentColor"
        stroke-width="2.5"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M19.5 4.5l-15 15m0 0h11.25M4.5 19.5V8.25"
        />
      </svg>
    </div>
    """
  end

  defp status_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between text-sm">
      <div class="flex items-center gap-2">
        <span class={["w-2.5 h-2.5 rounded-full", @color]}></span>
        <span class="text-slate-600">{@label}</span>
      </div>
      <div class="flex items-center gap-2">
        <span class="font-mono text-slate-400 text-xs">{@count}</span>
        <span class="font-mono font-semibold text-slate-800">{@pct}</span>
      </div>
    </div>
    """
  end

  defp region_row(assigns) do
    ~H"""
    <tr class={["hover:bg-slate-50 transition-colors", unless(@last, do: "border-b border-slate-50")]}>
      <td class="px-6 py-3.5 text-xs font-semibold text-slate-400">{@rank}</td>
      <td class="px-6 py-3.5"><span class="font-medium text-slate-800">{@name}</span></td>
      <td class="px-6 py-3.5 text-right font-mono text-slate-700">{@orders}</td>
      <td class="px-6 py-3.5 text-right font-mono font-semibold text-slate-900">{@revenue}</td>
      <td class="px-6 py-3.5 text-right font-mono text-slate-600">{@avg_order}</td>
      <td class="px-6 py-3.5 text-right font-mono text-slate-600">{@conv_rate}</td>
      <td class="px-6 py-3.5 text-right">
        <div class="flex items-center justify-end gap-2.5">
          <div class="w-20 bg-slate-100 rounded-full h-1.5">
            <div class={[@bar_shade, "h-1.5 rounded-full"]} style={"width:#{@bar_width}%"}></div>
          </div>
          <span class="font-mono text-slate-600 w-12 text-right text-xs">{@pct_total}</span>
        </div>
      </td>
    </tr>
    """
  end

  defp insight_card(assigns) do
    {border_color, icon_color, label_color, icon_path} =
      case assigns.type do
        :growth ->
          {"border-emerald-500", "text-emerald-600", "text-emerald-700",
           "M2.25 18L9 11.25l4.306 4.307a11.95 11.95 0 015.814-5.519l2.74-1.22m0 0l-5.94-2.28m5.94 2.28l-2.28 5.941"}

        :opportunity ->
          {"border-amber-500", "text-amber-600", "text-amber-700",
           "M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"}

        :payments ->
          {"border-blue-500", "text-blue-600", "text-blue-700",
           "M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z"}
      end

    assigns =
      assigns
      |> assign(:border_color, border_color)
      |> assign(:icon_color, icon_color)
      |> assign(:label_color, label_color)
      |> assign(:icon_path, icon_path)

    ~H"""
    <div class={["p-4 rounded-xl bg-slate-50 border-l-[3px]", @border_color]}>
      <div class="flex items-center gap-1.5 mb-2">
        <svg
          class={["w-3.5 h-3.5", @icon_color]}
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d={@icon_path} />
        </svg>
        <span class={["text-[10px] font-semibold uppercase tracking-wider", @label_color]}>
          {@title}
        </span>
      </div>
      <p class="text-sm text-slate-700 leading-relaxed">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  # ── Data ──

  defp regions do
    [
      %{
        name: "Greater Accra",
        orders: "156",
        revenue: "GH₵ 21,840",
        avg_order: "GH₵ 140",
        conv_rate: "4.8%",
        pct_total: "56.8%",
        bar_width: "56.8",
        bar_shade: "bg-emerald-600"
      },
      %{
        name: "Ashanti",
        orders: "52",
        revenue: "GH₵ 7,280",
        avg_order: "GH₵ 140",
        conv_rate: "3.9%",
        pct_total: "18.9%",
        bar_width: "18.9",
        bar_shade: "bg-emerald-500"
      },
      %{
        name: "Western",
        orders: "28",
        revenue: "GH₵ 3,920",
        avg_order: "GH₵ 140",
        conv_rate: "3.2%",
        pct_total: "10.2%",
        bar_width: "10.2",
        bar_shade: "bg-emerald-400"
      },
      %{
        name: "Eastern",
        orders: "18",
        revenue: "GH₵ 2,520",
        avg_order: "GH₵ 140",
        conv_rate: "2.8%",
        pct_total: "6.5%",
        bar_width: "6.5",
        bar_shade: "bg-emerald-300"
      },
      %{
        name: "Central",
        orders: "15",
        revenue: "GH₵ 1,680",
        avg_order: "GH₵ 112",
        conv_rate: "2.5%",
        pct_total: "4.4%",
        bar_width: "4.4",
        bar_shade: "bg-emerald-200"
      },
      %{
        name: "Others",
        orders: "15",
        revenue: "GH₵ 1,230",
        avg_order: "GH₵ 82",
        conv_rate: "1.8%",
        pct_total: "3.2%",
        bar_width: "3.2",
        bar_shade: "bg-slate-300"
      }
    ]
  end

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp date_range_to_dates("7d"), do: {Date.add(Date.utc_today(), -7), Date.utc_today()}
  defp date_range_to_dates("30d"), do: {Date.add(Date.utc_today(), -30), Date.utc_today()}
  defp date_range_to_dates("90d"), do: {Date.add(Date.utc_today(), -90), Date.utc_today()}

  defp date_range_to_dates("12m"),
    do: {Date.add(Date.utc_today(), -365), Date.utc_today()}

  defp date_range_to_dates(_), do: {Date.add(Date.utc_today(), -30), Date.utc_today()}
end
