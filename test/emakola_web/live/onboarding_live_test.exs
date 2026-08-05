defmodule EmakolaWeb.OnboardingLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Emakola.Factory

  require Ash.Query

  defp auth_conn(conn, user) do
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(user))

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  describe "mount" do
    test "renders step 1 for unauthenticated user", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      {:ok, _view, html} = live(conn, "/onboarding")
      assert html =~ "Name Your Store"
    end

    test "redirects to dashboard when merchant already has a store", %{conn: conn} do
      merchant = create_merchant!()
      store = create_store!()
      create_store_membership!(merchant, store, :owner)

      conn = auth_conn(conn, merchant)

      assert {:error, {:live_redirect, %{to: "/dashboard"}}} = live(conn, "/onboarding")
    end

    test "legacy User subject no longer resolves (treated as anonymous)", %{conn: conn} do
      user = create_user!()
      org = create_organisation!()
      create_membership!(user, org, :owner)

      conn = auth_conn(conn, user)

      # Previously redirected to /dashboard via the legacy User path; that
      # auth path is retired, so the visitor is anonymous and step 1 renders.
      {:ok, _view, html} = live(conn, "/onboarding")
      assert html =~ "Name Your Store"
    end

    test "renders step 1 for authenticated merchant without store", %{conn: conn} do
      merchant = create_merchant!()
      conn = auth_conn(conn, merchant)

      {:ok, _view, html} = live(conn, "/onboarding")
      assert html =~ "Name Your Store"
    end
  end

  describe "step 1 validation" do
    test "blocks advance with blank store name", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      {:ok, view, _html} = live(conn, "/onboarding")

      render_click(view, "next_step")
      assert has_element?(view, "#onboarding-error")
    end

    test "generates slug from store name", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_store_name", %{"store_name" => "Kojo's Fashion"})
      assert has_element?(view, "#store-slug-preview[data-slug='kojos-fashion']")
    end

    test "advances from step 1 with valid store name", %{conn: conn} do
      merchant = create_merchant!()
      conn = auth_conn(conn, merchant)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_store_name", %{"store_name" => "My Store"})
      html = render_click(view, "next_step")
      assert html =~ "Choose Your Theme"
    end
  end

  describe "change bindings are form-wrapped (browser-faithful)" do
    # phx-change on a bare input is silently dead in real browsers
    # ("form events require the input to be inside a form" — LiveView JS),
    # while view-level render_change/3 bypasses the DOM entirely. These
    # tests target the actual <form> elements so the binding structure a
    # real browser needs is what gets verified.
    test "typing a store name through its form enables Continue", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      {:ok, view, _html} = live(conn, "/onboarding")

      assert has_element?(view, "#onboarding-next-button[disabled]")

      view
      |> element("#store-name-form")
      |> render_change(%{"store_name" => "Kojo Fashion"})

      refute has_element?(view, "#onboarding-next-button[disabled]")
      assert has_element?(view, "#store-slug-preview[data-slug='kojo-fashion']")
    end

    test "currency select is inside a change form", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      {:ok, view, _html} = live(conn, "/onboarding")

      view
      |> element("#currency-form")
      |> render_change(%{"currency" => "NGN"})

      assert has_element?(view, "#currency option[value='NGN'][selected]")
    end

    test "product name and price inputs are inside change forms", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      {:ok, view, _html} = live(conn, "/onboarding")

      view |> element("#store-name-form") |> render_change(%{"store_name" => "Shop"})
      render_click(view, "next_step")
      render_click(view, "next_step")

      view |> element("#product-name-form") |> render_change(%{"product_name" => "Ankara Dress"})

      view
      |> element("#product-price-form")
      |> render_change(%{"product_price" => "150"})

      assert has_element?(view, "#product_name[value='Ankara Dress']")
      assert has_element?(view, "#product_price[value='150']")
    end
  end

  describe "step 2 (theme selection)" do
    test "shows theme selection with three themes", %{conn: conn} do
      merchant = create_merchant!()
      conn = auth_conn(conn, merchant)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_store_name", %{"store_name" => "Theme Store"})
      html = render_click(view, "next_step")

      assert html =~ "Market"
      assert html =~ "Atelier"
      assert html =~ "Vibrant"
    end

    test "can select a theme", %{conn: conn} do
      merchant = create_merchant!()
      conn = auth_conn(conn, merchant)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_store_name", %{"store_name" => "Theme Store"})
      render_click(view, "next_step")

      html = render_click(view, "select_theme", %{"theme-id" => "atelier"})
      assert html =~ "border-emerald-500"
    end
  end

  describe "step 3 (add product)" do
    test "can skip adding a product", %{conn: conn} do
      merchant = create_merchant!()
      conn = auth_conn(conn, merchant)

      {:ok, view, _html} = live(conn, "/onboarding")

      # Step 1: Enter store name
      render_change(view, "update_store_name", %{"store_name" => "Skip Store"})
      render_click(view, "next_step")

      # Step 2: Theme (continue with default)
      render_click(view, "next_step")

      # Step 3: Skip
      html = render_click(view, "skip_step")
      assert html =~ "Ready" or html =~ "ready"
    end

    test "can advance with product details", %{conn: conn} do
      merchant = create_merchant!()
      conn = auth_conn(conn, merchant)

      {:ok, view, _html} = live(conn, "/onboarding")

      # Step 1
      render_change(view, "update_store_name", %{"store_name" => "Product Store"})
      render_click(view, "next_step")

      # Step 2: Theme (continue with default)
      render_click(view, "next_step")

      # Step 3: Enter product info
      render_change(view, "update_product", %{
        "product_name" => "Test Product",
        "product_price" => "50"
      })

      html = render_click(view, "next_step")
      assert html =~ "Ready" or html =~ "ready"
    end
  end

  describe "store creation on complete" do
    test "creates the sample product and variant on complete", %{conn: conn} do
      # Regression: nil-actor writes were silently denied after the H2 policy
      # tightening because maybe_create_product called the domain interface
      # without authorize?: false.
      merchant = create_merchant!()
      conn = auth_conn(conn, merchant)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_store_name", %{"store_name" => "Sample Product Store"})
      render_click(view, "next_step")

      # Step 2: Theme (continue with default)
      render_click(view, "next_step")

      # Step 3: Product details
      render_change(view, "update_product", %{
        "product_name" => "Kente Scarf",
        "product_price" => "50"
      })

      render_click(view, "next_step")
      render_click(view, "complete")
      assert_redirect(view, "/dashboard")

      store =
        Emakola.Stores.Store
        |> Ash.Query.filter(name: "Sample Product Store")
        |> Ash.read_one!(authorize?: false)

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id: store.id)
        |> Ash.read_one!(authorize?: false)

      assert product.title == "Kente Scarf"

      variants =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(product_id: product.id)
        |> Ash.read!(authorize?: false)

      assert [%{price: 5000}] = variants
    end

    test "creates store and membership for Merchant on complete", %{conn: conn} do
      merchant = create_merchant!()
      conn = auth_conn(conn, merchant)

      {:ok, view, _html} = live(conn, "/onboarding")

      # Step 1
      render_change(view, "update_store_name", %{"store_name" => "Merchant Store"})
      render_click(view, "next_step")

      # Step 2: Theme (continue with default)
      render_click(view, "next_step")

      # Step 3: Skip
      render_click(view, "skip_step")

      # Step 4: Complete
      render_click(view, "complete")
      assert_redirect(view, "/dashboard")

      # Verify store
      stores = Emakola.Stores.Store |> Ash.read!(authorize?: false)
      store = Enum.find(stores, &(&1.name == "Merchant Store"))
      assert store
      assert store.slug == "merchant-store"
      assert store.currency == "GHS"

      # Verify store membership for merchant
      memberships =
        Emakola.Accounts.StoreMembership
        |> Ash.Query.filter(merchant_id: merchant.id)
        |> Ash.read!(authorize?: false)

      assert length(memberships) == 1
      assert hd(memberships).role == :owner
    end

    test "creates store with custom currency", %{conn: conn} do
      merchant = create_merchant!()
      conn = auth_conn(conn, merchant)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_store_name", %{"store_name" => "Naija Store"})
      render_change(view, "update_currency", %{"currency" => "NGN"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "skip_step")

      render_click(view, "complete")
      assert_redirect(view, "/dashboard")

      stores = Emakola.Stores.Store |> Ash.read!(authorize?: false)
      store = Enum.find(stores, &(&1.name == "Naija Store"))
      assert store.currency == "NGN"
    end
  end

  describe "navigation" do
    test "back button returns to previous step", %{conn: conn} do
      merchant = create_merchant!()
      conn = auth_conn(conn, merchant)

      {:ok, view, _html} = live(conn, "/onboarding")

      # Go to step 2
      render_change(view, "update_store_name", %{"store_name" => "Test"})
      render_click(view, "next_step")

      # Go back to step 1
      html = render_click(view, "prev_step")
      assert html =~ "Name Your Store"
    end
  end
end
