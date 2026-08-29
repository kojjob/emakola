defmodule EmakolaWeb.Storefront.BackInStockTest do
  @moduledoc """
  An out-of-stock product must not be a dead end, on every theme that sells
  stocked goods.

  What is shared is the promise: a prefilled WhatsApp message to the shop, and
  nothing at all when the merchant has given no number. What is deliberately
  not shared is the look — each theme says it in its own voice, so the wording
  below differs on purpose. A theme whose treatment is a copy of its neighbour's
  is a regression this file is meant to make obvious.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  # theme => the words that theme uses to offer the nudge.
  @themes %{
    "starter" => "Ask about this one",
    "bold" => "Message the shop",
    "fresh" => "Ask the stall",
    "electronics" => "OPEN WHATSAPP THREAD",
    "market" => "Message the seller",
    "vibrant" => "Chat about this one"
  }

  defp store_on(theme, attrs) do
    attrs
    |> Map.merge(%{theme_config: %{"theme" => theme}, currency: "GHS"})
    |> Factory.create_store!()
  end

  defp product_with_stock!(store, stock) do
    product = Factory.create_product!(store, %{status: :active, title: "Kente Sandals"})
    Factory.create_variant!(product, store, %{price: 25_000, stock_quantity: stock})
    product
  end

  defp visit(conn, store, product) do
    {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")
    html
  end

  for {theme, cta} <- @themes do
    describe "#{theme} theme" do
      test "offers its own WhatsApp nudge when the variant has run out", %{conn: conn} do
        store =
          store_on(unquote(theme), %{name: "Nova market", whatsapp_number: "+233 24 118 4402"})

        html = visit(conn, store, product_with_stock!(store, 0))

        assert html =~ unquote(cta)
        assert html =~ "wa.me/233241184402"
        assert html =~ "Kente%20Sandals"
      end

      test "says nothing when the merchant has given no WhatsApp number", %{conn: conn} do
        store = store_on(unquote(theme), %{name: "Quiet Shop"})

        html = visit(conn, store, product_with_stock!(store, 0))

        refute html =~ unquote(cta)
        refute html =~ ~s(id="back-in-stock")
      end

      test "keeps the buy button and offers no nudge while stock lasts", %{conn: conn} do
        store =
          store_on(unquote(theme), %{name: "Nova market", whatsapp_number: "+233 24 118 4402"})

        html = visit(conn, store, product_with_stock!(store, 7))

        assert html =~ "add_to_cart"
        refute html =~ unquote(cta)
      end

      test "the buy button is gone once the variant has run out", %{conn: conn} do
        store =
          store_on(unquote(theme), %{name: "Nova market", whatsapp_number: "+233 24 118 4402"})

        html = visit(conn, store, product_with_stock!(store, 0))

        refute html =~ ~s(phx-click="add_to_cart")
        assert html =~ ~s(id="back-in-stock")
      end

      # Found in a browser, not in a test: the button went but the quantity
      # stepper stayed, and two themes kept their own WhatsApp button under the
      # new one. A control that leads nowhere is still a dead end.
      test "leaves no controls behind that lead nowhere", %{conn: conn} do
        store =
          store_on(unquote(theme), %{name: "Nova market", whatsapp_number: "+233 24 118 4402"})

        html = visit(conn, store, product_with_stock!(store, 0))

        refute html =~ "decrement_quantity"
        refute html =~ "Ask on WhatsApp"
      end
    end
  end

  describe "across the themes" do
    test "no two themes use the same words", %{conn: _conn} do
      labels = @themes |> Map.values() |> Enum.map(&String.downcase/1)
      assert length(Enum.uniq(labels)) == length(labels)
    end
  end
end
