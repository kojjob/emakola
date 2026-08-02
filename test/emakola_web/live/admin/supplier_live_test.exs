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

      assert html =~ "My Contacts"
    end

    test "lists existing suppliers", %{conn: conn, store: store} do
      Factory.create_supplier!(store, name: "Accra Wholesale")

      {:ok, _view, html} = live(conn, ~p"/admin/settings/suppliers")

      assert html =~ "Accra Wholesale"
    end

    test "can add a new supplier via the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings/suppliers")

      view |> element("#add-supplier-btn") |> render_click()

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

    # The active toggle lives inside the edit slide-over now.
    test "toggles supplier active status", %{conn: conn, store: store} do
      supplier = Factory.create_supplier!(store, name: "Toggle Co", active: true)

      {:ok, view, _html} = live(conn, ~p"/admin/settings/suppliers")

      view
      |> element("button[phx-click=\"edit_supplier\"][phx-value-id=\"#{supplier.id}\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"toggle_active\"][phx-value-id=\"#{supplier.id}\"]")
      |> render_click()

      reloaded = Ash.reload!(supplier, authorize?: false)
      assert reloaded.active == false
    end

    test "tiles show tap-to-call and WhatsApp links when numbers exist", %{
      conn: conn,
      store: store
    } do
      Factory.create_supplier!(store,
        name: "Reachable Co",
        contact_phone: "+233 24 000 0000",
        whatsapp_number: "+233 24 111 1111"
      )

      {:ok, view, _html} = live(conn, ~p"/admin/settings/suppliers")

      assert has_element?(view, ~s{a[href="tel:+233 24 000 0000"]})
      assert has_element?(view, ~s{a[href="https://wa.me/233241111111"]})
    end

    test "tiles omit contact links when numbers are missing", %{conn: conn, store: store} do
      Factory.create_supplier!(store, name: "Silent Co")

      {:ok, view, _html} = live(conn, ~p"/admin/settings/suppliers")

      refute has_element?(view, ~s{a[href^="tel:"]})
      refute has_element?(view, ~s{a[href^="https://wa.me"]})
    end

    test "inactive suppliers are labelled", %{conn: conn, store: store} do
      Factory.create_supplier!(store, name: "Dormant Co", active: false)

      {:ok, _view, html} = live(conn, ~p"/admin/settings/suppliers")

      assert html =~ "Dormant Co"
      assert html =~ "Inactive"
    end

    test "tile shows the supplier logo when one is set", %{conn: conn, store: store} do
      Factory.create_supplier!(store,
        name: "Branded Co",
        logo_url: "https://cdn.example.com/logos/branded.png"
      )

      {:ok, view, _html} = live(conn, ~p"/admin/settings/suppliers")

      assert has_element?(view, ~s{img[src="https://cdn.example.com/logos/branded.png"]})
    end

    test "edit slide-over offers a logo upload", %{conn: conn, store: store} do
      supplier = Factory.create_supplier!(store, name: "Logo Co")

      {:ok, view, _html} = live(conn, ~p"/admin/settings/suppliers")

      view
      |> element("button[phx-click=\"edit_supplier\"][phx-value-id=\"#{supplier.id}\"]")
      |> render_click()

      assert has_element?(view, ~s{#supplier-form input[type="file"]})
    end

    test "grid includes a dashed add-supplier tile", %{conn: conn, store: store} do
      Factory.create_supplier!(store, name: "Any Co")

      {:ok, view, _html} = live(conn, ~p"/admin/settings/suppliers")

      assert has_element?(view, "#add-supplier-tile")
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
      assert html =~ "You owe"
      assert html =~ "300"
      assert html =~ "Mark Paid"
    end

    test "shows big metric cards: owed, paid so far, payment count", %{conn: conn, store: store} do
      supplier = Factory.create_supplier!(store, name: "Metrics Co")
      order = Factory.create_order!(store)
      fulfillment = Factory.create_fulfillment!(order, store, supplier_id: supplier.id)

      Factory.create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 30_000)

      order2 = Factory.create_order!(store)
      fulfillment2 = Factory.create_fulfillment!(order2, store, supplier_id: supplier.id)

      paid =
        Factory.create_supplier_ledger_entry!(supplier, fulfillment2, store, amount_owed: 20_000)

      Emakola.Suppliers.mark_ledger_entry_paid!(paid, authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/suppliers/#{supplier.id}")

      assert html =~ "You owe"
      assert html =~ "300"
      assert html =~ "Paid so far"
      assert html =~ "200"
      assert html =~ "Payments"
    end

    test "header shows the supplier logo when one is set", %{conn: conn, store: store} do
      supplier =
        Factory.create_supplier!(store,
          name: "Branded Co",
          logo_url: "https://cdn.example.com/logos/branded.png"
        )

      {:ok, view, _html} = live(conn, ~p"/admin/suppliers/#{supplier.id}")

      assert has_element?(view, ~s{img[src="https://cdn.example.com/logos/branded.png"]})
    end

    test "header has call and WhatsApp links for the supplier", %{conn: conn, store: store} do
      supplier =
        Factory.create_supplier!(store,
          name: "Contact Co",
          contact_phone: "+233200000000",
          whatsapp_number: "+233 20 123 4567"
        )

      {:ok, view, _html} = live(conn, ~p"/admin/suppliers/#{supplier.id}")

      assert has_element?(view, ~s{a[href="tel:+233200000000"]})
      assert has_element?(view, ~s{a[href="https://wa.me/233201234567"]})
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

    test "hides Mark Paid for an entry claimed by platform settlement (no manual double-pay)", %{
      conn: conn,
      store: store
    } do
      supplier = Factory.create_supplier!(store, name: "Claimed Co")
      order = Factory.create_order!(store)
      fulfillment = Factory.create_fulfillment!(order, store, supplier_id: supplier.id)

      entry =
        Factory.create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 15_000)

      entry
      |> Ash.Changeset.for_update(:claim_for_platform_settlement, %{source: :platform_payout})
      |> Ash.update!(authorize?: false)

      {:ok, view, html} = live(conn, ~p"/admin/suppliers/#{supplier.id}")

      assert html =~ "150"
      refute has_element?(view, "button[phx-click=\"mark_paid\"][phx-value-id=\"#{entry.id}\"]")
      assert html =~ "Settling"
    end

    test "shows a neutral 'Voided' pill for a voided entry, no amount owed", %{
      conn: conn,
      store: store
    } do
      supplier = Factory.create_supplier!(store, name: "Voided Co")
      order = Factory.create_order!(store)
      fulfillment = Factory.create_fulfillment!(order, store, supplier_id: supplier.id)

      entry =
        Factory.create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 8_000)

      entry
      |> Ash.Changeset.for_update(:claim_for_platform_settlement, %{source: :platform_payout})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:void, %{})
      |> Ash.update!(authorize?: false)

      {:ok, view, html} = live(conn, ~p"/admin/suppliers/#{supplier.id}")

      assert html =~ "Voided"
      refute has_element?(view, "button[phx-click=\"mark_paid\"][phx-value-id=\"#{entry.id}\"]")

      # The balance card excludes it — it was never manual outstanding debt.
      assert has_element?(view, "#outstanding-balance", "0")
    end
  end

  defp setup_authenticated_merchant(conn) do
    {merchant, store} = Factory.create_merchant_with_store!()
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, merchant, store}
  end
end
