defmodule EmakolaWeb.Platform.DashboardLive do
  @moduledoc """
  Platform-level dashboard: aggregate metrics rendered with the shared
  stat tiles, GMV and new-store trend charts (ChartHook), and recent
  stores as Studio-style rows linking into the Directory Studio.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Platform.Stats

  @empty_trend %{labels: [], values: []}

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
          gmv_trend: @empty_trend,
          new_store_trend: @empty_trend,
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
    |> assign(:gmv_trend, Stats.gmv_by_day(30))
    |> assign(:new_store_trend, Stats.new_stores_by_week(8))
    |> assign(:recent_stores_loaded?, true)
    |> assign(:recent_stores_count, length(recent_stores))
    |> stream(:recent_stores, recent_stores, reset: true)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Page header --%>
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900 tracking-tight">Platform Overview</h1>
        <p class="text-sm text-gray-500 mt-1">All stores and merchants across Makola</p>
      </div>

      <%!-- Stat tiles --%>
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
        <.stat_tile label="Total stores" value={@total_stores} icon="storefront" color="blue" />
        <.stat_tile label="Merchants" value={@total_merchants} icon="people" color="indigo" />
        <.stat_tile label="Total orders" value={@total_orders} icon="shopping_bag" color="emerald" />
        <.stat_tile
          label="Platform GMV"
          value={format_gmv(@total_gmv)}
          icon="payments"
          color="amber"
        />
      </div>
      <div class="grid grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
        <.stat_tile
          label="Active products"
          value={@total_products}
          icon="inventory_2"
          color="violet"
        />
        <.stat_tile label="Customers" value={@total_customers} icon="group" color="rose" />
        <.stat_tile label="Active stores" value={@active_stores} icon="check_circle" color="green" />
      </div>

      <%!-- Trend charts --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
        <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <h2 class="text-[13px] font-bold text-gray-900">GMV — last 30 days</h2>
          <div class="h-48 mt-3">
            <canvas
              id="gmv-trend-chart"
              phx-hook="ChartHook"
              phx-update="ignore"
              data-chart-type="gmv-line"
              data-chart-data={Jason.encode!(@gmv_trend)}
            >
            </canvas>
          </div>
        </div>
        <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <h2 class="text-[13px] font-bold text-gray-900">New stores — last 8 weeks</h2>
          <div class="h-48 mt-3">
            <canvas
              id="new-stores-chart"
              phx-hook="ChartHook"
              phx-update="ignore"
              data-chart-type="count-bar"
              data-chart-data={Jason.encode!(@new_store_trend)}
            >
            </canvas>
          </div>
        </div>
      </div>

      <%!-- Recent stores --%>
      <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <div class="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
          <h2 class="text-[15px] font-bold text-gray-900">Recent stores</h2>
          <.link
            :if={Emakola.Accounts.PlatformPermissions.allowed?(@current_user, :manage_stores)}
            navigate="/platform/stores"
            class="text-[13px] text-blue-600 hover:text-blue-700 font-semibold"
          >
            Open Directory Studio &rarr;
          </.link>
        </div>
        <div id="platform-recent-stores" phx-update="stream" class="p-2">
          <div
            :if={!@recent_stores_loaded?}
            id="platform-recent-stores-loading"
            class="px-4 py-10 text-center text-sm text-gray-400"
          >
            Loading stores…
          </div>
          <div
            :if={@recent_stores_loaded? and @recent_stores_count == 0}
            id="platform-recent-stores-empty"
            class="px-4 py-10 text-center text-sm text-gray-400"
          >
            No stores yet.
          </div>
          <div
            :for={{id, store} <- @streams.recent_stores}
            id={id}
            class="flex items-center gap-3 px-3 py-2.5 rounded-[10px] hover:bg-slate-50 transition-colors"
          >
            <.store_avatar store={store} class="w-9 h-9 rounded-[9px] text-[13px]" />
            <div class="min-w-0 flex-1">
              <p class="text-[13.5px] font-semibold text-gray-900 leading-tight truncate">
                {store.name}
              </p>
              <p class="text-[11px] text-gray-400 leading-tight mt-0.5 truncate">
                <span class="font-mono">{store.slug}</span>
                {" · Joined #{Calendar.strftime(store.inserted_at, "%b %d, %Y")}"}
              </p>
            </div>
            <.severity_pill
              label={if Map.get(store, :active, true), do: "Active", else: "Suspended"}
              tone={if Map.get(store, :active, true), do: "green", else: "red"}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_gmv(amount_pesewas) when is_integer(amount_pesewas) do
    "GHS #{div(amount_pesewas, 100)}"
  end

  defp format_gmv(_), do: "GHS 0"
end
