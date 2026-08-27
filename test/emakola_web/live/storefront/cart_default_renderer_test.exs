defmodule EmakolaWeb.Storefront.CartDefaultRendererTest do
  @moduledoc """
  The shared default cart page (every theme without its own :render_cart):
  Mobile Stall conversion contract — a sticky mobile checkout bar, honest
  trust copy (real rails, policies links, no invented guarantees), 44px
  quantity steppers, and no dead controls.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  defp cart_with_item(conn, variant_attrs \\ %{}) do
    store = create_store!(%{slug: "stall-cart-#{System.unique_integer([:positive])}"})
    product = create_product!(store, %{title: "Kente Stole"})

    create_variant!(
      product,
      store,
      Map.merge(%{price: 12_000, track_inventory: false, stock_quantity: 0}, variant_attrs)
    )

    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)

    session_id = Ecto.UUID.generate()
    conn = init_test_session(conn, %{"cart_session_id" => session_id})

    {:ok, product_view, _html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")
    product_view |> element("button[phx-click=add_to_cart]") |> render_click()

    {conn, store}
  end

  test "a sticky mobile checkout bar carries the total and the checkout link", %{conn: conn} do
    {conn, store} = cart_with_item(conn)

    {:ok, view, html} = live(conn, "/s/#{store.slug}/cart")

    assert has_element?(view, "#mobile-checkout-bar a[href='/s/#{store.slug}/checkout']")
    assert html =~ "GH₵ 120"
  end

  test "trust copy names real rails and links policies — no invented guarantees", %{conn: conn} do
    {conn, store} = cart_with_item(conn)

    {:ok, view, html} = live(conn, "/s/#{store.slug}/cart")

    refute html =~ "Free Returns"
    assert html =~ "MTN MoMo"
    assert has_element?(view, "a[href='/s/#{store.slug}/policies#returns']")
  end

  test "the dead move-to-wishlist button is gone", %{conn: conn} do
    {conn, store} = cart_with_item(conn)

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

    refute html =~ "Move to Wishlist"
  end

  test "the summary invents no tax and the total is the subtotal", %{conn: conn} do
    {conn, store} = cart_with_item(conn)

    {:ok, view, html} = live(conn, "/s/#{store.slug}/cart")

    refute html =~ "Estimated Tax"
    assert view |> element("#summary-total") |> render() =~ "GH₵ 120"
  end

  test "the placebo promo box is gone — coupons belong to checkout", %{conn: conn} do
    {conn, store} = cart_with_item(conn)

    {:ok, view, html} = live(conn, "/s/#{store.slug}/cart")

    refute has_element?(view, "#promo-section")
    refute html =~ "Promo Code"
  end

  test "a lone variant's SKU is never shown as its variant label", %{conn: conn} do
    {conn, store} = cart_with_item(conn, %{sku: "EARN-TEST-99"})

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

    refute html =~ "EARN-TEST-99"
  end

  test "quantity steppers meet the 44px tap target", %{conn: conn} do
    {conn, store} = cart_with_item(conn)

    {:ok, view, _html} = live(conn, "/s/#{store.slug}/cart")

    assert has_element?(view, "button[aria-label='Increase quantity'].w-11")
    assert has_element?(view, "button[aria-label='Decrease quantity'].w-11")
  end
end
