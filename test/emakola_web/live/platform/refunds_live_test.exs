defmodule EmakolaWeb.Platform.RefundsLiveTest do
  @moduledoc """
  Platform refund oversight page: hero totals + cross-store refunds table,
  permission gating, and the empty state.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  defp refunded!(store, amount, currency \\ "GHS") do
    payment = Factory.create_payment!(store, %{amount: amount, currency: currency})

    {:ok, payment} =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update(authorize?: false)

    {:ok, payment} =
      payment
      |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: amount})
      |> Ash.update(authorize?: false)

    payment
  end

  test "staff without :manage_billing is redirected", %{conn: conn} do
    {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
    assert {:error, {:redirect, _}} = live(conn, ~p"/platform/refunds")
  end

  describe "as an owner" do
    setup %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      %{conn: conn, user: user}
    end

    test "shows the empty state when there are no refunds", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/refunds")

      assert has_element?(view, "#platform-refunds-title")
      assert has_element?(view, "#platform-refunds-empty")
      refute has_element?(view, "#platform-refunds-table")
    end

    test "renders totals and a refunds row", %{conn: conn} do
      store = Factory.create_store!(%{name: "Kente Kingdom"})
      payment = refunded!(store, 100_000)

      {:ok, view, _html} = live(conn, ~p"/platform/refunds")

      assert has_element?(view, "#platform-refunds-table")
      assert has_element?(view, "#platform-refunds[phx-update='stream']")
      assert has_element?(view, "#refunds-#{payment.id}")
      refute has_element?(view, "#platform-refunds-empty")
    end

    test "ledger rows show a capitalized gateway pill and a friendly date", %{conn: conn} do
      store = Factory.create_store!(%{name: "Kente Kingdom"})
      payment = refunded!(store, 100_000)

      {:ok, view, _html} = live(conn, ~p"/platform/refunds")

      assert has_element?(view, "#refunds-#{payment.id}", "Paystack")

      assert has_element?(
               view,
               "#refunds-#{payment.id}",
               Calendar.strftime(payment.inserted_at, "%b %d, %Y")
             )
    end

    # The headline was hardcoded "GHS" while summing every currency into one
    # integer, so a single NGN refund both mislabelled and corrupted the total.
    test "totals are kept apart per currency, never added together", %{conn: conn} do
      store = Factory.create_store!(%{name: "Kente Kingdom"})
      refunded!(store, 100_000)
      refunded!(store, 40_000, "NGN")

      {:ok, view, _html} = live(conn, ~p"/platform/refunds")

      total = view |> element("#platform-refunds-total") |> render()

      assert total =~ "GHS 1,000.00"
      assert total =~ "NGN 400.00"
      # 140_000 minor units labelled as one currency is the bug.
      refute total =~ "GHS 1,400.00"
    end

    # The table stops at a server-side cap while the count tile reports the
    # true total, and nothing on screen accounted for the gap.
    test "the table says how much of the total it is showing", %{conn: conn} do
      store = Factory.create_store!(%{name: "Kente Kingdom"})
      refunded!(store, 100_000)
      refunded!(store, 25_000)

      {:ok, view, _html} = live(conn, ~p"/platform/refunds")

      assert has_element?(view, "#platform-refunds-showing", "Showing 2")
      assert has_element?(view, "#platform-refunds-showing", "of 2")
    end
  end
end
