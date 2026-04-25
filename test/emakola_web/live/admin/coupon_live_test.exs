defmodule EmakolaWeb.Admin.CouponLiveTest do
  @moduledoc """
  LiveView tests for the admin coupon management page.
  Tests coupon listing, creation, editing, activation toggling,
  empty state, and authentication redirection.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {merchant, store} = create_authenticated_merchant!()
    conn = authenticate_conn(conn, merchant)

    {:ok, conn: conn, store: store, merchant: merchant}
  end

  describe "CouponLive" do
    test "renders coupons page with title and subtitle", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/coupons")

      assert html =~ "Coupons"
      assert html =~ "Create and manage coupon codes for your customers"
    end

    test "displays empty state when no coupons exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/coupons")

      assert html =~ "No coupons yet"
      assert html =~ "Create your first coupon code"
    end

    test "displays summary cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/coupons")

      assert html =~ "Active Coupons"
      assert html =~ "Total Uses"
      assert html =~ "Expired / Maxed"
    end

    test "shows create coupon form when button clicked", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/coupons")

      refute html =~ "Create New Coupon"

      html = render_click(view, "show_create_form")

      assert html =~ "Create New Coupon"
      assert html =~ "Configure your coupon code settings"
      assert html =~ "Coupon Code"
      assert html =~ "Discount Type"
    end

    test "create form shows discount type options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/coupons")

      html = render_click(view, "show_create_form")

      assert html =~ "Percentage"
      assert html =~ "Fixed Amount"
      assert html =~ "Free Shipping"
    end

    test "create form hides value input for free shipping", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/coupons")

      render_click(view, "show_create_form")
      html = render_click(view, "set_discount_type", %{"type" => "free_shipping"})

      refute html =~ "Discount Value"
    end

    test "create form shows value input for percentage", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/coupons")

      render_click(view, "show_create_form")
      html = render_click(view, "set_discount_type", %{"type" => "percentage"})

      assert html =~ "Discount Value"
      assert html =~ "Enter as whole number"
    end

    test "closes form when cancel clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/coupons")

      render_click(view, "show_create_form")
      html = render_click(view, "close_form")

      refute html =~ "Create New Coupon"
    end

    test "creates a percentage coupon", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/coupons")

      render_click(view, "show_create_form")

      html =
        view
        |> form("form", %{
          "coupon" => %{
            "code" => "SAVE10",
            "discount_type" => "percentage",
            "discount_value" => "10",
            "active" => "true"
          }
        })
        |> render_submit()

      assert html =~ "Coupon created successfully"
      assert html =~ "SAVE10"
      assert html =~ "10% off"
    end

    test "creates a fixed amount coupon", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/coupons")

      render_click(view, "show_create_form")
      render_click(view, "set_discount_type", %{"type" => "fixed_amount"})

      html =
        view
        |> form("form", %{
          "coupon" => %{
            "code" => "FIVEOFF",
            "discount_type" => "fixed_amount",
            "discount_value" => "5.00",
            "active" => "true"
          }
        })
        |> render_submit()

      assert html =~ "Coupon created successfully"
      assert html =~ "FIVEOFF"
    end

    test "creates a free shipping coupon", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/coupons")

      render_click(view, "show_create_form")
      render_click(view, "set_discount_type", %{"type" => "free_shipping"})

      html =
        view
        |> form("form", %{
          "coupon" => %{
            "code" => "FREESHIP",
            "discount_type" => "free_shipping",
            "active" => "true"
          }
        })
        |> render_submit()

      assert html =~ "Coupon created successfully"
      assert html =~ "FREESHIP"
      assert html =~ "Free shipping"
    end

    test "toggles coupon active status", %{conn: conn, store: store} do
      coupon = create_coupon!(store)

      {:ok, view, html} = live(conn, ~p"/admin/coupons")

      assert html =~ coupon.code
      assert html =~ "Deactivate"

      html = render_click(view, "toggle_active", %{"id" => coupon.id})

      assert html =~ "deactivated"
    end

    test "shows edit form when edit clicked", %{conn: conn, store: store} do
      coupon =
        create_coupon!(store, %{code: "EDIT_ME", discount_type: :percentage, discount_value: 1500})

      {:ok, view, _html} = live(conn, ~p"/admin/coupons")

      html = render_click(view, "edit_coupon", %{"id" => coupon.id})

      assert html =~ "Edit Coupon"
      assert html =~ "EDIT_ME"
    end

    test "displays coupon table with all columns", %{conn: conn, store: store} do
      create_coupon!(store, %{
        code: "TABLE_TEST",
        discount_type: :percentage,
        discount_value: 2000
      })

      {:ok, _view, html} = live(conn, ~p"/admin/coupons")

      assert html =~ "TABLE_TEST"
      assert html =~ "Percentage"
      assert html =~ "20% off"
      assert html =~ "Active"
    end

    test "displays create coupon button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/coupons")

      assert html =~ "Create Coupon"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users to login" do
      conn = build_conn()

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/coupons")
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

  defp create_coupon!(store, attrs \\ %{}) do
    default = %{
      store_id: store.id,
      code: "TEST#{System.unique_integer([:positive])}",
      discount_type: :percentage,
      discount_value: 1000,
      active: true
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Orders.Coupon
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(authorize?: false)
  end
end
