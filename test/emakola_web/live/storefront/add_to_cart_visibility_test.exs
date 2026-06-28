defmodule EmakolaWeb.Storefront.AddToCartVisibilityTest do
  @moduledoc """
  The storefront add-to-cart handlers must refuse a product that isn't
  customer-visible. A draft product with an in-stock variant must NOT be added
  to the cart even when a customer crafts the request with the product's id — so
  the only barrier under test here is the status gate, not stock.
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Cart.CartStore
  alias Emakola.Factory

  setup %{conn: conn} do
    store = Factory.create_store!()
    session_id = Ecto.UUID.generate()
    conn = init_test_session(conn, %{"cart_session_id" => session_id})
    %{conn: conn, store: store, session_id: session_id}
  end

  defp stocked_product!(store, status) do
    product = Factory.create_product!(store, %{status: status})
    Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})
    product
  end

  describe "store landing page" do
    test "does not add a draft product to the cart even when it has stock", ctx do
      %{conn: conn, store: store, session_id: session_id} = ctx
      product = stocked_product!(store, :draft)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}")
      render_click(view, "add_to_cart", %{"product-id" => product.id})

      assert CartStore.get_cart(session_id, store.id) == []
    end

    test "adds an active, in-stock product to the cart", ctx do
      %{conn: conn, store: store, session_id: session_id} = ctx
      product = stocked_product!(store, :active)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}")
      render_click(view, "add_to_cart", %{"product-id" => product.id})

      assert length(CartStore.get_cart(session_id, store.id)) == 1
    end
  end

  describe "category page" do
    test "does not add a draft product to the cart even when it has stock", ctx do
      %{conn: conn, store: store, session_id: session_id} = ctx
      category = Factory.create_category!(store, %{name: "Spices"})
      product = stocked_product!(store, :draft)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/category/#{category.slug}")
      render_click(view, "add_to_cart", %{"product-id" => product.id})

      assert CartStore.get_cart(session_id, store.id) == []
    end
  end
end
