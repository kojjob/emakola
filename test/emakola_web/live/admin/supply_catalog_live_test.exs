defmodule EmakolaWeb.Admin.SupplyCatalogLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Suppliers.{Network, Offers}

  describe "unauthenticated" do
    test "redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/supply/catalog")
    end
  end

  describe "catalog index" do
    setup %{conn: conn} do
      {reseller_actor, reseller} = Factory.create_merchant_with_store!(%{name: "Reseller Shop"})

      token =
        EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(reseller_actor))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, reseller_actor: reseller_actor, reseller: reseller}
    end

    test "lists an unconnected supplier's offer WITHOUT wholesale pricing", %{conn: conn} do
      fixture = create_published_offer!()

      {:ok, _view, html} = live(conn, ~p"/admin/supply/catalog")

      assert html =~ "Shea Butter 500g"
      assert html =~ "Accra Wholesale"
      # suggested retail (4_500 pesewas) is public
      assert html =~ EmakolaWeb.Helpers.Currency.format_price(4_500)
      # wholesale price (3_000 pesewas) must NOT leak on the index
      refute html =~ EmakolaWeb.Helpers.Currency.format_price(3_000)
      assert fixture.offer.dispatch_fees == %{"Greater Accra" => 1_500}
      # dispatch fee shown
      assert html =~ EmakolaWeb.Helpers.Currency.format_price(1_500)
    end

    test "search filters by product title", %{conn: conn} do
      create_published_offer!(title: "Shea Butter 500g")
      create_published_offer!(title: "Kente Stole", supplier_name: "Bonwire Weavers")

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog")

      html =
        view
        |> element("form[phx-change=search]")
        |> render_change(%{"search" => "kente"})

      assert html =~ "Kente Stole"
      refute html =~ "Shea Butter 500g"
    end
  end

  # -- fixtures --------------------------------------------------------------

  def create_published_offer!(opts \\ []) do
    {wholesaler_actor, wholesaler} =
      Factory.create_merchant_with_store!(%{name: opts[:supplier_name] || "Accra Wholesale"})

    product =
      Factory.create_product!(wholesaler,
        status: :active,
        title: opts[:title] || "Shea Butter 500g"
      )

    variant =
      Factory.create_variant!(product, wholesaler,
        price: 5_000,
        stock_quantity: 10
      )

    {:ok, offer} =
      Offers.create_draft(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        source_product_id: product.id,
        earning_model: :markup,
        delivery_areas: ["Greater Accra", "Ashanti"],
        return_terms: "Returns accepted within seven days",
        returns_window_days: 7,
        warranty_months: 6
      })

    {:ok, _terms} =
      Offers.add_variant(wholesaler_actor, offer, %{
        source_variant_id: variant.id,
        supplier_price: 3_000,
        suggested_retail_price: 4_500,
        max_retail_price: 6_000
      })

    {:ok, offer} =
      Offers.update_terms(wholesaler_actor, offer, %{
        dispatch_fees: %{"Greater Accra" => 1_500}
      })

    {:ok, published} = Offers.publish(wholesaler_actor, offer)

    %{
      wholesaler_actor: wholesaler_actor,
      wholesaler: wholesaler,
      product: product,
      variant: variant,
      offer: published
    }
  end

  def connect!(reseller_actor, reseller, fixture) do
    {:ok, conn} =
      Network.request(reseller_actor, %{
        wholesaler_store_id: fixture.wholesaler.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: reseller.id
      })

    {:ok, active} = Network.approve(fixture.wholesaler_actor, conn)
    active
  end
end
