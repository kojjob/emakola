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
    test "renders customer account page with profile section", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/@#{store.slug}/account")

      assert html =~ "My Account"
      assert html =~ "Profile"
    end

    test "shows profile tab with name, email, phone fields", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/@#{store.slug}/account")

      assert html =~ "Name"
      assert html =~ "Email"
      assert html =~ "Phone"
      assert html =~ "Ama Mensah"
      assert html =~ "ama@example.com"
    end

    test "shows empty state when customer has no orders", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/@#{store.slug}/account")

      assert html =~ "Recent Orders"
      assert html =~ "No orders yet"
    end

    test "shows orders when customer has them", %{conn: conn, store: store, customer: customer} do
      Factory.create_order!(store, %{
        customer_id: customer.id,
        total: 48_500,
        status: :delivered
      })

      {:ok, _view, html} = live(conn, "/@#{store.slug}/account")

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

      {:ok, _view, html} = live(conn, "/@#{store.slug}/account")

      assert html =~ "GH\u20B5"
    end

    test "tab navigation switches content", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/@#{store.slug}/account")

      html = render_click(view, "switch_tab", %{"tab" => "orders"})

      assert html =~ "Order History"
    end

    test "shows addresses tab content", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/@#{store.slug}/account")

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

      {:ok, view, _html} = live(conn, "/@#{store.slug}/account")

      html = render_click(view, "switch_tab", %{"tab" => "addresses"})

      assert html =~ "Home"
      assert html =~ "14 Independence Ave"
      assert html =~ "Accra"
      assert html =~ "Default"
    end

    test "redirects unauthenticated users to login", %{store: store} do
      conn = build_conn() |> Phoenix.ConnTest.init_test_session(%{})

      assert {:error, {:redirect, %{to: "/@ghana-shop/login"}}} =
               live(conn, "/@#{store.slug}/account")
    end

    test "redirects for non-existent store", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/@no-such-store/account")
    end

    test "sets page title with store name", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/@#{store.slug}/account")

      assert html =~ "My Account"
    end

    test "shows sign out link", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/@#{store.slug}/account")

      assert html =~ "Sign Out"
      assert html =~ "/auth/customer-logout"
    end

    test "shows customer initials in avatar", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/@#{store.slug}/account")

      assert html =~ "AM"
    end
  end
end
