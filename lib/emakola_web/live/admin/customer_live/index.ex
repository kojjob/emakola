defmodule EmakolaWeb.Admin.CustomerLive.Index do
  @moduledoc """
  Lists all customers for the current store with search filtering,
  order count, total spent, and mobile-responsive layout.
  """
  use EmakolaWeb, :live_view

  # Page window for the customer list; "Load more" grows it by this much.
  @customers_limit 100

  require Logger

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
        search_form: to_form(%{"search" => ""}),
        customers: [],
        customers_limit: @customers_limit,
        more_customers?: false,
        total_customers: 0,
        new_this_month: 0
      )
      |> load_customers()

    {:ok, socket}
  end

  @impl true
  def handle_event("load_more_customers", _params, socket) do
    {:noreply,
     socket
     |> assign(customers_limit: socket.assigns.customers_limit + @customers_limit)
     |> load_customers()}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    socket =
      socket
      |> assign(
        search_query: query,
        search_form: to_form(%{"search" => query}),
        customers_limit: @customers_limit
      )
      |> load_customers()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header title="Customers" subtitle="Manage your customer base">
        <button class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer">
          <.icon name="hero-arrow-down-tray" class="size-4" /> Export
        </button>
        <button class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer">
          <.icon name="hero-plus" class="size-4" /> Add Customer
        </button>
      </.admin_page_header>

      <%!-- KPI Cards --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        <.stat_card
          label="Total Customers"
          value={Integer.to_string(@total_customers)}
          icon_bg="bg-emerald-50"
        >
          <:icon><.icon name="hero-users" class="size-[18px] text-emerald-600" /></:icon>
        </.stat_card>
        <.stat_card
          label="Active"
          value={Integer.to_string(@total_customers)}
          icon_bg="bg-violet-50"
        >
          <:icon><.icon name="hero-check-circle" class="size-[18px] text-violet-600" /></:icon>
        </.stat_card>
        <.stat_card
          label="New This Month"
          value={Integer.to_string(@new_this_month)}
          icon_bg="bg-amber-50"
        >
          <:icon><.icon name="hero-user-plus" class="size-[18px] text-amber-600" /></:icon>
        </.stat_card>
        <.stat_card
          label="Avg. Order Value"
          value={calculate_avg_order_value(@customers)}
          icon_bg="bg-rose-50"
        >
          <:icon><.icon name="hero-currency-dollar" class="size-[18px] text-rose-600" /></:icon>
        </.stat_card>
      </div>

      <%!-- Filter Bar --%>
      <.table_toolbar
        id="customer-search-form"
        form={@search_form}
        search_query={@search_query}
        placeholder="Search by name or email..."
      />

      <%!-- Customers Table (desktop) --%>
      <%= if @customers == [] do %>
        <%!-- A store with no customers yet is waiting, not broken; a search
              that matched nothing needs to say it was the search. --%>
        <.empty_state
          :if={@search_query != ""}
          icon="hero-users"
          title="No customers found"
          description="Try adjusting your search"
        />
        <.empty_state
          :if={@search_query == ""}
          icon="hero-users"
          title="No customers yet"
          description="They appear when someone buys"
        />
      <% else %>
        <%!-- Desktop Table --%>
        <div class="hidden md:block bg-white rounded-2xl shadow-sm overflow-hidden">
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
            class="block bg-white rounded-2xl shadow-sm p-4 hover:shadow-md transition-all"
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

      <%!-- The list is a window, not the whole book. This was a "pagination
      placeholder" that only ever printed a count, so customers past the limit
      were unreachable with no hint they existed. --%>
      <div class="flex items-center justify-between gap-3">
        <p class="text-sm text-slate-500">
          Showing <span class="font-semibold text-slate-700">{length(@customers)}</span> customers
        </p>
        <.admin_button
          :if={@more_customers?}
          id="load-more-customers"
          variant={:secondary}
          phx-click="load_more_customers"
          phx-disable-with="Loading..."
        >
          Load more customers
        </.admin_button>
      </div>
    </div>
    """
  end

  # ── Data Loading ──

  defp load_customers(socket) do
    store_id = socket.assigns.store_id
    search_query = socket.assigns.search_query
    limit = socket.assigns[:customers_limit] || @customers_limit

    customers =
      if store_id do
        if search_query != "" do
          Emakola.Customers.search_customers!(store_id, search_query,
            query: [limit: limit + 1],
            authorize?: false
          )
        else
          Emakola.Customers.list_customers_by_store!(store_id,
            query: [limit: limit + 1],
            authorize?: false
          )
        end
      else
        []
      end

    # One row past the window answers "is there more?" without a second COUNT.
    {customers, more?} =
      if length(customers) > limit,
        do: {Enum.take(customers, limit), true},
        else: {customers, false}

    socket
    |> assign(customers: customers, customers_limit: limit, more_customers?: more?)
    |> assign_customer_totals(store_id, search_query)
  rescue
    exception ->
      Logger.error(
        "[customer_live.index] load_customers loading customers raised: #{Exception.message(exception)}"
      )

      assign(socket, customers: [], more_customers?: false, total_customers: 0, new_this_month: 0)
  end

  # The KPI tiles used to count `length(@customers)` — i.e. the loaded WINDOW,
  # not the store. A merchant with 250 customers was told they had 100, and the
  # number changed as they pressed "Load more". These are real counts over the
  # same scope as the list (store, plus the active search).
  defp assign_customer_totals(socket, nil, _search),
    do: assign(socket, total_customers: 0, new_this_month: 0)

  defp assign_customer_totals(socket, store_id, search_query) do
    require Ash.Query

    base =
      if search_query != "" do
        Ash.Query.for_read(Emakola.Customers.Customer, :search, %{
          store_id: store_id,
          query: search_query
        })
      else
        Ash.Query.for_read(Emakola.Customers.Customer, :list_by_store, %{store_id: store_id})
      end

    start_of_month = Date.utc_today() |> Date.beginning_of_month() |> DateTime.new!(~T[00:00:00])

    assign(socket,
      total_customers: Ash.count!(base, authorize?: false),
      new_this_month:
        base
        |> Ash.Query.filter(inserted_at >= ^start_of_month)
        |> Ash.count!(authorize?: false)
    )
  rescue
    exception ->
      Logger.error(
        "[customer_live.index] customer totals failed: #{Exception.message(exception)}"
      )

      assign(socket, total_customers: length(socket.assigns.customers), new_this_month: 0)
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

  defp calculate_avg_order_value(_customers) do
    # Placeholder - would require loading all orders
    "N/A"
  end
end
