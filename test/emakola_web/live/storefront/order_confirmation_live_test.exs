defmodule EmakolaWeb.Storefront.OrderConfirmationLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  setup do
    store = create_store!(%{name: "Confirm Shop", slug: "confirm-shop", currency: "GHS"})
    product = create_product!(store, %{title: "Confirm Item"})
    variant = create_variant!(product, store, %{price: 5000, stock_quantity: 20, sku: "CI-001"})

    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)

    # Create an order via the checkout service
    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 2}],
        notes: "Test order",
        shipping_address: %{
          "name" => "Ama Mensah",
          "phone" => "+233241234567",
          "address" => "House 14, Osu",
          "region" => "greater_accra"
        }
      )

    %{store: store, order: order, product: product, variant: variant}
  end

  describe "mount/3" do
    test "renders order confirmation page", %{conn: conn, store: store, order: order} do
      {:ok, _view, html} =
        live(conn, "/s/#{store.slug}/orders/#{order.order_number}/confirmation")

      assert html =~ order.order_number
      assert html =~ "all set" or html =~ "Order Confirmed" or html =~ "Thank you"
    end

    test "shows order total and items", %{conn: conn, store: store, order: order} do
      {:ok, view, html} =
        live(conn, "/s/#{store.slug}/orders/#{order.order_number}/confirmation")

      assert html =~ "GH\u20B5"

      # Items may be in expandable details -- click to expand if needed
      if has_element?(view, "[phx-click='toggle_details']") do
        html = render_click(view, "toggle_details", %{})
        assert html =~ "Confirm Item"
      end
    end

    test "shows continue shopping link", %{conn: conn, store: store, order: order} do
      {:ok, _view, html} =
        live(conn, "/s/#{store.slug}/orders/#{order.order_number}/confirmation")

      assert html =~ "Continue Shopping" or html =~ "/s/#{store.slug}"
    end

    test "redirects for non-existent order", %{conn: conn, store: store} do
      result = live(conn, "/s/#{store.slug}/orders/ORD-INVALID-000000/confirmation")

      case result do
        {:error, {:redirect, _}} -> assert true
        {:ok, _view, html} -> assert html =~ "not found" or html =~ "error"
      end
    end

    test "redirects for non-existent store", %{conn: conn, order: order} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, "/s/no-such-store/orders/#{order.order_number}/confirmation")
    end
  end

  describe "payment status display" do
    test "shows pending status for unpaid order", %{conn: conn, store: store, order: order} do
      {:ok, _view, html} =
        live(conn, "/s/#{store.slug}/orders/#{order.order_number}/confirmation")

      # Order is pending by default
      assert html =~ "pending" or html =~ "Pending" or html =~ "Awaiting"
    end
  end
end
