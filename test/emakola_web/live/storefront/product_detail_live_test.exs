defmodule EmakolaWeb.Storefront.ProductDetailLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Cart.CartStore

  defp activate!(product) do
    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)
  end

  defp with_cart_session(conn) do
    session_id = Ecto.UUID.generate()
    {init_test_session(conn, %{"cart_session_id" => session_id}), session_id}
  end

  describe "add_to_cart stock gate" do
    test "untracked variant adds to cart even at zero stock", %{conn: conn} do
      store = create_store!(%{slug: "untracked-shop"})
      product = create_product!(store, %{title: "Made To Order Bowl"})
      create_variant!(product, store, %{price: 4500, track_inventory: false, stock_quantity: 0})
      activate!(product)
      {conn, session_id} = with_cart_session(conn)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      html = view |> element("button[phx-click=add_to_cart]") |> render_click()

      assert html =~ "Added to cart"
      assert CartStore.cart_count(session_id, store.id) == 1
    end

    test "tracked variant at zero stock disables the add-to-cart button", %{conn: conn} do
      store = create_store!(%{slug: "tracked-shop"})
      product = create_product!(store, %{title: "Limited Bowl"})
      create_variant!(product, store, %{price: 4500, track_inventory: true, stock_quantity: 0})
      activate!(product)
      {conn, _session_id} = with_cart_session(conn)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      # A genuinely out-of-stock (tracked) product still disables the button —
      # the gate now respects track_inventory rather than ignoring it.
      assert has_element?(view, "button[phx-click=add_to_cart][disabled]")
    end
  end
end
