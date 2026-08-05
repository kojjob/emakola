defmodule EmakolaWeb.Platform.DashboardLive do
  @moduledoc "Platform-level dashboard showing aggregate metrics across all stores."
  use EmakolaWeb, :live_view

  alias Emakola.Platform.Stats

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Platform Dashboard")
      |> assign(:active_nav, :dashboard)
      |> stream(:recent_stores, [])

    # No DB queries in disconnected mount — render a loading shell first.
    socket =
      if connected?(socket) do
        load_stats(socket)
      else
        assign(socket,
          total_stores: 0,
          active_stores: 0,
          total_merchants: 0,
          total_orders: 0,
          total_gmv: 0,
          total_products: 0,
          total_customers: 0,
          recent_stores_loaded?: false,
          recent_stores_count: 0
        )
      end

    {:ok, socket}
  end

  defp load_stats(socket) do
    recent_stores = Stats.recent_stores(8)

    socket
    |> assign(:total_stores, Stats.total_stores())
    |> assign(:active_stores, Stats.active_stores())
    |> assign(:total_merchants, Stats.total_merchants())
    |> assign(:total_orders, Stats.total_orders())
    |> assign(:total_gmv, Stats.total_gmv())
    |> assign(:total_products, Stats.total_products())
    |> assign(:total_customers, Stats.total_customers())
    |> assign(:recent_stores_loaded?, true)
    |> assign(:recent_stores_count, length(recent_stores))
    |> stream(:recent_stores, recent_stores, reset: true)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Page header --%>
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-gray-900">Platform Overview</h1>
        <p class="text-sm text-gray-500 mt-1">All stores and merchants across Makola</p>
      </div>

      <%!-- Metric cards — row 1 --%>
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
        <.metric_card label="Total Stores" value={@total_stores} icon="storefront" color="blue" />
        <.metric_card label="Merchants" value={@total_merchants} icon="people" color="indigo" />
        <.metric_card label="Total Orders" value={@total_orders} icon="shopping_bag" color="emerald" />
        <.metric_card
          label="Platform GMV"
          value={format_gmv(@total_gmv)}
          icon="payments"
          color="amber"
        />
      </div>

      <%!-- Metric cards — row 2 --%>
      <div class="grid grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
        <.metric_card
          label="Active Products"
          value={@total_products}
          icon="inventory_2"
          color="violet"
        />
        <.metric_card label="Customers" value={@total_customers} icon="group" color="rose" />
        <.metric_card label="Active Stores" value={@active_stores} icon="check_circle" color="green" />
      </div>

      <%!-- Recent stores table --%>
      <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <h2 class="text-lg font-semibold text-gray-900">Recent Stores</h2>
          <.link
            :if={Emakola.Accounts.PlatformPermissions.allowed?(@current_user, :manage_stores)}
            navigate="/platform/stores"
            class="text-sm text-blue-600 hover:text-blue-700 font-medium"
          >
            View all &rarr;
          </.link>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                <th class="px-6 py-3">Store</th>
                <th class="px-6 py-3">Slug</th>
                <th class="px-6 py-3">Status</th>
                <th class="px-6 py-3">Created</th>
              </tr>
            </thead>
            <tbody id="platform-recent-stores" phx-update="stream" class="divide-y divide-gray-100">
              <tr :if={!@recent_stores_loaded?} id="platform-recent-stores-loading">
                <td colspan="4" class="px-6 py-12 text-center text-sm text-gray-400">
                  Loading stores…
                </td>
              </tr>
              <tr
                :if={@recent_stores_loaded? and @recent_stores_count == 0}
                id="platform-recent-stores-empty"
              >
                <td colspan="4" class="px-6 py-12 text-center text-sm text-gray-400">
                  No stores yet.
                </td>
              </tr>
              <tr
                :for={{id, store} <- @streams.recent_stores}
                id={id}
                class="hover:bg-gray-50 transition-colors"
              >
                <td class="px-6 py-4">
                  <div class="flex items-center gap-3">
                    <div class="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 text-sm font-bold shrink-0">
                      {store.name |> String.first() |> String.upcase()}
                    </div>
                    <span class="font-medium text-gray-900">{store.name}</span>
                  </div>
                </td>
                <td class="px-6 py-4 text-sm text-gray-500 font-mono">{store.slug}</td>
                <td class="px-6 py-4">
                  <span class={[
                    "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                    if(Map.get(store, :active, true),
                      do: "bg-green-100 text-green-700",
                      else: "bg-red-100 text-red-700"
                    )
                  ]}>
                    {if(Map.get(store, :active, true), do: "Active", else: "Suspended")}
                  </span>
                </td>
                <td class="px-6 py-4 text-sm text-gray-500">
                  {Calendar.strftime(store.inserted_at, "%b %d, %Y")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  # -- Private components --

  defp metric_card(assigns) do
    color_classes = %{
      "blue" => "bg-blue-50 text-blue-600",
      "indigo" => "bg-indigo-50 text-indigo-600",
      "emerald" => "bg-emerald-50 text-emerald-600",
      "amber" => "bg-amber-50 text-amber-600",
      "violet" => "bg-violet-50 text-violet-600",
      "rose" => "bg-rose-50 text-rose-600",
      "green" => "bg-green-50 text-green-600"
    }

    assigns =
      assign(
        assigns,
        :color_class,
        Map.get(color_classes, assigns.color, "bg-gray-50 text-gray-600")
      )

    ~H"""
    <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-gray-500">{@label}</span>
        <span class={["flex h-9 w-9 items-center justify-center rounded-xl", @color_class]}>
          <span class="material-symbols-outlined text-[20px]">{@icon}</span>
        </span>
      </div>
      <p class="mt-3 text-3xl font-bold text-gray-900 tabular-nums">{@value}</p>
    </div>
    """
  end

  defp format_gmv(amount_pesewas) when is_integer(amount_pesewas) do
    "GHS #{div(amount_pesewas, 100)}"
  end

  defp format_gmv(_), do: "GHS 0"
end
