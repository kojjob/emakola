defmodule EmakolaWeb.Storefront.ProductListLive do
  @moduledoc """
  Product listing page — shows all active products for a store with
  category filtering, search, and pagination.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

  require Ash.Query

  @products_per_page 12

  @impl true
  def mount(%{"store_slug" => slug}, _session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        categories = Emakola.Catalog.list_root_categories!(store.id)
        products = load_active_products(store.id, nil, nil)

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:categories, categories)
         |> assign(:products, products)
         |> assign(:selected_category, nil)
         |> assign(:search_query, "")
         |> assign(:page, 1)
         |> assign(:has_more, length(products) >= @products_per_page)
         |> assign(:cart, [])
         |> assign(:cart_count, 0)
         |> assign(:page_title, "Products - #{store.name}")
         |> assign(:meta_description, "Browse products from #{store.name}")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    products =
      if String.trim(query) == "" do
        load_active_products(socket.assigns.store.id, socket.assigns.selected_category, nil)
      else
        search_active_products(socket.assigns.store.id, String.trim(query))
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:products, products)
     |> assign(:page, 1)
     |> assign(:has_more, length(products) >= @products_per_page)}
  end

  @impl true
  def handle_event("filter_category", %{"category_id" => "all"}, socket) do
    products = load_active_products(socket.assigns.store.id, nil, nil)

    {:noreply,
     socket
     |> assign(:selected_category, nil)
     |> assign(:products, products)
     |> assign(:search_query, "")
     |> assign(:page, 1)
     |> assign(:has_more, length(products) >= @products_per_page)}
  end

  @impl true
  def handle_event("filter_category", %{"category_id" => category_id}, socket) do
    products = load_active_products(socket.assigns.store.id, category_id, nil)

    {:noreply,
     socket
     |> assign(:selected_category, category_id)
     |> assign(:products, products)
     |> assign(:search_query, "")
     |> assign(:page, 1)
     |> assign(:has_more, length(products) >= @products_per_page)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    next_page = socket.assigns.page + 1

    new_products =
      load_active_products(
        socket.assigns.store.id,
        socket.assigns.selected_category,
        next_page
      )

    {:noreply,
     socket
     |> assign(:products, socket.assigns.products ++ new_products)
     |> assign(:page, next_page)
     |> assign(:has_more, length(new_products) >= @products_per_page)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 py-6">
      <h1 class="text-2xl font-bold text-gray-900 mb-6">Products</h1>

      <div class="flex flex-col sm:flex-row gap-6">
        <!-- Category sidebar -->
        <aside class="w-full sm:w-48 flex-shrink-0">
          <details class="sm:open" open>
            <summary class="sm:hidden cursor-pointer text-sm font-semibold text-gray-700 mb-2">
              Filter by Category
            </summary>
            <nav class="flex flex-col gap-1">
              <button
                phx-click="filter_category"
                phx-value-category_id="all"
                class={[
                  "text-left text-sm px-3 py-2 rounded-lg transition-colors",
                  if(is_nil(@selected_category),
                    do: "bg-indigo-50 text-indigo-700 font-semibold",
                    else: "text-gray-600 hover:bg-gray-50"
                  )
                ]}
              >
                All Products
              </button>
              <button
                :for={cat <- @categories}
                phx-click="filter_category"
                phx-value-category_id={cat.id}
                class={[
                  "text-left text-sm px-3 py-2 rounded-lg transition-colors",
                  if(@selected_category == cat.id,
                    do: "bg-indigo-50 text-indigo-700 font-semibold",
                    else: "text-gray-600 hover:bg-gray-50"
                  )
                ]}
              >
                {cat.name}
              </button>
            </nav>
          </details>
        </aside>
        <!-- Products grid -->
        <div class="flex-1">
          <!-- Search -->
          <form phx-change="search" class="mb-6">
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search products..."
              phx-debounce="300"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
            />
          </form>

          <%= if @products == [] do %>
            <p class="text-center text-gray-500 py-12">No products found.</p>
          <% else %>
            <div class="grid grid-cols-2 sm:grid-cols-3 gap-4">
              <.product_card :for={product <- @products} product={product} store={@store} />
            </div>

            <div :if={@has_more} class="mt-8 text-center">
              <button
                phx-click="load_more"
                class="px-6 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
              >
                Load more
              </button>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # -- Components --

  defp product_card(assigns) do
    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="group block bg-white rounded-lg border border-gray-200 overflow-hidden hover:shadow-md transition-shadow"
    >
      <div class="aspect-square bg-gray-100 flex items-center justify-center">
        <%= if first_image(@product) do %>
          <img
            src={first_image(@product)}
            alt={@product.title}
            loading="lazy"
            class="w-full h-full object-cover"
          />
        <% else %>
          <svg
            class="w-12 h-12 text-gray-300"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
        <% end %>
      </div>
      <div class="p-3">
        <h3 class="text-sm font-medium text-gray-900 truncate group-hover:text-indigo-600">
          {@product.title}
        </h3>
        <p class="mt-1 text-sm font-semibold text-gray-700">
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
      </div>
    </a>
    """
  end

  # -- Helpers --

  defp load_active_products(store_id, nil, nil) do
    Emakola.Catalog.list_products_by_store_and_status!(store_id, :active)
    |> Ash.load!([:min_price, :max_price, :images])
    |> Enum.take(@products_per_page)
  end

  defp load_active_products(store_id, nil, page) do
    Emakola.Catalog.list_products_by_store_and_status!(store_id, :active)
    |> Ash.load!([:min_price, :max_price, :images])
    |> Enum.drop((page - 1) * @products_per_page)
    |> Enum.take(@products_per_page)
  end

  defp load_active_products(store_id, category_id, _page) do
    Emakola.Catalog.list_products_by_category!(category_id, store_id)
    |> Enum.filter(&(&1.status == :active))
    |> Ash.load!([:min_price, :max_price, :images])
    |> Enum.take(@products_per_page)
  end

  defp search_active_products(store_id, query) do
    Emakola.Catalog.search_products!(query, store_id)
    |> Enum.filter(&(&1.status == :active))
    |> Ash.load!([:min_price, :max_price, :images])
    |> Enum.take(@products_per_page)
  end

  defp first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end
end
