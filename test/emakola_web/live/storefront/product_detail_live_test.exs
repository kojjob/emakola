defmodule EmakolaWeb.Storefront.ProductDetailLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  require Ash.Query

  alias Emakola.Cart.CartStore
  alias Emakola.Suppliers.{ListingImporter, Network, Offers}

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

    test "tracked variant at zero stock disables the add-to-cart button", %{conn: conn} do
      store = create_store!(%{slug: "tracked-shop"})
      product = create_product!(store, %{title: "Limited Bowl"})
      create_variant!(product, store, %{price: 4500, track_inventory: true, stock_quantity: 0})
      activate!(product)
      {conn, _session_id} = with_cart_session(conn)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      # A genuinely out-of-stock (tracked) product still disables the button —
      # the gate now respects track_inventory rather than ignoring it.
      assert has_element?(view, "button[phx-click=add_to_cart][disabled]")
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
end
