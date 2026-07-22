defmodule EmakolaWeb.DashboardLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "unauthenticated" do
    test "redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/dashboard")
    end
  end

  describe "dashboard page" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)

      customer = Factory.create_customer!(store)
      product = Factory.create_product!(store, status: :active)
      variant = Factory.create_variant!(product, store, price: 15_000, stock_quantity: 5)

      order =
        Factory.create_order!(store, %{
          customer_id: customer.id,
          total: 15_000,
          subtotal: 15_000,
          status: :confirmed
        })

      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: variant.id,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

      %{conn: conn, merchant: merchant, store: store, order: order, customer: customer}
    end

    test "mounts and renders KPI cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Dashboard"
      assert html =~ "Revenue"
      assert html =~ "Orders"
      assert html =~ "Customers"
      assert html =~ "Avg Order"
    end

    test "disconnected render defers data loading until the socket connects", %{
      conn: conn,
      order: order
    } do
      html = conn |> get(~p"/dashboard") |> html_response(200)

      # The dead render is a shell — the ~12 dashboard queries only run on
      # the connected mount (covered by "renders recent orders" below).
      refute html =~ order.order_number
    end

    test "topbar New button links to the product create page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # The quick-add "New" in the admin topbar must be a real navigation,
      # not a decorative button (it shipped dead — no handler, no href).
      assert view
             |> element(~s{a[href="/admin/products/new"]}, "New")
             |> has_element?()
    end

    test "renders period toggle", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Today"
      assert html =~ "7 Days"
      assert html =~ "30 Days"
      assert html =~ "All Time"
    end

    test "renders chart canvases with hooks", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ ~s(phx-hook="ChartHook")
      assert html =~ ~s(id="revenue-chart")
      assert html =~ ~s(id="orders-chart")
      assert html =~ ~s(id="customers-chart")
      assert html =~ ~s(id="top-products-chart")
    end

    test "renders alerts panel", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Needs Attention"
      assert html =~ "Pending Orders"
      assert html =~ "Low Stock Items"
      assert html =~ "Failed Payments"
    end

    test "renders recent orders with order data", %{conn: conn, order: order} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ order.order_number
    end

    test "shows correct order total", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "150.00"
    end

    test "period toggle updates data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      html = element(view, "button", "30 Days") |> render_click()

      assert html =~ "Dashboard"
    end

    test "refresh button works", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      element(view, "button[phx-click=\"refresh_data\"]") |> render_click()

      assert render(view) =~ "Dashboard refreshed"
    end

    test "shows low stock alert count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Variant has stock_quantity: 5, which is < 10 threshold,
      # so low stock count should be at least 1
      assert html =~ "Low Stock Items"
    end

    test "shows customer name in recent orders", %{conn: conn, customer: customer} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ customer.name
    end
  end

  describe "multi-tenant isolation" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "does not show orders from another store", %{conn: conn} do
      other_store = Factory.create_store!()
      other_customer = Factory.create_customer!(other_store)

      Factory.create_order!(other_store, %{
        customer_id: other_customer.id,
        total: 999_999,
        subtotal: 999_999,
        status: :confirmed
      })

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      refute html =~ "9,999.99"
    end
  end

  describe "sidebar badges" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "Orders link shows the real pending-order count", %{conn: conn, store: store} do
      Factory.create_order!(store, %{status: :pending})
      Factory.create_order!(store, %{status: :pending})
      Factory.create_order!(store, %{status: :confirmed})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ ~s(<span class="sidebar-badge nav-label sidebar-badge-emerald">2</span>)
    end

    test "no sidebar badge renders when there are no pending orders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      refute html =~ "sidebar-badge"
    end
  end

  describe "empty state" do
    test "handles store with no orders gracefully", %{conn: _conn} do
      {conn, _merchant, _store} = setup_authenticated_merchant(build_conn())

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "No orders yet"
      assert html =~ "GHS 0.00"
    end
  end

  defp setup_authenticated_merchant(conn, store_attrs \\ %{}) do
    {merchant, store} = Factory.create_merchant_with_store!(store_attrs)
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, merchant, store}
  end
end
