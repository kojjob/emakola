defmodule EmakolaWeb.Admin.DiscountLive.Index do
  @moduledoc """
  Lists all discount codes for the current store with summary cards,
  status filtering, search, and a create discount form.
  UI-only page with placeholder data — no Ash resource yet.
  Pixel-matched to design/prototypes/emakola-admin-discounts.html.
  """
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Discounts",
        active_nav: :discounts,
        store_id: store_id,
        search_query: "",
        status_filter: :all,
        discounts: placeholder_discounts(),
        show_create_form: false,
        discount_type: "percentage"
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    filtered = filter_discounts(placeholder_discounts(), query, socket.assigns.status_filter)
    {:noreply, assign(socket, search_query: query, discounts: filtered)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom =
      case status do
        "all" -> :all
        "active" -> :active
        "scheduled" -> :scheduled
        "expired" -> :expired
        _ -> :all
      end

    filtered = filter_discounts(placeholder_discounts(), socket.assigns.search_query, status_atom)
    {:noreply, assign(socket, status_filter: status_atom, discounts: filtered)}
  end

  @impl true
  def handle_event("toggle_create_form", _params, socket) do
    {:noreply, assign(socket, show_create_form: !socket.assigns.show_create_form)}
  end

  @impl true
  def handle_event("set_discount_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, discount_type: type)}
  end

  @impl true
  def handle_event("generate_code", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_discount", _params, socket) do
    socket =
      socket
      |> put_flash(:info, "Discount created successfully")
      |> assign(show_create_form: false)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Page Header --%>
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">Discounts</h1>
        <p class="text-sm text-slate-500 mt-1">Create and manage discount codes</p>
      </div>
      <button
        phx-click="toggle_create_form"
        class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:ring-offset-2 self-start sm:self-auto"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        Create Discount
      </button>
    </div>

    <%!-- Summary Cards --%>
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
      <%!-- Active Discounts --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Active Discounts
          </span>
          <div class="w-9 h-9 bg-emerald-50 rounded-xl flex items-center justify-center">
            <svg
              class="w-[18px] h-[18px] text-emerald-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z"
              />
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 6h.008v.008H6V6z" />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">
          {count_by_status(@discounts, :active)}
        </p>
      </div>
      <%!-- Total Uses --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Total Uses
          </span>
          <div class="w-9 h-9 bg-violet-50 rounded-xl flex items-center justify-center">
            <svg
              class="w-[18px] h-[18px] text-violet-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">
          {total_uses(@discounts)}
        </p>
      </div>
      <%!-- Revenue Impact --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Revenue Impact
          </span>
          <div class="w-9 h-9 bg-amber-50 rounded-xl flex items-center justify-center">
            <svg
              class="w-[18px] h-[18px] text-amber-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">
          GH&#8373; 8,420
        </p>
        <p class="text-xs text-slate-400 mt-1">saved by customers</p>
      </div>
    </div>

    <%!-- Filter Bar --%>
    <div class="flex flex-wrap items-center gap-3 mb-6">
      <div class="relative">
        <form phx-change="filter_status">
          <select
            name="status"
            class="appearance-none bg-white border border-slate-200 rounded-xl pl-3 pr-9 py-2.5 text-sm text-slate-700 font-medium cursor-pointer focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
          >
            <option value="all" selected={@status_filter == :all}>All Statuses</option>
            <option value="active" selected={@status_filter == :active}>Active</option>
            <option value="scheduled" selected={@status_filter == :scheduled}>Scheduled</option>
            <option value="expired" selected={@status_filter == :expired}>Expired</option>
          </select>
        </form>
      </div>
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
          placeholder="Search discounts..."
          class="w-full pl-9 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-700 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
          autocomplete="off"
        />
      </form>
    </div>

    <%!-- Discounts Table --%>
    <div class="bg-white rounded-2xl border border-slate-200 overflow-hidden mb-8">
      <div class="flex items-center justify-between px-6 py-5 border-b border-slate-100">
        <div>
          <h2 class="text-base font-bold text-slate-900">All Discount Codes</h2>
          <p class="text-xs text-slate-400 mt-0.5">{length(@discounts)} discount codes</p>
        </div>
      </div>

      <%= if @discounts == [] do %>
        <div class="text-center py-16">
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
              d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z"
            />
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 6h.008v.008H6V6z" />
          </svg>
          <p class="text-slate-600 font-medium">No discount codes found</p>
          <p class="text-sm text-slate-400 mt-1">
            <%= if @search_query != "" or @status_filter != :all do %>
              Try adjusting your search or filters
            <% else %>
              Create your first discount code to get started
            <% end %>
          </p>
        </div>
      <% else %>
        <%!-- Desktop Table --%>
        <div class="overflow-x-auto hidden sm:block">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100">
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                  Code
                </th>
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 hidden sm:table-cell">
                  Type
                </th>
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                  Value
                </th>
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 hidden md:table-cell">
                  Min. Purchase
                </th>
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 hidden lg:table-cell">
                  Usage
                </th>
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                  Status
                </th>
                <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3 hidden lg:table-cell">
                  Valid Period
                </th>
                <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={discount <- @discounts}
                class="border-b border-slate-50 hover:bg-slate-50 transition-colors cursor-pointer"
              >
                <td class="px-6 py-4">
                  <span class={[
                    "font-mono font-semibold px-2.5 py-1 rounded-lg text-xs",
                    code_style(discount.status)
                  ]}>
                    {discount.code}
                  </span>
                </td>
                <td class="px-6 py-4 hidden sm:table-cell">
                  <.type_badge type={discount.type} />
                </td>
                <td class="px-6 py-4 font-semibold text-slate-800">
                  <span class={if(discount.type in [:percentage, :fixed], do: "font-mono", else: "")}>
                    {discount.value_display}
                  </span>
                </td>
                <td class="px-6 py-4 hidden md:table-cell">
                  <%= if discount.min_purchase do %>
                    <span class="text-slate-600 font-mono">
                      GH&#8373; {discount.min_purchase}
                    </span>
                  <% else %>
                    <span class="text-slate-400">No min</span>
                  <% end %>
                </td>
                <td class="px-6 py-4 hidden lg:table-cell">
                  <.usage_bar
                    used={discount.used}
                    limit={discount.usage_limit}
                    status={discount.status}
                  />
                </td>
                <td class="px-6 py-4">
                  <.status_badge status={discount.status} />
                </td>
                <td class="px-6 py-4 text-xs text-slate-500 hidden lg:table-cell">
                  {discount.valid_period}
                </td>
                <td class="px-6 py-4 text-right">
                  <div class="flex items-center justify-end gap-1">
                    <button
                      class="p-1.5 rounded-lg hover:bg-slate-100 transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-emerald-500"
                      aria-label={"Edit #{discount.code}"}
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
                          d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10"
                        />
                      </svg>
                    </button>
                    <button
                      class="p-1.5 rounded-lg hover:bg-slate-100 transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-emerald-500"
                      aria-label={"Delete #{discount.code}"}
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
                          d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"
                        />
                      </svg>
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Mobile Cards --%>
        <div class="sm:hidden divide-y divide-slate-100">
          <div :for={discount <- @discounts} class="px-4 py-4">
            <div class="flex items-start justify-between gap-3 mb-2">
              <span class={[
                "font-mono font-semibold px-2.5 py-1 rounded-lg text-xs",
                code_style(discount.status)
              ]}>
                {discount.code}
              </span>
              <.status_badge status={discount.status} />
            </div>
            <div class="flex items-center justify-between text-sm mt-2">
              <span class="text-slate-500">{discount.value_display}</span>
              <span class="text-xs text-slate-400">{discount.valid_period}</span>
            </div>
          </div>
        </div>
      <% end %>
    </div>

    <%!-- Create Discount Form --%>
    <div :if={@show_create_form} class="bg-white rounded-2xl border border-slate-200 p-6">
      <h2 class="text-base font-bold text-slate-900 mb-1">Create New Discount</h2>
      <p class="text-xs text-slate-400 mb-6">Configure your discount code settings</p>

      <form phx-submit="create_discount" class="space-y-6">
        <%!-- Row 1: Code + Type --%>
        <div class="grid sm:grid-cols-2 gap-4">
          <div>
            <label for="discount-code" class="block text-sm font-medium text-slate-700 mb-1.5">
              Discount Code
            </label>
            <div class="flex gap-2">
              <input
                type="text"
                id="discount-code"
                name="code"
                placeholder="e.g. SUMMER20"
                class="flex-1 px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm font-mono text-slate-700 placeholder:text-slate-400 uppercase focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
              <button
                type="button"
                phx-click="generate_code"
                class="px-3 py-2.5 bg-slate-100 border border-slate-200 rounded-xl text-xs font-medium text-slate-600 hover:bg-slate-200 transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-emerald-500 whitespace-nowrap"
              >
                <svg
                  class="w-4 h-4 inline-block mr-1 -mt-0.5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M19.5 12c0-1.232-.046-2.453-.138-3.662a4.006 4.006 0 00-3.7-3.7 48.678 48.678 0 00-7.324 0 4.006 4.006 0 00-3.7 3.7c-.017.22-.032.441-.046.662M19.5 12l3-3m-3 3l-3-3m-12 3c0 1.232.046 2.453.138 3.662a4.006 4.006 0 003.7 3.7 48.656 48.656 0 007.324 0 4.006 4.006 0 003.7-3.7c.017-.22.032-.441.046-.662M4.5 12l3 3m-3-3l-3 3"
                  />
                </svg>
                Auto
              </button>
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Discount Type</label>
            <div class="grid grid-cols-2 gap-2">
              <label
                :for={
                  {label, value} <- [
                    {"Percentage", "percentage"},
                    {"Fixed Amount", "fixed"},
                    {"Free Shipping", "shipping"},
                    {"Buy X Get Y", "bogo"}
                  ]
                }
                class={[
                  "flex items-center gap-2 px-3 py-2.5 rounded-xl cursor-pointer transition-colors",
                  if(@discount_type == value,
                    do: "bg-emerald-50 border-2 border-emerald-500",
                    else: "bg-slate-50 border border-slate-200 hover:border-slate-300"
                  )
                ]}
              >
                <input
                  type="radio"
                  name="discount_type"
                  value={value}
                  checked={@discount_type == value}
                  phx-click="set_discount_type"
                  phx-value-type={value}
                  class="w-4 h-4 text-emerald-600 focus:ring-emerald-500"
                />
                <span class={[
                  "text-sm font-medium",
                  if(@discount_type == value, do: "text-emerald-700", else: "text-slate-600")
                ]}>
                  {label}
                </span>
              </label>
            </div>
          </div>
        </div>

        <%!-- Row 2: Value + Min Purchase --%>
        <div class="grid sm:grid-cols-2 gap-4">
          <div>
            <label for="discount-value" class="block text-sm font-medium text-slate-700 mb-1.5">
              Discount Value
            </label>
            <div class="relative">
              <input
                type="number"
                id="discount-value"
                name="value"
                placeholder="10"
                class="w-full px-3 py-2.5 pr-10 bg-slate-50 border border-slate-200 rounded-xl text-sm font-mono text-slate-700 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
              <span class="absolute right-3 top-1/2 -translate-y-1/2 text-sm font-medium text-slate-400">
                {if @discount_type == "percentage", do: "%", else: "GH₵"}
              </span>
            </div>
          </div>
          <div>
            <label for="min-purchase" class="block text-sm font-medium text-slate-700 mb-1.5">
              Minimum Purchase
            </label>
            <div class="relative">
              <span class="absolute left-3 top-1/2 -translate-y-1/2 text-sm font-mono font-medium text-slate-400">
                GH&#8373;
              </span>
              <input
                type="number"
                id="min-purchase"
                name="min_purchase"
                placeholder="0.00"
                class="w-full pl-12 pr-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm font-mono text-slate-700 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
          </div>
        </div>

        <%!-- Row 3: Usage Limit + Date Range --%>
        <div class="grid sm:grid-cols-3 gap-4">
          <div>
            <label for="usage-limit" class="block text-sm font-medium text-slate-700 mb-1.5">
              Usage Limit
            </label>
            <input
              type="number"
              id="usage-limit"
              name="usage_limit"
              placeholder="Unlimited"
              class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
            />
          </div>
          <div>
            <label for="start-date" class="block text-sm font-medium text-slate-700 mb-1.5">
              Start Date
            </label>
            <input
              type="date"
              id="start-date"
              name="start_date"
              class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all cursor-pointer"
            />
          </div>
          <div>
            <label for="end-date" class="block text-sm font-medium text-slate-700 mb-1.5">
              End Date
            </label>
            <input
              type="date"
              id="end-date"
              name="end_date"
              class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all cursor-pointer"
            />
          </div>
        </div>

        <%!-- Row 4: Applies To --%>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1.5">Applies To</label>
          <div class="flex flex-wrap gap-2">
            <label class="flex items-center gap-2 px-4 py-2.5 bg-emerald-50 border-2 border-emerald-500 rounded-xl cursor-pointer">
              <input
                type="radio"
                name="applies_to"
                value="all"
                checked
                class="w-4 h-4 text-emerald-600 focus:ring-emerald-500"
              />
              <span class="text-sm font-medium text-emerald-700">All Products</span>
            </label>
            <label class="flex items-center gap-2 px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl cursor-pointer hover:border-slate-300 transition-colors">
              <input
                type="radio"
                name="applies_to"
                value="categories"
                class="w-4 h-4 text-emerald-600 focus:ring-emerald-500"
              />
              <span class="text-sm font-medium text-slate-600">Specific Categories</span>
            </label>
            <label class="flex items-center gap-2 px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl cursor-pointer hover:border-slate-300 transition-colors">
              <input
                type="radio"
                name="applies_to"
                value="products"
                class="w-4 h-4 text-emerald-600 focus:ring-emerald-500"
              />
              <span class="text-sm font-medium text-slate-600">Specific Products</span>
            </label>
          </div>
        </div>

        <%!-- Submit --%>
        <div class="flex justify-end pt-2">
          <button
            type="submit"
            class="inline-flex items-center gap-2 px-6 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:ring-offset-2"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
            </svg>
            Create Discount
          </button>
        </div>
      </form>
    </div>
    """
  end

  # ── Components ──

  attr :type, :atom, required: true

  defp type_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center text-xs font-semibold px-2.5 py-1 rounded-full",
      type_badge_class(@type)
    ]}>
      {type_label(@type)}
    </span>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-full",
      status_badge_class(@status)
    ]}>
      <span class={["w-1.5 h-1.5 rounded-full", status_dot_class(@status)]}></span>
      {status_label(@status)}
    </span>
    """
  end

  attr :used, :integer, required: true
  attr :limit, :integer, default: nil
  attr :status, :atom, required: true

  defp usage_bar(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <%= if @limit do %>
        <div class="flex-1 h-1.5 bg-slate-100 rounded-full overflow-hidden w-20">
          <div
            class={["h-full rounded-full", usage_bar_color(@used, @limit, @status)]}
            style={"width: #{usage_percentage(@used, @limit)}%"}
          >
          </div>
        </div>
        <span class="text-xs text-slate-500 font-mono">{@used}/{@limit}</span>
      <% else %>
        <span class="text-xs text-slate-500 font-mono">{@used}/unlimited</span>
      <% end %>
    </div>
    """
  end

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp count_by_status(discounts, status) do
    Enum.count(discounts, &(&1.status == status))
  end

  defp total_uses(discounts) do
    Enum.sum(Enum.map(discounts, & &1.used))
  end

  defp filter_discounts(discounts, query, status_filter) do
    discounts
    |> maybe_filter_status(status_filter)
    |> maybe_filter_search(query)
  end

  defp maybe_filter_status(discounts, :all), do: discounts

  defp maybe_filter_status(discounts, status) do
    Enum.filter(discounts, &(&1.status == status))
  end

  defp maybe_filter_search(discounts, ""), do: discounts

  defp maybe_filter_search(discounts, query) do
    q = String.downcase(query)
    Enum.filter(discounts, fn d -> String.contains?(String.downcase(d.code), q) end)
  end

  defp code_style(:expired), do: "text-slate-500 bg-slate-100"
  defp code_style(_), do: "text-emerald-600 bg-emerald-50"

  defp type_badge_class(:percentage), do: "text-violet-700 bg-violet-50"
  defp type_badge_class(:fixed), do: "text-blue-700 bg-blue-50"
  defp type_badge_class(:free_shipping), do: "text-emerald-700 bg-emerald-50"
  defp type_badge_class(:bogo), do: "text-amber-700 bg-amber-50"
  defp type_badge_class(_), do: "text-slate-700 bg-slate-50"

  defp type_label(:percentage), do: "Percentage"
  defp type_label(:fixed), do: "Fixed Amount"
  defp type_label(:free_shipping), do: "Free Shipping"
  defp type_label(:bogo), do: "Buy X Get Y"
  defp type_label(_), do: "Other"

  defp status_badge_class(:active), do: "text-emerald-700 bg-emerald-50"
  defp status_badge_class(:scheduled), do: "text-blue-700 bg-blue-50"
  defp status_badge_class(:expired), do: "text-slate-500 bg-slate-100"
  defp status_badge_class(_), do: "text-slate-500 bg-slate-100"

  defp status_dot_class(:active), do: "bg-emerald-500"
  defp status_dot_class(:scheduled), do: "bg-blue-500"
  defp status_dot_class(:expired), do: "bg-slate-400"
  defp status_dot_class(_), do: "bg-slate-400"

  defp status_label(:active), do: "Active"
  defp status_label(:scheduled), do: "Scheduled"
  defp status_label(:expired), do: "Expired"
  defp status_label(_), do: "Unknown"

  defp usage_percentage(_used, 0), do: 0
  defp usage_percentage(used, limit), do: min(round(used / limit * 100), 100)

  defp usage_bar_color(_used, _limit, :expired), do: "bg-slate-400"
  defp usage_bar_color(used, limit, _status) when used >= limit, do: "bg-slate-400"
  defp usage_bar_color(used, limit, _status) when used / limit > 0.5, do: "bg-amber-500"
  defp usage_bar_color(_used, _limit, _status), do: "bg-emerald-500"

  # ── Placeholder Data ──

  defp placeholder_discounts do
    [
      %{
        id: "1",
        code: "WELCOME10",
        type: :percentage,
        value_display: "10% off",
        min_purchase: "50",
        used: 128,
        usage_limit: 500,
        status: :active,
        valid_period: "01/01/2026 - 31/12/2026"
      },
      %{
        id: "2",
        code: "FIRSTORDER",
        type: :fixed,
        value_display: "GH\u20B5 20 off",
        min_purchase: "100",
        used: 89,
        usage_limit: 200,
        status: :active,
        valid_period: "01/03/2026 - 30/06/2026"
      },
      %{
        id: "3",
        code: "FREESHIP",
        type: :free_shipping,
        value_display: "Free delivery",
        min_purchase: "200",
        used: 67,
        usage_limit: 100,
        status: :active,
        valid_period: "15/03/2026 - 15/04/2026"
      },
      %{
        id: "4",
        code: "EASTER25",
        type: :percentage,
        value_display: "25% off",
        min_purchase: nil,
        used: 0,
        usage_limit: 50,
        status: :scheduled,
        valid_period: "18/04/2026 - 21/04/2026"
      },
      %{
        id: "5",
        code: "FLASH50",
        type: :percentage,
        value_display: "50% off",
        min_purchase: "500",
        used: 50,
        usage_limit: 50,
        status: :expired,
        valid_period: "01/03/2026 - 07/03/2026"
      },
      %{
        id: "6",
        code: "LOYALTY15",
        type: :percentage,
        value_display: "15% off",
        min_purchase: nil,
        used: 58,
        usage_limit: nil,
        status: :active,
        valid_period: "Ongoing"
      }
    ]
  end
end
