defmodule EmakolaWeb.Platform.BillingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  describe "permission gating" do
    test "owner can mount /platform/billing", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "Billing"
    end

    test "staff with :manage_billing can mount", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_billing])
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "Billing"
    end

    test "staff without :manage_billing is bounced to /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      assert {:error, {:redirect, %{to: "/platform", flash: flash}}} =
               live(conn, ~p"/platform/billing")

      assert flash["error"] =~ "permission"
    end
  end
end
