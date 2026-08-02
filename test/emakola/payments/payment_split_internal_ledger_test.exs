defmodule Emakola.Payments.PaymentSplitInternalLedgerTest do
  @moduledoc """
  Internal-rail ledger vocabulary on PaymentSplit ("one ledger, two rails"):
  settlement method, currency, and the paid-out claim state.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.PaymentSplit

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

  defp settle!(split) do
    split
    |> Ash.Changeset.for_update(:mark_settled, %{})
    |> Ash.update!(authorize?: false)
  end

  defp payable_internal(recipient_store_id) do
    PaymentSplit
    |> Ash.Query.for_read(:payable_internal, %{recipient_store_id: recipient_store_id})
    |> Ash.read!(authorize?: false)
  end

  describe "ledger attributes" do
    test "settlement_method defaults to :gateway_share and accepts :internal_hold", %{
      store: store,
      payment: payment
    } do
      default = create_split!(store, payment, %{role: :platform, amount: 840})
      assert default.settlement_method == :gateway_share

      internal =
        create_split!(store, payment, %{
          role: :merchant,
          recipient_store_id: store.id,
          amount: 41_160,
          settlement_method: :internal_hold,
          currency: "GHS"
        })

      assert internal.settlement_method == :internal_hold
      assert internal.currency == "GHS"
      assert is_nil(internal.paid_out_at)
      assert is_nil(internal.payout_id)
      assert is_nil(internal.paid_amount)
      assert internal.netted_reversal_amount == 0
    end
  end

  describe "payable_internal" do
    test "includes only settled, unclaimed, non-platform internal_hold rows", %{
      store: store,
      payment: payment
    } do
      wholesaler = create_store!(name: "Wholesaler Co")

      payable =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            amount: 41_160,
            settlement_method: :internal_hold
          })
        )

      # Each excluded for exactly one reason:
      _platform =
        settle!(
          create_split!(store, payment, %{
            role: :platform,
            amount: 840,
            settlement_method: :internal_hold
          })
        )

      _gateway =
        settle!(
          create_split!(store, payment, %{
            role: :wholesaler,
            recipient_store_id: wholesaler.id,
            supplier_id: Ash.UUID.generate(),
            subaccount_code: "ACCT_w",
            amount: 1_600,
            settlement_method: :gateway_share
          })
        )

      _pending =
        create_split!(store, payment, %{
          role: :dropshipper,
          recipient_store_id: store.id,
          amount: 2_000,
          settlement_method: :internal_hold
        })

      fully_reversed =
        settle!(
          create_split!(store, payment, %{
            role: :wholesaler,
            recipient_store_id: wholesaler.id,
            supplier_id: Ash.UUID.generate(),
            amount: 900,
            settlement_method: :internal_hold
          })
        )

      fully_reversed
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 900})
      |> Ash.update!(authorize?: false)

      assert [found] = payable_internal(nil)
      assert found.id == payable.id

      # Scoped to a recipient with nothing payable → empty.
      assert payable_internal(wholesaler.id) == []

      # Through the domain's defined function (not just Ash.Query directly) —
      # catches a typo'd arg name in the `define` that the calls above,
      # bypassing the domain, would never exercise.
      assert {:ok, [found_via_domain]} =
               Emakola.Payments.list_payable_internal_splits(store.id, authorize?: false)

      assert found_via_domain.id == payable.id
    end

    test "a partially reversed split stays payable for its net", %{
      store: store,
      payment: payment
    } do
      split =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            amount: 10_000,
            settlement_method: :internal_hold
          })
        )

      split
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 4_000})
      |> Ash.update!(authorize?: false)

      assert [found] = payable_internal(store.id)
      assert found.status == :partially_reversed
      assert found.amount - found.reversed_amount == 6_000
    end
  end

  describe "mark_paid_out / release_from_payout" do
    test "claim freezes paid_amount and the netted fence; release resets them", %{
      store: store,
      payment: payment
    } do
      payout_id = Ash.UUID.generate()

      split =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            amount: 10_000,
            settlement_method: :internal_hold
          })
        )

      split =
        split
        |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 4_000})
        |> Ash.update!(authorize?: false)

      claimed =
        split
        |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
        |> Ash.update!(authorize?: false)

      assert claimed.payout_id == payout_id
      assert %DateTime{} = claimed.paid_out_at
      assert claimed.paid_amount == 6_000
      assert claimed.netted_reversal_amount == 4_000

      # Claimed → no longer payable.
      assert payable_internal(store.id) == []

      released =
        claimed
        |> Ash.Changeset.for_update(:release_from_payout, %{})
        |> Ash.update!(authorize?: false)

      assert is_nil(released.paid_out_at)
      assert is_nil(released.payout_id)
      assert is_nil(released.paid_amount)
      assert released.netted_reversal_amount == 0

      # Released → payable again, exactly once.
      assert [%{id: _}] = payable_internal(store.id)
    end

    test "refuses a gateway split, a pending split, and a double claim", %{
      store: store,
      payment: payment
    } do
      payout_id = Ash.UUID.generate()

      payment2 = create_payment!(store)
      payment3 = create_payment!(store)

      gateway =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            subaccount_code: "ACCT_m",
            amount: 1_000,
            settlement_method: :gateway_share
          })
        )

      assert {:error, %Ash.Error.Invalid{}} =
               gateway
               |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
               |> Ash.update(authorize?: false)

      pending =
        create_split!(store, payment2, %{
          role: :merchant,
          recipient_store_id: store.id,
          amount: 1_000,
          settlement_method: :internal_hold
        })

      assert {:error, %Ash.Error.Invalid{}} =
               pending
               |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
               |> Ash.update(authorize?: false)

      claimed =
        settle!(
          create_split!(store, payment3, %{
            role: :dropshipper,
            recipient_store_id: store.id,
            amount: 2_000,
            settlement_method: :internal_hold
          })
        )
        |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
        |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               claimed
               |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
               |> Ash.update(authorize?: false)
    end

    # Post-review hardening (PR #372): a nil payout_id let a split claim
    # itself (paid_out_at set, dropped out of payable_internal) with no
    # payout to own it — money claimed but unreachable via by_payout.
    test "refuses a claim with no payout_id", %{store: store, payment: payment} do
      split =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            amount: 1_000,
            settlement_method: :internal_hold
          })
        )

      assert {:error, %Ash.Error.Invalid{}} =
               split
               |> Ash.Changeset.for_update(:mark_paid_out, %{})
               |> Ash.update(authorize?: false)
    end

    # Wave 2 hardening: release_from_payout had no guard at all — calling it
    # on a gateway split could write a nonzero netted_reversal_amount onto a
    # row the attribute's contract says must keep 0 (see the attribute doc).
    test "release refuses a gateway split", %{store: store, payment: payment} do
      gateway =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            subaccount_code: "ACCT_m",
            amount: 1_000,
            settlement_method: :gateway_share
          })
        )

      assert {:error, %Ash.Error.Invalid{}} =
               gateway
               |> Ash.Changeset.for_update(:release_from_payout, %{})
               |> Ash.update(authorize?: false)
    end
  end

  describe "by_payout" do
    test "returns exactly the splits a payout claimed", %{store: store, payment: payment} do
      payout_id = Ash.UUID.generate()

      claimed =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            amount: 3_000,
            settlement_method: :internal_hold
          })
        )
        |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
        |> Ash.update!(authorize?: false)

      _other =
        settle!(
          create_split!(store, payment, %{
            role: :dropshipper,
            recipient_store_id: store.id,
            amount: 500,
            settlement_method: :internal_hold
          })
        )

      {:ok, found} = Emakola.Payments.list_payment_splits_by_payout(payout_id, authorize?: false)
      assert [%{id: id}] = found
      assert id == claimed.id
    end
  end

  describe "release_from_payout on an unreclaimable split" do
    test "stamps remediation metadata when the released split can never be re-claimed", %{
      store: store,
      payment: payment
    } do
      payout_id = Ash.UUID.generate()

      split =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            amount: 6_000,
            settlement_method: :internal_hold
          })
        )
        |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 2_000})
        |> Ash.update!(authorize?: false)
        |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
        |> Ash.update!(authorize?: false)

      # Post-claim the refund grows to the FULL amount → :reversed → unreclaimable.
      split =
        split
        |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 6_000})
        |> Ash.update!(authorize?: false)

      released =
        split
        |> Ash.Changeset.for_update(:release_from_payout, %{})
        |> Ash.update!(authorize?: false)

      assert released.status == :reversed
      assert is_nil(released.paid_out_at)
      # payable_internal must NOT resurface it (amount > reversed is false)...
      assert payable_internal(store.id) == []
      # ...and the forensic flag marks it for manual remediation review.
      assert released.recovery_breakdown["unreclaimable_release"] == true
    end
  end
end
