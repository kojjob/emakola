defmodule EmakolaWeb.Storefront.AccountLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup %{conn: conn} do
    store = Factory.create_store!(%{name: "Ghana Shop", slug: "ghana-shop", currency: "GHS"})

    customer =
      Emakola.Customers.Customer
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "ama@example.com",
        name: "Ama Mensah",
        phone: "+233240000000",
        store_id: store.id,
        password: "password123",
        password_confirmation: "password123"
      })
      |> Ash.create!(authorize?: false)

    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{"customer_token" => token})

    %{store: store, customer: customer, conn: conn}
  end

  describe "AccountLive" do
    # /account/downloads is built, themed and tested but had no link from
    # anywhere — the same orphaned-route defect as the admin files page, and
    # the reason a buyer would never find what they paid for. The tab nav is a
    # phx-click="switch_tab" button list, so a cross-route entry cannot join
    # tabs/0 and needs its own link.
    test "links to the downloads library", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "/s/#{store.slug}/account/downloads"
    end

    test "renders customer account page with profile section", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "My Account"
      assert html =~ "Profile"
    end

    test "shows profile tab with name, email, phone fields", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "Name"
      assert html =~ "Email"
      assert html =~ "Phone"
      assert html =~ "Ama Mensah"
      assert html =~ "ama@example.com"
    end

    test "shows empty state when customer has no orders", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "Recent Orders"
      assert html =~ "No orders yet"
    end

    test "shows orders when customer has them", %{conn: conn, store: store, customer: customer} do
      Factory.create_order!(store, %{
        customer_id: customer.id,
        total: 48_500,
        status: :delivered
      })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "Recent Orders"
      assert html =~ "ORD-"
      assert html =~ "delivered"
    end

    test "displays order totals with GHS currency", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      Factory.create_order!(store, %{customer_id: customer.id, total: 48_500})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "GH\u20B5"
    end

    test "tab navigation switches content", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/account")

      html = render_click(view, "switch_tab", %{"tab" => "orders"})

      assert html =~ "Order History"
    end

    test "shows addresses tab content", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/account")

      html = render_click(view, "switch_tab", %{"tab" => "addresses"})

      assert html =~ "Addresses"
      assert html =~ "No saved addresses"
    end

    test "shows addresses when customer has them", %{conn: conn, store: store, customer: customer} do
      address =
        Emakola.Customers.Address
        |> Ash.Changeset.for_create(:create, %{
          customer_id: customer.id,
          store_id: store.id,
          label: "Home",
          first_name: "Ama",
          last_name: "Mensah",
          line_1: "14 Independence Ave",
          city: "Accra",
          region: "Greater Accra"
        })
        |> Ash.create!(authorize?: false)

      address
      |> Ash.Changeset.for_update(:toggle_default, %{is_default: true})
      |> Ash.update!(authorize?: false)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/account")

      html = render_click(view, "switch_tab", %{"tab" => "addresses"})

      assert html =~ "Home"
      assert html =~ "14 Independence Ave"
      assert html =~ "Accra"
      assert html =~ "Default"
    end

    test "redirects unauthenticated users to login", %{store: store} do
      conn = build_conn() |> Phoenix.ConnTest.init_test_session(%{})

      assert {:error, {:redirect, %{to: "/s/ghana-shop/login"}}} =
               live(conn, "/s/#{store.slug}/account")
    end

    test "redirects for non-existent store", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/s/no-such-store/account")
    end

    test "sets page title with store name", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "My Account"
    end

    test "shows sign out link", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "Sign Out"
      assert html =~ "/auth/customer-logout"
    end

    test "shows customer initials in avatar", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "AM"
    end

    test "submitting a return request persists a Return row with the chosen reason", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      order = Factory.create_order!(store, %{customer_id: customer.id, status: :delivered})

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/account")

      view
      |> render_click("show_return_modal", %{"order" => to_string(order.order_number)})

      view
      |> render_click("set_return_reason", %{"reason" => "defective"})

      html = view |> render_click("submit_return_request", %{})

      assert html =~ "Return request submitted for Order ##{order.order_number}"

      assert [return] = Emakola.Orders.list_returns_by_store!(store.id, authorize?: false)
      assert return.order_id == order.id
      assert return.store_id == store.id
      assert return.customer_id == customer.id
      assert return.reason == :defective
      assert return.status == :requested
    end

    test "shows a return the customer already requested after a reload", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      # The request is a database row, not page state: reloading the account
      # page must still show it, or the customer thinks it never went through.
      order = Factory.create_order!(store, %{customer_id: customer.id, status: :delivered})

      Emakola.Orders.Return
      |> Ash.Changeset.for_create(:request_return, %{
        store_id: store.id,
        order_id: order.id,
        customer_id: customer.id,
        reason: :defective,
        currency: order.currency
      })
      |> Ash.create!(authorize?: false)

      {:ok, view, html} = live(conn, "/s/#{store.slug}/account")

      assert html =~ "Return:"
      refute has_element?(view, "button[phx-click='show_return_modal']")
    end

    test "resubmitting a return request for the same order shows a friendly error instead of crashing",
         %{conn: conn, store: store, customer: customer} do
      order = Factory.create_order!(store, %{customer_id: customer.id, status: :delivered})

      Emakola.Orders.Return
      |> Ash.Changeset.for_create(:request_return, %{
        store_id: store.id,
        order_id: order.id,
        customer_id: customer.id,
        reason: :defective,
        currency: order.currency
      })
      |> Ash.create!(authorize?: false)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/account")

      view
      |> render_click("show_return_modal", %{"order" => to_string(order.order_number)})

      view
      |> render_click("set_return_reason", %{"reason" => "wrong_item"})

      html = view |> render_click("submit_return_request", %{})

      assert html =~ "We couldn&#39;t submit that return request."

      assert [_return] = Emakola.Orders.list_returns_by_store!(store.id, authorize?: false)
    end
  end
end
