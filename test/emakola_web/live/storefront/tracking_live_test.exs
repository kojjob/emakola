defmodule EmakolaWeb.Storefront.TrackingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  setup do
    store = create_store!(%{name: "Ghana Shop", slug: "ghana-shop", currency: "GHS"})
    product = create_product!(store, %{title: "Kente Wrap Dress"})

    variant =
      create_variant!(product, store, %{price: 28_000, stock_quantity: 10, sku: "KWD-001"})

    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 1}],
        notes: "Test tracking order",
        shipping_address: %{
          "name" => "Ama Mensah",
          "phone" => "+233241234567",
          "address" => "House 14, Osu",
          "region" => "greater_accra"
        }
      )

    %{store: store, order: order, product: product, variant: variant}
  end

  describe "TrackingLive with real order" do
    test "renders tracking page with order number", %{conn: conn, store: store, order: order} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ order.order_number
      assert html =~ store.name
    end

    test "shows delivery status timeline", %{conn: conn, store: store, order: order} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Delivery Status"
      assert html =~ "Order Placed"
      assert html =~ "Confirmed"
      assert html =~ "Being Prepared"
      assert html =~ "Shipped"
      assert html =~ "Delivered"
    end

    test "shows status hero for pending order", %{conn: conn, store: store, order: order} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Awaiting Confirmation"
      assert html =~ "Waiting for payment confirmation"
    end

    test "shows order details section with real items", %{conn: conn, store: store, order: order} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert render(view) =~ "Order Details"

      html = render_click(view, "toggle_details")

      assert html =~ "Kente Wrap Dress"
      assert html =~ "GH\u20B5"
    end

    test "shows total in order details", %{conn: conn, store: store, order: order} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      html = render_click(view, "toggle_details")

      assert html =~ "Total"
      assert html =~ "Subtotal"
    end

    test "shows shipping address in order details", %{conn: conn, store: store, order: order} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      html = render_click(view, "toggle_details")

      assert html =~ "Ama Mensah"
      assert html =~ "House 14, Osu"
    end

    test "toggle order details expands/collapses", %{conn: conn, store: store, order: order} do
      {:ok, view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      refute html =~ "Kente Wrap Dress"

      html = render_click(view, "toggle_details")
      assert html =~ "Kente Wrap Dress"

      html = render_click(view, "toggle_details")
      refute html =~ "Kente Wrap Dress"
    end

    test "does not show rider card for non-shipped order", %{
      conn: conn,
      store: store,
      order: order
    } do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      refute html =~ "Contact Store"
    end

    test "shows confirmed status hero for confirmed order", %{
      conn: conn,
      store: store,
      order: order
    } do
      Emakola.Orders.confirm_order!(order, authorize?: false)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Order Confirmed"
      assert html =~ "Your payment has been verified"
    end

    test "shows processing status for processing order", %{conn: conn, store: store, order: order} do
      order = Emakola.Orders.confirm_order!(order, authorize?: false)
      Emakola.Orders.start_processing_order!(order)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Being Prepared"
      assert html =~ "The seller is preparing your order"
    end

    test "shows rider card for shipped order", %{conn: conn, store: store, order: order} do
      order = Emakola.Orders.confirm_order!(order, authorize?: false)
      order = Emakola.Orders.start_processing_order!(order)
      Emakola.Orders.mark_order_shipped!(order)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Order Shipped"
      assert html =~ "Contact Store"
    end

    test "shows delivered status for delivered order", %{conn: conn, store: store, order: order} do
      order = Emakola.Orders.confirm_order!(order, authorize?: false)
      order = Emakola.Orders.start_processing_order!(order)
      order = Emakola.Orders.mark_order_shipped!(order)
      Emakola.Orders.mark_order_delivered!(order)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/track/#{order.order_number}")

      assert html =~ "Delivered"
      assert html =~ "Your order has been delivered"
    end
  end

  describe "error handling" do
    test "redirects for non-existent order", %{conn: conn, store: store} do
      assert {:error, {:redirect, %{to: "/s/ghana-shop"}}} =
               live(conn, "/s/#{store.slug}/track/ORD-INVALID-000000")
    end

    test "redirects for non-existent store", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/s/no-such-store/track/EM-4821")
    end
  end
end
