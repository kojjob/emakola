defmodule EmakolaWeb.Storefront.TrackingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Ghana Shop", slug: "ghana-shop", currency: "GHS"})
    %{store: store}
  end

  describe "TrackingLive" do
    test "renders tracking page with order number", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/EM-4821")

      assert html =~ "EM-4821"
    end

    test "shows delivery status timeline", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/EM-4821")

      assert html =~ "Delivery Status"
      assert html =~ "Order Confirmed"
      assert html =~ "Picked Up"
      assert html =~ "On The Way"
      assert html =~ "Delivered"
    end

    test "shows store name in header", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/EM-4821")

      assert html =~ store.name
    end

    test "shows order details section", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/EM-4821")

      assert html =~ "Order Details"
    end

    test "shows estimated delivery information", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/EM-4821")

      assert html =~ "Estimated"
    end

    test "shows payment method info after expanding details", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/EM-4821")

      html = render_click(view, "toggle_details")

      assert html =~ "MTN Mobile Money"
      assert html =~ "Paid"
    end

    test "displays GHS currency in order details", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/EM-4821")

      html = render_click(view, "toggle_details")

      assert html =~ "GH\u20B5"
    end

    test "toggle order details expands/collapses", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/EM-4821")

      html = render_click(view, "toggle_details")

      assert html =~ "Kente Wrap Dress"
    end

    test "redirects for non-existent store", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/s/no-such-store/track/EM-4821")
    end
  end
end
