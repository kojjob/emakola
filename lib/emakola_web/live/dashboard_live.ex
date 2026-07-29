defmodule EmakolaWeb.DashboardLive do
  use EmakolaWeb, :live_view

  require Logger

  import EmakolaWeb.DashboardComponents
  import EmakolaWeb.DashboardMetricComponents
  import EmakolaWeb.SetupChecklistComponent

  alias EmakolaWeb.DashboardHelpers
  alias Emakola.Onboarding.SetupChecklist

  # 5-minute safety-net poll. Real-time updates land via PubSub
  # (`{:order_event, event, order}` broadcast by
  # `Emakola.Notifications.Dispatcher`) so this only catches edge cases
  # where a PubSub message was missed (process restart, dropped
  # connection). Was 30s — too aggressive given each refresh fires
  # 12 queries.
  @refresh_interval 300_000
  @periods ~w(today week month all)

  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        active_nav: :dashboard,
        page_title: "Dashboard",
        store_id: store_id,
        period: "week",
        periods: @periods
      )
      |> assign_setup_checklist()

    socket =
      if connected?(socket) do
        Process.send_after(self(), :refresh, @refresh_interval)
        if store_id, do: Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{store_id}:orders")
        load_dashboard_data(socket)
      else
        # Dead render is a shell: the ~12 dashboard queries run once, on the
        # connected mount, instead of twice per page view.
        assign(socket, DashboardHelpers.default_data())
      end

    {:ok, socket}
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, load_dashboard_data(socket)}
  end

  # Must match what Emakola.Notifications.Dispatcher actually broadcasts.
  # This previously matched `{:order_created, _}` / `{:order_updated, _}`,
  # which nothing ever sent — the catch-all below swallowed every real event,
  # so the dashboard silently fell back to the 5-minute poll.
  def handle_info({:order_event, _event, _order}, socket),
    do: {:noreply, load_dashboard_data(socket)}

  def handle_info(_, socket), do: {:noreply, socket}

  def handle_event("change_period", %{"period" => period}, socket) when period in @periods do
    socket = socket |> assign(period: period) |> load_dashboard_data() |> push_chart_events()
    {:noreply, socket}
  end

  def handle_event("change_period", _params, socket), do: {:noreply, socket}

  def handle_event("refresh_data", _, socket) do
    {:noreply,
     socket
     |> load_dashboard_data()
     |> push_chart_events()
     |> put_flash(:info, "Dashboard refreshed")}
  end

  defp load_dashboard_data(socket) do
    store_id = socket.assigns.store_id
    period = socket.assigns.period

    data =
      if store_id do
        try do
          DashboardHelpers.load_merchant_dashboard(store_id, period)
        rescue
          exception ->
            Logger.error(
              "[dashboard_live] dashboard data load raised: #{Exception.message(exception)}"
            )

            DashboardHelpers.default_data()
        end
      else
        DashboardHelpers.default_data()
      end

    assign(socket, data)
  end

  defp push_chart_events(socket) do
    socket
    |> push_event("chart-data:revenue-chart", %{data: socket.assigns.revenue_chart})
    |> push_event("chart-data:orders-chart", %{data: socket.assigns.orders_chart})
    |> push_event("chart-data:customers-chart", %{data: socket.assigns.customers_chart})
    |> push_event("chart-data:top-products-chart", %{data: socket.assigns.top_products_chart})
  end

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  # Computes the merchant setup checklist and assigns it for the
  # dashboard widget. Cheap (two count queries + struct introspection)
  # so we can recompute on every mount without dedicated invalidation.
  defp assign_setup_checklist(socket) do
    case socket.assigns[:current_store] do
      nil ->
        assign(socket, setup_steps: [], setup_complete?: true)

      store ->
        product_count = count_products(store.id)
        delivery_zone_count = count_delivery_zones(store.id)

        steps =
          SetupChecklist.steps(store,
            product_count: product_count,
            delivery_zone_count: delivery_zone_count
          )

        assign(socket,
          setup_steps: steps,
          setup_complete?: Enum.all?(steps, & &1.done?)
        )
    end
  end

  defp count_products(store_id) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store_id, status: :active})
    |> Ash.count!(authorize?: false)
  rescue
    exception ->
      Logger.error("[dashboard_live] count_products raised: #{Exception.message(exception)}")
      0
  end

  defp count_delivery_zones(store_id) do
    Emakola.Shipping.DeliveryZone
    |> Ash.Query.for_read(:list_active_by_store, %{store_id: store_id})
    |> Ash.count!(authorize?: false)
  rescue
    exception ->
      Logger.error(
        "[dashboard_live] count_delivery_zones raised: #{Exception.message(exception)}"
      )

      0
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6 pb-8">
      <.dashboard_header period={@period} periods={@periods} />

      <%!-- Setup checklist — auto-hides when all steps are done --%>
      <.setup_checklist :if={@setup_steps != []} steps={@setup_steps} />

      <.kpi_cards
        total_revenue={@total_revenue}
        revenue_change={@revenue_change}
        order_count={@order_count}
        orders_change={@orders_change}
        customer_count={@customer_count}
        customers_change={@customers_change}
        avg_order_value={@avg_order_value}
        aov_change={@aov_change}
      />

      <section class="grid grid-cols-1 lg:grid-cols-12 gap-6">
        <div class="lg:col-span-8 space-y-6">
          <.chart_card
            id="revenue-chart"
            title="Revenue"
            chart_type="revenue-bar"
            chart_data={@revenue_chart}
          />
          <.chart_card
            id="orders-chart"
            title="Orders"
            chart_type="orders-line"
            chart_data={@orders_chart}
          />
        </div>
        <div class="lg:col-span-4 space-y-6">
          <.alerts_panel
            pending_orders={@pending_orders}
            low_stock_count={@low_stock_count}
            failed_payments={@failed_payments}
          />
          <.chart_card
            id="top-products-chart"
            title="Top Products"
            chart_type="top-products-horizontal"
            chart_data={@top_products_chart}
            height="h-48"
          />
          <.chart_card
            id="customers-chart"
            title="New Customers"
            chart_type="customers-line"
            chart_data={@customers_chart}
            height="h-48"
          />
        </div>
      </section>

      <.recent_orders_table recent_orders={@recent_orders} />
    </div>
    """
  end
end
