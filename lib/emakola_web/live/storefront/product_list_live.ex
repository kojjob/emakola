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
  def mount(params, session, socket) do
    store = socket.assigns.store
    categories = Emakola.Catalog.list_root_categories!(store.id)
    initial_query = Map.get(params, "q", "")

    products =
      if String.trim(initial_query) == "" do
        load_active_products(store.id, nil, nil)
      else
        search_active_products(store.id, String.trim(initial_query))
      end

    cart_session_id = session["cart_session_id"]

    cart_count =
      if connected?(socket) && cart_session_id,
        do: CartStore.cart_count(cart_session_id, store.id),
        else: 0

    {:ok,
     socket
     |> assign(:categories, categories)
     |> assign(:products_count, length(products))
     |> assign(:selected_category, nil)
     |> assign(:search_query, initial_query)
     |> assign(:page, 1)
     |> assign(:has_more, length(products) >= @products_per_page)
     |> assign(:cart_session_id, cart_session_id)
     |> assign(:cart_count, cart_count)
     |> assign(:page_title, "Shop - #{store.name}")
     |> assign(
       :meta_description,
       "Browse products from #{store.name} with current prices, options, availability, delivery information, and store policies."
     )
     |> assign(:og_type, "website")
     |> assign(:og_site_name, store.name)
     |> assign(:robots, if(products == [], do: "noindex, follow", else: "index, follow"))
     |> assign_search_defaults()
     |> stream(:products, product_stream_items(products))}
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

    query = Map.get(params, "q", "")

    products =
      if String.trim(query) == "" do
        load_active_products(socket.assigns.store.id, nil, nil)
      else
        search_active_products(socket.assigns.store.id, String.trim(query))
      end

    {:noreply,
     socket
     |> assign(:selected_category, nil)
     |> assign(:search_query, query)
     |> assign(:page, 1)
     |> assign(:has_more, length(products) >= @products_per_page)
     |> reset_product_stream(products)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    products =
      if String.trim(query) == "" do
        load_active_products(socket.assigns.store.id, socket.assigns.selected_category, nil)
      else
        search_active_products(socket.assigns.store.id, String.trim(query))
      end

    if String.trim(query) != "" do
      Emakola.Suppliers.OpportunitySignals.track_search(socket.assigns.store.id, query, products)
    end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:page, 1)
     |> assign(:has_more, length(products) >= @products_per_page)
     |> reset_product_stream(products)}
  end

  @impl true
  def handle_event("filter_category", %{"category_id" => "all"}, socket) do
    products = load_active_products(socket.assigns.store.id, nil, nil)

    {:noreply,
     socket
     |> assign(:selected_category, nil)
     |> assign(:search_query, "")
     |> assign(:page, 1)
     |> assign(:has_more, length(products) >= @products_per_page)
     |> reset_product_stream(products)}
  end

  @impl true
  def handle_event("filter_category", %{"category_id" => category_id}, socket) do
    products = load_active_products(socket.assigns.store.id, category_id, nil)

    {:noreply,
     socket
     |> assign(:selected_category, category_id)
     |> assign(:search_query, "")
     |> assign(:page, 1)
     |> assign(:has_more, length(products) >= @products_per_page)
     |> reset_product_stream(products)}
  end

  @impl true
  # Product cards are theme chrome and several themes put a quick-add button on
  # this page. Without this clause the button raised FunctionClauseError and took
  # the page down — the same button works fine on the home page.
  def handle_event("add_to_cart", %{"product-id" => product_id}, socket) do
    EmakolaWeb.Storefront.QuickAdd.add_to_cart(socket, product_id)
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    next_page = socket.assigns.page + 1

    query = String.trim(socket.assigns.search_query)

    new_products =
      if query == "" do
        load_active_products(
          socket.assigns.store.id,
          socket.assigns.selected_category,
          next_page
        )
      else
        search_active_products(socket.assigns.store.id, query, next_page)
      end

    {:noreply,
     socket
     |> assign(:page, next_page)
     |> assign(:has_more, length(new_products) >= @products_per_page)
     |> assign(:products_count, socket.assigns.products_count + length(new_products))
     |> stream(
       :products,
       product_stream_items(new_products, socket.assigns.products_count)
     )}
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

  defp load_active_products(store_id, category_id, page) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_category, %{
      category_id: category_id,
      store_id: store_id,
      status: :active
    })
    |> paginate(page)
    |> Ash.read!(authorize?: false)
  end

  defp load_active_products_query(store_id, offset) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store_id, status: :active})
    |> Ash.Query.sort(inserted_at: :desc, id: :desc)
    |> Ash.Query.limit(@products_per_page)
    |> Ash.Query.offset(offset)
    |> Ash.read!(authorize?: false)
  end

  defp search_active_products(store_id, query, page \\ 1) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:search, %{query: query, store_id: store_id, status: :active})
    |> paginate(page)
    |> Ash.read!(authorize?: false)
  end

  defp paginate(query, page) do
    offset = ((page || 1) - 1) * @products_per_page

    query
    |> Ash.Query.sort(inserted_at: :desc, id: :desc)
    |> Ash.Query.limit(@products_per_page)
    |> Ash.Query.offset(offset)
  end

  defp reset_product_stream(socket, products) do
    socket
    |> assign(:products_count, length(products))
    |> stream(:products, product_stream_items(products), reset: true)
  end

  defp product_stream_items(products, offset \\ 0) do
    products
    |> Enum.with_index(offset + 1)
    |> Enum.map(fn {product, position} ->
      %{id: product.id, product: product, position: position}
    end)
  end

  defp assign_search_defaults(socket) do
    socket
    |> assign(:search_overlay_query, "")
    |> assign(:search_overlay_results, [])
    |> assign(:search_overlay_total, 0)
    |> assign(:searching, false)
  end
end
