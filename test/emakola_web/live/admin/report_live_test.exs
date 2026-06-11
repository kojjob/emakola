defmodule EmakolaWeb.Admin.ReportLiveTest do
  @moduledoc """
  LiveView tests for the admin reports page.
  Tests page rendering, KPI sections, charts, and authentication.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  describe "ReportLive.Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/reports")
    end
  end

  describe "ReportLive.Index (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders reports page heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "Reports"
      assert html =~ "Detailed analytics and insights"
    end

    test "renders KPI summary strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "Total Revenue"
      assert html =~ "38,470"
      assert html =~ "Orders"
      assert html =~ "284"
      assert html =~ "Avg. Order Value"
      assert html =~ "135.46"
      assert html =~ "Conversion Rate"
      assert html =~ "4.12%"
      assert html =~ "Returning Customers"
      assert html =~ "34.2%"
    end

    test "renders revenue trend chart", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "Revenue Trend"
      assert html =~ "Daily revenue"
    end

    test "renders sales by channel section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "Sales by Channel"
      assert html =~ "Instagram"
      assert html =~ "WhatsApp"
      assert html =~ "2,787"
    end

    test "renders top products section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "Top Products"
      assert html =~ "Kente Wrap Dress"
      assert html =~ "8,400"
    end

    test "renders customer acquisition chart", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "Customer Acquisition"
      assert html =~ "128 new customers this month"
    end

    test "renders payment methods section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "Payment Methods"
      assert html =~ "MTN MoMo"
      assert html =~ "Vodafone Cash"
    end

    test "renders order status breakdown", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "Order Status"
      assert html =~ "Delivered"
      assert html =~ "Shipped"
      assert html =~ "Processing"
    end

    test "renders sales by region table", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "Sales by Region"
      assert html =~ "Greater Accra"
      assert html =~ "Ashanti"
      assert html =~ "Western"
    end

    test "renders AI insights section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "AI Insights"
      assert html =~ "Revenue is up 15.3%"
      assert html =~ "Beaded Choker"
    end

    test "renders date range toggle buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "7D"
      assert html =~ "30D"
      assert html =~ "90D"
      assert html =~ "12M"
      assert html =~ "Custom"
    end

    test "renders export buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reports")

      assert html =~ "Export PDF"
      assert html =~ "Export CSV"
    end

    test "handles date range toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      html =
        view
        |> element("button[phx-click='set_date_range'][phx-value-range='7d']")
        |> render_click()

      # The 7D button should now have the active styling
      assert html =~ "Reports"
    end

    test "handles compare toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/reports")

      html =
        view
        |> element("input[phx-click='toggle_compare']")
        |> render_click()

      assert html =~ "vs previous period"
    end
  end
end
