defmodule EmakolaWeb.Hooks.RequirePlatformStaffTest do
  @moduledoc """
  Tests for the RequirePlatformStaff on_mount hook via the /platform pages.

  Platform pages authenticate with a DB-backed session resolved by
  AssignDefaults from :platform_session_token; RequirePlatformStaff then
  gates on active staff (owner or any platform permission).
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  describe "access granted" do
    test "platform owner can mount /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, _view, html} = live(conn, "/platform")
      assert html =~ "Platform Overview"
    end

    test "staff with a permission can mount /platform", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

      refute user.is_owner
      {:ok, _view, html} = live(conn, "/platform")
      assert html =~ "Platform Overview"
    end
  end

  describe "access denied" do
    test "unauthenticated visitor is redirected to the platform login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/platform/login"}}} = live(conn, "/platform")
    end

    test "plain user with a session row but no permissions is redirected", %{conn: conn} do
      user = Factory.create_user!()
      session = Factory.create_user_session!(user)
      signed = EmakolaWeb.AuthTokens.sign_platform_session(session.id)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:platform_session_token, signed)

      assert {:error, {:redirect, %{to: "/platform/login"}}} = live(conn, "/platform")
    end

    test "deactivated staff is redirected", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

      user
      |> Ash.Changeset.for_update(:deactivate_staff, %{})
      |> Ash.update!(authorize?: false)

      assert {:error, {:redirect, %{to: "/platform/login"}}} = live(conn, "/platform")
    end

    test "merchant session does not grant platform access", %{conn: conn} do
      {conn, _merchant, _store} = setup_authenticated_merchant(conn)

      assert {:error, {:redirect, %{to: "/platform/login"}}} = live(conn, "/platform")
    end

    test "revoked platform session is redirected", %{conn: conn} do
      {conn, _user, session} = setup_platform_staff(conn)
      {:ok, _} = Emakola.Accounts.Sessions.revoke(session)

      assert {:error, {:redirect, %{to: "/platform/login"}}} = live(conn, "/platform")
    end
  end
end
