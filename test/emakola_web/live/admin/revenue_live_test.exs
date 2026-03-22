defmodule EmakolaWeb.Admin.RevenueLiveTest do
  @moduledoc """
  LiveView tests for the admin revenue analytics page.
  Tests page rendering, period toggle, KPI display, and auth redirect.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {merchant, store} = create_authenticated_merchant!()
    conn = authenticate_conn(conn, merchant)

    {:ok, conn: conn, store: store, merchant: merchant}
  end

  describe "RevenueLive.Index" do
    test "renders revenue page with title and subtitle", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "Revenue"
      assert html =~ "Track your earnings and payouts"
    end

    test "displays KPI cards with formatted amounts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      # Gross Revenue
      assert html =~ "Gross Revenue"
      assert html =~ "38,470.00"

      # Net Revenue
      assert html =~ "Net Revenue"
      assert html =~ "34,623.00"

      # Platform Fees
      assert html =~ "Platform Fees"
      assert html =~ "769.40"

      # Pending Payouts
      assert html =~ "Pending Payouts"
      assert html =~ "4,280.00"
    end

    test "displays period toggle with month active by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "Today"
      assert html =~ "This Week"
      assert html =~ "This Month"
      assert html =~ "This Year"
    end

    test "changes period on toggle click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/revenue")

      html = render_click(view, "change_period", %{"period" => "week"})

      # Week button should now have active styling
      assert html =~ "This Week"
    end

    test "displays daily revenue chart section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "Daily Revenue"
      assert html =~ "March 1"
      assert html =~ "revenueGradient"
    end

    test "displays revenue by category donut chart", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "Revenue by Category"
      assert html =~ "Dresses"
      assert html =~ "42%"
      assert html =~ "Bags"
      assert html =~ "Accessories"
      assert html =~ "Beauty"
    end

    test "displays revenue by payment method bars", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "Revenue by Payment Method"
      assert html =~ "MTN MoMo"
      assert html =~ "52%"
      assert html =~ "Vodafone Cash"
      assert html =~ "Card"
      assert html =~ "Cash on Delivery"
    end

    test "displays recent transactions table", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "Recent Transactions"
      assert html =~ "EM-4821"
      assert html =~ "Ama Mensah"
      assert html =~ "EM-4820"
      assert html =~ "Kofi Adjei"
      assert html =~ "Completed"
      assert html =~ "Pending"
    end

    test "displays payout history section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "Payout History"
      assert html =~ "Settled to MTN MoMo"
      assert html =~ "15/03/2026"
      assert html =~ "12,480.00"
      assert html =~ "08/03/2026"
      assert html =~ "01/03/2026"
    end

    test "displays next payout banner", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "Next payout:"
      assert html =~ "4,280.00"
      assert html =~ "22/03/2026"
    end

    test "displays export button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/revenue")

      assert html =~ "Export"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users to login" do
      conn = build_conn()

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, ~p"/admin/revenue")
    end
  end

  # ── Test Helpers ──

  defp create_authenticated_merchant! do
    store =
      Emakola.Accounts.Store
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Store #{System.unique_integer([:positive])}",
        slug: "test-store-#{System.unique_integer([:positive])}"
      })
      |> Ash.create!()

    merchant =
      Emakola.Accounts.Merchant
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "merchant-#{System.unique_integer([:positive])}@test.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!()

    Emakola.Accounts.StoreMembership
    |> Ash.Changeset.for_create(:create, %{
      merchant_id: merchant.id,
      store_id: store.id,
      role: :owner
    })
    |> Ash.create!()

    {merchant, store}
  end

  defp authenticate_conn(conn, merchant) do
    subject = AshAuthentication.user_to_subject(merchant)

    conn
    |> init_test_session(%{"user_token" => subject})
  end
end
