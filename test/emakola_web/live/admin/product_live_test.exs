defmodule EmakolaWeb.Admin.ProductLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  require Ash.Query

  describe "ProductLive.Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/products")
    end
  end

  describe "ProductLive.Index (authenticated)" do
    setup %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      %{conn: conn, user: user, org: org}
    end

    test "renders product list heading", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/products")

      assert html =~ "Products"
      assert has_element?(view, "button", "New Product")
    end

    test "renders status filter tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/products")

      assert html =~ "All"
      assert html =~ "Draft"
      assert html =~ "Active"
      assert html =~ "Archived"
    end

    test "renders search input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")

      assert has_element?(view, "input[name=\"search\"]")
    end
  end

  describe "ProductLive.Form (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/products/new")
    end
  end

  describe "ProductLive.Form (authenticated)" do
    setup %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      %{conn: conn, user: user, org: org}
    end

    test "renders new product form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/products/new")

      assert html =~ "New Product"
      assert html =~ "Title"
      assert html =~ "Save as Draft"
    end
  end

  describe "ProductLive.Form create (authenticated merchant)" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    # Regression: form saves were silently denied after the H2 policy
    # tightening because create_product was called without authorize?: false.
    test "submitting the form creates a draft product", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/new")

      view
      |> element("form[phx-submit=\"save_product\"]")
      |> render_submit(%{"product" => %{"title" => "Bolga Basket", "description" => "Handwoven"}})

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id: store.id)
        |> Ash.read_one!(authorize?: false)

      assert product.title == "Bolga Basket"
      assert product.status == :draft
    end
  end

  describe "ProductLive.Index edit (authenticated merchant)" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    # Regression: open_edit_product crashed the LiveView with
    # Protocol.UndefinedError because get_product did not load :images,
    # and the slide-over template enumerates @editing_product.images.
    test "clicking Edit opens the slide-over with the product loaded",
         %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Kente Stole"})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      html =
        view
        |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
        |> render_click()

      assert html =~ "Edit Product"
      assert html =~ "Kente Stole"
    end

    test "edit slide-over shows a price input per variant", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Adinkra Scarf"})
      variant = Factory.create_variant!(product, store, %{price: 15050, sku: "ADK-1"})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      html =
        view
        |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
        |> render_click()

      assert html =~ "Pricing"
      assert html =~ "ADK-1"

      assert has_element?(
               view,
               ~s{input[name="product[variant_prices][#{variant.id}]"][value="150.50"]}
             )
    end

    # Regression: build_product_attrs always included :store_id, which the
    # product :update action does not accept — every edit save failed with
    # NoSuchInput and the form just showed an error flash.
    test "submitting the edit form updates the product", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Old Title"})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      view
      |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
      |> render_click()

      view
      |> element("#product-slide-over-form")
      |> render_submit(%{"product" => %{"title" => "New Title"}})

      updated = Ash.get!(Emakola.Catalog.Product, product.id, authorize?: false)
      assert updated.title == "New Title"
    end

    test "submitting a changed price updates the variant", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Adinkra Scarf"})
      variant = Factory.create_variant!(product, store, %{price: 15050})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      view
      |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
      |> render_click()

      view
      |> element("#product-slide-over-form")
      |> render_submit(%{
        "product" => %{
          "title" => "Adinkra Scarf",
          "variant_prices" => %{variant.id => "200"}
        }
      })

      updated = Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)
      assert updated.price == 20_000
    end

    test "an invalid price shows an error and does not save", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Adinkra Scarf"})
      variant = Factory.create_variant!(product, store, %{price: 15050})

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      view
      |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
      |> render_click()

      html =
        view
        |> element("#product-slide-over-form")
        |> render_submit(%{
          "product" => %{
            "title" => "Adinkra Scarf",
            "variant_prices" => %{variant.id => "abc"}
          }
        })

      assert html =~ "must be a valid amount"

      unchanged = Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)
      assert unchanged.price == 15_050
    end

    test "clicking Edit on a product with images shows the image grid",
         %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Fugu Smock"})
      image = Factory.create_image!(product, store)

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      html =
        view
        |> element(~s{tr button[phx-click*="open_edit_product"][phx-click*="#{product.id}"]})
        |> render_click()

      assert html =~ "Edit Product"
      assert html =~ (image.thumbnail_url || image.url)
    end
  end

  # Uses the pattern from LiveViewHelpers — creates user, org, membership
  defp setup_authenticated_user(conn) do
    user = Factory.create_user!()
    org = Factory.create_organisation!()
    Factory.create_membership!(user, org, :owner)

    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(user))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, user, org}
  end
end
