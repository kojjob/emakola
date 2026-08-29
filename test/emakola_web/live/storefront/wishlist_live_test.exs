defmodule EmakolaWeb.Storefront.WishlistLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Ghana Shop", slug: "ghana-shop", currency: "GHS"})
    %{store: store}
  end

  describe "WishlistLive" do
    test "renders wishlist page with title", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

      assert has_element?(view, "#wishlist-title")
      assert has_element?(view, "#wishlist-items[phx-update='stream']")
    end

    test "shows empty state when wishlist is empty", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

      assert has_element?(view, "#wishlist-items[data-count='0']")
      assert has_element?(view, "#wishlist-empty")
      assert has_element?(view, "#wishlist-browse-products[href$='/products']")
    end

    test "shows product grid when items exist", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

      # Add an item to the wishlist
      render_click(view, "add_to_wishlist", %{
        "product_id" => "placeholder-1",
        "title" => "Kente Dress",
        "price" => "28000",
        "image_url" => "/images/placeholder.jpg"
      })

      assert has_element?(view, "#wishlist-item-placeholder-1")
      assert has_element?(view, "#wishlist-count[data-count='1']")
    end

    test "remove button removes item from wishlist", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

      # Add item
      render_click(view, "add_to_wishlist", %{
        "product_id" => "placeholder-1",
        "title" => "Kente Dress",
        "price" => "28000",
        "image_url" => "/images/placeholder.jpg"
      })

      # Remove it
      render_click(view, "remove_from_wishlist", %{"product_id" => "placeholder-1"})

      refute has_element?(view, "#wishlist-item-placeholder-1")
      assert has_element?(view, "#wishlist-items[data-count='0']")
      assert has_element?(view, "#wishlist-empty")
    end

    # This asserted the toast appeared for product_id "placeholder-1" — a product
    # that does not exist. It passed because the handler threw the id away and
    # flashed "Added to bag" unconditionally, without ever touching the cart.
    # That was the bug. A product the store does not sell must not be reported as
    # added; the real behaviour is covered in WishlistAddToBagTest.
    test "add to bag does not claim to add a product that does not exist", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

      html = render_click(view, "add_to_bag", %{"product_id" => Ecto.UUID.generate()})

      refute html =~ "Added to bag"
    end

    test "displays saved items count", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

      render_click(view, "add_to_wishlist", %{
        "product_id" => "p1",
        "title" => "Item 1",
        "price" => "10000",
        "image_url" => "/images/1.jpg"
      })

      render_click(view, "add_to_wishlist", %{
        "product_id" => "p2",
        "title" => "Item 2",
        "price" => "20000",
        "image_url" => "/images/2.jpg"
      })

      assert has_element?(view, "#wishlist-count[data-count='2']")
      assert has_element?(view, "#wishlist-item-p1")
      assert has_element?(view, "#wishlist-item-p2")
    end

    test "redirects for non-existent store", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/s/no-such-store/wishlist")
    end
  end

  describe "add_to_wishlist input safety" do
    test "a guest event with a missing price doesn't crash the LiveView",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

      # A crafted event without "price" must not crash (was String.to_integer(nil)).
      render_click(view, "add_to_wishlist", %{"product_id" => "p-x", "title" => "X"})

      assert has_element?(view, "#wishlist-title")
      assert has_element?(view, "#wishlist-item-p-x")
    end
  end

  describe "WishlistLive (authenticated customer)" do
    setup %{conn: conn, store: store} do
      customer =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "wish-auth-#{System.unique_integer([:positive])}@example.com",
          name: "Wish Auth",
          store_id: store.id,
          password: "password123",
          password_confirmation: "password123"
        })
        |> Ash.create!(authorize?: false)

      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))
      conn = Phoenix.ConnTest.init_test_session(conn, %{"customer_token" => token})
      %{conn: conn, customer: customer}
    end

    test "a logged-in customer's add persists to the DB", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      product = Factory.create_product!(store, status: :active)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")
      render_click(view, "add_to_wishlist", %{"product_id" => product.id})

      {:ok, items} = Emakola.Customers.list_wishlist(customer.id, store.id)
      assert Enum.any?(items, &(&1.product_id == product.id))
    end

    test "ignores a product from another store (store-scoped validation)", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      other = Factory.create_store!()
      foreign = Factory.create_product!(other, status: :active)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")
      render_click(view, "add_to_wishlist", %{"product_id" => foreign.id})

      {:ok, items} = Emakola.Customers.list_wishlist(customer.id, store.id)
      assert items == []
    end
  end
end
