defmodule EmakolaWeb.Admin.OrderLive.Index do
  @moduledoc """
  Lists all orders for the current store with status filtering, search,
  and mobile-responsive layout matching the Emakola admin orders prototype.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

  require Ash.Query

  @statuses [:all, :pending, :confirmed, :processing, :shipped, :delivered, :cancelled]

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
        status_filter: :all,
        orders: [],
        statuses: @statuses
      )
      |> load_orders()

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    socket =
      socket
      |> assign(search_query: query)
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
      |> assign(status_filter: status_atom)
      |> load_orders()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Page Header --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-slate-900">Orders</h1>
          <p class="text-sm text-slate-500 mt-1">Manage and track all customer orders</p>
        </div>
      </div>

      <%!-- Status Filter Tabs --%>
      <div class="flex flex-wrap items-center gap-3">
        <div class="flex gap-1 bg-slate-100 rounded-xl p-1 overflow-x-auto">
          <.status_tab :for={status <- @statuses} status={status} current={@status_filter} />
        </div>

        <%!-- Search --%>
        <form phx-change="search" phx-debounce="300" class="relative flex-1 min-w-[200px] max-w-xs">
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
          <input
            type="search"
            name="search"
            value={@search_query}
            placeholder="Search orders..."
            class="w-full pl-9 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-700
                   placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/30
                   focus:border-emerald-500 transition-all"
            autocomplete="off"
          />
        </form>
      </div>

      <%!-- Orders --%>
      <%= if @orders == [] do %>
        <div class="text-center py-16 bg-white rounded-2xl border border-slate-200">
          <svg
            class="w-12 h-12 mx-auto text-slate-300 mb-3"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
            />
          </svg>
          <p class="text-slate-600 font-medium">No orders found</p>
          <p class="text-sm text-slate-400 mt-1">
            <%= if @search_query != "" or @status_filter != :all do %>
              Try adjusting your search or filters
            <% else %>
              Orders will appear here when customers place them
            <% end %>
          </p>
        </div>
      <% else %>
        <%!-- Desktop Table --%>
        <div class="hidden md:block bg-white rounded-2xl border border-slate-200 overflow-hidden">
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
                      class="font-mono text-xs font-medium text-emerald-600 hover:text-emerald-700"
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
                    <.order_status_badge status={order.status} />
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
        </div>

        <%!-- Mobile Cards --%>
        <div class="md:hidden space-y-3">
          <.link
            :for={order <- @orders}
            navigate={~p"/admin/orders/#{order.id}"}
            class="block bg-white rounded-2xl border border-slate-200 p-4 hover:shadow-sm
                   hover:border-slate-300 transition-all"
          >
            <div class="flex items-start justify-between gap-3 mb-3">
              <div>
                <p class="font-mono text-xs font-medium text-emerald-600">
                  {order.order_number}
                </p>
                <p class="text-sm font-medium text-slate-800 mt-1">
                  {customer_name(order)}
                </p>
              </div>
              <.order_status_badge status={order.status} />
            </div>
            <div class="flex items-center justify-between text-sm">
              <span class="text-slate-400">{format_date(order.inserted_at)}</span>
              <span class="font-mono font-semibold text-slate-800">
                {format_price(order.total, order.currency)}
              </span>
            </div>
          </.link>
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

  attr :status, :atom, required: true

  defp order_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold",
      status_badge_class(@status)
    ]}>
      {status_label(@status)}
    </span>
    """
  end

  # ── Data Loading ──

  @orders_per_page 50

  defp load_orders(socket) do
    require Ash.Query
    %{store_id: store_id, search_query: query, status_filter: status} = socket.assigns

    orders =
      try do
        base =
          Emakola.Orders.Order
          |> Ash.Query.filter(store_id == ^store_id)
          |> Ash.Query.sort(inserted_at: :desc)
          |> Ash.Query.load([:customer])
          |> Ash.Query.limit(@orders_per_page)

        base =
          if status != :all do
            Ash.Query.filter(base, status == ^status)
          else
            base
          end

        base =
          if query != "" do
            Ash.Query.filter(base, contains(order_number, ^query))
          else
            base
          end

        Ash.read!(base, authorize?: false)
      rescue
        _ -> []
      end

    assign(socket, orders: orders)
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

  defp status_badge_class(:pending), do: "bg-amber-50 text-amber-700"
  defp status_badge_class(:confirmed), do: "bg-blue-50 text-blue-700"
  defp status_badge_class(:processing), do: "bg-indigo-50 text-indigo-700"
  defp status_badge_class(:shipped), do: "bg-purple-50 text-purple-700"
  defp status_badge_class(:delivered), do: "bg-emerald-50 text-emerald-700"
  defp status_badge_class(:cancelled), do: "bg-red-50 text-red-700"
  defp status_badge_class(_), do: "bg-slate-50 text-slate-700"

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
