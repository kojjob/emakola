defmodule EmakolaWeb.Storefront.WishlistAddToBagTest do
  @moduledoc """
  "Add to Bag" must add to the bag.

  The wishlist's button matched the event, discarded the product id, and set a
  toast reading "Added to bag" — without ever touching the cart. The shopper was
  told their item was in the bag; the bag stayed empty. It is the one bug in this
  sweep that does not crash and does not look broken, which is what makes it the
  most likely to cost a sale.

  The page also hardcoded `cart_count` to 0, so the header's cart badge read
  empty on the wishlist even when the cart was full.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Cart.CartStore

  setup %{conn: conn} do
    store = Emakola.Factory.create_store!(%{theme_config: %{"theme" => "market"}})
    product = Emakola.Factory.create_product!(store, %{title: "Shea Butter", status: :active})
    Emakola.Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})

    %{conn: conn, store: store, product: product}
  end

  test "adding a wishlisted product to the bag puts it in the cart", %{
    conn: conn,
    store: store,
    product: product
  } do
    {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

    render_click(view, "add_to_bag", %{"product_id" => product.id})

    cart_session_id = :sys.get_state(view.pid).socket.assigns.cart_session_id

    assert CartStore.cart_count(cart_session_id, store.id) == 1,
           "the wishlist said 'Added to bag' but never added anything to the cart"
  end

  test "the cart badge updates when something is added", %{
    conn: conn,
    store: store,
    product: product
  } do
    {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

    assert :sys.get_state(view.pid).socket.assigns.cart_count == 0

    render_click(view, "add_to_bag", %{"product_id" => product.id})

    # The page hardcoded cart_count to 0, so the header's cart badge stayed empty
    # no matter what the shopper did.
    assert :sys.get_state(view.pid).socket.assigns.cart_count == 1
  end

  test "an out-of-stock product is not claimed to be in the bag", %{conn: conn, store: store} do
    sold_out = Emakola.Factory.create_product!(store, %{title: "Sold Out", status: :active})
    Emakola.Factory.create_variant!(sold_out, store, %{price: 5000, stock_quantity: 0})

    {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

    html = render_click(view, "add_to_bag", %{"product_id" => sold_out.id})

    cart_session_id = :sys.get_state(view.pid).socket.assigns.cart_session_id

    assert CartStore.cart_count(cart_session_id, store.id) == 0
    refute html =~ "Added to bag", "the wishlist claimed a sold-out product was added to the bag"
  end
end
