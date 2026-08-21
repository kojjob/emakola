defmodule EmakolaWeb.Storefront.CheckoutDefaultRendererTest do
  @moduledoc """
  The shared default checkout page: honest trust copy only — no invented
  guarantees ("Free Returns", "100% Authentic"), returns pointing at the
  store's own policies, and clean CTA copy.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  defp checkout_with_item(conn) do
    store = create_store!(%{slug: "stall-checkout-#{System.unique_integer([:positive])}"})
    product = create_product!(store, %{title: "Kente Stole"})
    create_variant!(product, store, %{price: 12_000, track_inventory: false, stock_quantity: 0})

    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)

    session_id = Ecto.UUID.generate()
    conn = init_test_session(conn, %{"cart_session_id" => session_id})

    {:ok, product_view, _html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")
    product_view |> element("button[phx-click=add_to_cart]") |> render_click()

    {conn, store}
  end

  test "trust badges carry no invented guarantees and link the store's policies", %{conn: conn} do
    {conn, store} = checkout_with_item(conn)

    {:ok, view, html} = live(conn, "/s/#{store.slug}/checkout")

    refute html =~ "Free Returns"
    refute html =~ "100%"
    refute html =~ "Authentic"
    assert has_element?(view, "a[href='/s/#{store.slug}/policies#returns']")
  end

  test "the place-order button reads cleanly, without a literal double dash", %{conn: conn} do
    {conn, store} = checkout_with_item(conn)

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

    assert html =~ "Place Order"
    refute html =~ "Place Order --"
  end

  test "no emoji stands in for an icon", %{conn: conn} do
    {conn, store} = checkout_with_item(conn)

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

    refute html =~ "🛡"
  end
end
