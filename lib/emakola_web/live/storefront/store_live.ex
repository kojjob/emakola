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

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  import EmakolaWeb.StorefrontComponents, only: [coupon_banner: 1]

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        products = load_featured_products(store)
        categories = load_root_categories(store)
        public_coupons = load_public_coupons(store)
        cart_session_id = session["cart_session_id"]
        cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

        theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{})
        theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:products, products)
         |> assign(:categories, categories)
         |> assign(:public_coupons, public_coupons)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart_count, cart_count)
         |> assign(:page_title, store.name)
         |> assign(:theme, theme)
         |> assign(:theme_module, theme_module)
         |> assign(:theme_fonts, theme_module.fonts())
         |> assign(:search_overlay_query, "")
         |> assign(:search_overlay_results, [])
         |> assign(:search_overlay_total, 0)
         |> assign(:searching, false)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
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
    ~H"""
    <div>
      <div :if={@public_coupons != []} class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-2">
        <.coupon_banner coupons={@public_coupons} store={@store} />
      </div>
      {render_theme_home(assigns)}
    </div>
    """
  end

  defp render_theme_home(assigns) do
    assigns.theme_module.render_home(assigns)
  end

  # -- Helpers --

  defp load_featured_products(store) do
    Emakola.Catalog.list_products_by_store_and_status!(store.id, :active)
    |> Ash.load!([:min_price, :max_price, :images])
    |> Enum.take(8)
  end

  defp load_root_categories(store) do
    Emakola.Catalog.list_root_categories!(store.id)
  end

  defp load_public_coupons(store) do
    case Emakola.Orders.list_active_public_coupons(store.id) do
      {:ok, coupons} -> coupons
      _ -> []
    end
  end

  defp search_overlay_products(store_id, query) do
    Emakola.Catalog.search_products!(query, store_id)
    |> Enum.filter(&(&1.status == :active))
    |> Ash.load!([:min_price, :max_price, :images])
  end
end
