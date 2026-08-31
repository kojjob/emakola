defmodule EmakolaWeb.AdminSettingsReachabilityTest do
  @moduledoc """
  A settings page with no link pointing at it does not exist as far as a
  merchant is concerned. /admin/settings/address had zero inbound links
  anywhere in the app, and delivery could only be reached by remembering it
  was three clicks inside Settings — which is why merchants started guessing
  URLs like /admin/delivery.

  These tests pin reachability by clicking, not by route existence.
  """
  use EmakolaWeb.ConnCase, async: true
  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest

  # Settings pages a merchant must be able to reach without typing a URL.
  # Suppliers and supply-network are deliberately absent: they already have
  # their own Marketplace entries in the sidebar.
  @settings_pages [
    "/admin/settings/delivery",
    "/admin/settings/notifications",
    "/admin/settings/domain",
    "/admin/settings/address"
  ]

  @settings_tabs ~w(general contact delivery domain social notifications)

  defp clickable_surface(conn) do
    {:ok, _view, sidebar_html} = live(conn, "/dashboard")
    {:ok, settings, settings_html} = live(conn, "/admin/settings")

    tab_html =
      Enum.map_join(@settings_tabs, fn tab ->
        render_click(settings, "switch_tab", %{"tab" => tab})
      end)

    sidebar_html <> settings_html <> tab_html
  end

  test "every settings page is reachable by clicking", %{conn: conn} do
    {conn, _merchant, _store} = setup_authenticated_merchant(conn)

    surface = clickable_surface(conn)

    for page <- @settings_pages do
      assert surface =~ ~s(href="#{page}"),
             "#{page} has no link anywhere a merchant can click — it is unreachable"
    end
  end

  test "delivery is one click from the sidebar, not buried in settings", %{conn: conn} do
    {conn, _merchant, _store} = setup_authenticated_merchant(conn)

    {:ok, _view, dashboard_html} = live(conn, "/dashboard")

    assert dashboard_html =~ ~s(href="/admin/settings/delivery"),
           "the sidebar offers no direct way to delivery, so a merchant changing " <>
             "a delivery fee has to remember where it lives"
  end

  test "notification preferences goes to the notifications page", %{conn: conn} do
    {conn, _merchant, _store} = setup_authenticated_merchant(conn)

    {:ok, _view, dashboard_html} = live(conn, "/dashboard")

    [_ | after_label] = String.split(dashboard_html, "Notification Preferences")

    refute after_label == [],
           "the Notification Preferences link is gone — this test would be vacuous"

    assert dashboard_html =~ ~s(href="/admin/settings/notifications"),
           "Notification Preferences points at the settings hub instead of the " <>
             "notifications page that already exists"
  end

  test "the delivery page lights up its own sidebar entry", %{conn: conn} do
    {conn, _merchant, _store} = setup_authenticated_merchant(conn)

    {:ok, _view, html} = live(conn, "/admin/settings/delivery")

    assert html =~
             ~s(href="/admin/settings/delivery" title="Delivery" class="sidebar-link active"),
           "the delivery page does not mark its sidebar entry active"
  end
end
