defmodule EmakolaWeb.Admin.CustomerLive.Index do
  @moduledoc """
  Lists all customers for the current store with search filtering,
  order count, total spent, and mobile-responsive layout.
  """
  use EmakolaWeb, :live_view

  require Ash.Query
  import EmakolaWeb.Helpers.Currency, only: [format_price: 1]

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Customers",
        active_nav: :customers,
        store_id: store_id,
        search_query: "",
        customers: []
      )
      |> load_customers()

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    socket =
      socket
      |> assign(search_query: query)
      |> load_customers()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Page Header --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-slate-900">Customers</h1>
          <p class="text-sm text-slate-500 mt-1">Manage your customer base</p>
        </div>
        <div class="flex gap-2">
          <button class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer">
            <.icon name="hero-arrow-down-tray" class="size-4" /> Export
          </button>
          <button class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer">
            <.icon name="hero-plus" class="size-4" /> Add Customer
          </button>
        </div>
      </div>

      <%!-- KPI Cards --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        <.kpi_card
          label="Total Customers"
          value={length(@customers) |> Integer.to_string()}
          icon="hero-users"
          icon_bg="bg-emerald-50"
          icon_color="text-emerald-600"
        />
        <.kpi_card
          label="Active"
          value={length(@customers) |> Integer.to_string()}
          icon="hero-check-circle"
          icon_bg="bg-violet-50"
          icon_color="text-violet-600"
        />
        <.kpi_card
          label="New This Month"
          value={count_new_this_month(@customers) |> Integer.to_string()}
          icon="hero-user-plus"
          icon_bg="bg-amber-50"
          icon_color="text-amber-600"
        />
        <.kpi_card
          label="Avg. Order Value"
          value={calculate_avg_order_value(@customers)}
          icon="hero-currency-dollar"
          icon_bg="bg-rose-50"
          icon_color="text-rose-600"
        />
      </div>

      <%!-- Filter Bar --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-4">
        <div class="flex flex-col lg:flex-row gap-3">
          <form phx-change="search" phx-debounce="300" class="flex-1">
            <div class="relative">
              <.icon
                name="hero-magnifying-glass"
                class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-slate-400"
              />
              <input
                type="search"
                name="search"
                value={@search_query}
                placeholder="Search by name or email..."
                class="w-full pl-9 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
                autocomplete="off"
              />
            </div>
          </form>
        </div>
      </div>

      <%!-- Customers Table (desktop) --%>
      <%= if @customers == [] do %>
        <div class="text-center py-16 bg-white rounded-2xl border border-slate-200">
          <.icon name="hero-users" class="size-12 mx-auto text-slate-300 mb-3" />
          <p class="text-slate-600 font-medium">No customers found</p>
          <p class="text-sm text-slate-400 mt-1">
            <%= if @search_query != "" do %>
              Try adjusting your search
            <% else %>
              Customers will appear here once they place orders
            <% end %>
          </p>
        </div>
      <% else %>
        <%!-- Desktop Table --%>
        <div class="hidden md:block bg-white rounded-2xl border border-slate-200 overflow-hidden">
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-100">
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Customer
                  </th>
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Phone
                  </th>
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Orders
                  </th>
                  <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Total Spent
                  </th>
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Joined
                  </th>
                  <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={customer <- @customers}
                  class="border-b border-slate-50 hover:bg-slate-50/50 transition-colors"
                >
                  <td class="px-6 py-4">
                    <.link
                      navigate={~p"/admin/customers/#{customer.id}"}
                      class="flex items-center gap-3"
                    >
                      <div class="w-9 h-9 rounded-full bg-emerald-100 flex items-center justify-center flex-shrink-0">
                        <span class="text-sm font-semibold text-emerald-700">
                          {customer_initials(customer.name)}
                        </span>
                      </div>
                      <div>
                        <p class="font-medium text-slate-800">{customer.name || "Unnamed"}</p>
                        <p class="text-[11px] text-slate-400">{customer.email}</p>
                      </div>
                    </.link>
                  </td>
                  <td class="px-6 py-4 text-slate-600">{customer.phone || "-"}</td>
                  <td class="px-6 py-4 text-slate-600">{customer.order_count || 0}</td>
                  <td class="px-6 py-4 text-right font-mono font-semibold text-slate-800">
                    {format_total_spent(customer)}
                  </td>
                  <td class="px-6 py-4 text-slate-500">
                    {Calendar.strftime(customer.inserted_at, "%d/%m/%Y")}
                  </td>
                  <td class="px-6 py-4 text-right">
                    <.link
                      navigate={~p"/admin/customers/#{customer.id}"}
                      class="text-emerald-600 hover:text-emerald-700 text-sm font-medium"
                    >
                      View
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
            :for={customer <- @customers}
            navigate={~p"/admin/customers/#{customer.id}"}
            class="block bg-white rounded-2xl border border-slate-200 p-4 hover:shadow-md transition-all"
          >
            <div class="flex items-center gap-3 mb-3">
              <div class="w-10 h-10 rounded-full bg-emerald-100 flex items-center justify-center flex-shrink-0">
                <span class="text-sm font-semibold text-emerald-700">
                  {customer_initials(customer.name)}
                </span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="font-medium text-slate-800 truncate">{customer.name || "Unnamed"}</p>
                <p class="text-xs text-slate-400 truncate">{customer.email}</p>
              </div>
            </div>
            <div class="flex items-center justify-between text-xs text-slate-500">
              <span>{customer.order_count || 0} orders</span>
              <span class="font-mono font-semibold text-slate-800">
                {format_total_spent(customer)}
              </span>
            </div>
          </.link>
        </div>
      <% end %>

      <%!-- Pagination placeholder --%>
      <div class="flex items-center justify-between">
        <p class="text-sm text-slate-500">
          Showing <span class="font-semibold text-slate-700">{length(@customers)}</span> customers
        </p>
      </div>
    </div>
    """
  end

  # ── Components ──

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :icon_bg, :string, required: true
  attr :icon_color, :string, required: true

  defp kpi_card(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300">
      <div class="flex items-center justify-between mb-4">
        <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">{@label}</span>
        <div class={"w-9 h-9 #{@icon_bg} rounded-xl flex items-center justify-center"}>
          <.icon name={@icon} class={"size-[18px] #{@icon_color}"} />
        </div>
      </div>
      <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">{@value}</p>
    </div>
    """
  end

  # ── Data Loading ──

  defp load_customers(socket) do
    store_id = socket.assigns.store_id
    search_query = socket.assigns.search_query

    customers =
      if store_id do
        result =
          if search_query != "" do
            Emakola.Customers.search_customers(store_id, search_query)
          else
            Emakola.Customers.list_customers_by_store(store_id)
          end

        case result do
          {:ok, customers} ->
            customers
            |> Ash.load!(:order_count)

          _ ->
            []
        end
      else
        []
      end

    assign(socket, customers: customers)
  end

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp customer_initials(nil), do: "?"

  defp customer_initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp format_total_spent(customer) do
    orders = Map.get(customer, :orders, nil)

    total =
      if is_list(orders) do
        Enum.reduce(orders, 0, fn order, acc -> acc + (order.total || 0) end)
      else
        0
      end

    format_price(total)
  end

  defp count_new_this_month(customers) do
    now = Date.utc_today()
    start_of_month = Date.beginning_of_month(now)

    Enum.count(customers, fn c ->
      Date.compare(DateTime.to_date(c.inserted_at), start_of_month) != :lt
    end)
  end

  defp calculate_avg_order_value(_customers) do
    # Placeholder - would require loading all orders
    "N/A"
  end
end
