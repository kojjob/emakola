defmodule EmakolaWeb.Admin.CustomerLive.Index do
  @moduledoc """
  Lists all customers for the current store with search filtering,
  order count, total spent, and mobile-responsive layout.
  """
  use EmakolaWeb, :live_view

  # Page window for the customer list; "Load more" grows it by this much.
  @customers_limit 100

  require Logger

  alias Emakola.Customers.Segments

  import EmakolaWeb.Helpers.Currency, only: [format_price: 1]

  import EmakolaWeb.Admin.CustomerLive.Components,
    only: [customer_initials: 1, add_customer_form: 1, segment_chips: 1]

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
        new_this_month: 0,
        bought_again: 0,
        segment: :everyone,
        segment_counts: %{},
        adding?: false,
        add_form: to_form(%{"name" => "", "phone" => "", "email" => ""}, as: :customer)
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
    # A search overrides any chosen segment (see load_customers/1) — clear it
    # here so the chip row doesn't keep highlighting a segment the search has
    # silently stopped applying.
    socket =
      socket
      |> assign(
        search_query: query,
        search_form: to_form(%{"search" => query}),
        segment: :everyone,
        customers_limit: @customers_limit
      )
      |> load_customers()

    {:noreply, socket}
  end

  # A search in progress ignores the segment (see load_customers/1) — clearing
  # it here keeps the chip honest about what the list is actually showing,
  # rather than highlighting a segment the search has silently overridden.
  def handle_event("segment", %{"segment" => segment_param}, socket) do
    segment = Emakola.SafeAtom.to_atom_in(segment_param, Segments.all(), :everyone)

    {:noreply,
     socket
     |> assign(
       segment: segment,
       search_query: "",
       search_form: to_form(%{"search" => ""}),
       customers_limit: @customers_limit
     )
     |> load_customers()}
  end

  def handle_event("toggle_add", _params, socket) do
    {:noreply, assign(socket, adding?: not socket.assigns.adding?)}
  end

  def handle_event("add_customer", %{"customer" => params}, socket) do
    with {:ok, name} <- as_binary(params["name"]),
         {:ok, phone} <- as_binary(params["phone"]),
         {:ok, email} <- as_binary(params["email"]) do
      if phone not in [nil, ""] and not Emakola.Accounts.PhoneAuth.valid?(phone) do
        {:noreply, put_flash(socket, :error, "Enter a valid phone number")}
      else
        attrs = %{
          store_id: socket.assigns.store_id,
          name: name,
          phone: normalize_phone(phone),
          email: blank_to_nil(email)
        }

        case Emakola.Customers.create_customer(attrs, authorize?: false) do
          {:ok, _customer} ->
            {:noreply,
             socket
             |> assign(adding?: false)
             |> load_customers()
             |> put_flash(:info, "Customer saved")}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, add_customer_error_message(error))}
        end
      end
    else
      # A crafted param (e.g. customer[phone][]=1) arrives as a list/map, not
      # a string — reject it the same way as a plain bad phone, rather than
      # crashing inside PhoneAuth.valid?/1 further down.
      :error -> {:noreply, put_flash(socket, :error, "Enter a valid phone number")}
    end
  end

  defp as_binary(nil), do: {:ok, nil}
  defp as_binary(value) when is_binary(value), do: {:ok, value}
  defp as_binary(_value), do: :error

  defp normalize_phone(phone) when is_binary(phone) and phone != "",
    do: Emakola.Accounts.PhoneAuth.normalize(phone)

  defp normalize_phone(_phone), do: nil

  defp blank_to_nil(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: value)

  defp blank_to_nil(_value), do: nil

  defp add_customer_error_message(%Ash.Error.Invalid{errors: errors}) do
    cond do
      Enum.any?(errors, &duplicate_on_constraint?(&1, "email")) ->
        "That email is already a customer"

      Enum.any?(errors, &duplicate_on_constraint?(&1, "phone")) ->
        "That phone is already a customer"

      true ->
        "Give a name and a phone or email"
    end
  end

  defp add_customer_error_message(_error), do: "Give a name and a phone or email"

  # AshPostgres attributes a composite unique-index violation (customer
  # identities are `[:store_id, :phone]` / `[:store_id, :email]`) to
  # whichever column comes first in the index — always `field: :store_id`
  # here, never the field the merchant actually typed. The Postgres
  # constraint name (from the migration: customers_unique_store_<field>_index)
  # is the reliable signal instead.
  defp duplicate_on_constraint?(error, substring) do
    with %{private_vars: vars} when is_list(vars) <- error,
         name when is_binary(name) <- Keyword.get(vars, :constraint) do
      name =~ substring
    else
      _ -> false
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header icon="hero-users" title="Customers" subtitle="Manage your customer base">
        <.link
          href="/admin/export/customers.csv"
          class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors"
        >
          <.icon name="hero-arrow-down-tray" class="size-4" /> Export
        </.link>
        <button
          id="add-customer-toggle"
          type="button"
          phx-click="toggle_add"
          class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
        >
          <.icon name="hero-plus" class="size-4" /> Add customer
        </button>
      </.admin_page_header>

      <.add_customer_form adding?={@adding?} form={@add_form} />

      <%!-- KPI Cards --%>
      <%!-- Three tiles, not four: "Active" rendered @total_customers, the same
            assign as "Total Customers", so it was the same number by
            construction and told a merchant nothing. --%>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <.stat_card
          label="Total Customers"
          value={Integer.to_string(@total_customers)}
          tone={:accent}
        >
          <:icon><.icon name="hero-users" class="size-7" /></:icon>
        </.stat_card>
        <.stat_card
          label="New This Month"
          value={Integer.to_string(@new_this_month)}
          tone={:success}
        >
          <:icon><.icon name="hero-user-plus" class="size-7" /></:icon>
        </.stat_card>
        <.stat_card
          id="customers-bought-again"
          label="Bought again"
          value={Integer.to_string(@bought_again)}
          tone={:info}
        >
          <:icon><.icon name="hero-arrow-path" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">Two or more paid orders</p>
          </:delta>
        </.stat_card>
      </div>

      <.segment_chips segment={@segment} segment_counts={@segment_counts} />

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
          tone={:info}
          title="No customers yet"
          description="They appear when someone buys"
          secondary_label="See how selling works"
          secondary_path="/how-it-works/tour"
          secondary_icon="hero-play-circle"
        />
      <% else %>
        <%!-- Desktop Table --%>
        <div class="hidden md:block bg-white rounded-2xl shadow-sm overflow-hidden">
          <div class="overflow-x-auto">
            <table id="customers-table" class="w-full text-sm">
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
                    Last bought
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
                  id={"customer-#{customer.id}"}
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
                    {format_price(customer.paid_total || 0)}
                  </td>
                  <td class="px-6 py-4 text-slate-500">
                    {last_bought(customer.last_order_at)}
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
            id={"customer-#{customer.id}-card"}
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
              <span>{Emakola.Plural.count(customer.order_count, "order")}</span>
              <span class="font-mono font-semibold text-slate-800">
                {format_price(customer.paid_total || 0)}
              </span>
            </div>
            <div class="text-xs text-slate-500 mt-1">
              Last bought {last_bought(customer.last_order_at)}
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
    segment = socket.assigns[:segment] || :everyone
    limit = socket.assigns[:customers_limit] || @customers_limit

    customers =
      cond do
        is_nil(store_id) ->
          []

        search_query != "" ->
          Emakola.Customers.search_customers!(store_id, search_query,
            query: [limit: limit + 1],
            authorize?: false
          )

        segment != :everyone ->
          store_id
          |> Segments.query(segment)
          |> Ash.Query.sort(inserted_at: :desc)
          |> Ash.Query.load([:order_count, :paid_total, :paid_order_count])
          |> Ash.Query.limit(limit + 1)
          |> Ash.read!(authorize?: false)

        true ->
          Emakola.Customers.list_customers_by_store!(store_id,
            query: [limit: limit + 1],
            authorize?: false
          )
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

      assign(socket,
        customers: [],
        more_customers?: false,
        total_customers: 0,
        new_this_month: 0,
        bought_again: 0,
        segment_counts: %{}
      )
  end

  # The KPI tiles used to count `length(@customers)` — i.e. the loaded WINDOW,
  # not the store. A merchant with 250 customers was told they had 100, and the
  # number changed as they pressed "Load more". These are real counts over the
  # same scope as the list (store, plus the active search).
  defp assign_customer_totals(socket, nil, _search),
    do:
      assign(socket,
        total_customers: 0,
        new_this_month: 0,
        bought_again: 0,
        segment_counts: %{}
      )

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

    bought_again_query =
      Ash.Query.for_read(Emakola.Customers.Customer, :bought_again_by_store, %{
        store_id: store_id
      })

    assign(socket,
      total_customers: Ash.count!(base, authorize?: false),
      new_this_month:
        base
        |> Ash.Query.filter(inserted_at >= ^start_of_month)
        |> Ash.count!(authorize?: false),
      bought_again: Ash.count!(bought_again_query, authorize?: false),
      segment_counts: Segments.counts(store_id)
    )
  rescue
    exception ->
      Logger.error(
        "[customer_live.index] customer totals failed: #{Exception.message(exception)}"
      )

      assign(socket,
        total_customers: length(socket.assigns.customers),
        new_this_month: 0,
        bought_again: 0,
        segment_counts: %{}
      )
  end

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp last_bought(nil), do: "Not yet"

  defp last_bought(at) do
    days = Date.diff(Date.utc_today(), DateTime.to_date(at))

    cond do
      days <= 0 -> "Today"
      days == 1 -> "Yesterday"
      days < 30 -> "#{days} days ago"
      true -> Calendar.strftime(at, "%d %b %Y")
    end
  end
end
