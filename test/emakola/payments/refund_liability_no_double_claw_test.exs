defmodule Emakola.Payments.RefundLiabilityNoDoubleClawTest do
  @moduledoc """
  The no-double-claw invariant: an internal-rail reversal that was netted at
  claim time (payable = amount - reversed) must NOT also be recovered from the
  recipient's future earnings. netted_reversal_amount, frozen by mark_paid_out
  and reset by release_from_payout, is the fence.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.{PaymentSplit, RefundLiability}

  setup do
    store = create_store!()
    payment = create_payment!(store)
    {:ok, store: store, payment: payment}
  end

  defp create_split!(store, payment, attrs) do
    params = Map.merge(%{store_id: store.id, payment_id: payment.id}, Map.new(attrs))

    PaymentSplit
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(authorize?: false)
  end

  defp settled_internal!(store, payment, amount) do
    create_split!(store, payment, %{
      role: :merchant,
      recipient_store_id: store.id,
      amount: amount,
      settlement_method: :internal_hold
    })
    |> Ash.Changeset.for_update(:mark_settled, %{})
    |> Ash.update!(authorize?: false)
  end

  defp reverse!(split, amount) do
    split
    |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: amount})
    |> Ash.update!(authorize?: false)
  end

  defp reserve_for_new_earning(store, amount) do
    RefundLiability.reserve!([
      %{role: :merchant, recipient_store_id: store.id, amount: amount, subaccount_code: nil},
      %{role: :platform, recipient_store_id: nil, amount: 0, subaccount_code: nil}
    ])
  end

  test "a reversal netted at claim is NOT recovered from future earnings", %{
    store: store,
    payment: payment
  } do
    split = settled_internal!(store, payment, 10_000)
    split = reverse!(split, 4_000)

    # Claim nets the reversal into the payout (pays 6_000, fences 4_000).
    split
    |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
    |> Ash.update!(authorize?: false)

    adjusted = reserve_for_new_earning(store, 5_000)
    merchant = Enum.find(adjusted, &(&1.role == :merchant))

    # Nothing recoverable — the 4_000 was never paid to the merchant.
    assert merchant.amount == 5_000
    assert merchant.recovery_amount == 0
  end

  test "a reversal AFTER claim is recoverable only for the delta", %{
    store: store,
    payment: payment
  } do
    split = settled_internal!(store, payment, 10_000)
    split = reverse!(split, 4_000)

    split =
      split
      |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
      |> Ash.update!(authorize?: false)

    # Refund grows to 7_000 after the payout paid 6_000 → only 3_000 was
    # over-paid and is recoverable.
    reverse!(split, 7_000)

    adjusted = reserve_for_new_earning(store, 5_000)
    merchant = Enum.find(adjusted, &(&1.role == :merchant))

    assert merchant.recovery_amount == 3_000
    assert merchant.amount == 2_000
  end

  test "release_from_payout resets the fence — reversals net at source again", %{
    store: store,
    payment: payment
  } do
    split = settled_internal!(store, payment, 10_000)
    split = reverse!(split, 4_000)

    split =
      split
      |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
      |> Ash.update!(authorize?: false)

    split
    |> Ash.Changeset.for_update(:release_from_payout, %{})
    |> Ash.update!(authorize?: false)

    adjusted = reserve_for_new_earning(store, 5_000)
    merchant = Enum.find(adjusted, &(&1.role == :merchant))

    # Unclaimed again: the 4_000 nets at source (payable 6_000), not recovered.
    assert merchant.recovery_amount == 0
  end

  test "add_to_platform synthesizes a platform row instead of dropping money", %{
    store: store,
    payment: payment
  } do
    split = settled_internal!(store, payment, 10_000)
    split = reverse!(split, 4_000)

    split
    |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
    |> Ash.update!(authorize?: false)

    # Post-payout the refund grows: 2_000 recoverable.
    reverse!(split, 6_000)

    # Allocation set WITHOUT a platform row.
    adjusted =
      RefundLiability.reserve!([
        %{role: :merchant, recipient_store_id: store.id, amount: 5_000, subaccount_code: nil}
      ])

    merchant = Enum.find(adjusted, &(&1.role == :merchant))
    platform = Enum.find(adjusted, &(&1.role == :platform))

    assert merchant.amount == 3_000
    assert platform.amount == 2_000
    assert platform.settlement_method == :internal_hold
    assert Enum.sum(Enum.map(adjusted, & &1.amount)) == 5_000
  end
end
