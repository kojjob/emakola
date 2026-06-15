defmodule EmakolaWeb.Platform.MerchantLive.IndexTest do
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  describe "permission gating" do
    test "owner can mount /platform/merchants", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/merchants")
      assert html =~ "Merchants"
    end

    test "staff with :manage_merchants can mount", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_merchants])
      {:ok, _view, html} = live(conn, ~p"/platform/merchants")
      assert html =~ "Merchants"
    end

    test "staff without :manage_merchants is bounced to /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      assert {:error, {:redirect, %{to: "/platform", flash: flash}}} =
               live(conn, ~p"/platform/merchants")

      assert flash["error"] =~ "permission"
    end
  end
end
