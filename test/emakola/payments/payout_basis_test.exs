defmodule Emakola.Payments.PayoutBasisTest do
  @moduledoc "Payout.basis partitions the two payout engines (:payments legacy / :allocations internal)."
  use Emakola.DataCase, async: true
  import Emakola.Factory

  test "defaults to :payments and accepts :allocations" do
    store = create_store!()

    {:ok, legacy} =
      Emakola.Payments.create_payout(
        %{store_id: store.id, amount: 1_000, currency: "GHS", transfer_reference: "po_basis_a"},
        authorize?: false
      )

    assert legacy.basis == :payments

    {:ok, internal} =
      Emakola.Payments.create_payout(
        %{
          store_id: store.id,
          amount: 2_000,
          currency: "GHS",
          transfer_reference: "po_basis_b",
          basis: :allocations
        },
        authorize?: false
      )

    assert internal.basis == :allocations
  end
end
