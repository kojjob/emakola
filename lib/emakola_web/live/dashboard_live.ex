defmodule EmakolaWeb.DashboardLive do
  @moduledoc """
  Merchant admin dashboard -- the main overview page for store owners.

  Displays key metrics, recent orders, top products, low stock alerts,
  and a revenue chart placeholder. All data is scoped to the current store.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Dashboard.Stats
  alias EmakolaWeb.Helpers.Currency

  @refresh_interval 30_000

  def mount(_params, _session, socket) do
    store = socket.assigns[:current_store]
    merchant = socket.assigns[:current_merchant]

    if connected?(socket) && store do
      Process.send_after(self(), :refresh, @refresh_interval)
      Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{store.id}:orders")
    end

    socket =
      socket
      |> assign(active_nav: :dashboard, page_title: "Dashboard")
      |> load_dashboard_data(store, merchant)

    {:ok, socket}
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)
    store = socket.assigns[:current_store]
    merchant = socket.assigns[:current_merchant]
    {:noreply, load_dashboard_data(socket, store, merchant)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  def handle_event("refresh_data", _, socket) do
    store = socket.assigns[:current_store]
    merchant = socket.assigns[:current_merchant]

    {:noreply,
     socket
     |> load_dashboard_data(store, merchant)
     |> put_flash(:info, "Dashboard refreshed")}
  end

  defp load_dashboard_data(socket, nil, _merchant) do
    assign_empty_stats(socket)
  end

  defp load_dashboard_data(socket, store, merchant) do
    stats = Stats.load_stats(store.id)

    merchant_name =
      if merchant do
        merchant.email
        |> to_string()
        |> String.split("@")
        |> List.first()
        |> String.capitalize()
      else
        ""
      end

    assign(socket,
      merchant_name: merchant_name,
      store_name: store.name,
      store_currency: Map.get(store, :currency, "GHS") || "GHS",
      total_revenue: stats.total_revenue,
      order_count: stats.order_count,
      active_products: stats.active_products,
      customer_count: stats.customer_count,
      recent_orders: stats.recent_orders,
      low_stock: stats.low_stock,
      top_products: stats.top_products
    )
  end

  defp assign_empty_stats(socket) do
    assign(socket,
      merchant_name: "",
      store_name: "",
      store_currency: "GHS",
      total_revenue: 0,
      order_count: 0,
      active_products: 0,
      customer_count: 0,
      recent_orders: [],
      low_stock: [],
      top_products: []
    )
  end

  # -- Rendering --

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <%!-- Header --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-slate-900">Dashboard</h1>
          <p class="text-sm text-slate-500 mt-1">
            Welcome back, {@merchant_name}. Here's your store today.
          </p>
        </div>
        <div class="flex gap-2">
          <button
            phx-click="refresh_data"
            class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
          >
            Refresh
          </button>
          <.link
            navigate="/admin/products/new"
            class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
          >
            Add Product
          </.link>
        </div>
      </div>

      <%!-- KPI CARDS --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        <.stat_card
          label="Revenue"
          value={format_revenue(@total_revenue, @store_currency)}
          change="+15.3%"
          change_positive={true}
        />
        <.stat_card
          label="Orders"
          value={format_number(@order_count)}
          change="+8.2%"
          change_positive={true}
        />
        <.stat_card
          label="Products"
          value={format_number(@active_products)}
          change="+3"
          change_positive={true}
        />
        <.stat_card
          label="Customers"
          value={format_number(@customer_count)}
          change="+22.4%"
          change_positive={true}
        />
      </div>

      <%!-- REVENUE CHART + SUMMARY --%>
      <div class="grid xl:grid-cols-3 gap-4">
        <div class="xl:col-span-2 bg-white rounded-2xl border border-slate-200 p-6">
          <div class="flex items-center justify-between mb-6">
            <div>
              <h2 class="text-base font-bold text-slate-900">Revenue Overview</h2>
              <p class="text-xs text-slate-400 mt-0.5">Revenue This Month</p>
            </div>
            <div class="text-right">
              <p class="text-2xl font-bold font-mono text-slate-900">
                {format_revenue(@total_revenue, @store_currency)}
              </p>
            </div>
          </div>
          <div class="relative h-[280px] flex items-center justify-center bg-slate-50 rounded-xl border-2 border-dashed border-slate-200">
            <div class="text-center">
              <p class="text-sm text-slate-400">Revenue chart coming soon</p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-2xl border border-slate-200 p-6">
          <h2 class="text-base font-bold text-slate-900 mb-1">Store Summary</h2>
          <p class="text-xs text-slate-400 mb-6">Key metrics at a glance</p>
          <div class="space-y-4">
            <div class="flex items-center justify-between py-3 border-b border-slate-100">
              <span class="text-sm text-slate-600">Total Revenue</span>
              <span class="font-mono font-semibold text-slate-800">
                {format_revenue(@total_revenue, @store_currency)}
              </span>
            </div>
            <div class="flex items-center justify-between py-3 border-b border-slate-100">
              <span class="text-sm text-slate-600">Orders</span>
              <span class="font-mono font-semibold text-slate-800">
                {format_number(@order_count)}
              </span>
            </div>
            <div class="flex items-center justify-between py-3 border-b border-slate-100">
              <span class="text-sm text-slate-600">Active Products</span>
              <span class="font-mono font-semibold text-slate-800">
                {format_number(@active_products)}
              </span>
            </div>
            <div class="flex items-center justify-between py-3 border-b border-slate-100">
              <span class="text-sm text-slate-600">Customers</span>
              <span class="font-mono font-semibold text-slate-800">
                {format_number(@customer_count)}
              </span>
            </div>
            <div class="flex items-center justify-between py-3">
              <span class="text-sm text-slate-600">Low Stock Items</span>
              <span class={[
                "font-mono font-semibold",
                if(length(@low_stock) > 0, do: "text-red-600", else: "text-slate-800")
              ]}>
                {length(@low_stock)}
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- RECENT ORDERS + TOP PRODUCTS --%>
      <div class="grid xl:grid-cols-3 gap-4">
        <div class="xl:col-span-2 bg-white rounded-2xl border border-slate-200 overflow-hidden">
          <div class="flex items-center justify-between px-6 py-5 border-b border-slate-100">
            <div>
              <h2 class="text-base font-bold text-slate-900">Recent Orders</h2>
              <p class="text-xs text-slate-400 mt-0.5">Latest orders</p>
            </div>
            <.link
              navigate="/admin/orders"
              class="text-xs font-semibold text-emerald-600 hover:text-emerald-700 transition-colors"
            >
              View all
            </.link>
          </div>
          <div class="overflow-x-auto">
            <%= if @recent_orders == [] do %>
              <div class="px-6 py-12 text-center text-slate-400">
                <p class="text-sm font-medium">No orders yet</p>
                <p class="text-xs mt-1 text-slate-400">
                  Orders will appear here once customers start buying
                </p>
              </div>
            <% else %>
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-slate-100">
                    <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                      Order
                    </th>
                    <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                      Customer
                    </th>
                    <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                      Amount
                    </th>
                    <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                      Status
                    </th>
                    <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 hidden md:table-cell">
                      Date
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    :for={order <- @recent_orders}
                    class="border-b border-slate-50 hover:bg-slate-50/50 transition-colors"
                  >
                    <td class="px-6 py-4 font-mono text-xs text-emerald-600 font-medium">
                      {order.order_number}
                    </td>
                    <td class="px-6 py-4 text-slate-700">{customer_name(order)}</td>
                    <td class="px-6 py-4 text-right font-mono font-semibold text-slate-800">
                      {Currency.format_price(order.total, order.currency)}
                    </td>
                    <td class="px-6 py-4"><.status_badge status={order.status} /></td>
                    <td class="px-6 py-4 text-xs text-slate-400 hidden md:table-cell">
                      {format_date(order.inserted_at)}
                    </td>
                  </tr>
                </tbody>
              </table>
            <% end %>
          </div>
        </div>

        <div class="bg-white rounded-2xl border border-slate-200 p-6">
          <div class="flex items-center justify-between mb-6">
            <div>
              <h2 class="text-base font-bold text-slate-900">Top Products</h2>
              <p class="text-xs text-slate-400 mt-0.5">By variant count</p>
            </div>
            <.link
              navigate="/admin/products"
              class="text-xs font-semibold text-emerald-600 hover:text-emerald-700 transition-colors"
            >
              View all
            </.link>
          </div>
          <%= if @top_products == [] do %>
            <div class="py-8 text-center text-slate-400">
              <p class="text-sm">No products yet</p>
            </div>
          <% else %>
            <div class="space-y-3">
              <div
                :for={product <- @top_products}
                class="flex items-center gap-4 p-3 rounded-xl hover:bg-slate-50 transition-colors cursor-pointer group"
              >
                <div class="w-12 h-12 rounded-xl bg-emerald-50 flex items-center justify-center shrink-0 ring-1 ring-slate-200 group-hover:ring-emerald-200 transition-colors">
                  <span class="text-emerald-600 text-lg font-bold">
                    {String.first(product.title)}
                  </span>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="font-semibold text-slate-800 text-sm truncate">{product.title}</p>
                  <p class="text-xs text-slate-400 mt-0.5">
                    {product.variant_count} variant{if product.variant_count != 1, do: "s"}
                  </p>
                </div>
                <p class="font-mono font-bold text-slate-800 text-sm shrink-0">
                  {Currency.format_price_range(product.min_price, product.max_price, @store_currency)}
                </p>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- LOW STOCK ALERTS --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h2 class="text-base font-bold text-slate-900">Low Stock Alerts</h2>
            <p class="text-xs text-slate-400 mt-0.5">Variants below 10 units</p>
          </div>
          <span
            :if={length(@low_stock) > 0}
            class="flex items-center gap-1.5 text-[11px] font-semibold text-red-600"
          >
            {length(@low_stock)} alert{if length(@low_stock) != 1, do: "s"}
          </span>
        </div>
        <%= if @low_stock == [] do %>
          <div class="py-8 text-center text-slate-400">
            <p class="text-sm font-medium text-emerald-600">All stocked up!</p>
            <p class="text-xs mt-1">No variants are running low on inventory</p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-100">
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-4 py-3">
                    Product
                  </th>
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-4 py-3">
                    SKU
                  </th>
                  <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-4 py-3">
                    Stock
                  </th>
                  <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-4 py-3">
                    Action
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={variant <- @low_stock}
                  class="border-b border-slate-50 hover:bg-red-50/30 transition-colors"
                >
                  <td class="px-4 py-3 text-slate-700 font-medium">
                    {variant_product_title(variant)}
                  </td>
                  <td class="px-4 py-3 font-mono text-xs text-slate-500">{variant.sku || "--"}</td>
                  <td class="px-4 py-3 text-right">
                    <span class={[
                      "inline-flex items-center gap-1 font-mono text-xs font-semibold px-2 py-0.5 rounded-full",
                      stock_level_classes(variant.stock_quantity)
                    ]}>
                      {variant.stock_quantity}
                    </span>
                  </td>
                  <td class="px-4 py-3 text-right">
                    <button class="text-xs font-semibold text-emerald-600 hover:text-emerald-700 px-3 py-1.5 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition-colors cursor-pointer">
                      Restock
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # -- Components --

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :change, :string, default: nil
  attr :change_positive, :boolean, default: true

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300 cursor-default">
      <div class="flex items-center justify-between mb-4">
        <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">{@label}</span>
      </div>
      <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">{@value}</p>
      <div :if={@change} class="flex items-center gap-1.5 mt-2">
        <span class={[
          "inline-flex items-center gap-0.5 text-xs font-semibold px-2 py-0.5 rounded-full",
          if(@change_positive, do: "text-emerald-600 bg-emerald-50", else: "text-red-600 bg-red-50")
        ]}>
          {@change}
        </span>
        <span class="text-xs text-slate-400">vs last month</span>
      </div>
    </div>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-full",
      status_classes(@status)
    ]}>
      <span class={["w-1.5 h-1.5 rounded-full", status_dot_class(@status)]}></span>
      {status_label(@status)}
    </span>
    """
  end

  # -- Helpers --

  defp format_revenue(amount, currency) do
    Currency.format_price(amount, currency)
  end

  defp format_number(n) when is_integer(n) and n >= 1_000_000 do
    "#{Float.round(n / 1_000_000, 1)}M"
  end

  defp format_number(n) when is_integer(n) and n >= 1_000 do
    Integer.to_string(n)
    |> String.reverse()
    |> String.replace(~r/(\d{3})/, "\\1,")
    |> String.reverse()
    |> String.trim_leading(",")
  end

  defp format_number(n) when is_integer(n), do: Integer.to_string(n)
  defp format_number(_), do: "0"

  defp format_date(nil), do: "--"
  defp format_date(datetime), do: Calendar.strftime(datetime, "%b %d, %Y")

  defp customer_name(%{customer: %{name: name}}) when is_binary(name) and name != "", do: name
  defp customer_name(%{customer: %{email: email}}) when not is_nil(email), do: to_string(email)
  defp customer_name(_), do: "Guest"

  defp variant_product_title(%{product: %{title: title}}) when is_binary(title), do: title
  defp variant_product_title(_), do: "Unknown product"

  defp status_classes(:pending), do: "text-amber-700 bg-amber-50"
  defp status_classes(:confirmed), do: "text-blue-700 bg-blue-50"
  defp status_classes(:processing), do: "text-blue-700 bg-blue-50"
  defp status_classes(:shipped), do: "text-violet-700 bg-violet-50"
  defp status_classes(:delivered), do: "text-emerald-700 bg-emerald-50"
  defp status_classes(:cancelled), do: "text-red-700 bg-red-50"
  defp status_classes(_), do: "text-slate-700 bg-slate-50"

  defp status_dot_class(:pending), do: "bg-amber-500"
  defp status_dot_class(:confirmed), do: "bg-blue-500"
  defp status_dot_class(:processing), do: "bg-blue-500"
  defp status_dot_class(:shipped), do: "bg-violet-500"
  defp status_dot_class(:delivered), do: "bg-emerald-500"
  defp status_dot_class(:cancelled), do: "bg-red-500"
  defp status_dot_class(_), do: "bg-slate-500"

  defp status_label(:pending), do: "Pending"
  defp status_label(:confirmed), do: "Confirmed"
  defp status_label(:processing), do: "Processing"
  defp status_label(:shipped), do: "Shipping"
  defp status_label(:delivered), do: "Delivered"
  defp status_label(:cancelled), do: "Cancelled"
  defp status_label(s), do: s |> to_string() |> String.capitalize()

  defp stock_level_classes(qty) when qty <= 3, do: "text-red-700 bg-red-100"
  defp stock_level_classes(qty) when qty <= 5, do: "text-amber-700 bg-amber-100"
  defp stock_level_classes(_), do: "text-slate-700 bg-slate-100"
end
