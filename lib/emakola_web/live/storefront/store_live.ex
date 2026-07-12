defmodule EmakolaWeb.Storefront.StoreLive do
  @moduledoc """
  Store landing page — the customer's first view of a merchant's shop.

  Matches the emakola-storefront-home.html prototype:
  - Story-style category circles (horizontal scroll)
  - Featured product hero card
  - Product grid (2-col mobile, 3-col tablet, 4-col desktop)
  - About section
  """
  use EmakolaWeb, :live_view

  require Logger

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.SEO, as: SEOHelpers

  import EmakolaWeb.StorefrontComponents, only: [coupon_banner: 1]

  @impl true
  def mount(_params, session, socket) do
    store = socket.assigns.store
    products = load_featured_products(store)
    categories = load_root_categories(store)
    public_coupons = load_public_coupons(store)
    delivery_zones = load_delivery_zones(store)
    cart_session_id = session["cart_session_id"]

    cart_count =
      if connected?(socket) && cart_session_id,
        do: CartStore.cart_count(cart_session_id, store.id),
        else: 0

    {:ok,
     socket
     |> assign(:products, products)
     |> assign(:categories, categories)
     |> assign(:public_coupons, public_coupons)
     |> assign(:cart_session_id, cart_session_id)
     |> assign(:cart_count, cart_count)
     |> assign(:page_title, store.name)
     |> assign_seo_metadata(store, products)
     |> assign(:delivery_zones, delivery_zones)
     |> assign(:search_overlay_query, "")
     |> assign(:search_overlay_results, [])
     |> assign(:search_overlay_total, 0)
     |> assign(:searching, false)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Canonical pinned to the apex /s/:slug (never the request host).
    {:noreply,
     assign(socket, :canonical_url, EmakolaWeb.SEO.Canonical.store_url(socket.assigns.store))}
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
      results = search_overlay_products(socket.assigns.store.id, query)
      total = count_search_results(socket.assigns.store.id, query)

      {:noreply,
       socket
       |> assign(:search_overlay_query, query)
       |> assign(:search_overlay_results, Enum.take(results, 6))
       |> assign(:search_overlay_total, total)
       |> assign(:searching, false)}
    end
  end

  @impl true
  def handle_event("add_to_cart", %{"product-id" => product_id}, socket) do
    case Emakola.Catalog.get_active_product(socket.assigns.store.id, product_id,
           authorize?: false
         ) do
      {:ok, product} ->
        product = Ash.load!(product, [:variants, :images], authorize?: false)
        variant = product.variants |> Enum.sort_by(& &1.position) |> List.first()

        if variant && Emakola.Catalog.Variant.in_stock?(variant) do
          image_url =
            case product.images do
              [img | _] -> img.thumbnail_url || img.url
              _ -> nil
            end

          CartStore.add_item(socket.assigns.cart_session_id, socket.assigns.store.id, %{
            variant_id: variant.id,
            quantity: 1,
            product_title: product.title,
            variant_info: variant.sku || "",
            unit_price: variant.price,
            sku: variant.sku,
            image_url: image_url
          })

          cart_count =
            CartStore.cart_count(socket.assigns.cart_session_id, socket.assigns.store.id)

          {:noreply,
           socket
           |> assign(:cart_count, cart_count)
           |> put_flash(:info, "#{product.title} added to cart")}
        else
          {:noreply, put_flash(socket, :error, "This product is out of stock")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Product not found")}
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
    ~H"""
    <div>
      <div :if={@public_coupons != []} class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-2">
        <.coupon_banner coupons={@public_coupons} store={@store} />
      </div>
      {render_theme_home(assigns)}
    </div>
    """
  end

  # Page-builder override: if the merchant has a published page at slug
  # "home", render it via the page-builder pipeline. Otherwise fall through
  # to the active theme's home renderer (existing behaviour, zero risk to
  # stores that haven't opted in).
  defp render_theme_home(assigns) do
    case Emakola.Pages.fetch_published_page(assigns.store, "home") do
      {:ok, page} ->
        Emakola.PageBuilder.Renderer.page(%{
          __changed__: nil,
          page: page,
          store: assigns.store,
          products: assigns[:products] || [],
          categories: assigns[:categories] || []
        })

      :not_found ->
        assigns.theme_module.render_home(assigns)
    end
  end

  # -- Helpers --

  defp load_featured_products(store) do
    # Variants feed the theme cards' sale (compare-at) and sold-out states.
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
    |> Ash.Query.limit(8)
    |> Ash.Query.load(:variants)
    |> Ash.read!(authorize?: false)
  end

  defp load_root_categories(store) do
    Emakola.Catalog.list_root_categories!(store.id)
  end

  defp load_public_coupons(store) do
    case Emakola.Marketing.list_active_public_coupons(store.id) do
      {:ok, coupons} -> coupons
      _ -> []
    end
  end

  defp load_delivery_zones(store) do
    try do
      Emakola.Shipping.list_delivery_zones!(store.id)
      |> Enum.filter(& &1.active)
    rescue
      exception ->
        Logger.error(
          "[store_live] load_delivery_zones loading delivery zones raised: #{Exception.message(exception)}"
        )

        []
    end
  end

  defp search_overlay_products(store_id, query) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:search, %{query: query, store_id: store_id, status: :active})
    |> Ash.Query.limit(10)
    |> Ash.read!(authorize?: false)
  end

  defp count_search_results(store_id, query) do
    result =
      Emakola.Catalog.Product
      |> Ash.Query.for_read(:search, %{query: query, store_id: store_id, status: :active})
      |> Ash.count(authorize?: false)

    case result do
      {:ok, n} -> n
      _ -> 0
    end
  end

  # -- SEO --

  # Sets meta_description, og_image, og_type, and Store JSON-LD for the
  # storefront home page. These flow to the root layout and get rendered
  # as OG/Twitter/JSON-LD tags, so WhatsApp and Google show rich previews
  # when the merchant's store URL is shared.
  defp assign_seo_metadata(socket, store, products) do
    description = store_description_for_seo(store)
    og_image = first_featured_product_image(products) || store_logo_url(store)
    json_ld = SEOHelpers.json_ld_local_business(store)

    socket
    |> assign(:meta_description, description)
    |> assign(:og_image, og_image)
    |> assign(:og_type, "website")
    |> assign(:og_site_name, store.name)
    |> assign(:json_ld, json_ld)
  end

  defp store_description_for_seo(store) do
    raw =
      Map.get(store, :description) ||
        Map.get(store, :tagline) ||
        "Shop authentic products from #{store.name} — fast delivery, mobile money accepted."

    raw
    |> to_string()
    |> String.trim()
    |> truncate_at_word(155)
  end

  defp first_featured_product_image([first | _]) when is_map(first) do
    case Map.get(first, :images) do
      [img | _] when is_map(img) ->
        Map.get(img, :medium_url) || Map.get(img, :url)

      _ ->
        nil
    end
  end

  defp first_featured_product_image(_), do: nil

  defp store_logo_url(store) do
    Map.get(store, :logo_url)
  end

  defp truncate_at_word(str, max) when byte_size(str) <= max, do: str

  defp truncate_at_word(str, max) do
    str
    |> binary_part(0, max)
    |> String.trim_trailing()
    |> String.replace(~r/\s+\S*$/, "")
    |> Kernel.<>("…")
  end
end
