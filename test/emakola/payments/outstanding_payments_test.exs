defmodule Emakola.Payments.OutstandingPaymentsTest do
  @moduledoc """
  `Payment.outstanding_for_payout` is the single definition of the money the
  platform holds and still owes a merchant.

  This predicate used to live as four hand-copied filters (PayoutService twice,
  FinanceStats twice). Whoever edited one and missed the others would make the
  finance page and the payout engine disagree about what the platform owes —
  silently, in production, about money. Now the Payment resource defines it
  once and every caller queries the action by name.

  Outstanding = the charge succeeded, AND it was not split at source (with
  split-at-source the gateway already paid the merchant), AND it is not under a
  payout hold, AND it has not already been covered by a payout.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Payments.Payment

  defp success_payment!(store, attrs) do
    store
    |> Emakola.Factory.create_payment!(attrs)
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)
  end

  defp outstanding(store_id \\ nil) do
    Payment
    |> Ash.Query.for_read(:outstanding_for_payout, %{store_id: store_id})
    |> Ash.read!(authorize?: false)
  end

  test "a successful un-split, un-held, un-paid-out payment is outstanding" do
    store = Emakola.Factory.create_store!()
    payment = success_payment!(store, %{amount: 50_000})

    assert [%{id: id}] = outstanding()
    assert id == payment.id
  end

  test "each disqualifying condition excludes the payment" do
    store = Emakola.Factory.create_store!()

    # Not successful: charge never confirmed.
    Emakola.Factory.create_payment!(store, %{amount: 1_000})

    # Split at source: the gateway already paid the merchant directly.
    success_payment!(store, %{amount: 2_000, split_mode: :platform_fee})

    # Held: deliberately withheld from payout (set at create time — holds are
    # placed when the charge is recorded, released via :release_payout_hold).
    success_payment!(store, %{amount: 3_000, payout_held: true})

    # Already covered by a payout.
    store
    |> success_payment!(%{amount: 4_000})
    |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ecto.UUID.generate()})
    |> Ash.update!(authorize?: false)

    assert outstanding() == []
  end

  test "the store_id argument scopes to one store; nil means every store" do
    store_a = Emakola.Factory.create_store!()
    store_b = Emakola.Factory.create_store!()
    payment_a = success_payment!(store_a, %{amount: 10_000})
    payment_b = success_payment!(store_b, %{amount: 20_000})

    assert [%{id: id}] = outstanding(store_a.id)
    assert id == payment_a.id

    all_ids = outstanding() |> Enum.map(& &1.id) |> Enum.sort()
    assert all_ids == Enum.sort([payment_a.id, payment_b.id])
  end
end
