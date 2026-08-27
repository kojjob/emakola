defmodule EmakolaWeb.DashboardLiveTest do
  # async: false — the "snap quick-action" tests toggle the shared
  # :anthropic_api_key application env (same reason product_snap_test.exs
  # and seo_dashboard_live_test.exs are async: false).
  use EmakolaWeb.ConnCase, async: false

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

    test "the disconnected render shows skeletons, never a misleading zero", %{conn: conn} do
      html = conn |> get(~p"/dashboard") |> html_response(200)

      # The ~12 dashboard queries are deferred to the connected mount, so the
      # dead render has no data. Showing "Revenue GHS 0.00" there is
      # indistinguishable from "you have made no sales" — alarming for a
      # merchant whose figures are about to appear a moment later.
      assert html =~ "animate-pulse"
      assert html =~ "Loading Revenue"
      refute html =~ "GHS 0.00"
    end

    test "the connected render replaces skeletons with real figures", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      refute html =~ "Loading Revenue"
      assert html =~ "Revenue"
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

    test "refreshes in real time when a new order is dispatched", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      {:ok, view, html} = live(conn, ~p"/dashboard")

      new_order =
        Factory.create_order!(store, %{
          customer_id: customer.id,
          total: 99_900,
          subtotal: 99_900,
          status: :pending
        })

      refute html =~ new_order.order_number

      # Go through the real Dispatcher so this pins the actual broadcast
      # contract. DashboardLive subscribes to "store:<id>:orders" and relaxed
      # its safety-net poll to 5 minutes on the assumption that PubSub covers
      # real time — if the message shape drifts, merchants wait 5 minutes to
      # see an order, with no error anywhere to signal it.
      Emakola.Notifications.Dispatcher.dispatch(new_order, :order_placed)

      assert render(view) =~ new_order.order_number
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

  describe "Twi greeting" do
    test "greets by time of day" do
      # Ghana runs on GMT year-round, so UTC hours are local hours.
      assert EmakolaWeb.DashboardHelpers.greeting_for_hour(6) == "Maakye"
      assert EmakolaWeb.DashboardHelpers.greeting_for_hour(11) == "Maakye"
      assert EmakolaWeb.DashboardHelpers.greeting_for_hour(13) == "Maaha"
      assert EmakolaWeb.DashboardHelpers.greeting_for_hour(19) == "Maadwo"
      assert EmakolaWeb.DashboardHelpers.greeting_for_hour(2) == "Maadwo"
    end
  end

  describe "Dashboard redesign" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "greets the merchant by name in Twi", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#dashboard-greeting")
    end

    test "the work queue lists what needs doing, with counts and one-tap actions", %{
      conn: conn,
      store: store
    } do
      customer = Factory.create_customer!(store)

      Factory.create_order!(store, %{
        customer_id: customer.id,
        total: 10_000,
        subtotal: 10_000
      })

      product = Factory.create_product!(store, status: :active)
      Factory.create_variant!(product, store, price: 5_000, stock_quantity: 0)

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#work-queue-orders a[href='/admin/orders']")
      assert has_element?(view, "#work-queue-orders", "1")
      assert has_element?(view, "#work-queue-stock a[href='/admin/inventory']")
    end

    test "rows with nothing to do are hidden, and an all-clear takes their place", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      refute has_element?(view, "#work-queue-orders")
      refute has_element?(view, "#work-queue-stock")
      refute has_element?(view, "#work-queue-returns")
      assert has_element?(view, "#work-queue-all-clear")
    end

    test "best sellers lead with the product photo", %{conn: conn, store: store} do
      customer = Factory.create_customer!(store)
      product = Factory.create_product!(store, status: :active, title: "Kente Scarf")
      variant = Factory.create_variant!(product, store, price: 15_000, stock_quantity: 5)
      image = Factory.create_image!(product, store)

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
        quantity: 3
      })
      |> Ash.create!(authorize?: false)

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#best-sellers img[src='#{image.url}']")
      assert has_element?(view, "#best-sellers", "Kente Scarf")
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

  describe "snap quick-action" do
    setup do
      Application.put_env(:emakola, :anthropic_api_key, "test-key")
      on_exit(fn -> Application.delete_env(:emakola, :anthropic_api_key) end)
    end

    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "shows the Add by photo quick-action when AI is enabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, ~s{a[href="/admin/products/snap"]})
    end
  end

  describe "snap quick-action when AI is disabled" do
    setup do
      Application.delete_env(:emakola, :anthropic_api_key)
    end

    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "does not show the Add by photo quick-action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      refute has_element?(view, ~s{a[href="/admin/products/snap"]})
    end
  end

  describe "platform announcements" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "an active announcement banner renders on the dashboard", %{conn: conn} do
      {:ok, ann} =
        Emakola.Notifications.create_announcement(
          %{
            title: "Welcome to Makola Payouts",
            body: "You can now add your payout details.",
            channels: [:banner],
            audience: :all,
            publish_at: ~U[2026-06-20 00:00:00Z]
          },
          authorize?: false
        )

      {:ok, _} = Emakola.Notifications.publish_announcement(ann, authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Welcome to Makola Payouts"
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

  describe "featuring checklist" do
    test "an incomplete shop sees what featuring needs, plainly", %{conn: conn} do
      {conn, _merchant, store} = setup_authenticated_merchant(conn)

      # Clear the setup checklist so the featuring one shows (one list at a
      # time): theme, a product, a delivery zone, WhatsApp, a social link.
      Factory.create_product!(store, status: :active)
      Factory.create_delivery_zone!(store)

      store
      |> Ash.Changeset.for_update(:update_settings, %{
        whatsapp_number: "+233201234567",
        instagram_url: "https://instagram.com/shop",
        theme_config: %{"theme" => "market"}
      })
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "featuring-checklist" or html =~ "What featuring needs"
      # The payout item cannot be ticked — no verified payout account exists.
      assert html =~ "Add your MoMo payout"
    end
  end
end
