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
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/wishlist")

      assert html =~ "My Wishlist"
    end

    test "shows empty state when wishlist is empty", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/wishlist")

      assert html =~ "Your wishlist is empty"
      assert html =~ "Start Shopping"
    end

    test "shows product grid when items exist", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

      # Add an item to the wishlist
      html =
        render_click(view, "add_to_wishlist", %{
          "product_id" => "placeholder-1",
          "title" => "Kente Dress",
          "price" => "28000",
          "image_url" => "/images/placeholder.jpg"
        })

      assert html =~ "Kente Dress"
      assert html =~ "1 saved item"
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
      html = render_click(view, "remove_from_wishlist", %{"product_id" => "placeholder-1"})

      assert html =~ "Your wishlist is empty"
      refute html =~ "Kente Dress"
    end

    test "add to bag button triggers event", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

      # Add item
      render_click(view, "add_to_wishlist", %{
        "product_id" => "placeholder-1",
        "title" => "Kente Dress",
        "price" => "28000",
        "image_url" => "/images/placeholder.jpg"
      })

      html = render_click(view, "add_to_bag", %{"product_id" => "placeholder-1"})

      assert html =~ "Added to bag"
    end

    test "displays saved items count", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/wishlist")

      render_click(view, "add_to_wishlist", %{
        "product_id" => "p1",
        "title" => "Item 1",
        "price" => "10000",
        "image_url" => "/images/1.jpg"
      })

      html =
        render_click(view, "add_to_wishlist", %{
          "product_id" => "p2",
          "title" => "Item 2",
          "price" => "20000",
          "image_url" => "/images/2.jpg"
        })

      assert html =~ "2 saved items"
    end

    test "redirects for non-existent store", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/s/no-such-store/wishlist")
    end
  end
end
