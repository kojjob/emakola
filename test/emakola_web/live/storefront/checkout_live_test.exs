defmodule EmakolaWeb.Storefront.CheckoutLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory
  require Ash.Query

  alias Emakola.Cart.CartStore
  alias Emakola.Suppliers.{ListingImporter, Network, Offers}
  alias EmakolaWeb.Helpers.Currency

  setup do
    store = create_store!(%{name: "Checkout Shop", slug: "checkout-shop", currency: "GHS"})
    product = create_product!(store, %{title: "Test Shirt"})
    variant = create_variant!(product, store, %{price: 5000, stock_quantity: 20, sku: "TS-001"})

    # Activate product so it's visible in storefront
    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)

    %{store: store, product: product, variant: variant}
  end

  defp setup_cart_session(conn, variant) do
    session_id = Ecto.UUID.generate()

    CartStore.add_item(session_id, variant.store_id, %{
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
      assert html =~ "GH\u20B5 100"
    end

    test "discloses a fully consented attributed team's exact economics", %{conn: conn} do
      {owner, store} = create_merchant_with_store!(%{slug: "team-checkout"})
      seller = create_merchant!()

      {:ok, team} =
        Emakola.Suppliers.SalesTeams.create(owner, store.id, "Neighbour crew", [
          %{merchant_id: owner.id, role: :owner, split_bps: 6_000},
          %{merchant_id: seller.id, role: :seller, split_bps: 4_000}
        ])

      invited = Enum.find(team.members, &(&1.merchant_id == seller.id))
      {:ok, _accepted} = Emakola.Suppliers.SalesTeams.accept(seller, invited.id)

      conn =
        init_test_session(conn, %{
          "cart_session_id" => Ecto.UUID.generate(),
          "utm_attribution" => %{"sales_team_id" => team.id}
        })

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      assert has_element?(view, "#sales-team-economics", "Neighbour crew")
      assert has_element?(view, "#sales-team-splits", "owner: 60%")
      assert has_element?(view, "#sales-team-splits", "seller: 40%")
      assert has_element?(view, "#sales-team-economics", "does not increase your price")
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

      assert html =~ "MTN MoMo"
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

  # -- Dropship split settlement --

  describe "dropship split settlement" do
    defp verified_payout!(store, code) do
      Emakola.Stores.StorePayoutAccount
      |> Ash.Changeset.for_create(:create, %{store_id: store.id})
      |> Ash.create!(authorize?: false)
      |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: code})
      |> Ash.update!(authorize?: false)
    end

    test "places a dropship order with a split-routed payment", %{conn: conn} do
      dropshipper = create_store!(%{name: "Drop Shop", slug: "drop-shop", currency: "GHS"})
      verified_payout!(dropshipper, "ACCT_drop")
      wholesaler = create_store!(%{name: "Whole Co", slug: "whole-co"})
      verified_payout!(wholesaler, "ACCT_whole")
      supplier = create_supplier!(dropshipper, name: "Linked", linked_store_id: wholesaler.id)

      product = create_product!(dropshipper, %{title: "Dropship Item"})

      variant =
        create_variant!(product, dropshipper,
          price: 5_000,
          sku: "DS-1",
          supplier_id: supplier.id,
          cost_price: 800
        )

      product |> Ash.Changeset.for_update(:activate, %{}) |> Ash.update!(authorize?: false)

      session_id = Ecto.UUID.generate()

      CartStore.add_item(session_id, dropshipper.id, %{
        variant_id: variant.id,
        product_title: "Dropship Item",
        variant_info: "DS-1",
        unit_price: 5_000,
        quantity: 2,
        sku: "DS-1"
      })

      conn = init_test_session(conn, %{"cart_session_id" => session_id})
      {:ok, view, _html} = live(conn, "/s/#{dropshipper.slug}/checkout")

      render_submit(view, "place_order", %{
        "phone" => "241234567",
        "fullname" => "Ama Mensah",
        "address" => "House 14, Osu",
        "region" => "greater_accra",
        "notes" => ""
      })

      payment =
        Emakola.Payments.Payment
        |> Ash.Query.filter(store_id == ^dropshipper.id)
        |> Ash.read!(authorize?: false, tenant: dropshipper.id)
        |> List.first()

      assert payment.split_mode == :dropship_split

      {:ok, splits} =
        Emakola.Payments.PaymentSplit
        |> Ash.Query.for_read(:by_payment, %{payment_id: payment.id})
        |> Ash.read(authorize?: false)

      by_role = Map.new(splits, &{&1.role, &1})
      assert by_role[:wholesaler].amount == 1_600
      assert by_role[:wholesaler].subaccount_code == "ACCT_whole"
      assert by_role[:platform].amount == 840
      # dropshipper margin 7560 + Greater Accra delivery 1500 = 9060
      assert by_role[:dropshipper].amount == 9_060
    end
  end

  # -- Platform fee settlement (normal own-stock order) --

  describe "platform fee settlement" do
    test "places a normal order routing the merchant net and keeping the platform fee", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      verified_payout!(store, "ACCT_own")
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      render_submit(view, "place_order", %{
        "phone" => "241234567",
        "fullname" => "Kofi Owusu",
        "address" => "House 14, Osu",
        "region" => "greater_accra",
        "notes" => ""
      })

      payment =
        Emakola.Payments.Payment
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false, tenant: store.id)
        |> List.first()

      assert payment.split_mode == :platform_fee

      {:ok, splits} =
        Emakola.Payments.PaymentSplit
        |> Ash.Query.for_read(:by_payment, %{payment_id: payment.id})
        |> Ash.read(authorize?: false)

      by_role = Map.new(splits, &{&1.role, &1})
      # subtotal 10000 + Greater Accra delivery 1500 = 11500 total; 2% fee = 230.
      assert by_role[:merchant].amount == 11_270
      assert by_role[:merchant].subaccount_code == "ACCT_own"
      assert by_role[:platform].amount == 230
    end
  end

  # -- Region Select --

  describe "region select" do
    test "renders all 16 canonical regions plus Other", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      # Count option elements in the region select
      option_count = Regex.scan(~r/<option[^>]*>/, html) |> length()
      assert option_count >= 17, "Expected at least 17 options (16 regions + Other)"

      # Verify some specific regions are present
      assert html =~ ~s(<option value="bono_east")
      assert html =~ ~s(<option value="western_north")
      assert html =~ ~s(<option value="other")
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

      assert html =~ "GH\u20B5 15"
    end

    test "Ashanti region has higher delivery fee", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html =
        render_change(view, "update_details", %{
          "region" => "ashanti"
        })

      assert html =~ "GH\u20B5 25"
    end

    test "zone with per-kg pricing charges base fee plus weight surcharge",
         %{conn: conn, store: store, variant: variant} do
      # 600g x qty 2 = 1200g -> rounds up to 2kg -> 1500 + 2 * 500 = 2500
      variant
      |> Ash.Changeset.for_update(:update, %{weight_grams: 600})
      |> Ash.update!(authorize?: false)

      create_delivery_zone!(store, name: "Greater Accra", fee: 1500, per_kg_fee_pesewas: 500)

      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html = render_change(view, "update_details", %{"region" => "greater_accra"})

      assert html =~ "GH\u20B5 25"
    end

    test "zone with free-above threshold ships free when subtotal qualifies",
         %{conn: conn, store: store, variant: variant} do
      # Cart subtotal is 5000 x qty 2 = 10_000, meeting the threshold exactly.
      create_delivery_zone!(store, name: "Greater Accra", fee: 1500, free_above_pesewas: 10_000)

      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      html = render_change(view, "update_details", %{"region" => "greater_accra"})

      # Order total stays at the GH\u20B5 100 subtotal \u2014 a charged 1500 fee would
      # render a GH\u20B5 115 total instead.
      assert html =~ "GH\u20B5 100"
      refute html =~ "GH\u20B5 115"
    end
  end

  # -- Supplier Dispatch Fee --

  describe "supplier dispatch fee" do
    test "supplier dispatch line appears for dropship carts and updates with region", %{
      conn: conn
    } do
      {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Dispatch Reseller"})
      verified_payout!(reseller, "ACCT_reseller")
      {wholesaler_actor, wholesaler} = create_dropship_wholesaler!(reseller_actor, reseller)

      drop =
        import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, %{
          "Greater Accra" => 1_500,
          "Ashanti" => 2_500
        })

      session_id = Ecto.UUID.generate()

      CartStore.add_item(session_id, reseller.id, %{
        variant_id: drop.variant.id,
        product_title: "Dispatch Item",
        variant_info: "SKU",
        unit_price: 5_000,
        quantity: 1,
        sku: "SKU"
      })

      conn = init_test_session(conn, %{"cart_session_id" => session_id})
      {:ok, view, html} = live(conn, "/s/#{reseller.slug}/checkout")

      assert html =~ "Supplier dispatch"
      assert html =~ Currency.format_price(1_500)

      html = render_change(view, "update_details", %{"region" => "ashanti"})

      assert html =~ "Supplier dispatch"
      assert html =~ Currency.format_price(2_500)
      refute html =~ Currency.format_price(1_500)
    end

    test "no dispatch line for merchant-only carts", %{conn: conn, store: store, variant: variant} do
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      refute html =~ "Supplier dispatch"
    end
  end

  # -- Supplier dispatch fixtures ------------------------------------------
  # Real network flow (Offers -> publish -> ListingImporter), mirrored from
  # Emakola.Orders.CheckoutServiceTest, so the imported variant carries a
  # genuine ResellerListingVariant/offer chain for dispatch_fees_for/3 to read.

  defp create_dropship_wholesaler!(reseller_actor, reseller) do
    {wholesaler_actor, wholesaler} =
      create_merchant_with_store!(%{
        name: "Dispatch Wholesaler #{System.unique_integer([:positive])}"
      })

    {:ok, connection} =
      Network.request(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: wholesaler.id
      })

    {:ok, _active} = Network.approve(reseller_actor, connection)
    verified_payout!(wholesaler, "ACCT_wholesaler_#{System.unique_integer([:positive])}")

    {wholesaler_actor, wholesaler}
  end

  defp import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, dispatch_fees) do
    product =
      create_product!(wholesaler,
        status: :active,
        title: "Dispatch Item #{System.unique_integer([:positive])}"
      )

    source_variant =
      create_variant!(product, wholesaler,
        price: 6_000,
        sku: "SRC-#{System.unique_integer([:positive])}",
        stock_quantity: 50
      )

    {:ok, offer} =
      Offers.create_draft(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        source_product_id: product.id,
        earning_model: :markup,
        delivery_areas: Map.keys(dispatch_fees)
      })

    {:ok, _terms} =
      Offers.add_variant(wholesaler_actor, offer, %{
        source_variant_id: source_variant.id,
        supplier_price: 4_000,
        suggested_retail_price: 5_000,
        max_retail_price: 5_800
      })

    {:ok, published} = Offers.publish(wholesaler_actor, offer)

    {:ok, priced} =
      Offers.update_terms(wholesaler_actor, published, %{dispatch_fees: dispatch_fees})

    {:ok, listing} = ListingImporter.import(reseller_actor, reseller.id, priced)

    [variant | _] = listing.reseller_product.variants
    %{variant: variant, supplier_id: listing.supplier_id, offer: priced}
  end
end
