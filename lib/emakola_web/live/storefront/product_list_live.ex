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

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  @products_per_page 12

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        categories = Emakola.Catalog.list_root_categories!(store.id)
        products = load_active_products(store.id, nil, nil)
        cart_session_id = session["cart_session_id"]
        cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:categories, categories)
         |> assign(:products, products)
         |> assign(:selected_category, nil)
         |> assign(:search_query, "")
         |> assign(:page, 1)
         |> assign(:has_more, length(products) >= @products_per_page)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart_count, cart_count)
         |> assign(:page_title, "Shop - #{store.name}")
         |> assign(:theme, Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{}))
         |> assign(
           :theme_module,
           Emakola.Themes.ThemeResolver.theme_module(
             (store.theme_config || %{})["theme"] || "market"
           )
         )}

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
    assigns.theme_module.render_product_list(assigns)
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
end
