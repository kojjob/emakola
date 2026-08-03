defmodule EmakolaWeb.Platform.FinanceLiveRemediationTest do
  @moduledoc """
  Platform finance's "Needs remediation" surface (money-surfaces PR-1, Task
  4): splits `PaymentSplit.release_from_payout` stamped as unreclaimable
  (`recovery_breakdown["unreclaimable_release"] == true`) render in a
  dedicated tile + table with a severity pill — closing the gap where that
  flag had zero UI surface despite the domain code's own comment promising
  finance could find them.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Payments

  defp unreclaimable_split!(store, payment, attrs \\ %{}) do
    split =
      %{
        store_id: store.id,
        payment_id: payment.id,
        role: :merchant,
        recipient_store_id: store.id,
        amount: 10_000,
        settlement_method: :internal_hold
      }
      |> Map.merge(Map.new(attrs))
      |> then(&Payments.create_payment_split!(&1, authorize?: false))

    split
    |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: split.amount})
    |> Ash.update!(authorize?: false)
    |> Ash.Changeset.for_update(:release_from_payout, %{})
    |> Ash.update!(authorize?: false)
  end

  setup %{conn: conn} do
    {conn, user, _session} = setup_platform_staff(conn)
    %{conn: conn, user: user}
  end

  test "a stamped split renders in the Needs remediation tile and table with a severity pill",
       %{conn: conn} do
    store = Factory.create_store!(%{name: "Remediate Co"})
    payment = Factory.create_payment!(store, %{amount: 10_000})
    unreclaimable_split!(store, payment)

    {:ok, _view, html} = live(conn, ~p"/platform/finance")

    assert html =~ "Needs remediation"
    assert html =~ "Remediate Co"
    # The stat tile's count reads 1 (a bare integer — every money tile on
    # this page is currency-formatted, so this substring is unambiguous).
    assert html =~ "tabular-nums\">1<"
    # The row's severity pill uses the shared ring-inset pill markup.
    assert html =~ "ring-1 ring-inset"
  end

  test "with no flagged splits, the tile shows 0 and a rich empty state", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/platform/finance")

    assert html =~ "Needs remediation"
    assert html =~ "tabular-nums\">0<"
    assert html =~ "Nothing needs remediation"
  end
end
