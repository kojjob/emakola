defmodule EmakolaWeb.Admin.SupplierLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "SupplierLive.Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/settings/suppliers")
    end
  end

  describe "SupplierLive.Index (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders suppliers page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/settings/suppliers")

      assert html =~ "Suppliers"
    end

    test "lists existing suppliers", %{conn: conn, store: store} do
      Factory.create_supplier!(store, name: "Accra Wholesale")

      {:ok, _view, html} = live(conn, ~p"/admin/settings/suppliers")

      assert html =~ "Accra Wholesale"
    end

    test "can add a new supplier via the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings/suppliers")

      view |> element("[phx-click=\"show_form\"]") |> render_click()

      html =
        view
        |> form("#supplier-form", %{
          supplier: %{
            name: "Tema Imports",
            contact_phone: "+233240000000",
            payment_info: "MTN MoMo 024 000 0000"
          }
        })
        |> render_submit()

      assert html =~ "Tema Imports"
    end

    test "can edit an existing supplier", %{conn: conn, store: store} do
      supplier = Factory.create_supplier!(store, name: "Old Name", contact_phone: "+233200000000")

      {:ok, view, _html} = live(conn, ~p"/admin/settings/suppliers")

      view
      |> element("button[phx-click=\"edit_supplier\"][phx-value-id=\"#{supplier.id}\"]")
      |> render_click()

      html =
        view
        |> form("#supplier-form", %{
          supplier: %{name: "New Name", contact_phone: "+233244444444"}
        })
        |> render_submit()

      assert html =~ "New Name"

      reloaded = Ash.reload!(supplier, authorize?: false)
      assert reloaded.name == "New Name"
      assert reloaded.contact_phone == "+233244444444"
    end

    test "toggles supplier active status", %{conn: conn, store: store} do
      supplier = Factory.create_supplier!(store, name: "Toggle Co", active: true)

      {:ok, view, _html} = live(conn, ~p"/admin/settings/suppliers")

      view
      |> element("button[phx-click=\"toggle_active\"][phx-value-id=\"#{supplier.id}\"]")
      |> render_click()

      reloaded = Ash.reload!(supplier, authorize?: false)
      assert reloaded.active == false
    end

    test "displays outstanding balance for a supplier with owed ledger entries", %{
      conn: conn,
      store: store
    } do
      supplier = Factory.create_supplier!(store, name: "Balance Co")
      order = Factory.create_order!(store)
      fulfillment = Factory.create_fulfillment!(order, store, supplier_id: supplier.id)

      Factory.create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 25_000)

      {:ok, _view, html} = live(conn, ~p"/admin/settings/suppliers")

      assert html =~ "250"
    end
  end

  describe "SupplierLive.Show (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders supplier balance and ledger entries", %{conn: conn, store: store} do
      supplier = Factory.create_supplier!(store, name: "Ledger Co")
      order = Factory.create_order!(store)
      fulfillment = Factory.create_fulfillment!(order, store, supplier_id: supplier.id)
      Factory.create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 30_000)

      {:ok, _view, html} = live(conn, ~p"/admin/suppliers/#{supplier.id}")

      assert html =~ "Ledger Co"
      assert html =~ "Outstanding Balance"
      assert html =~ "300"
      assert html =~ "Owed"
    end

    test "marking an owed entry paid updates the balance", %{conn: conn, store: store} do
      supplier = Factory.create_supplier!(store, name: "Payout Co")
      order = Factory.create_order!(store)
      fulfillment = Factory.create_fulfillment!(order, store, supplier_id: supplier.id)

      entry =
        Factory.create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 40_000)

      {:ok, view, html} = live(conn, ~p"/admin/suppliers/#{supplier.id}")
      assert html =~ "400"

      view
      |> element("button[phx-click=\"mark_paid\"][phx-value-id=\"#{entry.id}\"]")
      |> render_click()

      reloaded = Ash.reload!(entry, authorize?: false)
      assert reloaded.status == :paid

      # Balance now zero — the owed amount is excluded from the aggregate.
      assert has_element?(view, "#outstanding-balance", "0")
    end
  end

  defp setup_authenticated_merchant(conn) do
    {merchant, store} = Factory.create_merchant_with_store!()
    token = AshAuthentication.user_to_subject(merchant)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, merchant, store}
  end
end
