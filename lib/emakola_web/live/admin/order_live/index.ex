defmodule EmakolaWeb.Admin.OrderLive.Index do
  @moduledoc """
  Lists all orders for the current store with status filtering, search,
  and mobile-responsive layout matching the Emakola admin orders prototype.
  """
  use EmakolaWeb, :live_view

  require Ash.Query
  require Logger

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

  @statuses [:all, :pending, :confirmed, :processing, :shipped, :delivered, :cancelled]

  # Page window for the orders list; "Load more" grows it by this much.
  @orders_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Orders",
        active_nav: :orders,
        store_id: store_id,
        search_query: "",
        search_form: to_form(%{"search" => ""}),
        status_filter: :all,
        orders: [],
        orders_limit: @orders_per_page,
        more_orders?: false,
        statuses: @statuses,
        scanner_open?: false,
        scan_error: nil
      )
      |> load_orders()
      |> load_order_stats()

    {:ok, socket}
  end

  # -- Scanning a parcel ------------------------------------------------------
  #
  # A merchant holding a parcel should not have to read its order number aloud
  # and type it into search. The camera reads the slip instead.

  @impl true
  def handle_event("open_scanner", _params, socket) do
    {:noreply, assign(socket, scanner_open?: true, scan_error: nil)}
  end

  @impl true
  def handle_event("close_scanner", _params, socket) do
    {:noreply, assign(socket, scanner_open?: false, scan_error: nil)}
  end

  @impl true
  def handle_event("scan_camera_unavailable", _params, socket) do
    {:noreply, assign(socket, scan_error: "No camera. Type the order number instead.")}
  end

  # The decoded string is a claim about an identifier, never a destination. It
  # is resolved by EmakolaWeb.QRScan against the store_id held in assigns — read
  # here at handle-event time, never taken from the payload — so a sticker on a
  # parcel cannot steer this session anywhere. A code for another store's order
  # is reported exactly like an unreadable one, which is what keeps the scanner
  # from being usable to probe the platform.
  @impl true
  def handle_event("qr_scanned", %{"value" => value}, socket) do
    case EmakolaWeb.QRScan.resolve_order(value, socket.assigns.store_id) do
      {:ok, order} ->
        {:noreply, push_navigate(socket, to: ~p"/admin/orders/#{order.id}")}

      {:error, _reason} ->
        {:noreply,
         assign(socket,
           scanner_open?: false,
           scan_error: "No order here matches that code."
         )}
    end
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    socket =
      socket
      |> assign(
        search_query: query,
        search_form: to_form(%{"search" => query}),
        orders_limit: @orders_per_page
      )
      |> load_orders()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom =
      case status do
        "all" -> :all
        "pending" -> :pending
        "confirmed" -> :confirmed
        "processing" -> :processing
        "shipped" -> :shipped
        "delivered" -> :delivered
        "cancelled" -> :cancelled
        _ -> :all
      end

    socket =
      socket
      |> assign(status_filter: status_atom, orders_limit: @orders_per_page)
      |> load_orders()

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more_orders", _params, socket) do
    {:noreply,
     socket
     |> assign(orders_limit: socket.assigns.orders_limit + @orders_per_page)
     |> load_orders()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header
        icon="hero-shopping-bag"
        title="Orders"
        subtitle="Manage and track all customer orders"
      />

      <%!-- Find an order by pointing at its parcel. Sits above search because
            it is the path that needs no reading at all. --%>
      <div>
        <.admin_button
          :if={!@scanner_open?}
          id="scan-order-open"
          variant={:secondary}
          phx-click="open_scanner"
        >
          <.icon name="hero-qr-code" class="size-4" /> Scan a parcel
        </.admin_button>

        <.admin_card :if={@scanner_open?} id="order-scanner-card">
          <div class="flex flex-col sm:flex-row items-center gap-5">
            <div
              id="order-scanner"
              phx-hook="QRScanner"
              data-decoder-url={~p"/assets/js/qr_decoder.js"}
              class="w-56 h-56 shrink-0 rounded-card overflow-hidden bg-slate-900"
            >
              <video class="w-full h-full object-cover" muted playsinline></video>
            </div>
            <div class="min-w-0 text-center sm:text-left">
              <h3 class="text-base font-bold text-slate-900">Point at the parcel</h3>
              <p class="text-sm text-slate-600 mt-1">
                Hold the code in the box. The order opens by itself.
              </p>
              <p :if={@scan_error} class="text-sm text-danger mt-2">{@scan_error}</p>
              <.admin_button variant={:secondary} size={:sm} class="mt-4" phx-click="close_scanner">
                Stop
              </.admin_button>
            </div>
          </div>
        </.admin_card>

        <p :if={@scan_error && !@scanner_open?} id="scan-error" class="text-sm text-danger mt-2">
          {@scan_error}
        </p>
      </div>

      <%!-- KPI tiles (store-wide, independent of search/filter) --%>
      <div id="order-stats" class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div id="stat-orders-today">
          <.stat_card label="Orders today" value={to_string(@order_stats.today)} tone={:info}>
            <:icon><.icon name="hero-shopping-bag" class="size-7" /></:icon>
          </.stat_card>
        </div>
        <div id="stat-orders-pending">
          <.stat_card
            label="Pending"
            value={to_string(@order_stats.status_counts.pending)}
            tone={:warning}
          >
            <:icon><.icon name="hero-clock" class="size-7" /></:icon>
          </.stat_card>
        </div>
        <div id="stat-orders-revenue">
          <.stat_card
            label="Revenue (7 days)"
            value={format_price(@order_stats.revenue_7d, "GHS")}
            tone={:primary}
          >
            <:icon><.icon name="hero-banknotes" class="size-7" /></:icon>
          </.stat_card>
        </div>
        <div id="stat-orders-delivered">
          <.stat_card
            label="Delivered (30 days)"
            value={to_string(@order_stats.delivered_30d)}
            tone={:primary}
          >
            <:icon><.icon name="hero-check-circle" class="size-7" /></:icon>
          </.stat_card>
        </div>
      </div>

      <%!-- Status Filter Tabs --%>
      <div class="flex flex-wrap items-center gap-3">
        <.filter_tabs
          id="orders-filter-tabs"
          current={@status_filter}
          tabs={
            Enum.map(@statuses, fn status ->
              %{key: status, label: status_label(status), count: tab_count(@order_stats, status)}
            end)
          }
        />

        <%!-- Search --%>
        <.form
          for={@search_form}
          id="order-search-form"
          phx-change="search"
          class="relative flex-1 min-w-[200px] max-w-xs"
        >
          <svg
            class="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
            />
          </svg>
          <.input
            field={@search_form[:search]}
            type="search"
            value={@search_query}
            placeholder="Search orders..."
            phx-debounce="300"
            class="w-full pl-9 pr-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-700
                   placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/30
                   focus:border-emerald-500 transition-all"
            autocomplete="off"
          />
        </.form>
      </div>

      <%!-- Orders --%>
      <%= if @orders == [] do %>
        <%!-- A merchant who has never had an order needs directions; one whose
              filter matched nothing needs to know the filter is why. --%>
        <.empty_state
          :if={@search_query != "" or @status_filter != :all}
          icon="hero-shopping-bag"
          title="No orders found"
          description="Try adjusting your search or filters"
        />
        <%!-- The share opens WhatsApp with the merchant's own store link
              already in the message — how these merchants actually send a
              shop to a customer. --%>
        <.empty_state
          :if={@search_query == "" and @status_filter == :all}
          icon="hero-shopping-bag"
          tone={:accent}
          title="Your orders will show here"
          description="Share your store to get the first one"
          action_label="Share on WhatsApp"
          action_icon="hero-chat-bubble-oval-left-ellipsis"
          action_path={whatsapp_store_share_url(@current_store)}
          external
        />
      <% else %>
        <%!-- One responsive list of rows a merchant can act on: waiting
              orders carry the amber edge and the page's only loud button;
              everything else is a quiet status chip. --%>
        <.admin_card padding={:none} class="overflow-hidden">
          <div class="divide-y divide-slate-50">
            <div
              :for={order <- @orders}
              id={"order-row-#{order.id}"}
              class={[
                "flex items-center gap-3.5 px-4 py-3.5 sm:px-5 transition-colors hover:bg-slate-50/60",
                order.status == :pending && "shadow-[inset_4px_0_0_theme(colors.amber.500)]"
              ]}
            >
              <div class="flex size-10 shrink-0 items-center justify-center rounded-full bg-primary-soft text-xs font-bold text-emerald-700">
                {order_initials(order)}
              </div>
              <.link navigate={~p"/admin/orders/#{order.id}"} class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">{customer_name(order)}</p>
                <p class="truncate font-mono text-[11px] text-slate-400">
                  {order.order_number} · {format_date(order.inserted_at)}
                </p>
              </.link>
              <p class="shrink-0 text-[15px] font-extrabold text-slate-900 tabular-nums">
                {format_price(order.total, order.currency)}
              </p>
              <.link
                :if={order.status == :pending}
                navigate={~p"/admin/orders/#{order.id}"}
                class="inline-flex shrink-0 items-center gap-1.5 rounded-control bg-primary px-4 py-2 text-xs font-bold text-white shadow-sm shadow-emerald-600/25 transition-colors hover:bg-primary-hover"
              >
                Send it <.icon name="hero-arrow-right" class="size-3" />
              </.link>
              <%!-- Supplier state, icon-first. A merchant scanning forty rows
                    should see a red clock without reading a word — the label
                    is there for whoever wants it, not carrying the meaning on
                    its own. --%>
              <span
                :if={order.supplier_alert}
                class={[
                  "inline-flex shrink-0 items-center gap-1 rounded-full px-2 py-1 text-[11px] font-bold",
                  supplier_alert_classes(order.supplier_alert)
                ]}
                title={supplier_alert_label(order.supplier_alert)}
              >
                <.icon name={supplier_alert_icon(order.supplier_alert)} class="size-3.5" />
                <span class="hidden sm:inline">{supplier_alert_label(order.supplier_alert)}</span>
              </span>
              <.status_badge :if={order.status != :pending} status={order.status} variant={:order} />
            </div>
          </div>
        </.admin_card>

        <%!-- The list is a window, not the whole table. Without this the page
        simply stopped at the limit with no hint that older orders existed. --%>
        <div :if={@more_orders?} class="mt-4 flex flex-col items-center gap-2">
          <p class="text-xs text-slate-500">
            Showing the {length(@orders)} most recent orders.
          </p>
          <.admin_button
            id="load-more-orders"
            variant={:secondary}
            phx-click="load_more_orders"
            phx-disable-with="Loading..."
          >
            Load more orders
          </.admin_button>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Data Loading ──

  defp load_orders(socket) do
    %{store_id: store_id, search_query: query, status_filter: status} = socket.assigns
    limit = socket.assigns[:orders_limit] || @orders_per_page

    orders =
      try do
        status_arg = if status != :all, do: status, else: nil
        search_arg = if query != "", do: query, else: nil

        Emakola.Orders.Order
        |> Ash.Query.for_read(:list_admin, %{
          store_id: store_id,
          status: status_arg,
          search: search_arg
        })
        |> Ash.Query.limit(limit + 1)
        |> Ash.Query.load(:supplier_alert)
        |> Ash.read!(authorize?: false)
      rescue
        exception ->
          Logger.error(
            "[order_live.index] load_orders loading orders raised: #{Exception.message(exception)}"
          )

          []
      end

    # One row beyond the window is fetched purely to answer "is there more?"
    # without a second COUNT query.
    {orders, more?} =
      if length(orders) > limit, do: {Enum.take(orders, limit), true}, else: {orders, false}

    assign(socket, orders: orders, orders_limit: limit, more_orders?: more?)
  end

  # Store-wide KPI numbers and per-status counts. Deliberately independent
  # of the search/filter so the tiles and tab chips stay stable while the
  # list narrows.
  defp load_order_stats(%{assigns: %{store_id: nil}} = socket) do
    assign(socket, order_stats: empty_order_stats())
  end

  defp load_order_stats(socket) do
    store_id = socket.assigns.store_id
    now = DateTime.utc_now()
    start_of_today = %{now | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}
    seven_days_ago = DateTime.add(now, -7, :day)
    thirty_days_ago = DateTime.add(now, -30, :day)

    status_counts =
      Map.new(@statuses -- [:all], fn status ->
        {status, count_orders(store_id, status: status)}
      end)

    revenue_7d =
      admin_orders_query(store_id)
      |> Ash.Query.filter(
        inserted_at >= ^seven_days_ago and status not in [:cancelled, :refunded]
      )
      |> Ash.sum(:total, authorize?: false)
      |> case do
        {:ok, sum} when is_integer(sum) -> sum
        _ -> 0
      end

    assign(socket,
      order_stats: %{
        status_counts: status_counts,
        all: status_counts |> Map.values() |> Enum.sum(),
        today: count_orders(store_id, inserted_after: start_of_today),
        revenue_7d: revenue_7d,
        delivered_30d: count_orders(store_id, status: :delivered, inserted_after: thirty_days_ago)
      }
    )
  rescue
    exception ->
      Logger.error("[order_live.index] load_order_stats raised: #{Exception.message(exception)}")

      assign(socket, order_stats: empty_order_stats())
  end

  defp empty_order_stats do
    %{
      status_counts: Map.new(@statuses -- [:all], &{&1, 0}),
      all: 0,
      today: 0,
      revenue_7d: 0,
      delivered_30d: 0
    }
  end

  defp count_orders(store_id, opts) do
    query = admin_orders_query(store_id)

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        status -> Ash.Query.filter(query, status == ^status)
      end

    query =
      case Keyword.get(opts, :inserted_after) do
        nil -> query
        cutoff -> Ash.Query.filter(query, inserted_at >= ^cutoff)
      end

    case Ash.count(query, authorize?: false) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp admin_orders_query(store_id) do
    Ash.Query.for_read(Emakola.Orders.Order, :list_admin, %{
      store_id: store_id,
      status: nil,
      search: nil
    })
  end

  defp tab_count(order_stats, :all), do: order_stats.all
  defp tab_count(order_stats, status), do: Map.get(order_stats.status_counts, status, 0)

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  # wa.me with no number opens WhatsApp's own share sheet, so the merchant
  # picks the recipient. Falls back to a bare share when the store has not
  # resolved (the page still renders for a merchant mid-onboarding).
  defp whatsapp_store_share_url(%{slug: slug, name: name}) when is_binary(slug) do
    EmakolaWeb.StorefrontComponents.whatsapp_share_url(
      "#{EmakolaWeb.Endpoint.url()}#{EmakolaWeb.Storefront.Path.store_path(slug, "/")}",
      "Shop #{name} on Makola"
    )
  end

  defp whatsapp_store_share_url(_store), do: "https://wa.me/?text="

  defp status_label(:all), do: "All"
  defp status_label(:pending), do: "Pending"

  defp status_label(:confirmed), do: "Confirmed"
  defp status_label(:processing), do: "Processing"
  defp status_label(:shipped), do: "Shipped"
  defp status_label(:delivered), do: "Delivered"
  defp status_label(:cancelled), do: "Cancelled"

  defp format_date(nil), do: ""

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y")
  end

  defp format_date(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y")
  end

  defp format_date(_), do: ""

  defp customer_name(%{customer: %{name: name}}) when is_binary(name), do: name
  defp customer_name(_), do: "Unknown"

  # Colour and icon are the signal; the words repeat it for whoever reads. Red
  # for "you must act", amber for "still waiting", green for "handled".
  defp supplier_alert_classes(:blocked), do: "bg-danger-soft text-danger"
  defp supplier_alert_classes(:unreachable), do: "bg-danger-soft text-danger"
  defp supplier_alert_classes(:waiting), do: "bg-warning-soft text-warning"
  defp supplier_alert_classes(:accepted), do: "bg-success-soft text-success"
  defp supplier_alert_classes(_other), do: "bg-slate-100 text-slate-600"

  defp supplier_alert_icon(:blocked), do: "hero-exclamation-triangle"
  defp supplier_alert_icon(:unreachable), do: "hero-signal-slash"
  defp supplier_alert_icon(:waiting), do: "hero-clock"
  defp supplier_alert_icon(:accepted), do: "hero-check-circle"
  defp supplier_alert_icon(_other), do: "hero-truck"

  # Under the eight-word ceiling, and each says what to do rather than what
  # state a record is in.
  defp supplier_alert_label(:blocked), do: "Supplier failed"
  defp supplier_alert_label(:unreachable), do: "Not delivered"
  defp supplier_alert_label(:waiting), do: "No reply"
  defp supplier_alert_label(:accepted), do: "Supplier has it"
  defp supplier_alert_label(_other), do: "Supplier"

  defp order_initials(order) do
    order
    |> customer_name()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
    |> case do
      "" -> "?"
      initials -> initials
    end
  end
end
