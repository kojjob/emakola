defmodule EmakolaWeb.Storefront.ProductListLive do
  @moduledoc """
  Product listing page — matches shop.html prototype.

  Features:
  - Breadcrumb navigation
  - Page header with product count
  - Desktop filter sidebar with categories
  - Search bar with debounce
  - Product grid (2-col mobile, 3-col tablet, 4-col desktop)
  - Product cards with hover overlay, image swap effect
  - Load more pagination
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
         |> assign(:page_title, "Shop - #{store.name}")}

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
  def handle_event("filter_category_select", %{"category_id" => "all"}, socket) do
    handle_event("filter_category", %{"category_id" => "all"}, socket)
  end

  def handle_event("filter_category_select", %{"category_id" => category_id}, socket) do
    handle_event("filter_category", %{"category_id" => category_id}, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
      <%!-- Breadcrumb --%>
      <nav aria-label="Breadcrumb" class="pt-6 pb-4">
        <ol class="flex items-center gap-2 text-xs text-[#475569]">
          <li>
            <a href={"/s/#{@store.slug}"} class="hover:text-[#0F172A] transition-colors">Home</a>
          </li>
          <li>
            <svg
              class="w-3 h-3 inline"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="m9 5 7 7-7 7" />
            </svg>
          </li>
          <li class="text-[#0F172A] font-medium">Shop</li>
        </ol>
      </nav>

      <%!-- Page header --%>
      <div class="flex items-end justify-between gap-4 pb-6">
        <div>
          <h1 class="text-3xl sm:text-4xl font-bold text-[#0F172A]">Shop All</h1>
          <p class="text-sm text-[#475569] mt-1">{length(@products)} products</p>
        </div>
      </div>

      <%!-- Main content: sidebar + products --%>
      <div class="flex gap-8 pb-16">
        <%!-- Filter sidebar (desktop) --%>
        <aside class="hidden lg:block w-64 flex-shrink-0">
          <div class="sticky top-24 space-y-6">
            <%!-- Category filter --%>
            <div>
              <h3 class="text-lg font-semibold text-[#0F172A] mb-3">Category</h3>
              <div class="space-y-2.5">
                <label class="flex items-center gap-3 cursor-pointer group">
                  <input
                    type="radio"
                    name="category"
                    checked={is_nil(@selected_category)}
                    phx-click="filter_category"
                    phx-value-category_id="all"
                    class="w-[18px] h-[18px] accent-[#1C1917] cursor-pointer"
                  />
                  <span class={"text-sm group-hover:text-[#0F172A] transition-colors #{if is_nil(@selected_category), do: "text-[#0F172A] font-medium", else: "text-[#475569]"}"}>
                    All
                  </span>
                </label>
                <label :for={cat <- @categories} class="flex items-center gap-3 cursor-pointer group">
                  <input
                    type="radio"
                    name="category"
                    checked={@selected_category == cat.id}
                    phx-click="filter_category"
                    phx-value-category_id={cat.id}
                    class="w-[18px] h-[18px] accent-[#1C1917] cursor-pointer"
                  />
                  <span class={"text-sm group-hover:text-[#0F172A] transition-colors #{if @selected_category == cat.id, do: "text-[#0F172A] font-medium", else: "text-[#475569]"}"}>
                    {cat.name}
                  </span>
                </label>
              </div>
            </div>
          </div>
        </aside>

        <%!-- Product grid area --%>
        <div class="flex-1 min-w-0">
          <%!-- Mobile filter + Sort bar --%>
          <div class="flex items-center gap-3 mb-6 lg:mb-6">
            <%!-- Mobile category filter --%>
            <div class="lg:hidden flex-1">
              <select
                phx-change="filter_category_select"
                name="category_id"
                class="w-full px-3 py-2.5 border border-[#E2E8F0] rounded-lg text-sm text-[#0F172A] bg-white focus:outline-none focus:ring-2 focus:ring-[#B45309] appearance-none bg-[url('data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20width%3D%2212%22%20height%3D%2212%22%20viewBox%3D%220%200%2024%2024%22%20fill%3D%22none%22%20stroke%3D%22%2344403C%22%20stroke-width%3D%222%22%3E%3Cpath%20d%3D%22M6%209l6%206%206-6%22/%3E%3C/svg%3E')] bg-no-repeat bg-[right_12px_center]"
              >
                <option value="all" selected={is_nil(@selected_category)}>All Categories</option>
                <option
                  :for={cat <- @categories}
                  value={cat.id}
                  selected={@selected_category == cat.id}
                >
                  {cat.name}
                </option>
              </select>
            </div>

            <%!-- Search --%>
            <form phx-change="search" class="flex-1 lg:max-w-sm">
              <div class="relative">
                <svg
                  class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#94A3B8]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z"
                  />
                </svg>
                <input
                  type="text"
                  name="query"
                  value={@search_query}
                  placeholder="Search products..."
                  phx-debounce="300"
                  class="w-full pl-9 pr-4 py-2.5 border border-[#E2E8F0] rounded-lg text-sm text-[#0F172A] bg-white placeholder:text-[#94A3B8] focus:outline-none focus:ring-2 focus:ring-[#B45309] focus:border-transparent"
                />
              </div>
            </form>
          </div>

          <%!-- Products --%>
          <%= if @products == [] do %>
            <div class="py-20 text-center">
              <svg
                class="w-16 h-16 mx-auto text-[#E2E8F0] mb-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007ZM8.625 10.5a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm7.5 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
                />
              </svg>
              <p class="text-[#475569]">No products found.</p>
              <button
                :if={@search_query != "" || @selected_category}
                phx-click="filter_category"
                phx-value-category_id="all"
                class="mt-4 text-sm font-medium text-[#B45309] hover:text-[#92400E] transition-colors"
              >
                Clear filters
              </button>
            </div>
          <% else %>
            <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-4 gap-3 sm:gap-4 lg:gap-5">
              <.product_card :for={product <- @products} product={product} store={@store} />
            </div>

            <div :if={@has_more} class="mt-10 text-center">
              <button
                phx-click="load_more"
                class="inline-flex items-center gap-2 px-8 py-3 border border-[#E2E8F0] rounded-lg text-sm font-semibold text-[#0F172A] bg-white hover:bg-[#F1F5F9] transition-colors"
              >
                Load More
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M19.5 13.5 12 21m0 0-7.5-7.5M12 21V3"
                  />
                </svg>
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
      class="group block"
    >
      <div class="relative rounded-[16px] overflow-hidden mb-2 bg-[#F1F5F9]">
        <%= if first_image(@product) do %>
          <img
            src={first_image(@product)}
            alt={@product.title}
            loading="lazy"
            class="w-full aspect-[3/4] object-cover group-hover:scale-105 transition-transform duration-500"
          />
        <% else %>
          <div class="w-full aspect-[3/4] flex items-center justify-center">
            <svg
              class="w-12 h-12 text-[#94A3B8]"
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
          </div>
        <% end %>
        <%!-- Quick add overlay --%>
        <div class="absolute bottom-0 left-0 right-0 p-3 translate-y-full group-hover:translate-y-0 transition-transform duration-300">
          <span class="flex items-center justify-center w-full py-2.5 bg-white/95 backdrop-blur-sm rounded-lg text-xs font-semibold text-[#0F172A] tracking-wide shadow-sm">
            Quick View
          </span>
        </div>
      </div>
      <p class="text-sm font-medium text-[#0F172A] leading-tight mb-1 truncate group-hover:text-[#B45309] transition-colors">
        {@product.title}
      </p>
      <p class="text-sm font-bold text-[#0F172A]">
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>
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
