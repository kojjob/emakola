defmodule EmakolaWeb.Admin.ProductLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "ProductLive.Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/products")
    end
  end

  describe "ProductLive.Index (authenticated)" do
    setup %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      %{conn: conn, user: user, org: org}
    end

    test "renders product list heading", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/products")

      assert html =~ "Products"
      assert has_element?(view, "button", "New Product")
    end

    test "renders status filter tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/products")

      assert html =~ "All"
      assert html =~ "Draft"
      assert html =~ "Active"
      assert html =~ "Archived"
    end

    test "renders search input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")

      assert has_element?(view, "input[name=\"search\"]")
    end
  end

  describe "ProductLive.Form (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/products/new")
    end
  end

  describe "ProductLive.Form (authenticated)" do
    setup %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      %{conn: conn, user: user, org: org}
    end

    test "renders new product form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/products/new")

      assert html =~ "New Product"
      assert html =~ "Title"
      assert html =~ "Save as Draft"
    end
  end

  # Uses the pattern from LiveViewHelpers — creates user, org, membership
  defp setup_authenticated_user(conn) do
    user = Factory.create_user!()
    org = Factory.create_organisation!()
    Factory.create_membership!(user, org, :owner)

    token = AshAuthentication.user_to_subject(user)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, user, org}
  end
end
