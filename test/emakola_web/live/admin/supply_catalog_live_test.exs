defmodule EmakolaWeb.Admin.SupplyCatalogLiveTest do
  use EmakolaWeb.ConnCase, async: true
  use Oban.Testing, repo: Emakola.Repo

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

    test "a search event without a \"search\" key does not crash the view", %{conn: conn} do
      create_published_offer!()

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog")

      render_change(view, "search", %{})

      assert render(view) =~ "Browse Suppliers"
    end

    test "a search event with a non-binary \"search\" value does not crash the view", %{
      conn: conn
    } do
      create_published_offer!()

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog")

      render_change(view, "search", %{"search" => %{"evil" => "map"}})

      assert render(view) =~ "Browse Suppliers"
    end

    test "a connected supplier's card shows the margin; an unconnected one covers it", %{
      conn: conn,
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      connected = create_published_offer!(title: "Connected Soap", supplier_name: "Tema Traders")
      _stranger = create_published_offer!(title: "Stranger Soap", supplier_name: "Kumasi Traders")
      connect!(reseller_actor, reseller, connected)

      {:ok, view, html} = live(conn, ~p"/admin/supply/catalog")

      # margin = 4_500 - 3_000 = 1_500 pesewas, shown only for the connection
      assert has_element?(view, "#offer-card-#{connected.offer.id} [data-role=card-margin]")
      refute has_element?(view, "#offer-card-#{_stranger.offer.id} [data-role=card-margin]")
      assert has_element?(view, "#offer-card-#{_stranger.offer.id} [data-role=card-locked]")
      # the supplier's own price stays off this page in both states
      refute html =~ EmakolaWeb.Helpers.Currency.format_price(3_000)
    end

    test "an offer with no photo gets the product glyph, not an empty frame", %{conn: conn} do
      fixture = create_published_offer!()

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog")

      assert has_element?(view, "#offer-card-#{fixture.offer.id} [data-role=card-art] svg")
      refute has_element?(view, "#offer-card-#{fixture.offer.id} [data-role=card-art] img")
    end

    test "the supplier reads as a coloured initial, ticked when connected", %{
      conn: conn,
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      fixture = create_published_offer!(supplier_name: "Tema Traders")
      connect!(reseller_actor, reseller, fixture)

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog")

      assert has_element?(
               view,
               "#offer-card-#{fixture.offer.id} [data-role=supplier-avatar]",
               "T"
             )

      assert has_element?(view, "#offer-card-#{fixture.offer.id} [data-role=supplier-tick]")
    end

    test "stock reads as a bar, never as the supplier's raw quantity", %{conn: conn} do
      # 7 is "low" but still available — an offer with NO available variant is
      # not discoverable at all (Offers.discoverable?/1), so :out never renders
      fixture = create_published_offer!(stock_quantity: 7)

      {:ok, view, html} = live(conn, ~p"/admin/supply/catalog")

      assert has_element?(view, "#offer-card-#{fixture.offer.id} [data-role=stock-bar]")
      # SupplyStockStatus is status-only: the wholesaler's count is not ours to show
      refute html =~ ">7<"
    end

    test "the my-suppliers filter keeps only connected offers", %{
      conn: conn,
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      mine = create_published_offer!(title: "Mine Soap", supplier_name: "Tema Traders")
      other = create_published_offer!(title: "Other Soap", supplier_name: "Kumasi Traders")
      connect!(reseller_actor, reseller, mine)

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog")
      html = view |> element("[phx-click=toggle_mine]") |> render_click()

      assert html =~ "Mine Soap"
      refute html =~ "Other Soap"
    end

    test "an offer wears the supplier's own category, and nothing when there is none", %{
      conn: conn
    } do
      labelled = create_published_offer!(title: "Kente Stole", category_name: "Fashion")
      bare = create_published_offer!(title: "Plain Soap", supplier_name: "Tema Traders")

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog")

      assert has_element?(
               view,
               "#offer-card-#{labelled.offer.id} [data-role=card-category]",
               "Fashion"
             )

      refute has_element?(view, "#offer-card-#{bare.offer.id} [data-role=card-category]")
    end

    test "no emoji stands in for an icon on the catalogue", %{conn: conn} do
      create_published_offer!()

      {:ok, _view, html} = live(conn, ~p"/admin/supply/catalog")

      refute html =~ "🔒"
    end
  end

  describe "catalog show" do
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

    test "unconnected: shows retail, dispatch fees, terms — locks wholesale + margin", %{
      conn: conn
    } do
      fixture = create_published_offer!()

      {:ok, _view, html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      assert html =~ "Shea Butter 500g"
      # suggested retail (4_500 pesewas) is public
      assert html =~ EmakolaWeb.Helpers.Currency.format_price(4_500)
      assert html =~ "Greater Accra"
      # dispatch fee (1_500 pesewas) is public
      assert html =~ EmakolaWeb.Helpers.Currency.format_price(1_500)
      assert html =~ "Returns accepted within seven days"
      # wholesale price (3_000 pesewas) must NOT leak
      refute html =~ EmakolaWeb.Helpers.Currency.format_price(3_000)
      assert html =~ "Request connection"
      assert html =~ "See your price and profit"
      assert html =~ "Connect to see"
    end

    test "connected: shows wholesale price and margin", %{
      conn: conn,
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      fixture = create_published_offer!()
      connect!(reseller_actor, reseller, fixture)

      {:ok, view, html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      # wholesale price (3_000 pesewas)
      assert html =~ EmakolaWeb.Helpers.Currency.format_price(3_000)
      # margin = 4500 - 3000 = 1500 pesewas at 50.0% — assert the percentage,
      # because format_price(1_500) collides with the dispatch fee (also 1_500)
      assert html =~ "50.0%"
      # max retail cap (6_000 pesewas) is connection-gated info
      assert html =~ EmakolaWeb.Helpers.Currency.format_price(6_000)
      assert html =~ "Add to my store"
      refute html =~ "Request connection"
      # stat tiles above the variants table — prove they're rendered
      assert has_element?(view, "#offer-money", "Sells for")
      assert has_element?(view, "#offer-money", "You pay")
      assert has_element?(view, "#offer-money", "You keep")
    end

    test "the offer page names the supplier's category when there is one", %{conn: conn} do
      fixture = create_published_offer!(category_name: "Fashion")

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      # The supplier's own word for it — categories are store-scoped, so this
      # is a label about THEIR shop, never a cross-store claim.
      assert has_element?(view, "[data-role=offer-category]", "Fashion")
    end

    test "the phone variant list gates wholesale exactly as the table does", %{conn: conn} do
      fixture = create_published_offer!()

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      # The variants exist twice in the DOM — a table from sm up, a stacked
      # list below it — so the gate has to hold in both or the phone leaks.
      assert has_element?(view, "[data-role=variant-rows]")
      refute has_element?(view, "[data-role=variant-rows]", "GH₵ 30")
      assert has_element?(view, "[data-role=variant-rows]", "Connect to see")
    end

    test "no emoji stands in for the lock", %{conn: conn} do
      fixture = create_published_offer!()

      {:ok, _view, html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      refute html =~ "🔒"
    end

    test "an offer with no photo fills the identity slot with a drawn glyph", %{conn: conn} do
      fixture = create_published_offer!()

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      assert has_element?(view, "#offer-identity svg")
      refute has_element?(view, "#offer-identity img")
    end

    test "an offer with a photo puts it in the same identity slot", %{conn: conn} do
      fixture = create_published_offer!()
      Factory.create_image!(fixture.product, fixture.wholesaler, position: 0)

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      # The photo lies OVER the glyph rather than replacing it: app.js hides an
      # image that fails to load, and hiding it has to reveal something. A
      # supplier whose file was deleted gets the glyph, not an empty square.
      assert has_element?(view, "#offer-identity img.absolute")
      assert has_element?(view, "#offer-identity svg")
    end

    test "unconnected: the money row names all three numbers and covers the locked two", %{
      conn: conn
    } do
      fixture = create_published_offer!()

      {:ok, view, html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      assert has_element?(view, "#offer-money", "Sells for")
      assert has_element?(view, "#offer-money", "You pay")
      assert has_element?(view, "#offer-money", "You keep")
      assert has_element?(view, "#offer-money", "Connect to see")
      # the retail price is public and sits in the row
      assert has_element?(view, "#offer-money", EmakolaWeb.Helpers.Currency.format_price(4_500))
      # the wholesale price (3_000 pesewas) is still gated
      refute html =~ EmakolaWeb.Helpers.Currency.format_price(3_000)
    end

    test "a locked tile keeps its own hue — the row reads as three numbers, not two greyed cells",
         %{conn: conn} do
      fixture = create_published_offer!()

      {:ok, _view, html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      [money_row] = Regex.run(~r{<div id="offer-money".*?(?=<div id="catalog-cta")}s, html)

      # One hue per number, the way admin_components' stat_card row does it.
      # The lock glyph and the covered bar carry "locked" — colour carries
      # WHICH number, so a merchant can still tell the tiles apart.
      assert money_row =~ "bg-info"
      assert money_row =~ "bg-violet-600"
      assert money_row =~ "bg-primary"
    end

    test "connected: the money row fills in and the margin carries its percentage", %{
      conn: conn,
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      fixture = create_published_offer!()
      connect!(reseller_actor, reseller, fixture)

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      assert has_element?(view, "#offer-money", EmakolaWeb.Helpers.Currency.format_price(3_000))
      refute has_element?(view, "#offer-money", "Connect to see")

      # The amount is the number being decided on; the percentage rides beside
      # it as a chip rather than doubling the length of the headline figure.
      assert has_element?(view, "[data-role=margin-delta]", "50.0%")
      refute has_element?(view, "[data-role=margin-value]", "%")
    end

    test "a paused offer redirects back to the catalog", %{conn: conn} do
      fixture = create_published_offer!()
      {:ok, _} = Offers.pause(fixture.wholesaler_actor, fixture.offer)

      assert {:error, {:live_redirect, %{to: "/admin/supply/catalog"}}} =
               live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")
    end

    test "an area without a quoted fee shows the placeholder", %{conn: conn} do
      fixture = create_published_offer!()

      {:ok, _view, html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      # "Ashanti" is a delivery area with no fee quoted
      assert html =~ "Ask supplier"
    end

    test "request_connection creates a pending connection and flips the CTA", %{
      conn: conn,
      reseller: reseller
    } do
      fixture = create_published_offer!()

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      html =
        view
        |> element("button[phx-click=request_connection]")
        |> render_click()

      assert html =~ "Request sent"

      require Ash.Query

      assert [%{status: :pending}] =
               Emakola.Suppliers.SupplyConnection
               |> Ash.Query.filter(
                 reseller_store_id == ^reseller.id and
                   wholesaler_store_id == ^fixture.wholesaler.id
               )
               |> Ash.read!(authorize?: false)
    end

    test "request_connection enqueues the wholesaler notification", %{conn: conn} do
      fixture = create_published_offer!()

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      view |> element("button[phx-click=request_connection]") |> render_click()

      assert [job] =
               all_enqueued(worker: Emakola.Notifications.Workers.ConnectionNotificationWorker)

      assert job.args["event"] == "requested"
    end

    test "import_offer creates a reseller listing when connected", %{
      conn: conn,
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      fixture = create_published_offer!()
      connect!(reseller_actor, reseller, fixture)

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      html =
        view
        |> element("button[phx-click=import_offer]")
        |> render_click()

      assert html =~ "added to your store"

      require Ash.Query

      assert [_listing] =
               Emakola.Suppliers.ResellerListing
               |> Ash.Query.filter(
                 reseller_store_id == ^reseller.id and offer_id == ^fixture.offer.id
               )
               |> Ash.read!(authorize?: false)
    end

    test "import_offer is rejected server-side when not connected", %{
      conn: conn,
      reseller: reseller
    } do
      fixture = create_published_offer!()

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      # No import button is rendered, but a crafted event must ALSO be
      # rejected — the gate is server-side, not markup-deep.
      html = render_click(view, "import_offer", %{})

      refute html =~ "added to your store"

      require Ash.Query

      assert [] =
               Emakola.Suppliers.ResellerListing
               |> Ash.Query.filter(reseller_store_id == ^reseller.id)
               |> Ash.read!(authorize?: false)
    end

    test "rejected connection: shows an unavailable notice, no live request button, wholesale still hidden",
         %{conn: conn, reseller_actor: reseller_actor, reseller: reseller} do
      fixture = create_published_offer!()
      reject!(reseller_actor, reseller, fixture)

      {:ok, view, html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      assert html =~ "Connection unavailable"
      assert html =~ "Manage it from your Partners page"
      refute has_element?(view, "button[phx-click=request_connection]")
      # wholesale price (3_000 pesewas) must NOT leak
      refute html =~ EmakolaWeb.Helpers.Currency.format_price(3_000)
    end

    test "request_connection while connection is unavailable shows the specific flash, not the generic one",
         %{conn: conn, reseller_actor: reseller_actor, reseller: reseller} do
      fixture = create_published_offer!()
      reject!(reseller_actor, reseller, fixture)

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      # No button is rendered (crafted event), same server-side re-check
      # discipline as import_offer.
      html = render_click(view, "request_connection", %{})

      assert html =~ "A connection with this supplier already exists"
      assert html =~ "Partners page"

      require Ash.Query

      assert [%{status: :rejected}] =
               Emakola.Suppliers.SupplyConnection
               |> Ash.Query.filter(
                 reseller_store_id == ^reseller.id and
                   wholesaler_store_id == ^fixture.wholesaler.id
               )
               |> Ash.read!(authorize?: false)
    end

    test "crafted request_connection while already connected: no crash, specific flash, exactly one connection row",
         %{conn: conn, reseller_actor: reseller_actor, reseller: reseller} do
      fixture = create_published_offer!()
      connect!(reseller_actor, reseller, fixture)

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      # No "Request connection" button is rendered while connected — this is
      # a crafted event, not a real click.
      html = render_click(view, "request_connection", %{})

      assert html =~ "A connection with this supplier already exists"

      require Ash.Query

      assert [%{status: :active}] =
               Emakola.Suppliers.SupplyConnection
               |> Ash.Query.filter(
                 reseller_store_id == ^reseller.id and
                   wholesaler_store_id == ^fixture.wholesaler.id
               )
               |> Ash.read!(authorize?: false)
    end
  end

  # -- fixtures --------------------------------------------------------------

  def create_published_offer!(opts \\ []) do
    {wholesaler_actor, wholesaler} =
      Factory.create_merchant_with_store!(%{name: opts[:supplier_name] || "Accra Wholesale"})

    category =
      if name = opts[:category_name],
        do: Factory.create_category!(wholesaler, name: name),
        else: nil

    product =
      Factory.create_product!(wholesaler,
        status: :active,
        title: opts[:title] || "Shea Butter 500g",
        category_id: category && category.id
      )

    variant =
      Factory.create_variant!(product, wholesaler,
        price: 5_000,
        stock_quantity: Keyword.get(opts, :stock_quantity, 10)
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

  def reject!(reseller_actor, reseller, fixture) do
    {:ok, conn} =
      Network.request(reseller_actor, %{
        wholesaler_store_id: fixture.wholesaler.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: reseller.id
      })

    {:ok, rejected} = Network.reject(fixture.wholesaler_actor, conn, "Not a fit right now")
    rejected
  end
end
