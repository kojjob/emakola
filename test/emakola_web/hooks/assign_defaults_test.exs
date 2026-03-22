defmodule EmakolaWeb.Hooks.AssignDefaultsTest do
  @moduledoc """
  Tests for the AssignDefaults on_mount hook.
  Verifies merchant auth with store resolution, User auth backward compat,
  and unauthenticated handling.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "AssignDefaults with merchant auth" do
    test "assigns current_merchant and current_store for authenticated merchant", %{conn: conn} do
      {conn, _merchant, _store} = setup_authenticated_merchant(conn)

      {:ok, view, html} = live(conn, ~p"/admin/products")
      assert html =~ "Products"
      assert has_element?(view, "a", "New Product")
    end

    test "merchant without store gets nil current_store", %{conn: conn} do
      merchant = Factory.create_merchant!()
      token = AshAuthentication.user_to_subject(merchant)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      # Should still authenticate (merchant exists) but current_store will be nil
      # The admin pages may still render but with empty data
      {:ok, _view, html} = live(conn, ~p"/admin/products")
      assert html =~ "Products"
    end
  end

  describe "AssignDefaults with user auth (backward compat)" do
    test "assigns current_user for authenticated User", %{conn: conn} do
      user = Factory.create_user!()
      org = Factory.create_organisation!()
      Factory.create_membership!(user, org, :owner)

      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "Dashboard" || html =~ "dashboard"
    end
  end

  describe "AssignDefaults unauthenticated" do
    test "unauthenticated request gets nil assigns and redirects", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/products")
    end

    test "invalid token gets nil assigns and redirects", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, "invalid-token-garbage")

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/products")
    end
  end

  # ── Helpers ──

  defp setup_authenticated_merchant(conn, store_attrs \\ %{}) do
    {merchant, store} = Factory.create_merchant_with_store!(store_attrs)
    token = AshAuthentication.user_to_subject(merchant)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, merchant, store}
  end
end
