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
    split = unreclaimable_split!(store, payment)

    {:ok, view, html} = live(conn, ~p"/platform/finance")

    assert html =~ "Needs remediation"
    assert html =~ "Remediate Co"
    # The stat tile's count is targeted by a stable id, not matched against
    # rendered markup (money tiles on this page share the same tabular-nums
    # class, so a markup-coupled substring assertion is ambiguous).
    assert has_element?(view, "#remediation-count", "1")
    # The row streams in, keyed by the split's id, and carries a severity pill.
    assert has_element?(view, "#remediation-row-#{split.id}")
    assert has_element?(view, "#remediation-row-#{split.id} span", "Needs remediation")
  end

  test "with no flagged splits, the tile shows 0 and a rich empty state", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/platform/finance")

    assert html =~ "Needs remediation"
    assert has_element?(view, "#remediation-count", "0")
    assert html =~ "Nothing needs remediation"
    refute has_element?(view, "#remediation-rows tr")
  end
end
