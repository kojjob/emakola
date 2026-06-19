defmodule EmakolaWeb.Admin.PayoutsLiveTest do
  use EmakolaWeb.ConnCase, async: true
  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest
  import Mox

  describe "PayoutsLive (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/settings/payouts")
    end
  end

  describe "PayoutsLive (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders the payouts page with a not-connected status", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/settings/payouts")

      assert html =~ "Payouts"
      assert html =~ "Not connected" or html =~ "not connected"
    end

    test "connecting a MoMo destination verifies the payout account", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings/payouts")

      # connect_momo resolves settlement_bank via List Banks inside the LiveView
      # process; share a stub with it so the lookup falls back to static codes
      # (this test asserts verification, not the bank code value).
      Emakola.Payments.PaystackClientMock
      |> stub(:list_banks, fn _params -> {:error, :unset} end)
      |> allow(self(), view.pid)

      html =
        view
        |> form("#payout-form", %{
          payout: %{provider: "mtn", number: "0240000000", account_name: "Ama Mensah"}
        })
        |> render_submit()

      assert html =~ "Verified" or html =~ "verified"
      assert html =~ "0240000000"

      {:ok, account} = Emakola.Stores.get_payout_account(store.id, authorize?: false)
      assert account.verification_status == :verified
      assert is_binary(account.subaccount_code)
    end
  end
end
