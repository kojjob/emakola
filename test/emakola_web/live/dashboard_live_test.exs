defmodule EmakolaWeb.DashboardLiveTest do
  @moduledoc "Tests for the merchant admin dashboard LiveView."
  use EmakolaWeb.ConnCase, async: true
  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  describe "authenticated merchant" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders dashboard page with stat cards", %{conn: conn, store: store} do
      Factory.create_customer!(store)

      {:ok, view, _html} = live(conn, "/dashboard")

      # Use has_element? to check for stat card labels in the inner LiveView content
      assert has_element?(view, "h1", "Dashboard")
      assert has_element?(view, "span", "Revenue")
      assert has_element?(view, "span", "Orders")
      assert has_element?(view, "span", "Products")
      assert has_element?(view, "span", "Customers")
    end

    test "renders recent orders section with order data", %{conn: conn, store: store} do
      order = Factory.create_order!(store, %{total: 25_000})

      {:ok, view, _html} = live(conn, "/dashboard")

      assert has_element?(view, "h2", "Recent Orders")
      assert has_element?(view, "td", order.order_number)
    end

    test "renders low stock alerts with variant data", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Low Stock Item"})

      Factory.create_variant!(product, store, %{
        stock_quantity: 3,
        track_inventory: true,
        sku: "LOW-SKU"
      })

      {:ok, view, _html} = live(conn, "/dashboard")

      assert has_element?(view, "h2", "Low Stock Alerts")
      assert has_element?(view, "td", "LOW-SKU")
    end

    test "renders top products section", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Popular Product"})
      Factory.create_variant!(product, store, %{sku: "PP-1"})

      {:ok, view, _html} = live(conn, "/dashboard")

      assert has_element?(view, "h2", "Top Products")
      assert has_element?(view, "p", "Popular Product")
    end

    test "renders revenue chart placeholder", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      assert has_element?(view, "h2", "Revenue Overview")
    end

    test "displays formatted currency for revenue", %{conn: conn, store: store} do
      payment = Factory.create_payment!(store, %{amount: 1_284_700})

      payment
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!()

      {:ok, view, _html} = live(conn, "/dashboard")

      # The format_price for 1_284_700 pesewas should produce "12,847.00"
      assert has_element?(view, "p", "12847.00")
    end

    test "handles empty dashboard gracefully with empty state messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      assert has_element?(view, "h1", "Dashboard")
      assert has_element?(view, "p", "No orders yet")
      assert has_element?(view, "p", "All stocked up!")
    end
  end

  describe "unauthenticated access" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: path}}} = live(conn, "/dashboard")
      assert path =~ "/auth/login"
    end
  end
end
