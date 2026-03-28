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

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        products = load_featured_products(store)
        categories = load_root_categories(store)
        cart_session_id = session["cart_session_id"]
        cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

        theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{})
        theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

        public_coupons = load_public_coupons(store)
        delivery_zones = load_delivery_zones(store)

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:products, products)
         |> assign(:categories, categories)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart_count, cart_count)
         |> assign(:page_title, store.name)
         |> assign(:theme, theme)
         |> assign(:theme_module, theme_module)
         |> assign(:theme_fonts, theme_module.fonts())
         |> assign(:public_coupons, public_coupons)
         |> assign(:delivery_zones, delivery_zones)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
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
    now = DateTime.utc_now()

    Emakola.Orders.list_coupons_by_store!(store.id)
    |> Enum.filter(fn coupon ->
      coupon.active &&
        (is_nil(coupon.starts_at) || DateTime.compare(coupon.starts_at, now) != :gt) &&
        (is_nil(coupon.expires_at) || DateTime.compare(coupon.expires_at, now) != :lt) &&
        (is_nil(coupon.max_uses) || coupon.uses_count < coupon.max_uses)
    end)
  end

  defp load_delivery_zones(store) do
    Emakola.Shipping.list_delivery_zones!(store.id)
    |> Enum.filter(& &1.active)
  end
end
