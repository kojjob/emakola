defmodule EmakolaWeb.Admin.CustomerLiveTest do
  @moduledoc "Tests for Customer admin pages: Index and Show."
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  # -- Unauthenticated -------------------------------------------------------

  describe "CustomerLive.Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/customers")
    end
  end

  describe "CustomerLive.Show (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/customers/#{Ash.UUID.generate()}")
    end
  end

  # -- Index (authenticated) -------------------------------------------------

  describe "CustomerLive.Index (authenticated)" do
    setup %{conn: conn} do
      {merchant, store} = Factory.create_merchant_with_store!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders customer list heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/customers")

      assert html =~ "Customers"
      assert html =~ "Manage your customer base"
    end

    test "caps the customer list at 100", %{conn: conn, store: store} do
      for i <- 1..101 do
        Factory.create_customer!(store, email: "bulk#{i}@example.com")
      end

      {:ok, _view, html} = live(conn, ~p"/admin/customers")

      assert html =~ ">100</span> customers"
    end

    test "renders search input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/customers")

      assert has_element?(view, "#customer-search-form")
      assert has_element?(view, "input[name=\"search\"]")
    end

    test "renders export button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/customers")

      assert html =~ "Export"
    end

    test "lists customers for the store", %{conn: conn, store: store} do
      Factory.create_customer!(store,
        name: "Ama Mensah",
        email: "ama@example.com",
        phone: "+233241234567"
      )

      Factory.create_customer!(store, name: "Kofi Boateng", email: "kofi@example.com")

      {:ok, _view, html} = live(conn, ~p"/admin/customers")

      assert html =~ "Ama Mensah"
      assert html =~ "Kofi Boateng"
    end

    test "does not show customers from other stores", %{conn: conn, store: store} do
      Factory.create_customer!(store, name: "My Customer", email: "mine@example.com")

      other_store = Factory.create_store!()

      Factory.create_customer!(other_store,
        name: "Other Store Customer",
        email: "other@example.com"
      )

      {:ok, _view, html} = live(conn, ~p"/admin/customers")

      assert html =~ "My Customer"
      refute html =~ "Other Store Customer"
    end

    test "search filters customers by name", %{conn: conn, store: store} do
      Factory.create_customer!(store, name: "Ama Mensah", email: "ama@example.com")
      Factory.create_customer!(store, name: "Kofi Boateng", email: "kofi@example.com")

      {:ok, view, _html} = live(conn, ~p"/admin/customers")

      html =
        view
        |> element("#customer-search-form")
        |> render_change(%{"search" => "Ama"})

      assert html =~ "Ama Mensah"
      refute html =~ "Kofi Boateng"
    end

    test "search filters customers by email", %{conn: conn, store: store} do
      Factory.create_customer!(store, name: "Ama Mensah", email: "ama@example.com")
      Factory.create_customer!(store, name: "Kofi Boateng", email: "kofi@example.com")

      {:ok, view, _html} = live(conn, ~p"/admin/customers")

      html =
        view
        |> element("#customer-search-form")
        |> render_change(%{"search" => "kofi@"})

      refute html =~ "Ama Mensah"
      assert html =~ "Kofi Boateng"
    end

    test "clicking customer navigates to detail page", %{conn: conn, store: store} do
      customer = Factory.create_customer!(store, name: "Ama Mensah", email: "ama@example.com")

      {:ok, view, _html} = live(conn, ~p"/admin/customers")

      assert has_element?(view, "a[href=\"/admin/customers/#{customer.id}\"]")
    end
  end

  # -- Show (authenticated) --------------------------------------------------

  describe "CustomerLive.Show (authenticated)" do
    setup %{conn: conn} do
      {merchant, store} = Factory.create_merchant_with_store!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders customer detail header", %{conn: conn, store: store} do
      customer =
        Factory.create_customer!(store,
          name: "Ama Mensah",
          email: "ama@example.com",
          phone: "+233241234567"
        )

      {:ok, _view, html} = live(conn, ~p"/admin/customers/#{customer.id}")

      assert html =~ "Ama Mensah"
      assert html =~ "ama@example.com"
      assert html =~ "+233241234567"
    end

    test "shows order history for customer", %{conn: conn, store: store} do
      customer = Factory.create_customer!(store, name: "Ama Mensah", email: "ama@example.com")

      order = Factory.create_order!(store, customer_id: customer.id, total: 28_000)

      {:ok, _view, html} = live(conn, ~p"/admin/customers/#{customer.id}")

      assert html =~ order.order_number
    end

    test "shows total spent", %{conn: conn, store: store} do
      customer = Factory.create_customer!(store, name: "Ama Mensah", email: "ama@example.com")

      Factory.create_order!(store, customer_id: customer.id, total: 10_000)
      Factory.create_order!(store, customer_id: customer.id, total: 15_000)

      {:ok, _view, html} = live(conn, ~p"/admin/customers/#{customer.id}")

      # 10_000 + 15_000 = 25_000 pesewas = GH₵ 250
      assert html =~ "250"
    end

    test "shows notes section placeholder", %{conn: conn, store: store} do
      customer = Factory.create_customer!(store, name: "Ama Mensah", email: "ama@example.com")

      {:ok, _view, html} = live(conn, ~p"/admin/customers/#{customer.id}")

      assert html =~ "Notes"
    end

    test "cannot view a customer belonging to another store (cross-tenant)", %{conn: conn} do
      other_store = Factory.create_store!()

      foreign =
        Factory.create_customer!(other_store, name: "Foreign", email: "foreign@example.com")

      assert {:error, {:live_redirect, %{to: "/admin/customers"}}} =
               live(conn, ~p"/admin/customers/#{foreign.id}")
    end
  end
end
