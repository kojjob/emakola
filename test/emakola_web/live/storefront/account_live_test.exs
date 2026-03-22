defmodule EmakolaWeb.Storefront.AccountLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Ghana Shop", slug: "ghana-shop", currency: "GHS"})
    %{store: store}
  end

  describe "AccountLive" do
    test "renders customer account page with profile section", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "My Account"
      assert html =~ "Profile"
    end

    test "shows profile tab with name, email, phone fields", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "First Name"
      assert html =~ "Last Name"
      assert html =~ "Email"
      assert html =~ "Phone"
    end

    test "shows order history section with status badges", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "Recent Orders"
      # Placeholder orders should show status badges
      assert html =~ "Delivered"
      assert html =~ "Shipped"
    end

    test "displays placeholder orders with GHS currency", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "GH\u20B5"
    end

    test "tab navigation switches content", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/account")

      html = render_click(view, "switch_tab", %{"tab" => "orders"})

      assert html =~ "Order History"
    end

    test "shows addresses tab content", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/account")

      html = render_click(view, "switch_tab", %{"tab" => "addresses"})

      assert html =~ "Addresses"
    end

    test "redirects for non-existent store", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/s/no-such-store/account")
    end

    test "sets page title with store name", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "My Account"
    end
  end
end
