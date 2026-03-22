defmodule EmakolaWeb.Admin.ProductLive.Index do
  @moduledoc """
  Lists all products for the current store with search, status filtering,
  and mobile-responsive layout optimized for West African merchants.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  # TODO: Get store_id from authenticated merchant's session
  @test_store_id "00000000-0000-0000-0000-000000000001"

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Products",
        active_nav: :products,
        store_id: store_id,
        search_query: "",
        status_filter: :all,
        products: [],
        categories: %{}
      )
      |> load_products()
      |> load_categories()

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    socket =
      socket
      |> assign(search_query: query)
      |> load_products()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom =
      case status do
        "all" -> :all
        "draft" -> :draft
        "active" -> :active
        "archived" -> :archived
        _ -> :all
      end

    socket =
      socket
      |> assign(status_filter: status_atom)
      |> load_products()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold font-headline tracking-tight">Products</h1>
          <p class="text-sm text-on-surface-variant mt-1">
            Manage your store catalog
          </p>
        </div>
        <.link
          navigate={~p"/admin/products/new"}
          class="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg text-sm font-semibold
                 bg-emerald-600 text-white hover:bg-emerald-700 active:scale-95 transition-all
                 shadow-sm w-full sm:w-auto justify-center"
        >
          <.icon name="hero-plus" class="size-4" /> New Product
        </.link>
      </div>

      <%!-- Search & Filters --%>
      <div class="flex flex-col sm:flex-row gap-3">
        <form phx-change="search" phx-debounce="300" class="flex-1">
          <div class="relative">
            <.icon
              name="hero-magnifying-glass"
              class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-on-surface-variant"
            />
            <input
              type="text"
              name="search"
              value={@search_query}
              placeholder="Search products..."
              class="w-full pl-10 pr-4 py-2.5 text-sm rounded-lg border border-surface-container-highest
                     bg-surface-container-lowest focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500
                     placeholder:text-on-surface-variant/50"
              autocomplete="off"
            />
          </div>
        </form>

        <div class="flex gap-1 bg-surface-container rounded-lg p-1 overflow-x-auto">
          <.status_tab status={:all} current={@status_filter} label="All" />
          <.status_tab status={:draft} current={@status_filter} label="Draft" />
          <.status_tab status={:active} current={@status_filter} label="Active" />
          <.status_tab status={:archived} current={@status_filter} label="Archived" />
        </div>
      </div>

      <%!-- Product List --%>
      <%= if @products == [] do %>
        <div class="text-center py-16 bg-surface-container-lowest rounded-lg">
          <.icon name="hero-cube" class="size-12 mx-auto text-on-surface-variant/30 mb-3" />
          <p class="text-on-surface-variant font-medium">No products found</p>
          <p class="text-sm text-on-surface-variant/60 mt-1">
            <%= if @search_query != "" or @status_filter != :all do %>
              Try adjusting your search or filters
            <% else %>
              Get started by adding your first product
            <% end %>
          </p>
        </div>
      <% else %>
        <%!-- Desktop Table (hidden on mobile) --%>
        <div class="hidden md:block bg-surface-container-lowest rounded-lg overflow-hidden">
          <table class="w-full">
            <thead>
              <tr class="border-b border-surface-container text-left text-xs font-mono uppercase tracking-wider text-on-surface-variant">
                <th class="px-4 py-3">Product</th>
                <th class="px-4 py-3">Status</th>
                <th class="px-4 py-3">Category</th>
                <th class="px-4 py-3 text-right">Variants</th>
                <th class="px-4 py-3 text-right">Price</th>
                <th class="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={product <- @products}
                class="border-b border-surface-container/50 hover:bg-surface-container-high/30 transition-colors"
              >
                <td class="px-4 py-3">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-lg bg-surface-container flex items-center justify-center flex-shrink-0">
                      <.icon name="hero-photo" class="size-5 text-on-surface-variant/40" />
                    </div>
                    <span class="font-medium text-sm truncate max-w-[200px]">{product.title}</span>
                  </div>
                </td>
                <td class="px-4 py-3">
                  <.status_badge status={product.status} />
                </td>
                <td class="px-4 py-3 text-sm text-on-surface-variant">
                  {category_name(product.category_id, @categories)}
                </td>
                <td class="px-4 py-3 text-sm text-right font-mono text-on-surface-variant">
                  {variant_count(product)} variants
                </td>
                <td class="px-4 py-3 text-sm text-right font-mono font-medium">
                  {price_range(product)}
                </td>
                <td class="px-4 py-3 text-right">
                  <.link
                    navigate={~p"/admin/products/#{product.id}/edit"}
                    class="text-emerald-600 hover:text-emerald-700 text-sm font-medium"
                  >
                    Edit
                  </.link>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Mobile Cards (hidden on desktop) --%>
        <div class="md:hidden space-y-3">
          <div
            :for={product <- @products}
            class="bg-surface-container-lowest rounded-lg p-4 space-y-3"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="flex items-center gap-3 min-w-0">
                <div class="w-12 h-12 rounded-lg bg-surface-container flex items-center justify-center flex-shrink-0">
                  <.icon name="hero-photo" class="size-6 text-on-surface-variant/40" />
                </div>
                <div class="min-w-0">
                  <p class="font-medium text-sm truncate">{product.title}</p>
                  <p class="text-xs text-on-surface-variant">
                    {category_name(product.category_id, @categories)}
                  </p>
                </div>
              </div>
              <.status_badge status={product.status} />
            </div>
            <div class="flex items-center justify-between text-sm">
              <span class="text-on-surface-variant font-mono">
                {variant_count(product)} variants
              </span>
              <span class="font-mono font-medium">{price_range(product)}</span>
            </div>
            <.link
              navigate={~p"/admin/products/#{product.id}/edit"}
              class="block text-center py-2 rounded-lg border border-emerald-200 text-emerald-700
                     text-sm font-medium hover:bg-emerald-50 transition-colors"
            >
              Edit Product
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Components ──

  attr :status, :atom, required: true
  attr :current, :atom, required: true
  attr :label, :string, required: true

  defp status_tab(assigns) do
    ~H"""
    <button
      phx-click="filter_status"
      phx-value-status={@status}
      class={[
        "px-3 py-1.5 text-sm font-medium rounded-md transition-colors whitespace-nowrap",
        if(@status == @current,
          do: "bg-surface-container-lowest text-on-surface shadow-sm",
          else: "text-on-surface-variant hover:text-on-surface"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
      status_badge_class(@status)
    ]}>
      {@status |> to_string() |> String.capitalize()}
    </span>
    """
  end

  # ── Data Loading ──

  defp load_products(socket) do
    %{store_id: store_id, search_query: query, status_filter: status} = socket.assigns

    products =
      try do
        cond do
          query != "" ->
            Emakola.Catalog.search_products!(query, store_id)

          status != :all ->
            Emakola.Catalog.list_products_by_store_and_status!(store_id, status)

          true ->
            Emakola.Catalog.list_products_by_store!(store_id)
        end
      rescue
        _ -> []
      end

    assign(socket, products: products)
  end

  defp load_categories(socket) do
    categories =
      try do
        socket.assigns.store_id
        |> then(&Emakola.Catalog.list_categories_by_store!/1)
        |> Map.new(fn cat -> {cat.id, cat.name} end)
      rescue
        _ -> %{}
      end

    assign(socket, categories: categories)
  end

  # ── Helpers ──

  defp get_store_id(_socket) do
    # TODO: Get store_id from authenticated merchant's session
    @test_store_id
  end

  defp status_badge_class(:draft), do: "bg-gray-100 text-gray-700"
  defp status_badge_class(:active), do: "bg-green-100 text-green-700"
  defp status_badge_class(:archived), do: "bg-red-100 text-red-700"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-700"

  defp category_name(nil, _categories), do: "Uncategorized"
  defp category_name(id, categories), do: Map.get(categories, id, "Uncategorized")

  defp variant_count(_product) do
    # TODO: Load variant count via relationship or aggregation
    0
  end

  defp price_range(_product) do
    # TODO: Load price range from variants
    "GH\u20B5 0.00"
  end
end
