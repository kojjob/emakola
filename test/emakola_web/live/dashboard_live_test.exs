defmodule EmakolaWeb.DashboardLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/dashboard")
    end
  end
end
