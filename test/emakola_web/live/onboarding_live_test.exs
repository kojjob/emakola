defmodule EmakolaWeb.OnboardingLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Emakola.Factory

  require Ash.Query

  defp auth_conn(conn, user) do
    token = AshAuthentication.user_to_subject(user)

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

    test "redirects to dashboard when user already has an org membership", %{conn: conn} do
      user = create_user!()
      org = create_organisation!()
      create_membership!(user, org, :owner)

      conn = auth_conn(conn, user)

      assert {:error, {:live_redirect, %{to: "/dashboard"}}} = live(conn, "/onboarding")
    end

    test "renders step 1 for authenticated user without store", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

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

      html = render_click(view, "next_step")
      assert html =~ "enter a store name"
    end

    test "generates slug from store name", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      {:ok, view, _html} = live(conn, "/onboarding")

      html = render_change(view, "update_store_name", %{"store_name" => "Kojo's Fashion"})
      assert html =~ "kojos-fashion"
    end

    test "advances from step 1 with valid store name", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_store_name", %{"store_name" => "My Store"})
      html = render_click(view, "next_step")
      assert html =~ "Choose Your Theme"
    end
  end

  describe "step 2 (theme selection)" do
    test "shows theme selection with three themes", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_store_name", %{"store_name" => "Theme Store"})
      html = render_click(view, "next_step")

      assert html =~ "Market"
      assert html =~ "Atelier"
      assert html =~ "Vibrant"
    end

    test "can select a theme", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_store_name", %{"store_name" => "Theme Store"})
      render_click(view, "next_step")

      html = render_click(view, "select_theme", %{"theme-id" => "atelier"})
      assert html =~ "border-emerald-500"
    end
  end

  describe "step 3 (add product)" do
    test "can skip adding a product", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

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
      user = create_user!()
      conn = auth_conn(conn, user)

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
    test "creates store and membership for User on complete", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      # Step 1: Store name
      render_change(view, "update_store_name", %{"store_name" => "Kojo Shop"})
      render_click(view, "next_step")

      # Step 2: Theme (continue with default)
      render_click(view, "next_step")

      # Step 3: Skip product
      render_click(view, "skip_step")

      # Step 4: Complete — should redirect to dashboard
      render_click(view, "complete")
      assert_redirect(view, "/dashboard")

      # Verify store was created
      stores = Emakola.Accounts.Store |> Ash.read!(authorize?: false)
      assert Enum.any?(stores, &(&1.name == "Kojo Shop"))

      # Verify the store has the right slug
      store = Enum.find(stores, &(&1.name == "Kojo Shop"))
      assert store.slug == "kojo-shop"
      assert store.currency == "GHS"

      # Verify org membership was created for legacy User
      memberships =
        Emakola.Accounts.Membership
        |> Ash.Query.filter(user_id: user.id)
        |> Ash.read!(authorize?: false)

      assert length(memberships) == 1
      assert hd(memberships).role == :owner
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
      stores = Emakola.Accounts.Store |> Ash.read!(authorize?: false)
      store = Enum.find(stores, &(&1.name == "Merchant Store"))
      assert store
      assert store.slug == "merchant-store"

      # Verify store membership for merchant
      memberships =
        Emakola.Accounts.StoreMembership
        |> Ash.Query.filter(merchant_id: merchant.id)
        |> Ash.read!(authorize?: false)

      assert length(memberships) == 1
      assert hd(memberships).role == :owner
    end

    test "creates store with custom currency", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_store_name", %{"store_name" => "Naija Store"})
      render_change(view, "update_currency", %{"currency" => "NGN"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "skip_step")

      render_click(view, "complete")
      assert_redirect(view, "/dashboard")

      stores = Emakola.Accounts.Store |> Ash.read!(authorize?: false)
      store = Enum.find(stores, &(&1.name == "Naija Store"))
      assert store.currency == "NGN"
    end
  end

  describe "navigation" do
    test "back button returns to previous step", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

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
