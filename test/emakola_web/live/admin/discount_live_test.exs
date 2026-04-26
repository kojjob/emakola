defmodule EmakolaWeb.Admin.DiscountLiveTest do
  @moduledoc """
  LiveView tests for the admin discount management page.
  Tests discount listing, filtering, search, summary cards,
  create form toggling, and authentication redirection.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {merchant, store} = create_authenticated_merchant!()
    conn = authenticate_conn(conn, merchant)

    {:ok, conn: conn, store: store, merchant: merchant}
  end

  describe "DiscountLive.Index" do
    test "renders discounts page with title and subtitle", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/discounts")

      assert html =~ "Discounts"
      assert html =~ "Create and manage discount codes"
    end

    test "displays placeholder discount codes", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/discounts")

      assert html =~ "WELCOME10"
      assert html =~ "FIRSTORDER"
      assert html =~ "FREESHIP"
      assert html =~ "EASTER25"
      assert html =~ "FLASH50"
      assert html =~ "LOYALTY15"
    end

    test "displays summary cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/discounts")

      assert html =~ "Active Discounts"
      assert html =~ "Total Uses"
      assert html =~ "Revenue Impact"
    end

    test "displays status badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/discounts")

      assert html =~ "Active"
      assert html =~ "Scheduled"
      assert html =~ "Expired"
    end

    test "displays discount type badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/discounts")

      assert html =~ "Percentage"
      assert html =~ "Fixed Amount"
      assert html =~ "Free Shipping"
    end

    test "displays table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/discounts")

      assert html =~ "All Discount Codes"
      assert html =~ "6 discount codes"
    end

    test "filters discounts by status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/discounts")

      html =
        view
        |> element("form[phx-change='filter_status']")
        |> render_change(%{"status" => "active"})

      assert html =~ "WELCOME10"
      assert html =~ "LOYALTY15"
      refute html =~ "EASTER25"
      refute html =~ "FLASH50"
    end

    test "filters discounts by expired status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/discounts")

      html =
        view
        |> element("form[phx-change='filter_status']")
        |> render_change(%{"status" => "expired"})

      assert html =~ "FLASH50"
      refute html =~ "WELCOME10"
    end

    test "searches discounts by code", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/discounts")

      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{"search" => "WELCOME"})

      assert html =~ "WELCOME10"
      refute html =~ "FIRSTORDER"
      refute html =~ "FLASH50"
    end

    test "shows empty state when search returns no results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/discounts")

      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{"search" => "NONEXISTENT"})

      assert html =~ "No discount codes found"
      assert html =~ "Try adjusting your search or filters"
    end

    test "toggles create discount form", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/discounts")

      # Form should not be visible initially
      refute html =~ "Create New Discount"

      # Click the button to show the form
      html = render_click(view, "toggle_create_form")

      assert html =~ "Create New Discount"
      assert html =~ "Configure your discount code settings"
      assert html =~ "Discount Code"
      assert html =~ "Discount Type"
      assert html =~ "Discount Value"
      assert html =~ "Minimum Purchase"
      assert html =~ "Usage Limit"
      assert html =~ "Applies To"
    end

    test "create discount form shows discount type options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/discounts")

      html = render_click(view, "toggle_create_form")

      assert html =~ "Percentage"
      assert html =~ "Fixed Amount"
      assert html =~ "Free Shipping"
      assert html =~ "Buy X Get Y"
    end

    test "create discount form shows applies-to options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/discounts")

      html = render_click(view, "toggle_create_form")

      assert html =~ "All Products"
      assert html =~ "Specific Categories"
      assert html =~ "Specific Products"
    end

    test "displays usage progress bars", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/discounts")

      # Usage data from placeholder discounts
      assert html =~ "128/500"
      assert html =~ "89/200"
      assert html =~ "67/100"
      assert html =~ "0/50"
      assert html =~ "50/50"
      assert html =~ "58/unlimited"
    end

    test "displays valid period information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/discounts")

      assert html =~ "01/01/2026 - 31/12/2026"
      assert html =~ "Ongoing"
    end

    test "displays minimum purchase amounts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/discounts")

      assert html =~ "No min"
    end

    test "displays create discount button in header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/discounts")

      assert html =~ "Create Discount"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users to login" do
      conn = build_conn()

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/discounts")
    end
  end

  # ── Test Helpers ──

  defp create_authenticated_merchant! do
    store =
      Emakola.Stores.Store
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Store #{System.unique_integer([:positive])}",
        slug: "test-store-#{System.unique_integer([:positive])}"
      })
      |> Ash.create!(authorize?: false)

    merchant =
      Emakola.Accounts.Merchant
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "merchant-#{System.unique_integer([:positive])}@test.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!(authorize?: false)

    Emakola.Accounts.StoreMembership
    |> Ash.Changeset.for_create(:create, %{
      merchant_id: merchant.id,
      store_id: store.id,
      role: :owner
    })
    |> Ash.create!(authorize?: false)

    {merchant, store}
  end

  defp authenticate_conn(conn, merchant) do
    subject = AshAuthentication.user_to_subject(merchant)

    conn
    |> init_test_session(%{"user_token" => subject})
  end
end
