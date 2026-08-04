defmodule EmakolaWeb.Platform.DashboardLiveTest do
  @moduledoc """
  Tests for the /platform dashboard: no DB queries during the
  disconnected mount — a loading shell with zeroed metrics renders
  first, and stats load on the connected mount.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  describe "disconnected mount" do
    test "renders a loading shell without store data", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      store = Factory.create_store!()

      conn = get(conn, "/platform")

      html = html_response(conn, 200)
      assert html =~ "Platform Overview"
      assert html =~ "Loading stores"
      refute html =~ store.name
    end
  end

  describe "connected mount" do
    test "shows an explicit empty state when the platform has no stores", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, view, _html} = live(conn, "/platform")

      assert has_element?(view, "#platform-recent-stores-empty")
      refute has_element?(view, "#platform-recent-stores-loading")
    end

    test "shows recent stores", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      store = Factory.create_store!()

      {:ok, view, _html} = live(conn, "/platform")

      assert has_element?(view, "#platform-recent-stores[phx-update='stream']")
      assert has_element?(view, "#recent_stores-#{store.id}")
      refute has_element?(view, "#platform-recent-stores-loading")
    end
  end
end
