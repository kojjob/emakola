defmodule EmakolaWeb.Hooks.RequireAuthTest do
  @moduledoc """
  Tests for the RequireAuth on_mount hook via /dashboard.

  The merchant admin live_session is gated on current_merchant ONLY —
  a platform-staff session must not grant merchant admin access.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  test "merchant can mount /dashboard", %{conn: conn} do
    {conn, _merchant, _store} = setup_authenticated_merchant(conn)

    {:ok, _view, html} = live(conn, "/dashboard")
    assert html =~ "Dashboard"
  end

  test "platform staff session is redirected to /auth/login", %{conn: conn} do
    {conn, _user, _session} = setup_platform_staff(conn)

    assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/dashboard")
  end

  test "unauthenticated visitor is redirected to /auth/login", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/dashboard")
  end
end
