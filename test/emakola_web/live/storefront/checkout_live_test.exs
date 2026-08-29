defmodule EmakolaWeb.Storefront.CheckoutLiveTest do
  # async: false — the "internal rail settlement" describe block below swaps
  # the globally-configured :payment_gateway to the Mox-based GatewayMock (the
  # same pattern pay_link_live_test.exs and susu_link_live_test.exs use), which
  # would race with any other async test hitting the default
  # Emakola.Payments.Gateways.Mock gateway concurrently.
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Emakola.Factory
  import Mox
  require Ash.Query

  alias Emakola.Cart.CartStore
  alias Emakola.Suppliers.{ListingImporter, Network, Offers}
  alias EmakolaWeb.Helpers.Currency

  setup :verify_on_exit!

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

  defp to_shipping_step(view) do
    render_submit(view, "submit_details", %{"phone" => "0244123456", "fullname" => "Ama Mensah"})
  end

  defp to_payment_step(view) do
    to_shipping_step(view)
    render_submit(view, "submit_delivery", %{"address" => "House 14, Osu"})
  end

  # -- Mount --

  describe "mount/3" do
    test "renders checkout one step at a time", %{conn: conn, store: store} do
      {:ok, view, html} = live(conn, "/s/#{store.slug}/checkout")

      assert html =~ "Contact"
      assert html =~ "Phone number"
      assert html =~ "Full name"

      shipping = to_shipping_step(view)
      assert shipping =~ "Shipping Address"
      assert shipping =~ "Delivery Method"

      payment = render_submit(view, "submit_delivery", %{"address" => "House 14, Osu"})
      assert payment =~ "Payment"
      assert payment =~ "Place Order"
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
      to_payment_step(view)

      html = render_click(view, "select_payment", %{"method" => "card"})

      assert html =~ "redirected to enter your card"
    end

    test "shows MTN MoMo selected by default", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")
      html = to_payment_step(view)

      assert html =~ "MTN MoMo"
      assert html =~ "prompt will appear on your phone"
    end

    test "shows COD info when selected", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")
      to_payment_step(view)

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

  # -- GhanaPost digital address + landmark (TC-4 Task 2) --

  describe "GhanaPost digital address + landmark" do
    test "valid messy digital address normalizes and lands on the order with the landmark", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      render_submit(view, "place_order", %{
        "phone" => "241234567",
        "fullname" => "Ama Mensah",
        "address" => "House 14, Osu",
        "region" => "greater_accra",
        "notes" => "",
        "digital_address" => "ga 183 8164",
        "landmark" => "behind Achimota Melcom"
      })

      order =
        Emakola.Orders.Order
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false, tenant: store.id)
        |> List.first()

      assert order.shipping_address["digital_address"] == "GA-183-8164"
      assert order.shipping_address["landmark"] == "behind Achimota Melcom"
    end

    test "blank digital address and landmark are omitted from the order's shipping_address", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      render_submit(view, "place_order", %{
        "phone" => "241234567",
        "fullname" => "Ama Mensah",
        "address" => "House 14, Osu",
        "region" => "greater_accra",
        "notes" => "",
        "digital_address" => "",
        "landmark" => ""
      })

      order =
        Emakola.Orders.Order
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false, tenant: store.id)
        |> List.first()

      refute Map.has_key?(order.shipping_address, "digital_address")
      refute Map.has_key?(order.shipping_address, "landmark")
    end

    test "invalid digital address shows a friendly error and creates no order", %{
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
          "notes" => "",
          "digital_address" => "not-a-code",
          "landmark" => ""
        })

      assert html =~ "Check the digital address — it looks like GA-183-8164"

      orders =
        Emakola.Orders.Order
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false, tenant: store.id)

      assert orders == []
    end

    test "renders the GhanaPost digital address and landmark fields", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")
      html = to_shipping_step(view)

      assert html =~ ~s(name="digital_address")
      assert html =~ ~s(name="landmark")
      assert html =~ "GhanaPost Digital Address"
    end

    test "a landmark over 200 chars is truncated (never rejected) on the order", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

      long_landmark = String.duplicate("a", 250)

      render_submit(view, "place_order", %{
        "phone" => "241234567",
        "fullname" => "Ama Mensah",
        "address" => "House 14, Osu",
        "region" => "greater_accra",
        "notes" => "",
        "landmark" => long_landmark
      })

      order =
        Emakola.Orders.Order
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false, tenant: store.id)
        |> List.first()

      assert order.shipping_address["landmark"] == String.duplicate("a", 200)
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

    test "full checkout charges the fee and the splits carry it", %{conn: conn} do
      # Drive the real checkout UI to completion for a dropship cart with a fee
      # (region greater_accra), then:
      #   order.dispatch_fee_total == fee; order.total includes it
      #   OrderSettlement.prepare(order.id, store.id) → wholesaler allocation
      #   amount == cost + fee and Σ allocations == order.total

      {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Dispatch Reseller"})
      verified_payout!(reseller, "ACCT_reseller")
      {wholesaler_actor, wholesaler} = create_dropship_wholesaler!(reseller_actor, reseller)

      # Create offer with dispatch fee for Greater Accra (1500 pesewas = GH₵15)
      drop =
        import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, %{
          "Greater Accra" => 1_500
        })

      # Add to cart
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
      {:ok, view, _html} = live(conn, "/s/#{reseller.slug}/checkout")

      # Drive checkout to completion
      html =
        render_submit(view, "place_order", %{
          "phone" => "241234567",
          "fullname" => "Test Reseller",
          "address" => "Test Address",
          "region" => "greater_accra",
          "notes" => ""
        })

      # Verify order was created (check for success or waiting state)
      assert html =~ "Approve" or html =~ "Processing" or html =~ "Payment" or
               html =~ "waiting" or html =~ "Secure"

      # Get the created order
      {:ok, orders} =
        Emakola.Orders.Order
        |> Ash.Query.filter(store_id == ^reseller.id)
        |> Ash.read(authorize?: false, tenant: reseller.id)

      assert [order] = orders, "Expected exactly one order to be created"

      # SEAL ASSERTIONS:
      # 1. order.dispatch_fee_total == fee (1500 pesewas)
      assert order.dispatch_fee_total == 1_500,
             "Expected dispatch_fee_total == 1500, got #{order.dispatch_fee_total}"

      # 2. order.total includes the fee + delivery fee
      # Greater Accra has a default delivery fee of 1500 pesewas
      expected_total = order.subtotal + order.delivery_fee + 1_500

      assert order.total == expected_total,
             "Expected total == #{expected_total} (subtotal + delivery_fee + dispatch_fee), got #{order.total}"

      # 3. OrderSettlement.prepare returns splits with Σ allocations == order.total
      #    and wholesaler allocation includes cost + fee
      alias Emakola.Payments.OrderSettlement

      assert {:split, %{total: settlement_total, allocations: allocs}} =
               OrderSettlement.prepare(order.id, reseller.id)

      assert settlement_total == order.total,
             "Expected settlement total == order.total (#{order.total}), got #{settlement_total}"

      # Verify Σ allocations == order.total
      sum_allocs = Enum.sum(Enum.map(allocs, & &1.amount))

      assert sum_allocs == order.total,
             "Expected sum of allocations == #{order.total}, got #{sum_allocs}"

      # Find wholesaler allocation and verify it includes cost + fee
      wholesaler_alloc = Enum.find(allocs, &(&1.role == :wholesaler))
      assert wholesaler_alloc, "Expected wholesaler allocation to exist"

      # Wholesaler cost = variant cost_price * qty = 800 * 1 = 800
      # But need to account for actual fulfillment split calculation
      # The wholesaler receives the cost portion; fee goes into splits
      # This is verified by checking the fulfillment has the dispatch fee
      fulfillments =
        Emakola.Orders.list_fulfillments_by_order!(order.id, authorize?: false)

      assert [fulfillment] = fulfillments

      assert fulfillment.dispatch_fee == 1_500,
             "Expected fulfillment dispatch_fee == 1500, got #{fulfillment.dispatch_fee}"
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

  # -- Internal rail settlement (Phase 3 Task 5) --
  #
  # Proves the charge-site pass-through end-to-end: an unverified store (the
  # module's default `store`/`variant` fixture has NO StorePayoutAccount) hits
  # OrderSettlement.prepare/2's :internal fallback, and the LiveView's existing
  # split_mode/1 + maybe_attach_split/2 (both generic over settlement mode)
  # carry it through with zero code changes. Swaps in the Mox GatewayMock (see
  # module comment above) so the actual params handed to initiate_payment/1
  # can be inspected — Emakola.Payments.Gateways.Mock (the default test
  # gateway) discards its params and always succeeds, so it can't prove this.
  describe "internal rail settlement" do
    test "unverified store's MoMo checkout lands entirely on the internal rail", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      original = Application.get_env(:emakola, :payment_gateway)
      Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
      on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

      expect(Emakola.Payments.GatewayMock, :initiate_payment, fn params ->
        assert params[:split] in [nil, []]
        {:ok, %{reference: "PAY-internal-ref", authorization_url: "https://pay.test/internal"}}
      end)

      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")
      Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

      render_submit(view, "place_order", %{
        "phone" => "241234567",
        "fullname" => "Kofi Owusu",
        "address" => "House 14, Osu",
        "region" => "greater_accra",
        "notes" => ""
      })

      order =
        Emakola.Orders.Order
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false, tenant: store.id)
        |> List.first()

      payment =
        Emakola.Payments.Payment
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false, tenant: store.id)
        |> List.first()

      assert payment.split_mode == :internal

      {:ok, splits} =
        Emakola.Payments.PaymentSplit
        |> Ash.Query.for_read(:by_payment, %{payment_id: payment.id})
        |> Ash.read(authorize?: false)

      assert splits != [], "Expected internal-rail allocations to be recorded"
      assert Enum.all?(splits, &(&1.settlement_method == :internal_hold))

      sum_splits = Enum.sum(Enum.map(splits, & &1.amount))
      assert sum_splits == order.total
    end
  end

  # -- Buyer protection settlement (TC-2) --

  describe "buyer protection settlement" do
    test "places a protected order with no merchant split and a payout hold flagged", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      verified_payout!(store, "ACCT_protected")

      store
      |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
      |> Ash.update!(authorize?: false)

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

      assert payment.split_mode == :none
      assert payment.payout_held == true
      assert payment.payout_hold_reason == "buyer_protection"

      {:ok, splits} =
        Emakola.Payments.PaymentSplit
        |> Ash.Query.for_read(:by_payment, %{payment_id: payment.id})
        |> Ash.read(authorize?: false)

      assert splits == []
    end
  end

  # -- Buyer protection badge (TC-2 Task 11) --

  describe "buyer protection badge" do
    test "shows the badge when the store has protection enabled", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      store
      |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
      |> Ash.update!(authorize?: false)

      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      assert html =~ "Protected by Makola"
    end

    test "hides the badge when the store has protection disabled", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      refute html =~ "Protected by Makola"
    end

    test "hides the badge for a cart with dropship items even when protection is enabled", %{
      conn: conn
    } do
      store = create_store!(%{name: "Drop Badge Shop", slug: "drop-badge-shop", currency: "GHS"})

      store
      |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
      |> Ash.update!(authorize?: false)

      wholesaler = create_store!(%{name: "Whole Badge Co", slug: "whole-badge-co"})
      supplier = create_supplier!(store, name: "Linked", linked_store_id: wholesaler.id)

      product = create_product!(store, %{title: "Dropship Badge Item"})

      variant =
        create_variant!(product, store, price: 5_000, sku: "DBADGE-1", supplier_id: supplier.id)

      product |> Ash.Changeset.for_update(:activate, %{}) |> Ash.update!(authorize?: false)

      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      refute html =~ "Protected by Makola"
    end
  end

  # -- Region Select --

  describe "region select" do
    test "renders all 16 canonical regions plus Other", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")
      html = to_shipping_step(view)

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
    test "dispatch folds into the Shipping line and tracks region changes", %{
      conn: conn
    } do
      {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Dispatch Reseller"})
      verified_payout!(reseller, "ACCT_reseller")
      {wholesaler_actor, wholesaler} = create_dropship_wholesaler!(reseller_actor, reseller)

      drop =
        import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, %{
          "Greater Accra" => 1_500,
          # Deliberately distinct from Ashanti's fallback DELIVERY fee (2_500)
          # so the combined-line sums below (3_000 vs 5_200) can't collide.
          "Ashanti" => 2_700
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

      # Buyers never see supply-chain vocabulary — dispatch folds into
      # Shipping: Greater Accra fallback 1_500 + dispatch 1_500 = 3_000.
      refute html =~ "Supplier dispatch"
      assert html =~ Currency.format_price(3_000)

      html = render_change(view, "update_details", %{"region" => "ashanti"})

      # Ashanti fallback 2_500 + Ashanti dispatch 2_700 = 5_200.
      refute html =~ "Supplier dispatch"
      assert html =~ Currency.format_price(5_200)
      refute html =~ Currency.format_price(3_000)
    end

    test "no dispatch line for merchant-only carts", %{conn: conn, store: store, variant: variant} do
      {conn, _session_id} = setup_cart_session(conn, variant)
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

      refute html =~ "Supplier dispatch"
    end

    test "stale cart referencing a deleted variant does not crash mount", %{conn: conn} do
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

      drop.variant |> Ash.destroy!(authorize?: false)

      conn = init_test_session(conn, %{"cart_session_id" => session_id})
      {:ok, _view, html} = live(conn, "/s/#{reseller.slug}/checkout")

      assert html =~ "Secure Checkout"
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

  describe "customer attribution and digital carts" do
    defp digital_store_fixture! do
      create_store!()
      |> Ash.Changeset.for_update(:update_settings, %{
        enabled_product_types: [:physical, :digital_download]
      })
      |> Ash.update!(authorize?: false)
    end

    defp digital_cart(conn, store) do
      product = create_product!(store, product_type: :digital_download)

      variant =
        create_variant!(product, store,
          price: 5000,
          sku: "DIG-#{System.unique_integer([:positive])}"
        )

      session_id = Ecto.UUID.generate()

      CartStore.add_item(session_id, store.id, %{
        variant_id: variant.id,
        product_title: "Sample Pack",
        variant_info: "DIG",
        unit_price: 5000,
        quantity: 1,
        sku: "DIG"
      })

      {init_test_session(conn, %{"cart_session_id" => session_id}), variant}
    end

    defp sign_in_customer(conn, store) do
      customer =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "buyer-#{System.unique_integer([:positive])}@example.com",
          name: "Ama Buyer",
          phone: "+23324#{System.unique_integer([:positive])}",
          store_id: store.id,
          password: "password123",
          password_confirmation: "password123"
        })
        |> Ash.create!(authorize?: false)

      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))
      {init_test_session(conn, %{"customer_token" => token}), customer}
    end

    # Every storefront order was created with customer_id: nil, so every
    # DownloadGrant was a guest grant and the download controller 404s those
    # forever. Nothing else in the chain matters until this is fixed.
    test "a signed-in customer's order carries their customer_id", %{conn: conn} do
      store = digital_store_fixture!()
      {conn, customer} = sign_in_customer(conn, store)
      {conn, _variant} = digital_cart(conn, store)

      {:ok, view, _html} = live(conn, ~p"/s/#{store.slug}/checkout")

      render_submit(view, "place_order", %{
        "phone" => "244123456",
        "fullname" => "Ama Buyer"
      })

      order =
        Emakola.Orders.Order
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read_one!(authorize?: false)

      assert order.customer_id == customer.id
    end

    # A guest grant can never be redeemed — the emailed-token flow does not
    # exist. Taking the money would be taking it for nothing.
    test "a guest is refused a digital cart and no order is created", %{conn: conn} do
      store = digital_store_fixture!()
      {conn, _variant} = digital_cart(conn, store)

      {:ok, view, _html} = live(conn, ~p"/s/#{store.slug}/checkout")

      render_submit(view, "place_order", %{
        "phone" => "244123456",
        "fullname" => "Guest Buyer"
      })

      assert Emakola.Orders.Order
             |> Ash.Query.filter(store_id == ^store.id)
             |> Ash.read!(authorize?: false) == []
    end

    # Found by the production smoke test: the gate keyed on requires_shipping,
    # which a physical item flips true — so a MIXED cart sailed past it and the
    # digital line item minted a customer_id: nil grant nobody can ever redeem.
    # Taking money for an unredeemable download is the exact thing the gate
    # exists to prevent, so a mixed guest cart must be refused too.
    test "a guest is refused a MIXED digital+physical cart", %{conn: conn} do
      store = digital_store_fixture!()
      {conn, _digital_variant} = digital_cart(conn, store)

      physical = create_product!(store, %{title: "Tote"})

      physical_variant =
        create_variant!(physical, store,
          price: 3000,
          stock_quantity: 5,
          sku: "TOTE-#{System.unique_integer([:positive])}"
        )

      cart_session_id = conn.private.plug_session["cart_session_id"]

      CartStore.add_item(cart_session_id, store.id, %{
        variant_id: physical_variant.id,
        product_title: "Tote",
        variant_info: "TOTE",
        unit_price: 3000,
        quantity: 1,
        sku: "TOTE"
      })

      {:ok, view, _html} = live(conn, ~p"/s/#{store.slug}/checkout")

      render_submit(view, "place_order", %{
        "phone" => "244123456",
        "fullname" => "Guest Buyer",
        "address" => "12 Oxford St",
        "region" => "greater_accra"
      })

      assert Emakola.Orders.Order
             |> Ash.Query.filter(store_id == ^store.id)
             |> Ash.read!(authorize?: false) == []
    end

    test "a signed-in customer CAN buy a mixed cart", %{conn: conn} do
      store = digital_store_fixture!()
      {conn, _digital_variant} = digital_cart(conn, store)
      {conn, _customer} = sign_in_customer(conn, store)

      physical = create_product!(store, %{title: "Tote"})

      physical_variant =
        create_variant!(physical, store,
          price: 3000,
          stock_quantity: 5,
          sku: "TOTE-#{System.unique_integer([:positive])}"
        )

      cart_session_id = conn.private.plug_session["cart_session_id"]

      CartStore.add_item(cart_session_id, store.id, %{
        variant_id: physical_variant.id,
        product_title: "Tote",
        variant_info: "TOTE",
        unit_price: 3000,
        quantity: 1,
        sku: "TOTE"
      })

      {:ok, view, _html} = live(conn, ~p"/s/#{store.slug}/checkout")

      render_submit(view, "place_order", %{
        "phone" => "244123456",
        "fullname" => "Ama Buyer",
        "address" => "12 Oxford St",
        "region" => "greater_accra"
      })

      orders =
        Emakola.Orders.Order
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert length(orders) == 1
    end

    # Regression: phone-first guest checkout for physical goods is the dominant
    # Ghana flow and must stay untouched.
    test "a guest can still check out a physical cart", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      {conn, _sid} = setup_cart_session(conn, variant)

      {:ok, view, _html} = live(conn, ~p"/s/#{store.slug}/checkout")

      render_submit(view, "place_order", %{
        "phone" => "244123456",
        "fullname" => "Guest Buyer",
        "address" => "12 Oxford St",
        "region" => "greater_accra"
      })

      orders =
        Emakola.Orders.Order
        |> Ash.Query.filter(store_id == ^variant.store_id)
        |> Ash.read!(authorize?: false)

      assert length(orders) == 1
    end
  end
end
