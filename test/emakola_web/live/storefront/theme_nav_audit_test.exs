defmodule EmakolaWeb.Storefront.ThemeNavAuditTest do
  @moduledoc """
  Every theme, every shopping page: can a customer actually reach the cart?

  The storefront layout renders its fallback header only via
  `<header :if={!assigns[:theme_module]}>` — it assumes every theme supplies
  its own nav. When a theme doesn't, the safety net is silently switched off
  and shoppers are left with no route to checkout. Market shipped that way for
  ~82% of live stores and nobody noticed.

  The assertion is deliberately NOT "a cart link exists somewhere in the
  markup". The shared `bottom_nav/1` is `sm:hidden` — mobile only — so a page
  can carry a cart link and still strand every desktop shopper. That is exactly
  how Market's product list was broken, and a grep-for-`/cart` test would have
  passed on it. So we count cart links that are *not* inside the mobile-only
  bar, and require at least one.

  It also does not care which element the nav uses: Atelier reaches the cart
  from a `<nav>`, Vibrant from a `<header>`. Both are fine. Reachability is the
  requirement; markup taste is not.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Themes.ThemeResolver

  # The shared mobile bar. Anything inside it is invisible from `sm` upward.
  @mobile_only_bar ~s(nav[class~="sm:hidden"])
  @cart_link ~s(a[href$="/cart"])

  defp cart_reachable_on_desktop?(html) do
    doc = LazyHTML.from_document(html)

    total = doc |> LazyHTML.query(@cart_link) |> Enum.count()
    mobile_only = doc |> LazyHTML.query("#{@mobile_only_bar} #{@cart_link}") |> Enum.count()

    total > mobile_only
  end

  defp store_on_theme!(theme_id) do
    store = Factory.create_store!(%{currency: "GHS"})

    store
    |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => theme_id}})
    |> Ash.update!(authorize?: false)
  end

  defp stocked_product!(store) do
    product = Factory.create_product!(store, %{title: "Kente Wrap"})
    _variant = Factory.create_variant!(product, store, %{price: 12_000, stock_quantity: 5})

    product
    |> Ash.Changeset.for_update(:activate, %{}, authorize?: false)
    |> Ash.update!(authorize?: false)
  end

  # Sourced from the resolver itself, so a theme added to @theme_modules is
  # audited without anyone remembering to update this list.
  for theme_id <- ThemeResolver.theme_ids() do
    describe "#{theme_id} theme" do
      setup do
        store = store_on_theme!(unquote(theme_id))
        product = stocked_product!(store)
        %{store: store, product: product}
      end

      test "a desktop shopper can reach the cart from the home page", %{
        conn: conn,
        store: store
      } do
        {:ok, _view, html} = live(conn, "/s/#{store.slug}")

        assert cart_reachable_on_desktop?(html),
               "#{unquote(theme_id)}: the home page has no cart link outside the mobile-only " <>
                 "bar. A desktop customer can add to cart and never reach checkout."
      end

      test "a desktop shopper can reach the cart from the product list", %{
        conn: conn,
        store: store
      } do
        {:ok, _view, html} = live(conn, "/s/#{store.slug}/products")

        assert cart_reachable_on_desktop?(html),
               "#{unquote(theme_id)}: the product list has no cart link outside the " <>
                 "mobile-only bar. Desktop shoppers are stranded."
      end

      test "a desktop shopper can reach the cart from a product page", %{
        conn: conn,
        store: store,
        product: product
      } do
        {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

        assert cart_reachable_on_desktop?(html),
               "#{unquote(theme_id)}: the product page has no cart link outside the " <>
                 "mobile-only bar. Desktop shoppers are stranded."
      end
    end
  end
end
