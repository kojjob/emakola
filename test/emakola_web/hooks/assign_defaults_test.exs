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

      assert html
             |> LazyHTML.from_fragment()
             |> LazyHTML.query(~s(meta[name="robots"][content="noindex, nofollow"]))
             |> Enum.any?()

      assert has_element?(view, "button", "New Product")
    end

    test "merchant without store gets nil current_store", %{conn: conn} do
      merchant = Factory.create_merchant!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      # Should still authenticate (merchant exists) but current_store will be nil
      # The admin pages may still render but with empty data
      {:ok, view, html} = live(conn, ~p"/admin/products")
      assert html =~ "Products"
      assert has_element?(view, "#product-empty-state")
    end
  end

  describe "AssignDefaults with legacy User subject" do
    test "User subjects in :user_token no longer authenticate", %{conn: conn} do
      user = Factory.create_user!()
      org = Factory.create_organisation!()
      Factory.create_membership!(user, org, :owner)

      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(user))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, ~p"/dashboard")
    end
  end

  describe "AssignDefaults with platform session" do
    test "assigns current_user and current_session_id for platform staff", %{conn: conn} do
      user = Factory.create_platform_owner!()
      session = Factory.create_user_session!(user)
      signed = EmakolaWeb.AuthTokens.sign_platform_session(session.id)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:platform_session_token, signed)

      {:ok, _view, html} = live(conn, "/platform")
      assert html =~ "Platform Overview"
    end

    test "connected mount touches a stale session", %{conn: conn} do
      user = Factory.create_platform_owner!()
      stale = DateTime.add(DateTime.utc_now(), -10, :minute)
      session = Factory.create_user_session!(user, %{last_seen_at: stale})
      signed = EmakolaWeb.AuthTokens.sign_platform_session(session.id)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:platform_session_token, signed)

      {:ok, _view, _html} = live(conn, "/platform")

      {:ok, reloaded} = Ash.get(Emakola.Accounts.UserSession, session.id, authorize?: false)
      assert DateTime.after?(reloaded.last_seen_at, stale)
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
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, merchant, store}
  end
end
