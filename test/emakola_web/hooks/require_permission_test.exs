defmodule EmakolaWeb.Hooks.RequirePermissionTest do
  @moduledoc """
  Tests for the RequirePermission on_mount hook via /platform/team, which
  mounts {RequirePermission, :manage_team}. RequirePlatformStaff already
  guarantees staff; this hook gates on the specific permission and bounces
  to /platform (not the storefront) when it is missing.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  describe "permission granted" do
    test "owner can mount /platform/team", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, _view, html} = live(conn, "/platform/team")
      assert html =~ "Team"
    end

    test "staff with :manage_team can mount /platform/team", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      refute user.is_owner
      {:ok, _view, html} = live(conn, "/platform/team")
      assert html =~ "Team"
    end
  end

  describe "permission denied" do
    test "staff without :manage_team is bounced to /platform with a flash", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

      assert {:error, {:redirect, %{to: "/platform", flash: flash}}} =
               live(conn, "/platform/team")

      assert flash["error"] =~ "permission"
    end
  end
end
