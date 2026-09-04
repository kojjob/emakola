defmodule EmakolaWeb.Admin.OrderLive.Index do
  @moduledoc """
  `/admin/orders` — the work first.

  The page opens on what needs doing: every waiting order is a card with
  the product photo, the customer, how they paid, WhatsApp one tap away, the
  money largest, and one Send it. Everything else is a quiet picture list
  under On the way and Done. A status tab or a search narrows the page to
  one flat list instead (design/orders-redesign, A · Do these now, chosen
  2026-09-04).
  """
  use EmakolaWeb, :live_view

  require Ash.Query
  require Logger

  import EmakolaWeb.Admin.OrderLive.IndexComponents
  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

  alias EmakolaWeb.Admin.OrderLive.Rails

  @statuses [:all, :pending, :confirmed, :processing, :shipped, :delivered, :cancelled]
  @on_the_way [:confirmed, :processing, :shipped]

  # Page window for the orders list; "Load more" grows it by this much.
  @orders_per_page 50

  # Every waiting order is work, however old, so the work list is not a
  # window of recent orders; it is capped only so a runaway backlog cannot
  # render a thousand cards.
  @work_orders_cap 100

  # What a row needs to say what was bought: the first line item's product
  # photo.
  @order_loads [:supplier_alert, line_items: [variant: [product: [:images]]]]

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
        work_orders: [],
        # Payment rail per order id, for the chip a merchant knows by colour.
        rails: %{},
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
    status_atom = Emakola.SafeAtom.to_atom_in(status, @statuses, :all)

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
    grouped? = assigns.status_filter == :all and assigns.search_query == ""

    assigns =
      assign(assigns,
        grouped?: grouped?,
        on_the_way: Enum.filter(assigns.orders, &(&1.status in @on_the_way)),
        done: Enum.filter(assigns.orders, &(&1.status == :delivered)),
        cancelled: Enum.filter(assigns.orders, &(&1.status == :cancelled))
      )

    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header
        icon="hero-shopping-bag"
        title="Orders"
        subtitle={header_subtitle(@order_stats.waiting)}
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

      <%!-- Store-wide tiles: what is waiting, what is on the way, today's
            money, the week's done. A phone shows the two that matter now. --%>
      <div id="order-stats" class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <.stat_card
          id="stat-orders-waiting"
          label="Waiting"
          value={to_string(@order_stats.waiting)}
          tone={:warning}
        >
          <:icon><.icon name="hero-clock" class="size-7" /></:icon>
        </.stat_card>
        <div class="hidden lg:block">
          <.stat_card
            id="stat-orders-on-the-way"
            label="On the way"
            value={to_string(@order_stats.on_the_way)}
            tone={:info}
          >
            <:icon><.icon name="hero-truck" class="size-7" /></:icon>
          </.stat_card>
        </div>
        <.stat_card
          id="stat-orders-money-today"
          label="Money today"
          value={format_price(@order_stats.money_today, "GHS")}
          tone={:success}
        >
          <:icon><.icon name="hero-banknotes" class="size-7" /></:icon>
        </.stat_card>
        <div class="hidden lg:block">
          <.stat_card
            id="stat-orders-done"
            label="Done this week"
            value={to_string(@order_stats.done_7d)}
            tone={:success}
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
      <%= if @orders == [] and @work_orders == [] do %>
        <%!-- A merchant who has never had an order needs directions; one whose
              filter matched nothing needs to know the filter is why. --%>
        <.empty_state
          :if={!@grouped?}
          icon="hero-shopping-bag"
          title="No orders found"
          description="Try adjusting your search or filters"
        />
        <%!-- The share opens WhatsApp with the merchant's own store link
              already in the message — how these merchants actually send a
              shop to a customer. --%>
        <.empty_state
          :if={@grouped?}
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
        <%!-- The work first: every waiting order as a card with one button. --%>
        <section :if={@grouped? and @work_orders != []} id="do-these-now" class="space-y-3">
          <.section_eyebrow>Do these now</.section_eyebrow>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
            <.work_card :for={order <- @work_orders} order={order} rail={@rails[order.id]} />
          </div>
        </section>

        <%!-- Then everything else, quietly, by where it is. --%>
        <div :if={@grouped?} class="grid grid-cols-1 lg:grid-cols-2 gap-4 items-start">
          <section :if={@on_the_way != []} id="on-the-way" class="space-y-3">
            <.section_eyebrow>On the way</.section_eyebrow>
            <.admin_card padding={:none} class="overflow-hidden">
              <div class="divide-y divide-slate-50">
                <.order_row :for={order <- @on_the_way} order={order} rail={@rails[order.id]} />
              </div>
            </.admin_card>
          </section>
          <section :if={@done != []} id="done" class="space-y-3">
            <.section_eyebrow>Done</.section_eyebrow>
            <.admin_card padding={:none} class="overflow-hidden">
              <div class="divide-y divide-slate-50">
                <.order_row :for={order <- @done} order={order} rail={@rails[order.id]} />
              </div>
            </.admin_card>
          </section>
        </div>
        <section :if={@grouped? and @cancelled != []} id="cancelled" class="space-y-3">
          <.section_eyebrow>Cancelled</.section_eyebrow>
          <.admin_card padding={:none} class="overflow-hidden">
            <div class="divide-y divide-slate-50">
              <.order_row :for={order <- @cancelled} order={order} rail={@rails[order.id]} />
            </div>
          </.admin_card>
        </section>

        <%!-- A tab or a search: one flat list of what matched. --%>
        <.admin_card :if={!@grouped?} padding={:none} class="overflow-hidden">
          <div class="divide-y divide-slate-50">
            <.order_row :for={order <- @orders} order={order} rail={@rails[order.id]} />
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

  slot :inner_block, required: true

  defp section_eyebrow(assigns) do
    ~H"""
    <p class="px-0.5 text-xs font-extrabold uppercase tracking-[0.12em] text-slate-400">
      {render_slot(@inner_block)}
    </p>
    """
  end

  # ── Data Loading ──

  defp load_orders(socket) do
    %{store_id: store_id, search_query: query, status_filter: status} = socket.assigns
    limit = socket.assigns[:orders_limit] || @orders_per_page
    grouped? = status == :all and query == ""

    orders =
      read_orders(store_id, status: status, search: query, limit: limit + 1)

    # One row beyond the window is fetched purely to answer "is there more?"
    # without a second COUNT query.
    {orders, more?} =
      if length(orders) > limit, do: {Enum.take(orders, limit), true}, else: {orders, false}

    # On the grouped page the waiting orders come from their own query, so
    # the window holds only the rest.
    {work_orders, orders} =
      if grouped? do
        {read_orders(store_id, status: :pending, search: "", limit: @work_orders_cap),
         Enum.reject(orders, &(&1.status == :pending))}
      else
        {[], orders}
      end

    assign(socket,
      orders: orders,
      work_orders: work_orders,
      rails: load_rails(work_orders ++ orders),
      orders_limit: limit,
      more_orders?: more?
    )
  end

  defp read_orders(store_id, opts) do
    status = Keyword.fetch!(opts, :status)
    search = Keyword.fetch!(opts, :search)

    Emakola.Orders.Order
    |> Ash.Query.for_read(:list_admin, %{
      store_id: store_id,
      status: if(status != :all, do: status, else: nil),
      search: if(search != "", do: search, else: nil)
    })
    |> Ash.Query.limit(Keyword.fetch!(opts, :limit))
    |> Ash.Query.load(@order_loads)
    |> Ash.read!(authorize?: false)
  rescue
    exception ->
      Logger.error(
        "[order_live.index] read_orders loading orders raised: #{Exception.message(exception)}"
      )

      []
  end

  # One query for every successful payment on the page, keyed by order, so
  # fifty rows do not become fifty lookups.
  defp load_rails([]), do: %{}

  defp load_rails(orders) do
    ids = Enum.map(orders, & &1.id)

    Emakola.Payments.Payment
    |> Ash.Query.filter(order_id in ^ids and status == :success)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.order_id, Rails.for_payment(&1)})
  rescue
    exception ->
      Logger.error("[order_live.index] load_rails raised: #{Exception.message(exception)}")
      %{}
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

    status_counts =
      Map.new(@statuses -- [:all], fn status ->
        {status, count_orders(store_id, status: status)}
      end)

    money_today =
      admin_orders_query(store_id)
      |> Ash.Query.filter(inserted_at >= ^start_of_today and status != :cancelled)
      |> Ash.sum(:total, authorize?: false)
      |> case do
        {:ok, sum} when is_integer(sum) -> sum
        _ -> 0
      end

    assign(socket,
      order_stats: %{
        status_counts: status_counts,
        all: status_counts |> Map.values() |> Enum.sum(),
        waiting: Map.get(status_counts, :pending, 0),
        on_the_way: @on_the_way |> Enum.map(&Map.get(status_counts, &1, 0)) |> Enum.sum(),
        money_today: money_today,
        done_7d: count_orders(store_id, status: :delivered, inserted_after: seven_days_ago)
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
      waiting: 0,
      on_the_way: 0,
      money_today: 0,
      done_7d: 0
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

  # The subtitle counts the work while there is any.
  defp header_subtitle(0), do: "Manage and track all customer orders"
  defp header_subtitle(1), do: "1 waiting for you"
  defp header_subtitle(count), do: "#{count} waiting for you"

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
end
