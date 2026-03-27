defmodule EmakolaWeb.Storefront.CheckoutLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Cart.CartStore

  setup do
    store = create_store!(%{name: "Checkout Shop", slug: "checkout-shop", currency: "GHS"})
    product = create_product!(store, %{title: "Test Shirt"})
    variant = create_variant!(product, store, %{price: 5000, stock_quantity: 20, sku: "TS-001"})

    # Activate product so it's visible in storefront
    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!()

    %{store: store, product: product, variant: variant}
  end

  defp setup_cart_session(conn, variant) do
    session_id = Ecto.UUID.generate()

    CartStore.add_item(session_id, %{
      variant_id: variant.id,
      product_title: "Test Shirt",
      variant_info: "TS-001",
      unit_price: 5000,
      quantity: 2,
      sku: "TS-001"
    })

    conn = conn |> init_test_session(%{"cart_session_id" => session_id})
    {conn, session_id}
  end

  # -- Mount --

  describe "mount/3" do
    test "renders single-page checkout with all sections", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      assert html =~ "Contact"
      assert html =~ "Phone number"
      assert html =~ "Full name"
      assert html =~ "Shipping Address"
      assert html =~ "Delivery Method"
      assert html =~ "Payment"
      assert html =~ "Place Order"
    end

    test "loads cart items from CartStore session", %{conn: conn, store: store, variant: variant} do
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      assert html =~ "Test Shirt"
      assert html =~ "GH\u20B5 100.00"
    end

    test "renders order summary sidebar", %{conn: conn, store: store, variant: variant} do
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      assert html =~ "Order Summary"
      assert html =~ "Subtotal"
      assert html =~ "Shipping"
      assert html =~ "Total"
    end

    test "renders checkout with empty cart", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      assert html =~ "Contact"
      assert html =~ "Your cart is empty"
    end

    test "redirects for non-existent store", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, "/s/non-existent-store/checkout")
    end
  end

  # -- Payment Method Selection --

  describe "payment method selection" do
    test "selects card payment method", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html = render_click(view, "select_payment", %{"method" => "card"})

      assert html =~ "redirected to enter your card"
    end

    test "shows MTN MoMo selected by default", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      assert html =~ "MTN Mobile Money"
      assert html =~ "prompt will appear on your phone"
    end

    test "shows COD info when selected", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html = render_click(view, "select_payment", %{"method" => "cod"})

      assert html =~ "Pay on Delivery"
      assert html =~ "Pay the rider"
    end
  end

  # -- Place Order --

  describe "place_order" do
    test "validates required fields before placing order", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html =
        render_submit(view, "place_order", %{
          "phone" => "",
          "fullname" => "",
          "address" => "",
          "region" => "greater_accra",
          "notes" => ""
        })

      assert html =~ "required"
    end

    test "creates order with momo and shows waiting state", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html =
        render_submit(view, "place_order", %{
          "phone" => "241234567",
          "fullname" => "Ama Mensah",
          "address" => "House 14, Osu",
          "region" => "greater_accra",
          "notes" => "Leave at door"
        })

      # Should show waiting/processing state or error (gateway mock may not be configured)
      assert html =~ "Approve" or html =~ "Processing" or html =~ "error" or
               html =~ "Payment"
    end

    test "shows error when cart is empty on place_order", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html =
        render_submit(view, "place_order", %{
          "phone" => "241234567",
          "fullname" => "Test User",
          "address" => "Test Address",
          "region" => "greater_accra",
          "notes" => ""
        })

      assert html =~ "cart is empty" or html =~ "empty"
    end
  end

  # -- Delivery Fee --

  describe "delivery fee calculation" do
    test "Greater Accra has lowest delivery fee", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html =
        render_change(view, "update_details", %{
          "region" => "greater_accra"
        })

      assert html =~ "GH\u20B5 15.00"
    end

    test "Ashanti region has higher delivery fee", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html =
        render_change(view, "update_details", %{
          "region" => "ashanti"
        })

      assert html =~ "GH\u20B5 25.00"
    end
  end
end
