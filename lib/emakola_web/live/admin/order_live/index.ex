defmodule EmakolaWeb.Admin.OrderLive.Index do
  @moduledoc """
  Lists all orders for the current store with status filtering, search,
  and mobile-responsive layout matching the Emakola admin orders prototype.
  """
  use EmakolaWeb, :live_view

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
        statuses: @statuses
      )
      |> load_orders()

    {:ok, socket}
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
      <.admin_page_header title="Orders" subtitle="Manage and track all customer orders" />

      <%!-- Status Filter Tabs --%>
      <div class="flex flex-wrap items-center gap-3">
        <div class="flex gap-1 bg-slate-100 rounded-control p-1 overflow-x-auto">
          <.status_tab :for={status <- @statuses} status={status} current={@status_filter} />
        </div>

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
        <.empty_state
          icon="hero-shopping-bag"
          title="No orders found"
          description={
            if @search_query != "" or @status_filter != :all,
              do: "Try adjusting your search or filters",
              else: "Orders will appear here when customers place them"
          }
        />
      <% else %>
        <%!-- Desktop Table --%>
        <.admin_card padding={:none} class="hidden md:block overflow-hidden">
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-200 bg-slate-50/50">
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Order ID
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Date
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Customer
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Total
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-4 py-3.5 w-12"><span class="sr-only">Actions</span></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr
                  :for={order <- @orders}
                  class="hover:bg-slate-50 transition-colors"
                >
                  <td class="px-4 py-3.5">
                    <.link
                      navigate={~p"/admin/orders/#{order.id}"}
                      class="font-mono text-xs font-medium text-primary hover:text-primary-hover"
                    >
                      {order.order_number}
                    </.link>
                  </td>
                  <td class="px-4 py-3.5 text-slate-500 whitespace-nowrap">
                    {format_date(order.inserted_at)}
                  </td>
                  <td class="px-4 py-3.5">
                    <div class="min-w-0">
                      <p class="text-sm font-medium text-slate-800 truncate">
                        {customer_name(order)}
                      </p>
                      <p class="text-xs text-slate-400 truncate">
                        {customer_email(order)}
                      </p>
                    </div>
                  </td>
                  <td class="px-4 py-3.5 font-mono text-sm font-medium text-slate-800">
                    {format_price(order.total, order.currency)}
                  </td>
                  <td class="px-4 py-3.5">
                    <.status_badge status={order.status} variant={:order} />
                  </td>
                  <td class="px-4 py-3.5">
                    <.link
                      navigate={~p"/admin/orders/#{order.id}"}
                      class="p-1.5 rounded-lg hover:bg-slate-100 transition-colors inline-block"
                      aria-label={"View order #{order.order_number}"}
                    >
                      <svg
                        class="w-4 h-4 text-slate-400"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M8.25 4.5l7.5 7.5-7.5 7.5"
                        />
                      </svg>
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </.admin_card>

        <%!-- Mobile Cards --%>
        <div class="md:hidden space-y-3">
          <.link
            :for={order <- @orders}
            navigate={~p"/admin/orders/#{order.id}"}
            class="block bg-surface rounded-card border border-border shadow-sm p-4 hover:shadow-sm
                   hover:border-slate-300 transition-all"
          >
            <div class="flex items-start justify-between gap-3 mb-3">
              <div>
                <p class="font-mono text-xs font-medium text-primary">
                  {order.order_number}
                </p>
                <p class="text-sm font-medium text-slate-800 mt-1">
                  {customer_name(order)}
                </p>
              </div>
              <.status_badge status={order.status} variant={:order} />
            </div>
            <div class="flex items-center justify-between text-sm">
              <span class="text-slate-400">{format_date(order.inserted_at)}</span>
              <span class="font-mono font-semibold text-slate-800">
                {format_price(order.total, order.currency)}
              </span>
            </div>
          </.link>
        </div>

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

  # ── Components ──

  attr :status, :atom, required: true
  attr :current, :atom, required: true

  defp status_tab(assigns) do
    ~H"""
    <button
      phx-click="filter_status"
      phx-value-status={@status}
      class={[
        "px-3 py-1.5 text-sm font-medium rounded-lg transition-colors whitespace-nowrap",
        if(@status == @current,
          do: "bg-white text-slate-900 shadow-sm",
          else: "text-slate-500 hover:text-slate-700"
        )
      ]}
    >
      {status_label(@status)}
    </button>
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

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

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

  defp customer_email(%{customer: %{email: email}}) when is_binary(email), do: email
  defp customer_email(_), do: ""
end
