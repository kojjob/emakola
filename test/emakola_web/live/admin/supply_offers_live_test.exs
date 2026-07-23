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
