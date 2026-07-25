defmodule EmakolaWeb.Storefront.PdpParityTest do
  @moduledoc """
  Capabilities every theme's product page must have.

  `EmakolaWeb.Storefront.ProductDetailLive` loads the same data for every
  theme on every request. Where a theme does not render some of it, the
  shopper simply never sees it and nobody finds out — the page looks
  finished, the query still ran, and no test fails.

  That is how six themes shipped product pages that queried the store's
  reviews and threw them away, and how Akwaaba shipped a page with no
  variant picker at all. Each capability below is asserted for EVERY theme,
  with no `if` to opt a theme out — a conditional assertion is what let the
  Akwaaba bug survive its own guard test.

  Themes are free to look different. They are not free to drop data the
  merchant's shoppers are entitled to see.
  """
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest

  alias Emakola.Themes.ThemeResolver

  @themes ThemeResolver.theme_ids()

  defp seed(theme) do
    store = create_store!(%{theme_config: %{"theme" => theme}, currency: "GHS"})

    product =
      create_product!(store, %{
        title: "Sankofa Stool",
        status: :active,
        description: "A stool."
      })

    create_variant!(product, store, %{price: 45_000, stock_quantity: 4})

    %{store: store, product: product}
  end

  describe "every theme's product page shows the store's reviews" do
    for theme <- @themes do
      @theme theme

      test "#{theme}", %{conn: conn} do
        ctx = seed(@theme)

        {:ok, _view, html} = live(conn, "/s/#{ctx.store.slug}/products/#{ctx.product.slug}")

        assert html =~ ~s(id="reviews"),
               "the #{@theme} product page never renders ReviewComponents.review_section, " <>
                 "so the store's real reviews are queried on every request and discarded, " <>
                 "and no shopper can leave one"
      end
    end
  end

  describe "every theme's product page states the store's own delivery terms" do
    # `Delivery.callout/1` builds this line from the store's configured zones
    # and returns nil when there are none, so the paragraph is honest by
    # construction — it cannot promise delivery the merchant has not offered.
    # Sixteen themes loaded @delivery_zones on every request and rendered none
    # of it.
    for theme <- @themes do
      @theme theme

      test "#{theme}", %{conn: conn} do
        ctx = seed(@theme)
        create_delivery_zone!(ctx.store, %{name: "Accra", estimated_days: 1})

        {:ok, _view, html} = live(conn, "/s/#{ctx.store.slug}/products/#{ctx.product.slug}")

        assert html =~ "Next day",
               "the #{@theme} product page never renders the delivery callout, so the " <>
                 "store's own zones are loaded on every request and discarded"
      end
    end
  end

  describe "every theme's product page offers the store's other products" do
    for theme <- @themes do
      @theme theme

      test "#{theme}", %{conn: conn} do
        ctx = seed(@theme)

        sibling = create_product!(ctx.store, %{title: "Nkonwa Side Table", status: :active})
        create_variant!(sibling, ctx.store, %{price: 60_000, stock_quantity: 2})

        {:ok, _view, html} = live(conn, "/s/#{ctx.store.slug}/products/#{ctx.product.slug}")

        assert html =~ "Nkonwa Side Table",
               "the #{@theme} product page never renders @related_products, so a shopper " <>
                 "reaching a dead end has nothing else in the store offered to them"
      end
    end
  end

  describe "every theme's product page lets a shopper choose a quantity" do
    for theme <- @themes do
      @theme theme

      test "#{theme}", %{conn: conn} do
        ctx = seed(@theme)

        {:ok, view, _html} = live(conn, "/s/#{ctx.store.slug}/products/#{ctx.product.slug}")

        assert has_element?(view, ~s([phx-click="increment_quantity"])),
               "the #{@theme} product page has no quantity control"

        assert render_click(view, "increment_quantity", %{}) =~ "2"
      end
    end
  end
end
