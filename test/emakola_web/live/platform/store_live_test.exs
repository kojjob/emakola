defmodule EmakolaWeb.Platform.StoreLiveTest do
  @moduledoc """
  Permission gating for /platform/stores (requires :manage_stores) and
  platform layout regressions: the logout link must issue DELETE
  /platform/session, and the sidebar Stores link is permission-gated.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  describe "permission gating" do
    test "owner can mount /platform/stores", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, _view, html} = live(conn, "/platform/stores")
      assert html =~ "Stores"
    end

    test "staff with :manage_stores can mount /platform/stores", %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

      refute user.is_owner
      {:ok, _view, html} = live(conn, "/platform/stores")
      assert html =~ "Stores"
    end

    test "staff without :manage_stores is bounced to /platform with a flash", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      assert {:error, {:redirect, %{to: "/platform", flash: flash}}} =
               live(conn, "/platform/stores")

      assert flash["error"] =~ "permission"
    end
  end

  describe "platform layout" do
    test "logout links issue DELETE /platform/session", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, _view, html} = live(conn, "/platform")

      assert html =~ ~s(href="/platform/session")
      assert html =~ ~s(data-method="delete")
      refute html =~ ~s(href="/auth/session")
    end

    test "sidebar hides the Stores link without :manage_stores", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      {:ok, _view, html} = live(conn, "/platform")
      refute html =~ ~s(href="/platform/stores")
    end

    test "sidebar shows the Stores link with :manage_stores", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])

      {:ok, _view, html} = live(conn, "/platform")
      assert html =~ ~s(href="/platform/stores")
    end

    test "Merchants is a disabled Soon entry, not a dead link", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, _view, html} = live(conn, "/platform")

      refute html =~ "/platform/merchants"
      assert html =~ "Merchants"
    end
  end
end
