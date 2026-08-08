defmodule Emakola.Payments.InternalPayoutServiceTest do
  @moduledoc """
  Allocation-basis payouts: claim payable internal splits under FOR UPDATE and
  pay the Σ of frozen paid_amounts minus any outstanding refund liability the
  recipient owes (CONTRACT 1 (P2a): never amount − reversed, and never gross
  when a liability is outstanding).
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.{PaymentSplit, PayoutService}

  defp momo_destination!(store) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      payout_destination: %{
        "method" => "mobile_money",
        "provider" => "mtn",
        "number" => "0244000111",
        "account_name" => "Test Merchant"
      }
    })
    |> Ash.create!(authorize?: false)
  end

  defp settled_internal_split!(store, payment, attrs) do
    %{
      store_id: store.id,
      payment_id: payment.id,
      role: :merchant,
      recipient_store_id: store.id,
      amount: 10_000,
      settlement_method: :internal_hold
    }
    |> Map.merge(Map.new(attrs))
    |> then(&Ash.Changeset.for_create(PaymentSplit, :create, &1))
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:mark_settled, %{})
    |> Ash.update!(authorize?: false)
  end

  defp reload_split!(split), do: Ash.get!(PaymentSplit, split.id, authorize?: false)

  # A liability the recipient already owes: claimed at frozen value (via a
  # synthetic payout id, mirroring refund_liability_no_double_claw_test.exs's
  # settled_internal!/mark_paid_out idiom) BEFORE any reversal, so the claim
  # freezes netted_reversal_amount at 0 — then reversed AFTER the claim, so
  # the reversal is pure liability rather than netted at claim time.
  defp owing_split!(store, payment, amount, reversed_amount) do
    settled_internal_split!(store, payment, %{amount: amount})
    |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
    |> Ash.update!(authorize?: false)
    |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed_amount})
    |> Ash.update!(authorize?: false)
  end

  test "CONTRACT 1 (P2a): payout amount is Σ frozen paid_amounts minus liability deduction" do
    store = create_store!()
    momo_destination!(store)
    payment = create_payment!(store)

    plain = settled_internal_split!(store, payment, %{amount: 10_000})

    partially =
      settled_internal_split!(store, payment, %{role: :dropshipper, amount: 8_000})
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 3_000})
      |> Ash.update!(authorize?: false)

    {:ok, payout} = PayoutService.prepare_internal_payout(store.id)

    # 10_000 + (8_000 − 3_000) = 15_000 gross. No outstanding liability on
    # this store, so deduction is 0 — but the contract itself is
    # `Σ frozen − deduction`, not bare Σ frozen; the assertion says so
    # explicitly even though this fixture's deduction happens to be zero.
    deduction = 0
    assert payout.amount == 15_000 - deduction
    assert payout.basis == :allocations
    assert payout.currency == "GHS"
    assert payout.status == :pending

    {:ok, claimed} = Emakola.Payments.list_payment_splits_by_payout(payout.id, authorize?: false)
    assert length(claimed) == 2
    assert Enum.sum(Enum.map(claimed, & &1.paid_amount)) == payout.amount
    assert MapSet.new(claimed, & &1.id) == MapSet.new([plain.id, partially.id], & &1)

    # Second approval finds nothing — the claim emptied the payable set.
    assert {:error, :nothing_outstanding} = PayoutService.prepare_internal_payout(store.id)
  end

  test "frozen paid_amount is the 4-term formula, not naive amount − reversed_amount" do
    store = create_store!()
    momo_destination!(store)
    payment = create_payment!(store)

    # amount 8_000, reversed 3_000 — but that 3_000 was already recovered
    # from a later earning (recoverable_by_recipient) before this claim, so
    # netted = reversed_amount(3_000) - recovered_amount(3_000) -
    # reserved_recovery_amount(0) = 0 and the frozen paid_amount is the full
    # 8_000. The naive `amount - reversed_amount` would double-count the
    # already-recovered reversal and wrongly produce 5_000.
    split =
      settled_internal_split!(store, payment, %{amount: 8_000})
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 3_000})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:update_recovery_tracking, %{recovered_amount: 3_000})
      |> Ash.update!(authorize?: false)

    {:ok, payout} = PayoutService.prepare_internal_payout(store.id)

    assert payout.amount == 8_000

    {:ok, [claimed]} =
      Emakola.Payments.list_payment_splits_by_payout(payout.id, authorize?: false)

    assert claimed.id == split.id
    assert claimed.paid_amount == 8_000
  end

  test "frozen paid_amount pins the reserved_recovery_amount term specifically" do
    store = create_store!()
    momo_destination!(store)
    payment = create_payment!(store)

    # amount 9_000, reversed 4_000, recovered 1_000, reserved_recovery 2_000.
    # netted = 4_000 - 1_000 - 2_000 = 1_000, so paid_amount = 8_000. Naive
    # amount - reversed_amount gives 5_000; dropping ONLY the reserved term
    # (netted = 4_000 - 1_000 = 3_000) gives 6_000 — this pins the fourth
    # term specifically, distinct from both wrong answers.
    split =
      settled_internal_split!(store, payment, %{amount: 9_000})
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 4_000})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:update_recovery_tracking, %{
        recovered_amount: 1_000,
        reserved_recovery_amount: 2_000
      })
      |> Ash.update!(authorize?: false)

    {:ok, payout} = PayoutService.prepare_internal_payout(store.id)

    assert payout.amount == 9_000 - (4_000 - 1_000 - 2_000)
    assert payout.amount == 8_000

    {:ok, [claimed]} =
      Emakola.Payments.list_payment_splits_by_payout(payout.id, authorize?: false)

    assert claimed.id == split.id
    assert claimed.paid_amount == 8_000
  end

  test "no MoMo destination stamps nothing" do
    store = create_store!()
    payment = create_payment!(store)
    split = settled_internal_split!(store, payment, %{})

    assert {:error, :no_momo_destination} = PayoutService.prepare_internal_payout(store.id)

    assert is_nil(
             Ash.get!(Emakola.Payments.PaymentSplit, split.id, authorize?: false).paid_out_at
           )
  end

  test "nothing outstanding when only pending/platform/gateway splits exist" do
    store = create_store!()
    momo_destination!(store)
    assert {:error, :nothing_outstanding} = PayoutService.prepare_internal_payout(store.id)
  end

  test "currency partition claims one currency per payout" do
    store = create_store!()
    momo_destination!(store)
    ghs = create_payment!(store, currency: "GHS")
    ngn = create_payment!(store, currency: "NGN")
    settled_internal_split!(store, ghs, %{amount: 5_000, currency: "GHS"})
    settled_internal_split!(store, ngn, %{role: :dropshipper, amount: 7_000, currency: "NGN"})

    {:ok, first} = PayoutService.prepare_internal_payout(store.id)
    {:ok, second} = PayoutService.prepare_internal_payout(store.id)

    assert Enum.sort([first.amount, second.amount]) == [5_000, 7_000]
    assert Enum.sort([first.currency, second.currency]) == ["GHS", "NGN"]
  end

  test "momo_destination?/1" do
    with_dest = create_store!()
    momo_destination!(with_dest)
    without = create_store!()

    assert PayoutService.momo_destination?(with_dest.id)
    refute PayoutService.momo_destination?(without.id)
  end

  describe "payout-time liability netting (P2a)" do
    test "outstanding liability is deducted from the payout and booked on the source splits" do
      store = create_store!()
      momo_destination!(store)
      payment = create_payment!(store)
      old_payment = create_payment!(store)

      # A fresh settled internal split (10_000 payable) and an older claimed
      # split reversed 3_000 AFTER its claim (pure liability, not netted).
      payable_split = settled_internal_split!(store, payment, %{amount: 10_000})
      owing_split = owing_split!(store, old_payment, 8_000, 3_000)

      assert {:ok, payout} = PayoutService.prepare_internal_payout(store.id)

      # 10_000 earned − 3_000 owed = 7_000 transferred.
      assert payout.amount == 7_000

      # The claimed split keeps its frozen paid_amount — the deduction is NOT
      # hidden inside the claim value.
      claimed = reload_split!(payable_split)
      assert claimed.paid_amount == 10_000

      # The debt is booked on the SOURCE liability with payout provenance,
      # linked via transfer_reference (the payout doesn't exist yet when
      # collection runs).
      owing = reload_split!(owing_split)
      assert owing.recovered_amount == 3_000

      assert [%{"payout_ref" => ref, "amount" => 3_000}] =
               owing.recovery_breakdown["payout_recoveries"]

      assert ref == payout.transfer_reference

      # And the liability is extinguished: a second payout with new earnings
      # deducts nothing.
      new_payment = create_payment!(store)
      new_split = settled_internal_split!(store, new_payment, %{amount: 4_000})

      assert {:ok, second_payout} = PayoutService.prepare_internal_payout(store.id)
      assert second_payout.amount == 4_000
      assert reload_split!(owing_split).recovered_amount == 3_000
      assert reload_split!(new_split).paid_amount == 4_000
    end

    test "a payout fully consumed by debt collects and claims NOTHING — the debt waits for more earnings" do
      store = create_store!()
      momo_destination!(store)
      payment = create_payment!(store)
      old_payment = create_payment!(store)

      # payable 2_000, outstanding 5_000 → a payout here would be fully
      # consumed by the debt.
      payable_split = settled_internal_split!(store, payment, %{amount: 2_000})
      owing_split = owing_split!(store, old_payment, 8_000, 5_000)

      assert {:error, :nothing_outstanding} = PayoutService.prepare_internal_payout(store.id)

      # The key inversion (fix round 1): collection is conditional on a
      # payout actually committing. No payout committed here, so NOTHING was
      # collected (not even the withholdable 2_000) and NOTHING was claimed
      # — the debt is exactly as outstanding as before this call, and the
      # earnings stay payable for a later, larger payout or charge-time
      # reserve!/1 to grind down instead.
      assert reload_split!(owing_split).recovered_amount == 0
      assert reload_split!(payable_split).paid_out_at == nil

      # Repeated invocation on the same fully-consumed fixture is an
      # idempotent no-op — same error, same untouched state, every time.
      assert {:error, :nothing_outstanding} = PayoutService.prepare_internal_payout(store.id)
      assert reload_split!(owing_split).recovered_amount == 0

      # The recipient earns 4_000 more: 2_000 + 4_000 = 6_000 > 5_000 debt,
      # so this payout DOES commit and collection finally happens.
      new_payment = create_payment!(store)
      new_split = settled_internal_split!(store, new_payment, %{amount: 4_000})

      assert {:ok, payout} = PayoutService.prepare_internal_payout(store.id)
      assert payout.amount == 1_000
      assert reload_split!(owing_split).recovered_amount == 5_000
      refute is_nil(reload_split!(payable_split).paid_out_at)
      refute is_nil(reload_split!(new_split).paid_out_at)
    end

    test "a transfer failure releases the collected debt back to outstanding — retry nets fresh" do
      store = create_store!()
      momo_destination!(store)
      payment = create_payment!(store)
      old_payment = create_payment!(store)

      payable_split = settled_internal_split!(store, payment, %{amount: 10_000})
      owing_split = owing_split!(store, old_payment, 8_000, 3_000)

      assert {:ok, payout} = PayoutService.prepare_internal_payout(store.id)
      assert payout.amount == 7_000
      assert reload_split!(owing_split).recovered_amount == 3_000

      # The transfer never materialized — nobody was paid, so the
      # withholding must be undone along with the claim (this is what
      # PayoutWorker's mark_failed path and the transfer.failed webhook both
      # drive, via this same shared function).
      PayoutService.release_payout_balance(payout)

      released_owing = reload_split!(owing_split)
      assert released_owing.recovered_amount == 0
      assert released_owing.recovery_breakdown["payout_recoveries"] == []
      assert reload_split!(payable_split).paid_out_at == nil

      # Retry nets fresh: 3_000 is owed again, so a fresh payout still only
      # transfers 7_000, not the full 10_000.
      assert {:ok, retried} = PayoutService.prepare_internal_payout(store.id)
      assert retried.amount == 7_000
      assert reload_split!(owing_split).recovered_amount == 3_000
    end

    test "cross-currency: a liability in one currency does not net against payable in another" do
      store = create_store!()
      momo_destination!(store)
      ngn_payment = create_payment!(store, currency: "NGN")
      ghs_payment = create_payment!(store, currency: "GHS")
      old_payment = create_payment!(store)

      # The NGN split is inserted first, so it's the currency the
      # FOR-UPDATE read's sort (inserted_at asc, from payable_internal)
      # picks first — a deterministic partition.
      ngn_payable =
        settled_internal_split!(store, ngn_payment, %{amount: 10_000, currency: "NGN"})

      ghs_payable = settled_internal_split!(store, ghs_payment, %{amount: 5_000, currency: "GHS"})
      owing_split = owing_split!(store, old_payment, 8_000, 3_000)

      assert {:ok, ngn_payout} = PayoutService.prepare_internal_payout(store.id)
      assert ngn_payout.currency == "NGN"
      # The GHS debt does NOT touch the NGN payout — full gross transfers.
      assert ngn_payout.amount == 10_000
      assert reload_split!(owing_split).recovered_amount == 0
      assert reload_split!(ghs_payable).paid_out_at == nil

      assert {:ok, ghs_payout} = PayoutService.prepare_internal_payout(store.id)
      assert ghs_payout.currency == "GHS"
      # Now the GHS payout nets against the same-currency debt: 5_000 − 3_000.
      assert ghs_payout.amount == 2_000
      assert reload_split!(owing_split).recovered_amount == 3_000
      assert reload_split!(ngn_payable).paid_amount == 10_000
    end

    test "a recipient with no liability pays out gross, byte-identical to before" do
      store = create_store!()
      momo_destination!(store)
      payment = create_payment!(store)
      payable_split = settled_internal_split!(store, payment, %{amount: 10_000})

      assert {:ok, payout} = PayoutService.prepare_internal_payout(store.id)
      assert payout.amount == 10_000
      assert reload_split!(payable_split).paid_amount == 10_000

      # No payout_recoveries stamped anywhere — there was nothing to collect.
      refute Map.has_key?(reload_split!(payable_split).recovery_breakdown, "payout_recoveries")
    end
  end
end
