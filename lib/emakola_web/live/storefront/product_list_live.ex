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

  @products_per_page 12

  @impl true
  def mount(_params, session, socket) do
    store = socket.assigns.store
    categories = Emakola.Catalog.list_root_categories!(store.id)
    products = load_active_products(store.id, nil, nil)
    cart_session_id = session["cart_session_id"]

    cart_count =
      if connected?(socket) && cart_session_id,
        do: CartStore.cart_count(cart_session_id, store.id),
        else: 0

    {:ok,
     socket
     |> assign(:categories, categories)
     |> assign(:products, products)
     |> assign(:selected_category, nil)
     |> assign(:search_query, "")
     |> assign(:page, 1)
     |> assign(:has_more, length(products) >= @products_per_page)
     |> assign(:cart_session_id, cart_session_id)
     |> assign(:cart_count, cart_count)
     |> assign(:page_title, "Shop - #{store.name}")
     |> assign(
       :meta_description,
       "Browse the full collection at #{store.name}. Authentic products, secure mobile money checkout, fast delivery across Ghana."
     )
     |> assign(:og_type, "website")
     |> assign(:og_site_name, store.name)
     |> assign_search_defaults()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Canonical pinned to the apex /s/:slug/products (never the request host).
    socket =
      assign(
        socket,
        :canonical_url,
        EmakolaWeb.SEO.Canonical.path(socket.assigns.store, "/products")
      )

    case params do
      %{"q" => query} when query != "" ->
        products = search_active_products(socket.assigns.store.id, String.trim(query))

        {:noreply,
         socket
         |> assign(:search_query, query)
         |> assign(:products, products)
         |> assign(:page, 1)
         |> assign(:has_more, length(products) >= @products_per_page)}

      _ ->
        {:noreply, socket}
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
  def handle_event("search_overlay", %{"value" => query}, socket) do
    query = String.trim(query)

    if query == "" do
      {:noreply,
       socket
       |> assign(:search_overlay_query, "")
       |> assign(:search_overlay_results, [])
       |> assign(:search_overlay_total, 0)
       |> assign(:searching, false)}
    else
      results = search_active_products(socket.assigns.store.id, query)

      {:noreply,
       socket
       |> assign(:search_overlay_query, query)
       |> assign(:search_overlay_results, Enum.take(results, 6))
       |> assign(:search_overlay_total, length(results))
       |> assign(:searching, false)}
    end
  end

  @impl true
  def handle_event("close_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_overlay_query, "")
     |> assign(:search_overlay_results, [])
     |> assign(:search_overlay_total, 0)
     |> assign(:searching, false)}
  end

  @impl true
  def render(assigns) do
    assigns.theme_module.render_product_list(assigns)
  end

  # -- Helpers --

  defp load_active_products(store_id, nil, nil) do
    load_active_products_query(store_id, 0)
  end

  defp load_active_products(store_id, nil, page) do
    offset = ((page || 1) - 1) * @products_per_page
    load_active_products_query(store_id, offset)
  end

  defp load_active_products(store_id, category_id, _page) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_category, %{
      category_id: category_id,
      store_id: store_id,
      status: :active
    })
    |> Ash.Query.limit(@products_per_page)
    |> Ash.read!(authorize?: false)
  end

  defp load_active_products_query(store_id, offset) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store_id, status: :active})
    |> Ash.Query.limit(@products_per_page)
    |> Ash.Query.offset(offset)
    |> Ash.read!(authorize?: false)
  end

  defp search_active_products(store_id, query) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:search, %{query: query, store_id: store_id, status: :active})
    |> Ash.Query.limit(@products_per_page)
    |> Ash.read!(authorize?: false)
  end

  defp assign_search_defaults(socket) do
    socket
    |> assign(:search_overlay_query, "")
    |> assign(:search_overlay_results, [])
    |> assign(:search_overlay_total, 0)
    |> assign(:searching, false)
  end
end
