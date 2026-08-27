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
        periods: @periods,
        greeting: DashboardHelpers.greeting_for_hour(DateTime.utc_now().hour),
        merchant_name: merchant_first_name(socket)
      )
      |> assign_setup_checklist()
      |> assign_featuring_checklist()

    socket =
      if connected?(socket) do
        Process.send_after(self(), :refresh, @refresh_interval)
        if store_id, do: Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{store_id}:orders")

        socket
        |> assign(loading: false)
        |> load_dashboard_data()
      else
        # Dead render is a shell: the ~12 dashboard queries run once, on the
        # connected mount, instead of twice per page view.
        socket
        |> assign(DashboardHelpers.default_data())
        |> assign(loading: true)
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

  # First name only — the greeting is a hello, not an address label.
  defp merchant_first_name(socket) do
    case socket.assigns[:current_merchant] do
      %{name: name} when is_binary(name) ->
        name |> to_string() |> String.split(" ", parts: 2) |> List.first()

      _ ->
        nil
    end
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
  # The featuring floor as a to-do list — shown once basic setup is done,
  # so a brand-new merchant sees one list at a time. One store read with
  # the aggregates; the same 90-day quiet rule (with the creation-date
  # grace) the nightly worker applies.
  defp assign_featuring_checklist(socket) do
    case socket.assigns[:current_store] do
      nil ->
        assign(socket, featuring_items: [], featuring_eligible?: false)

      store ->
        loaded =
          Ash.get!(Emakola.Stores.Store, store.id,
            load: [:product_count, :payout_verified, :last_product_published_at, :last_order_at],
            authorize?: false
          )

        active_recently? =
          [loaded.last_product_published_at, loaded.last_order_at, loaded.inserted_at]
          |> Enum.reject(&is_nil/1)
          |> Enum.max(DateTime)
          |> DateTime.diff(DateTime.utc_now(), :day)
          |> Kernel.>=(-90)

        items =
          Emakola.Stores.FeaturingChecklist.items(loaded,
            product_count: loaded.product_count,
            payout_verified?: loaded.payout_verified,
            active_recently?: active_recently?
          )

        assign(socket,
          featuring_items: items,
          featuring_eligible?: Emakola.Stores.FeaturingChecklist.eligible?(items)
        )
    end
  rescue
    exception ->
      Logger.error("[dashboard] featuring checklist raised: #{Exception.message(exception)}")
      assign(socket, featuring_items: [], featuring_eligible?: false)
  end

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
      <.dashboard_header
        period={@period}
        periods={@periods}
        greeting={@greeting}
        merchant_name={@merchant_name}
      />

      <%!-- Setup checklist — auto-hides when all steps are done --%>
      <.setup_checklist :if={@setup_steps != []} steps={@setup_steps} />

      <section
        :if={@featuring_items != [] && @setup_complete?}
        id="featuring-checklist"
        class="rounded-card border border-border bg-surface p-5 sm:p-6"
      >
        <div class="flex items-center justify-between gap-4">
          <div>
            <p class="text-xs font-bold uppercase tracking-[0.14em] text-amber-700">
              Get featured
            </p>
            <h2 class="mt-1 text-lg font-black tracking-tight text-slate-900">
              <%= if @featuring_eligible? do %>
                Your shop can be featured
              <% else %>
                What featuring needs
              <% end %>
            </h2>
          </div>
          <span
            :if={@featuring_eligible?}
            class="inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-3 py-1.5 text-xs font-bold text-emerald-700"
          >
            <.icon name="hero-check-badge-solid" class="size-4" /> Ready
          </span>
        </div>

        <ul class="mt-4 grid gap-2 sm:grid-cols-2">
          <li
            :for={item <- @featuring_items}
            class="flex items-center gap-3 rounded-card bg-slate-50 px-3.5 py-3"
          >
            <span
              :if={item.done?}
              class="flex size-6 shrink-0 items-center justify-center rounded-full bg-success text-white"
            >
              <.icon name="hero-check" class="size-3.5" />
            </span>
            <span
              :if={!item.done?}
              class="size-6 shrink-0 rounded-full border-2 border-slate-300"
            >
            </span>
            <span class={[
              "text-sm font-semibold",
              if(item.done?, do: "text-slate-400 line-through", else: "text-slate-800")
            ]}>
              {item.label}
            </span>
          </li>
        </ul>

        <p class="mt-3 text-xs text-slate-400">
          Featured shops are picked automatically every night from shops that tick every box.
        </p>
      </section>

      <%!-- What needs doing, before any chart --%>
      <.work_queue
        pending_orders={@pending_orders}
        sold_out_count={@sold_out_count}
        open_returns={@open_returns}
      />

      <.kpi_cards
        loading={@loading}
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

      <.best_sellers_panel best_sellers={@best_sellers} />

      <.recent_orders_table recent_orders={@recent_orders} />
    </div>
    """
  end
end
