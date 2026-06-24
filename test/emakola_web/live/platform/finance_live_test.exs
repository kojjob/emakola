defmodule EmakolaWeb.Platform.FinanceLiveTest do
  @moduledoc """
  Platform finance oversight page (/platform/finance): revenue stat strip
  (fees collected, GMV, take rate, outstanding payouts) + per-store breakdown,
  permission gating, disconnected shell, and the empty state.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  defp success_payment!(store, attrs) do
    store
    |> Factory.create_payment!(attrs)
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)
  end

  defp platform_fee_split!(payment, amount) do
    Emakola.Payments.create_payment_split!(
      %{store_id: payment.store_id, payment_id: payment.id, role: :platform, amount: amount},
      authorize?: false
    )
  end

  defp verified_payout!(store, code) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{store_id: store.id})
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: code})
    |> Ash.update!(authorize?: false)
  end

  test "staff without :manage_billing is redirected", %{conn: conn} do
    {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
    assert {:error, {:redirect, _}} = live(conn, ~p"/platform/finance")
  end

  describe "disconnected mount" do
    test "renders a loading shell, not live data", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      store = Factory.create_store!(%{name: "Disconnected Co"})
      success_payment!(store, %{amount: 50_000})

      html = get(conn, "/platform/finance") |> html_response(200)

      assert html =~ "Loading"
      refute html =~ "Disconnected Co"
    end
  end

  describe "as an owner" do
    setup %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      %{conn: conn, user: user}
    end

    test "shows the empty state when there is no finance activity", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/finance")
      assert html =~ "No finance activity"
    end

    test "renders the revenue stat strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/finance")
      assert html =~ "Platform fees collected"
      assert html =~ "Outstanding"
      assert html =~ "GHS"
    end

    test "renders a per-store row with fees, outstanding and payout readiness", %{conn: conn} do
      owed_store = Factory.create_store!(%{name: "Owed Kingdom"})
      success_payment!(owed_store, %{amount: 80_000})

      fee_store = Factory.create_store!(%{name: "Fee Palace"})
      verified_payout!(fee_store, "ACCT_fee")
      payment = success_payment!(fee_store, %{amount: 10_000, split_mode: :dropship_split})
      platform_fee_split!(payment, 200)

      {:ok, _view, html} = live(conn, ~p"/platform/finance")

      assert html =~ "Owed Kingdom"
      assert html =~ "Fee Palace"
      # owed store has no payout set up; fee store is ready
      assert html =~ "No payout set up"
      assert html =~ "Ready"
    end
  end
end
