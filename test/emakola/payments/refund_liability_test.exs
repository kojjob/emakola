defmodule Emakola.Payments.RefundLiabilityTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Payments.PaymentSplit
  alias Emakola.Payments.RefundLiability

  setup do
    seller = create_store!(name: "Recovering seller")
    original_store = create_store!(name: "Original checkout")
    original_payment = create_payment!(original_store)

    liability =
      create_split!(original_store, original_payment, %{
        role: :wholesaler,
        recipient_store_id: seller.id,
        amount: 1_000
      })
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 700})
      |> Ash.update!(authorize?: false)

    {:ok, seller: seller, original_store: original_store, liability: liability}
  end

  test "reserves debt from future earnings without changing the charge total", %{
    seller: seller,
    liability: liability
  } do
    allocations = RefundLiability.reserve!(allocations(seller, 500, 100))
    by_role = Map.new(allocations, &{&1.role, &1})

    assert by_role.merchant.amount == 0
    assert by_role.merchant.recovery_amount == 500
    assert by_role.platform.amount == 600
    assert Enum.sum(Enum.map(allocations, & &1.amount)) == 600

    assert fresh(liability).reserved_recovery_amount == 500
    assert fresh(liability).recovered_amount == 0
  end

  test "a second reservation cannot claim an amount already reserved", %{
    seller: seller,
    liability: liability
  } do
    first = RefundLiability.reserve!(allocations(seller, 500, 100))
    second = RefundLiability.reserve!(allocations(seller, 500, 100))

    assert allocation(first, :merchant).recovery_amount == 500
    assert allocation(second, :merchant).recovery_amount == 200
    assert fresh(liability).reserved_recovery_amount == 700
  end

  test "releases a reservation when payment initiation fails", %{
    seller: seller,
    liability: liability
  } do
    reserved = RefundLiability.reserve!(allocations(seller, 500, 100))
    assert fresh(liability).reserved_recovery_amount == 500

    assert :ok = RefundLiability.release!(reserved)
    assert fresh(liability).reserved_recovery_amount == 0
    assert fresh(liability).recovered_amount == 0
  end

  test "applies a successful recovery exactly once", %{
    seller: seller,
    liability: liability
  } do
    [merchant | _] = RefundLiability.reserve!(allocations(seller, 500, 100))
    payment = create_payment!(seller, amount: 600)

    earning =
      create_split!(seller, payment, %{
        role: :merchant,
        recipient_store_id: seller.id,
        amount: merchant.amount,
        recovery_amount: merchant.recovery_amount,
        recovery_breakdown: merchant.recovery_breakdown
      })

    assert :ok = RefundLiability.apply_recoveries!([earning])
    assert :ok = RefundLiability.apply_recoveries!([earning])

    updated_liability = fresh(liability)
    assert updated_liability.recovered_amount == 500
    assert updated_liability.reserved_recovery_amount == 0
    assert fresh(earning).recovery_applied_amount == 500
  end

  test "reopens recovery proportionally when the earning is refunded", %{
    seller: seller,
    liability: liability
  } do
    [merchant | _] = RefundLiability.reserve!(allocations(seller, 500, 100))
    payment = create_payment!(seller, amount: 600)

    earning =
      create_split!(seller, payment, %{
        role: :merchant,
        recipient_store_id: seller.id,
        amount: merchant.amount,
        recovery_amount: merchant.recovery_amount,
        recovery_breakdown: merchant.recovery_breakdown
      })

    RefundLiability.apply_recoveries!([earning])
    assert fresh(liability).recovered_amount == 500

    RefundLiability.rollback_recoveries!(%{payment | refunded_amount: 300}, [earning])
    assert fresh(liability).recovered_amount == 250
    assert fresh(earning).recovery_reversed_amount == 250

    RefundLiability.rollback_recoveries!(%{payment | refunded_amount: 600}, [earning])
    assert fresh(liability).recovered_amount == 0
    assert fresh(earning).recovery_reversed_amount == 500
  end

  defp allocations(store, earning, platform) do
    [
      %{
        role: :merchant,
        recipient_store_id: store.id,
        subaccount_code: "ACCT_seller",
        amount: earning
      },
      %{role: :platform, recipient_store_id: nil, subaccount_code: nil, amount: platform}
    ]
  end

  defp allocation(allocations, role), do: Enum.find(allocations, &(&1.role == role))

  # Post-merge hardening (2026-07-11 review): per-split floor division left up
  # to n-1 pesewas of a partial refund unrecoverable. Reversals must sum
  # exactly to the refunded amount.
  describe "exact partial-refund reversals" do
    test "reversals sum exactly to the refunded amount", %{original_store: store} do
      payment = create_payment!(store, amount: 1_001)
      recipient = create_store!(name: "Split recipient")

      splits =
        for amount <- [333, 333, 335] do
          create_split!(store, payment, %{
            role: :wholesaler,
            recipient_store_id: recipient.id,
            # Real wholesaler splits always carry a supplier: SplitCalculator
            # groups by supplier_id, one row each. The unique_allocation
            # constraint enforces that shape here too.
            supplier_id: Ash.UUID.generate(),
            amount: amount
          })
        end

      RefundLiability.reconcile!(%{payment | refunded_amount: 500}, splits)

      assert splits |> Enum.map(&fresh(&1).reversed_amount) |> Enum.sum() == 500
    end

    test "successive partial refunds keep the running total exact", %{original_store: store} do
      payment = create_payment!(store, amount: 1_001)
      recipient = create_store!(name: "Split recipient two")

      splits =
        for amount <- [333, 333, 335] do
          create_split!(store, payment, %{
            role: :wholesaler,
            recipient_store_id: recipient.id,
            # Real wholesaler splits always carry a supplier: SplitCalculator
            # groups by supplier_id, one row each. The unique_allocation
            # constraint enforces that shape here too.
            supplier_id: Ash.UUID.generate(),
            amount: amount
          })
        end

      RefundLiability.reconcile!(%{payment | refunded_amount: 500}, splits)
      RefundLiability.reconcile!(%{payment | refunded_amount: 1_001}, splits)

      # A full refund reverses every split completely — no pesewa left behind.
      assert Enum.map(splits, &fresh(&1).reversed_amount) == [333, 333, 335]
    end
  end

  defp create_split!(store, payment, attrs) do
    attrs
    |> Map.merge(%{store_id: store.id, payment_id: payment.id})
    |> then(&Emakola.Payments.create_payment_split!(&1, authorize?: false))
  end

  defp fresh(split), do: Ash.get!(PaymentSplit, split.id, authorize?: false)
end
