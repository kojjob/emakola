defmodule EmakolaWeb.Admin.SupplyOffersLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Suppliers.Offers

  describe "unauthenticated" do
    test "redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/supply/offers")
    end
  end

  describe "offers index" do
    setup %{conn: conn} do
      {merchant, store} = Factory.create_merchant_with_store!(%{name: "Supply Side"})
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders with an empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/supply/offers")

      assert html =~ "My Offers"
      assert html =~ "New offer"
    end

    test "lists an owned draft with its status and actions", %{
      conn: conn,
      merchant: merchant,
      store: store
    } do
      _offer = create_draft_offer!(merchant, store, "Shea Butter 500g")

      {:ok, _view, html} = live(conn, ~p"/admin/supply/offers")

      assert html =~ "Shea Butter 500g"
      assert html =~ "Draft"
      assert html =~ "Publish"
    end

    test "publishes a draft from the index", %{conn: conn, merchant: merchant, store: store} do
      offer = create_draft_offer!(merchant, store, "Kente Stole")

      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers")

      html =
        view
        |> element(~s{button[phx-click=publish_offer][phx-value-id="#{offer.id}"]})
        |> render_click()

      assert html =~ "Published"
      assert html =~ "Pause"
    end

    test "pauses and republishes", %{conn: conn, merchant: merchant, store: store} do
      offer = create_draft_offer!(merchant, store, "Bolga Basket")
      {:ok, _} = Offers.publish(merchant, offer)

      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers")

      html =
        view
        |> element(~s{button[phx-click=pause_offer][phx-value-id="#{offer.id}"]})
        |> render_click()

      assert html =~ "Paused"
      assert html =~ "Republish"

      html =
        view
        |> element(~s{button[phx-click=publish_offer][phx-value-id="#{offer.id}"]})
        |> render_click()

      assert html =~ "Published"
    end

    test "a crafted event with a foreign offer id flashes and changes nothing", %{
      conn: conn,
      merchant: merchant,
      store: store
    } do
      _own = create_draft_offer!(merchant, store, "Adinkra Tote")

      {other_merchant, other_store} = Factory.create_merchant_with_store!()
      foreign = create_draft_offer!(other_merchant, other_store, "Foreign Offer")

      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers")

      html = render_click(view, "publish_offer", %{"id" => foreign.id})

      refute html =~ "Published"

      reloaded = Ash.get!(Emakola.Suppliers.SupplierOffer, foreign.id, authorize?: false)
      assert reloaded.status == :draft
    end
  end

  describe "offer form (new, markup)" do
    setup %{conn: conn} do
      {merchant, store} = Factory.create_merchant_with_store!(%{name: "Form Supply"})
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      product = Factory.create_product!(store, status: :active, title: "Baobab Oil 250ml")

      variant =
        Factory.create_variant!(product, store, price: 6_000, sku: "BAO-250", stock_quantity: 12)

      %{conn: conn, merchant: merchant, store: store, product: product, variant: variant}
    end

    test "renders the form shell", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/supply/offers/new")

      assert html =~ "New offer"
      assert html =~ "Baobab Oil 250ml"
      assert html =~ "Greater Accra"
    end

    test "save draft creates the offer with priced variant, regions, and fees", %{
      conn: conn,
      store: store,
      variant: variant,
      product: product
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "supplier",
        "value" => "38.00"
      })

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "suggested",
        "value" => "60"
      })

      render_click(view, "toggle_region", %{"region" => "Greater Accra"})
      render_change(view, "set_region_fee", %{"region" => "Greater Accra", "value" => "15"})
      render_change(view, "set_term", %{"field" => "return_terms", "value" => "7-day returns"})

      view |> element("button[phx-click=save_draft]") |> render_click()

      require Ash.Query

      [offer] =
        Emakola.Suppliers.SupplierOffer
        |> Ash.Query.filter(wholesaler_store_id == ^store.id)
        |> Ash.Query.load(:offer_variants)
        |> Ash.read!(authorize?: false)

      assert offer.status == :draft
      assert offer.delivery_areas == ["Greater Accra"]
      assert offer.dispatch_fees == %{"Greater Accra" => 1_500}
      assert offer.return_terms == "7-day returns"
      assert [terms] = offer.offer_variants
      assert terms.supplier_price == 3_800
      assert terms.suggested_retail_price == 6_000
    end

    test "an unparseable price shows an error and does not save", %{
      conn: conn,
      store: store,
      variant: variant,
      product: product
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "supplier",
        "value" => "abc"
      })

      html = view |> element("button[phx-click=save_draft]") |> render_click()

      assert html =~ "must be a valid amount"

      require Ash.Query

      assert [] =
               Emakola.Suppliers.SupplierOffer
               |> Ash.Query.filter(wholesaler_store_id == ^store.id)
               |> Ash.read!(authorize?: false)
    end

    test "unchecking a region clears its fee", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})
      render_click(view, "toggle_region", %{"region" => "Volta"})
      render_change(view, "set_region_fee", %{"region" => "Volta", "value" => "9"})
      render_click(view, "toggle_region", %{"region" => "Volta"})
      html = render_click(view, "toggle_region", %{"region" => "Volta"})

      # re-checked region shows an empty fee input, not the stale "9"
      refute html =~ ~s(value="9")
    end

    test "a second offer for the same product is rejected with a helpful error", %{
      conn: conn,
      merchant: merchant,
      store: store,
      product: product,
      variant: variant
    } do
      {:ok, _existing} =
        Offers.create_draft(merchant, %{
          wholesaler_store_id: store.id,
          source_product_id: product.id,
          earning_model: :markup,
          delivery_areas: ["Greater Accra"]
        })

      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "supplier",
        "value" => "10"
      })

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "suggested",
        "value" => "20"
      })

      html = view |> element("button[phx-click=save_draft]") |> render_click()

      assert html =~ "already have an offer for this product"
    end

    test "crafted payloads no-op instead of crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{})
      render_change(view, "set_variant_price", %{"variant-id" => %{"x" => 1}})
      render_click(view, "toggle_region", %{"region" => "Atlantis"})
      render_change(view, "set_term", %{"field" => "not_a_field", "value" => "x"})

      assert render(view) =~ "New offer"
    end
  end

  describe "offer form (publish + models + restricted edit)" do
    setup %{conn: conn} do
      {merchant, store} = Factory.create_merchant_with_store!(%{name: "Publish Supply"})
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      product = Factory.create_product!(store, status: :active, title: "Kente Sash")
      variant = Factory.create_variant!(product, store, price: 8_000, stock_quantity: 5)

      %{conn: conn, merchant: merchant, store: store, product: product, variant: variant}
    end

    test "publish from the form makes the offer live", %{
      conn: conn,
      store: store,
      product: product,
      variant: variant
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "supplier",
        "value" => "50"
      })

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "suggested",
        "value" => "80"
      })

      render_click(view, "toggle_region", %{"region" => "Ashanti"})

      view |> element("button[phx-click=publish]") |> render_click()

      require Ash.Query

      [offer] =
        Emakola.Suppliers.SupplierOffer
        |> Ash.Query.filter(wholesaler_store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert offer.status == :published
    end

    test "fixed commission must reconcile exactly", %{
      conn: conn,
      product: product,
      variant: variant
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})
      render_click(view, "select_model", %{"model" => "fixed_commission"})

      for {field, value} <- [{"supplier", "50"}, {"suggested", "80"}, {"commission", "20"}] do
        render_change(view, "set_variant_price", %{
          "variant-id" => variant.id,
          "field" => field,
          "value" => value
        })
      end

      html = view |> element("button[phx-click=save_draft]") |> render_click()
      assert html =~ "must equal the customer price exactly"

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "commission",
        "value" => "30"
      })

      view |> element("button[phx-click=save_draft]") |> render_click()

      require Ash.Query

      [offer] =
        Emakola.Suppliers.SupplierOffer
        |> Ash.Query.filter(source_product_id == ^product.id)
        |> Ash.Query.load(:offer_variants)
        |> Ash.read!(authorize?: false)

      assert [%{fixed_commission_amount: 3_000}] = offer.offer_variants
    end

    test "published offers open in restricted edit", %{
      conn: conn,
      merchant: merchant,
      store: store,
      product: product,
      variant: variant
    } do
      {:ok, offer} =
        Offers.create_draft(merchant, %{
          wholesaler_store_id: store.id,
          source_product_id: product.id,
          earning_model: :markup,
          delivery_areas: ["Greater Accra"]
        })

      {:ok, _} =
        Offers.add_variant(merchant, offer, %{
          source_variant_id: variant.id,
          supplier_price: 5_000,
          suggested_retail_price: 8_000
        })

      {:ok, _} = Offers.publish(merchant, offer)

      {:ok, view, html} = live(conn, ~p"/admin/supply/offers/#{offer.id}/edit")

      assert html =~ "Pricing is locked while the offer is live"
      assert has_element?(view, "input[name=value][disabled]")

      render_change(view, "set_term", %{"field" => "return_terms", "value" => "14-day returns"})
      view |> element("button[phx-click=save_draft]") |> render_click()

      reloaded = Ash.get!(Emakola.Suppliers.SupplierOffer, offer.id, authorize?: false)
      assert reloaded.return_terms == "14-day returns"
      # pricing untouched
      [terms] =
        reloaded |> Ash.load!(:offer_variants, authorize?: false) |> Map.get(:offer_variants)

      assert terms.supplier_price == 5_000
    end
  end

  # -- fixtures ---------------------------------------------------------------

  def create_draft_offer!(merchant, store, title) do
    product = Factory.create_product!(store, status: :active, title: title)
    variant = Factory.create_variant!(product, store, price: 5_000, stock_quantity: 10)

    {:ok, offer} =
      Offers.create_draft(merchant, %{
        wholesaler_store_id: store.id,
        source_product_id: product.id,
        earning_model: :markup,
        delivery_areas: ["Greater Accra"]
      })

    {:ok, _} =
      Offers.add_variant(merchant, offer, %{
        source_variant_id: variant.id,
        supplier_price: 3_000,
        suggested_retail_price: 4_500
      })

    offer
  end
end
