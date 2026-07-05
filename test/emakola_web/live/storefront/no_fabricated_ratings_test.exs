defmodule EmakolaWeb.Storefront.NoFabricatedRatingsTest do
  @moduledoc """
  No theme may render fabricated social proof. A product with zero reviews
  must not show a star rating, a rating number, or a review count on its
  detail page — several themes hardcoded literals like "4.8 · 254 reviews"
  into their templates for every product of every store.
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  @all_themes ~w(akoma atelier beauty bold electronics fashion fresh heritage
                 home_living market pharmacy spotlight starter vibrant)

  # Literals the audit found hardcoded in templates: "4.5", "(4.8)",
  # "4.8 · 254 reviews", "4.9 · 87 reviews", "4.5 (24 reviews)" etc.
  # The product under test has zero reviews, so ANY rating-shaped text
  # ("x.y · N reviews", "(x.y)", or a bare "x.y" rating span) is fabricated.
  @fake_rating ~r/\d\.\d\s*(·|\()\s*\d+\s+reviews?/i
  @bare_paren_rating ~r/\(\s*\d\.\d\s*\)/
  @bare_rating_span ~r/>\s*\d\.\d\s*<\/span>/

  for theme <- @all_themes do
    @theme theme
    test "#{theme} PDP shows no rating for a product without reviews", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => @theme}})
      product = Factory.create_product!(store, %{status: :active})
      Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      refute html =~ @fake_rating,
             "found a hardcoded 'x.y · N reviews' literal in the #{@theme} PDP"

      refute html =~ @bare_paren_rating,
             "found a hardcoded '(x.y)' rating literal in the #{@theme} PDP"

      refute html =~ @bare_rating_span,
             "found a bare 'x.y' rating span in the #{@theme} PDP"
    end
  end
end
