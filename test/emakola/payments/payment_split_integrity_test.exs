defmodule Emakola.Payments.PaymentSplitIntegrityTest do
  @moduledoc """
  Integrity guarantees on the split ledger.

  Every revenue number the platform reports is a sum over `payment_splits`, and
  every payout decision trusts a split's status. Two holes made both
  untrustworthy:

    * `record_splits!/2` was a plain `Enum.each` of creates with no idempotency
      key and no DB constraint — a checkout retry after a partial failure could
      double-record an allocation, silently inflating fees and merchant nets.

    * `:mark_settled` had no status guard (unlike Payout's transitions), so a
      replayed `charge.success` webhook interleaving with `refund.processed`
      could flip a `:reversed` split back to `:settled` — resurrecting money
      that had already been clawed back.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Payments.OrderSettlement
  alias Emakola.Payments.PaymentSplit

  defp seed_payment! do
    store = Emakola.Factory.create_store!()
    payment = Emakola.Factory.create_payment!(store)
    %{store: store, payment: payment}
  end

  defp allocations(store) do
    [
      %{role: :merchant, recipient_store_id: store.id, amount: 490_000, subaccount_code: "SUB_m"},
      %{role: :platform, recipient_store_id: nil, amount: 10_000, subaccount_code: nil}
    ]
  end

  defp splits_for(payment) do
    {:ok, splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)
    splits
  end

  describe "duplicate allocations are impossible" do
    test "the database rejects a second identical split", %{} do
      %{store: store, payment: payment} = seed_payment!()

      attrs = %{
        store_id: store.id,
        payment_id: payment.id,
        role: :platform,
        amount: 10_000
      }

      assert {:ok, _} = Emakola.Payments.create_payment_split(attrs, authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               Emakola.Payments.create_payment_split(attrs, authorize?: false)
    end

    test "two wholesaler splits for DIFFERENT suppliers are both allowed" do
      %{store: store, payment: payment} = seed_payment!()

      base = %{store_id: store.id, payment_id: payment.id, role: :wholesaler, amount: 5_000}

      assert {:ok, _} =
               base
               |> Map.put(:supplier_id, Ash.UUID.generate())
               |> Emakola.Payments.create_payment_split(authorize?: false)

      assert {:ok, _} =
               base
               |> Map.put(:supplier_id, Ash.UUID.generate())
               |> Emakola.Payments.create_payment_split(authorize?: false)
    end
  end

  describe "record_splits!/2 is idempotent" do
    test "recording the same allocations twice creates each split once" do
      %{store: store, payment: payment} = seed_payment!()

      OrderSettlement.record_splits!(payment, allocations(store))
      OrderSettlement.record_splits!(payment, allocations(store))

      assert length(splits_for(payment)) == 2
    end

    test "a retry after a partial write completes only the missing splits" do
      %{store: store, payment: payment} = seed_payment!()
      [merchant_alloc, _platform_alloc] = allocations(store)

      # First attempt died after writing only the merchant row.
      OrderSettlement.record_splits!(payment, [merchant_alloc])

      # The retry records the full allocation list.
      OrderSettlement.record_splits!(payment, allocations(store))

      splits = splits_for(payment)
      assert length(splits) == 2
      assert Enum.count(splits, &(&1.role == :merchant)) == 1
      assert Enum.count(splits, &(&1.role == :platform)) == 1
    end
  end

  describe "mark_settled only settles a pending split" do
    test "a pending split settles" do
      %{store: store, payment: payment} = seed_payment!()

      split =
        Emakola.Payments.create_payment_split!(
          %{store_id: store.id, payment_id: payment.id, role: :platform, amount: 10_000},
          authorize?: false
        )

      settled =
        split
        |> Ash.Changeset.for_update(:mark_settled, %{})
        |> Ash.update!(authorize?: false)

      assert settled.status == :settled
    end

    test "a merchant actor cannot mutate the ledger, even on their own store" do
      {merchant, store} = Emakola.Factory.create_merchant_with_store!()
      payment = Emakola.Factory.create_payment!(store)

      split =
        Emakola.Payments.create_payment_split!(
          %{store_id: store.id, payment_id: payment.id, role: :platform, amount: 10_000},
          authorize?: false
        )

      # Reads with store access: fine.
      assert {:ok, _} =
               Emakola.Payments.list_payment_splits(payment.id,
                 actor: merchant,
                 tenant: store.id
               )

      # Money-state mutations are system-only (authorize?: false from webhook
      # code). A merchant must never hold a lever over their own splits' status.
      assert {:error, %Ash.Error.Forbidden{}} =
               split
               |> Ash.Changeset.for_update(:mark_reversed, %{}, actor: merchant)
               |> Ash.update()

      # Settled first, so the status validation cannot mask the policy check:
      # this must fail on FORBIDDEN, not on invalid status.
      settled =
        split
        |> Ash.Changeset.for_update(:mark_settled, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Forbidden{}} =
               settled
               |> Ash.Changeset.for_update(
                 :record_settlement_reference,
                 %{paystack_split_reference: "evil"},
                 actor: merchant
               )
               |> Ash.update()
    end

    test "a reversed split cannot be flipped back to settled by a replayed webhook" do
      %{store: store, payment: payment} = seed_payment!()

      split =
        Emakola.Payments.create_payment_split!(
          %{store_id: store.id, payment_id: payment.id, role: :platform, amount: 10_000},
          authorize?: false
        )

      reversed =
        split
        |> Ash.Changeset.for_update(:mark_reversed, %{})
        |> Ash.update!(authorize?: false)

      assert reversed.status == :reversed

      assert {:error, %Ash.Error.Invalid{}} =
               reversed
               |> Ash.Changeset.for_update(:mark_settled, %{})
               |> Ash.update(authorize?: false)

      assert Ash.get!(PaymentSplit, split.id, authorize?: false, tenant: store.id).status ==
               :reversed
    end
  end
end
