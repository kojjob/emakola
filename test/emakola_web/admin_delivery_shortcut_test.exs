defmodule EmakolaWeb.AdminDeliveryShortcutTest do
  @moduledoc """
  Delivery settings live at /admin/settings/delivery, but its siblings in the
  merchant sidebar — payouts, earnings, verification, theme — all sit at
  /admin/<thing>. A merchant reaching for delivery the same way landed on a
  404, at the exact moment the dashboard setup card had told them to set
  delivery up.
  """
  use EmakolaWeb.ConnCase, async: true
  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest

  test "the short delivery path lands on delivery settings", %{conn: conn} do
    {conn, _merchant, _store} = setup_authenticated_merchant(conn)

    assert {:error, {:live_redirect, %{to: "/admin/settings/delivery"}}} =
             live(conn, "/admin/delivery")
  end

  test "the shortcut is not a way around signing in", %{conn: conn} do
    conn = Phoenix.ConnTest.init_test_session(conn, %{})

    {:error, {redirect_kind, %{to: to}}} = live(conn, "/admin/delivery")

    assert redirect_kind in [:redirect, :live_redirect]

    refute to == "/admin/settings/delivery",
           "a signed-out visitor was forwarded to the merchant page"
  end
end
