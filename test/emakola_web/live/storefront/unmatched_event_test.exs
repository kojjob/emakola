defmodule EmakolaWeb.Storefront.UnmatchedEventTest do
  @moduledoc """
  A storefront page must survive an event it does not handle.

  Without a catch-all clause an unmatched event raises inside the LiveView
  process and the shopper's page dies — a white screen mid-purchase because a
  theme sent `add_to_bag` where the page listens for `add_to_cart`. Themes and
  page modules are edited independently, so that drift is a question of when,
  not whether.

  The event names below are deliberately nonsense: the point is the absence of
  a crash, not any particular handler.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup %{conn: conn} do
    store = Factory.create_store!(%{name: "Nova market", currency: "GHS"})
    product = Factory.create_product!(store, %{status: :active, title: "Kente Sandals"})
    Factory.create_variant!(product, store, %{price: 25_000, stock_quantity: 4})

    conn = init_test_session(conn, %{"cart_session_id" => Ecto.UUID.generate()})
    {:ok, conn: conn, store: store, product: product}
  end

  defp survives_unknown_event(conn, path) do
    {:ok, view, _html} = live(conn, path)

    # Two shapes: a bare event, and one carrying params, since a stray
    # phx-value-* rides along with most real ones.
    assert render_click(view, "no-such-event-#{System.unique_integer([:positive])}", %{})
    assert render_click(view, "another-unknown-event", %{"id" => "whatever"})

    # render/1 on a connected view returns the LiveView's own markup, not the
    # whole document — so this checks the page is still there and rendering,
    # which is the whole claim. render_click above would have exited already
    # had the process died.
    assert byte_size(render(view)) > 500
  end

  test "the store home page ignores an event it does not know", ctx do
    survives_unknown_event(ctx.conn, "/s/#{ctx.store.slug}")
  end

  test "the product list ignores an event it does not know", ctx do
    survives_unknown_event(ctx.conn, "/s/#{ctx.store.slug}/products")
  end

  test "the product page ignores an event it does not know", ctx do
    survives_unknown_event(ctx.conn, "/s/#{ctx.store.slug}/products/#{ctx.product.slug}")
  end

  test "the cart ignores an event it does not know", ctx do
    survives_unknown_event(ctx.conn, "/s/#{ctx.store.slug}/cart")
  end
end
