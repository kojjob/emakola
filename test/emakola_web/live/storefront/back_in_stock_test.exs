defmodule EmakolaWeb.Storefront.BackInStockTest do
  @moduledoc """
  An out-of-stock product must not be a dead end.

  Today the product page greys out Add to Cart and offers the shopper nothing
  else, so a buyer who arrives the day a line sells out simply leaves. The page
  offers a prefilled WhatsApp message to the shop instead — and says nothing at
  all when the merchant has given no WhatsApp number, because a channel the
  merchant does not have is a promise the storefront cannot keep.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  defp starter_store(attrs) do
    attrs
    |> Map.merge(%{theme_config: %{"theme" => "starter"}, currency: "GHS"})
    |> Factory.create_store!()
  end

  defp product_with_stock!(store, stock) do
    product = Factory.create_product!(store, %{status: :active, title: "Kente Sandals"})
    Factory.create_variant!(product, store, %{price: 25_000, stock_quantity: stock})
    product
  end

  describe "an out-of-stock product" do
    test "offers a prefilled WhatsApp message to the shop", %{conn: conn} do
      store = starter_store(%{name: "Nova market", whatsapp_number: "+233 24 118 4402"})
      product = product_with_stock!(store, 0)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      assert html =~ "Tell me when it is back"
      assert html =~ "wa.me/233241184402"
      assert html =~ "Kente%20Sandals"
    end

    test "says nothing when the merchant has given no WhatsApp number", %{conn: conn} do
      store = starter_store(%{name: "Quiet Shop"})
      product = product_with_stock!(store, 0)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      refute html =~ "Tell me when it is back"
    end
  end

  describe "an in-stock product" do
    test "keeps Add to Cart and offers no back-in-stock message", %{conn: conn} do
      store = starter_store(%{name: "Nova market", whatsapp_number: "+233 24 118 4402"})
      product = product_with_stock!(store, 7)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      assert html =~ "Add to Cart"
      refute html =~ "Tell me when it is back"
    end
  end
end
