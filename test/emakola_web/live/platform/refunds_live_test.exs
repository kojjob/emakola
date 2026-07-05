defmodule EmakolaWeb.Platform.RefundsLiveTest do
  @moduledoc """
  Platform refund oversight page: hero totals + cross-store refunds table,
  permission gating, and the empty state.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  defp refunded!(store, amount) do
    payment = Factory.create_payment!(store, %{amount: amount})

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
      {:ok, _view, html} = live(conn, ~p"/platform/refunds")
      assert html =~ "No refunds"
    end

    test "renders totals and a refunds row", %{conn: conn} do
      store = Factory.create_store!(%{name: "Kente Kingdom"})
      refunded!(store, 100_000)

      {:ok, _view, html} = live(conn, ~p"/platform/refunds")

      assert html =~ "Refunds"
      assert html =~ "Kente Kingdom"
    end
  end
end
