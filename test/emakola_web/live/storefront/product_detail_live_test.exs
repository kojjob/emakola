defmodule EmakolaWeb.Storefront.ProductDetailLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  require Ash.Query

  alias Emakola.Cart.CartStore
  alias Emakola.Suppliers.{GroupBuys, ListingImporter, Network, Offers}

  defp activate!(product) do
    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)
  end

  defp with_cart_session(conn) do
    session_id = Ecto.UUID.generate()
    {init_test_session(conn, %{"cart_session_id" => session_id}), session_id}
  end

  describe "SEO canonical" do
    test "canonical + og:url use the apex host, not the request host", %{conn: conn} do
      store = create_store!(%{slug: "seo-canon-shop"})
      product = create_product!(store, %{title: "Canonical Bowl"})
      create_variant!(product, store, %{price: 4500, track_inventory: false, stock_quantity: 0})
      activate!(product)

      canonical = EmakolaWeb.SEO.Canonical.product_url(store, product)

      html =
        %{conn | host: "evil.example.com"}
        |> get("/s/#{store.slug}/products/#{product.slug}")
        |> html_response(200)

      assert html =~ ~s(rel="canonical" href="#{canonical}")
      refute html =~ "evil.example.com"
    end
  end

  describe "market theme chrome" do
    test "the detail page wears Market's own header, footer, and warm palette", %{conn: conn} do
      store = create_store!(%{slug: "chrome-shop"})
      product = create_product!(store, %{title: "Chrome Bowl"})
      create_variant!(product, store, %{price: 4500, track_inventory: false, stock_quantity: 0})
      activate!(product)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      # Market's banner nav: secure-checkout ribbon + mobile search pill
      assert html =~ "Secure checkout"
      assert html =~ "Search this store"
      # Market's own footer, not Atelier's
      assert html =~ "bg-stone-900"
      refute html =~ "#111111"
      # Warm stone palette — the PDP's cold slate ink is gone (the shared
      # search modal still carries its own palette; out of theme scope)
      refute html =~ "#0F172A"
    end
  end

  describe "add_to_cart stock gate" do
    test "records a privacy-safe product-view opportunity signal", %{conn: conn} do
      store = create_store!(%{slug: "signal-shop"})
      product = create_product!(store, %{title: "Signal Bowl"})
      create_variant!(product, store, %{price: 4_500, stock_quantity: 2})
      activate!(product)

      {:ok, _view, _html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      events =
        Emakola.Analytics.AppEvent
        |> Ash.Query.filter(event_name == "earn.product_view")
        |> Ash.read!(authorize?: false)

      assert Enum.any?(events, &(&1.metadata["product_id"] == product.id))
      refute Enum.any?(events, &Map.has_key?(&1.metadata, "customer_id"))
    end

    test "untracked variant adds to cart even at zero stock", %{conn: conn} do
      store = create_store!(%{slug: "untracked-shop"})
      product = create_product!(store, %{title: "Made To Order Bowl"})
      create_variant!(product, store, %{price: 4500, track_inventory: false, stock_quantity: 0})
      activate!(product)
      {conn, session_id} = with_cart_session(conn)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      html = view |> element("button[phx-click=add_to_cart]") |> render_click()

      assert html =~ "Added to cart"
      assert CartStore.cart_count(session_id, store.id) == 1
    end

    test "tracked variant at zero stock cannot be added to the cart", %{conn: conn} do
      store =
        create_store!(%{slug: "tracked-shop", whatsapp_number: "+233 24 118 4402"})

      product = create_product!(store, %{title: "Limited Bowl"})
      create_variant!(product, store, %{price: 4500, track_inventory: true, stock_quantity: 0})
      activate!(product)
      {conn, _session_id} = with_cart_session(conn)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      # A genuinely out-of-stock (tracked) product offers no buy button at all —
      # the gate still respects track_inventory rather than ignoring it, and the
      # shopper is offered a way to be told instead of a dead control. The
      # untracked case above proves the distinction still holds.
      refute has_element?(view, "button[phx-click=add_to_cart]")
      assert has_element?(view, "#back-in-stock")
    end
  end

  describe "partner fulfillment disclosure" do
    test "does not label merchant-owned products as partner fulfilled", %{conn: conn} do
      store = create_store!(%{slug: "merchant-owned-product"})
      product = create_product!(store, title: "Own Stock Basket")
      create_variant!(product, store, stock_quantity: 3)
      activate!(product)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")
      refute has_element?(view, "#partner-fulfillment-disclosure")
    end

    test "identifies imported products as fulfilled by a verified partner", %{conn: conn} do
      {wholesaler_actor, wholesaler} =
        create_merchant_with_store!(%{name: "Verified Kente Partner", slug: "verified-kente"})

      {reseller_actor, reseller} =
        create_merchant_with_store!(%{name: "Disclosure Shop", slug: "disclosure-shop"})

      product = create_product!(wholesaler, status: :active, title: "Partner Basket")
      variant = create_variant!(product, wholesaler, stock_quantity: 8)

      {:ok, offer} =
        Offers.create_draft(wholesaler_actor, %{
          wholesaler_store_id: wholesaler.id,
          source_product_id: product.id,
          earning_model: :markup
        })

      {:ok, _terms} =
        Offers.add_variant(wholesaler_actor, offer, %{
          source_variant_id: variant.id,
          supplier_price: 4_000,
          suggested_retail_price: 5_000,
          max_retail_price: 6_000
        })

      {:ok, published} = Offers.publish(wholesaler_actor, offer)

      {:ok, pending} =
        Network.request(wholesaler_actor, %{
          wholesaler_store_id: wholesaler.id,
          reseller_store_id: reseller.id,
          requested_by_store_id: wholesaler.id
        })

      {:ok, _active} = Network.approve(reseller_actor, pending)
      {:ok, listing} = ListingImporter.import(reseller_actor, reseller.id, published)

      {:ok, view, _html} =
        live(conn, "/s/#{reseller.slug}/products/#{listing.reseller_product.slug}")

      assert has_element?(
               view,
               "#partner-fulfillment-disclosure",
               "Fulfilled by verified partner Verified Kente Partner"
             )
    end
  end

  describe "customer group buys" do
    test "shows complete economics and starts a linked payment", %{conn: conn} do
      {supplier_actor, supplier} = create_merchant_with_store!()
      {reseller_actor, reseller} = create_merchant_with_store!(%{slug: "circle-shop"})
      source_product = create_product!(supplier, status: :active, title: "Circle Basket")
      source_variant = create_variant!(source_product, supplier, stock_quantity: 20)

      {:ok, offer} =
        Offers.create_draft(supplier_actor, %{
          wholesaler_store_id: supplier.id,
          source_product_id: source_product.id,
          earning_model: :markup
        })

      {:ok, _terms} =
        Offers.add_variant(supplier_actor, offer, %{
          source_variant_id: source_variant.id,
          supplier_price: 4_000,
          suggested_retail_price: 5_000,
          max_retail_price: 6_000
        })

      {:ok, offer} = Offers.publish(supplier_actor, offer)

      {:ok, pending} =
        Network.request(supplier_actor, %{
          wholesaler_store_id: supplier.id,
          reseller_store_id: reseller.id,
          requested_by_store_id: supplier.id
        })

      {:ok, _active} = Network.approve(reseller_actor, pending)
      {:ok, listing} = ListingImporter.import(reseller_actor, reseller.id, offer)
      listing = Ash.load!(listing, [listing_variants: :offer_variant], authorize?: false)
      mapping = List.first(listing.listing_variants)
      deadline = DateTime.add(DateTime.utc_now(), 7, :day)

      {:ok, campaign} =
        GroupBuys.create(reseller_actor, reseller.id, %{
          listing_id: listing.id,
          listing_variant_id: mapping.id,
          title: "Five-neighbour basket circle",
          threshold_quantity: 5,
          unit_price: 5_000,
          deadline: deadline,
          refund_deadline: DateTime.add(deadline, 2, :day)
        })

      {:ok, campaign} = GroupBuys.open(reseller_actor, reseller.id, campaign.id)
      customer = create_customer!(reseller)
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))
      conn = init_test_session(conn, %{"customer_token" => token})

      {:ok, view, _html} =
        live(conn, "/s/#{reseller.slug}/products/#{listing.reseller_product.slug}")

      assert has_element?(view, "#group-buy-offers", "Buy together, pay less")
      assert has_element?(view, "#group-buy-form-#{campaign.id}")
      assert has_element?(view, "#group-buy-offers", "Five-neighbour basket circle")
      assert has_element?(view, "#group-buy-offers", "automatically refunded")

      assert {:error, {:redirect, %{to: gateway_url}}} =
               view
               |> form("#group-buy-form-#{campaign.id}", group_buy: %{quantity: "2"})
               |> render_submit()

      assert gateway_url =~ "mock.paystack.co/pay/"

      commitment =
        Emakola.Suppliers.GroupBuyCommitment
        |> Ash.Query.filter(campaign_id == ^campaign.id and customer_id == ^customer.id)
        |> Ash.read_one!(authorize?: false)

      assert commitment.quantity == 2
      assert commitment.amount == 10_000
      assert commitment.payment_id
    end
  end
end
