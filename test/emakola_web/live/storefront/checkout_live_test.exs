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
    test "renders checkout page with step 1", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      assert html =~ "How would you like to pay?"
      assert html =~ "MTN Mobile Money"
      assert html =~ "Vodafone Cash"
      assert html =~ "Card Payment"
      assert html =~ "Cash on Delivery"
    end

    test "loads cart items from CartStore session", %{conn: conn, store: store, variant: variant} do
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      assert html =~ "Test Shirt"
      assert html =~ "GH\u20B5 100.00"
    end

    test "renders checkout with empty cart", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html = render(view)
      assert html =~ "How would you like to pay?"
    end

    test "redirects for non-existent store", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, "/s/non-existent-store/checkout")
    end
  end

  # -- Step Navigation --

  describe "step navigation" do
    test "can navigate from step 1 to step 2", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html = render_click(view, "go_to_step", %{"step" => "2"})

      assert html =~ "Contact &amp; delivery details"
      assert html =~ "Phone number"
      assert html =~ "Full name"
    end

    test "can navigate back from step 2 to step 1", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      render_click(view, "go_to_step", %{"step" => "2"})
      html = render_click(view, "go_to_step", %{"step" => "1"})

      assert html =~ "How would you like to pay?"
    end

    test "submit_details moves to step 3 with valid data", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      render_click(view, "go_to_step", %{"step" => "2"})

      html =
        render_submit(view, "submit_details", %{
          "phone" => "241234567",
          "fullname" => "Ama Mensah",
          "address" => "House 14, Osu",
          "region" => "greater_accra",
          "notes" => ""
        })

      assert html =~ "Review your order"
      assert html =~ "Ama Mensah"
      assert html =~ "House 14, Osu"
    end

    test "submit_details shows error with missing required fields", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      render_click(view, "go_to_step", %{"step" => "2"})

      html =
        render_submit(view, "submit_details", %{
          "phone" => "",
          "fullname" => "",
          "address" => "",
          "region" => "greater_accra",
          "notes" => ""
        })

      assert html =~ "Please fill in all required fields"
    end
  end

  # -- Payment Method Selection --

  describe "payment method selection" do
    test "selects payment method", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html = render_click(view, "select_payment", %{"method" => "card"})

      assert html =~ "Card Payment"
    end

    test "shows correct label on review step", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      render_click(view, "select_payment", %{"method" => "vodafone"})
      render_click(view, "go_to_step", %{"step" => "2"})

      render_submit(view, "submit_details", %{
        "phone" => "201234567",
        "fullname" => "Kofi Adu",
        "address" => "Kumasi, Adum",
        "region" => "ashanti",
        "notes" => ""
      })

      html = render(view)
      assert html =~ "Vodafone Cash"
    end
  end

  # -- Place Order --

  describe "place_order" do
    test "creates order with momo and shows waiting for payment", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      {conn, _session_id} = setup_cart_session(conn, variant)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      # Step 1: select momo
      render_click(view, "select_payment", %{"method" => "momo"})
      render_click(view, "go_to_step", %{"step" => "2"})

      # Step 2: fill details
      render_submit(view, "submit_details", %{
        "phone" => "241234567",
        "fullname" => "Ama Mensah",
        "address" => "House 14, Osu",
        "region" => "greater_accra",
        "notes" => "Leave at door"
      })

      # Step 3: place order — mock gateway returns success
      html = render_click(view, "place_order", %{})

      # Should show waiting for payment (momo uses polling)
      assert html =~ "Waiting for payment" or html =~ "Processing"
    end

    test "creates order with COD - Place Order button present", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      {conn, _session_id} = setup_cart_session(conn, variant)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      # Step 1: select COD
      render_click(view, "select_payment", %{"method" => "cod"})
      render_click(view, "go_to_step", %{"step" => "2"})

      # Step 2: fill details
      render_submit(view, "submit_details", %{
        "phone" => "241234567",
        "fullname" => "Kofi Mensah",
        "address" => "Accra, Dansoman",
        "region" => "greater_accra",
        "notes" => ""
      })

      # Step 3: Place Order button should be present
      assert view |> element("button", "Place Order") |> has_element?()
    end

    test "shows error when cart is empty on place_order", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      # Navigate through steps without cart items
      render_click(view, "go_to_step", %{"step" => "2"})

      render_submit(view, "submit_details", %{
        "phone" => "241234567",
        "fullname" => "Test User",
        "address" => "Test Address",
        "region" => "greater_accra",
        "notes" => ""
      })

      html = render_click(view, "place_order", %{})

      assert html =~ "cart is empty"
    end
  end

  # -- Delivery Fee --

  describe "delivery fee calculation" do
    test "Greater Accra has lowest delivery fee", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      render_click(view, "go_to_step", %{"step" => "2"})

      html =
        render_change(view, "update_details", %{
          "region" => "greater_accra"
        })

      assert html =~ "GH\u20B5 15.00"
    end

    test "Ashanti region has higher delivery fee", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      render_click(view, "go_to_step", %{"step" => "2"})

      html =
        render_change(view, "update_details", %{
          "region" => "ashanti"
        })

      assert html =~ "GH\u20B5 25.00"
    end
  end
end
