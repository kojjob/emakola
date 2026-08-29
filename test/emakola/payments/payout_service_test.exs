defmodule Emakola.Payments.PayoutServiceTest do
  @moduledoc """
  Prepares a merchant payout: resolves a MoMo transfer destination, gathers the
  store's outstanding un-split successful payments, creates a pending Payout and
  stamps the covered payments so they leave the backlog (no double-pay).
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Payments
  alias Emakola.Payments.{Payment, PayoutService, ProtectionHolds, ProtectionRelease}

  defp success_payment!(store, attrs) do
    store
    |> Factory.create_payment!(Map.merge(%{amount: 50_000}, attrs))
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)
  end

  defp momo_account!(store, provider \\ "mtn") do
    {:ok, _} =
      Emakola.Stores.create_payout_account(
        %{
          store_id: store.id,
          payout_destination: %{
            "method" => "mobile_money",
            "provider" => provider,
            "number" => "0244123456",
            "account_name" => "Kwame Owusu"
          }
        },
        authorize?: false
      )
  end

  describe "transfer_destination/1" do
    test "resolves the MoMo number, name and telco bank_code" do
      store = Factory.create_store!()
      momo_account!(store, "vodafone")

      assert {:ok, dest} = PayoutService.transfer_destination(store.id)
      assert dest.type == "mobile_money"
      assert dest.account_number == "0244123456"
      assert dest.name == "Kwame Owusu"
      assert dest.bank_code == "VOD"
      assert dest.currency == "GHS"
    end

    test "errors when the store has no MoMo payout details" do
      store = Factory.create_store!()
      assert {:error, :no_momo_destination} = PayoutService.transfer_destination(store.id)
    end
  end

  describe "prepare_payout/1" do
    test "creates a pending payout summing outstanding payments and stamps them" do
      store = Factory.create_store!()
      momo_account!(store)
      success_payment!(store, %{amount: 30_000})
      success_payment!(store, %{amount: 50_000})

      assert {:ok, payout} = PayoutService.prepare_payout(store.id)
      assert payout.status == :pending
      assert payout.amount == 80_000
      assert payout.store_id == store.id
      assert is_binary(payout.transfer_reference)

      # Covered payments are stamped → backlog now empty.
      assert PayoutService.outstanding_payments(store.id) == []

      stamped = Payments.list_payments_by_store!(store.id, authorize?: false)
      assert Enum.all?(stamped, &(&1.payout_id == payout.id))
      assert Enum.all?(stamped, &(&1.paid_out_at != nil))
    end

    test "errors with :nothing_outstanding when there is nothing to pay" do
      store = Factory.create_store!()
      momo_account!(store)
      assert {:error, :nothing_outstanding} = PayoutService.prepare_payout(store.id)
    end

    test "errors with :no_momo_destination and stamps nothing when MoMo details are missing" do
      store = Factory.create_store!()
      success_payment!(store, %{amount: 50_000})

      assert {:error, :no_momo_destination} = PayoutService.prepare_payout(store.id)
      # Nothing stamped — still outstanding.
      assert [_one] = PayoutService.outstanding_payments(store.id)
    end

    test "excludes split payments from the payout" do
      store = Factory.create_store!()
      momo_account!(store)
      success_payment!(store, %{amount: 50_000})
      success_payment!(store, %{amount: 99_000, split_mode: :dropship_split})

      assert {:ok, payout} = PayoutService.prepare_payout(store.id)
      assert payout.amount == 50_000
    end

    test "atomically claims the balance — a second approval finds nothing outstanding" do
      store = Factory.create_store!()
      momo_account!(store)
      success_payment!(store, %{amount: 40_000})

      assert {:ok, _payout} = PayoutService.prepare_payout(store.id)
      # The FOR UPDATE claim stamped the charges, so a concurrent/second approval
      # can't re-claim the same balance (no double-pay).
      assert {:error, :nothing_outstanding} = PayoutService.prepare_payout(store.id)
    end
  end

  describe "prepare_payout/1 with buyer-protection holds" do
    defp protected_payment!(store, attrs) do
      attrs = Map.new(attrs)
      amount = Map.get(attrs, :amount, 25_000)
      order = Factory.create_order!(store, %{total: amount})

      payment =
        store
        |> Factory.create_payment!(
          Map.merge(
            %{
              order_id: order.id,
              amount: amount,
              payout_held: true,
              payout_hold_reason: "buyer_protection"
            },
            attrs
          )
        )
        |> Ash.Changeset.for_update(:mark_success, %{})
        |> Ash.update!(authorize?: false)

      :ok = ProtectionHolds.ensure_hold(payment)

      {:ok, hold} =
        Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

      {payment, hold}
    end

    test "a released protected payment enters the backlog at net" do
      store = Factory.create_store!()
      momo_account!(store)
      {payment, hold} = protected_payment!(store, %{amount: 25_000})

      assert :ok = ProtectionRelease.release(hold, :buyer_confirmed)

      assert {:ok, payout} = PayoutService.prepare_payout(store.id)
      assert payout.amount == hold.net
      refute payout.amount == payment.amount

      reloaded = Ash.get!(Payment, payment.id, authorize?: false)
      assert reloaded.payout_id == payout.id
      assert reloaded.paid_out_at != nil
    end

    test "a still-held protected payment never enters the backlog" do
      store = Factory.create_store!()
      momo_account!(store)
      {_payment, _hold} = protected_payment!(store, %{amount: 25_000})

      assert {:error, :nothing_outstanding} = PayoutService.prepare_payout(store.id)
    end

    test "an unprotected payment is unaffected — payable_amount nil pays the full amount, byte-identical" do
      store = Factory.create_store!()
      momo_account!(store)
      payment = success_payment!(store, %{amount: 40_000})
      assert payment.payable_amount == nil

      assert {:ok, payout} = PayoutService.prepare_payout(store.id)
      assert payout.amount == 40_000

      reloaded = Ash.get!(Payment, payment.id, authorize?: false)
      assert reloaded.payable_amount == nil
      assert reloaded.amount == 40_000
      assert reloaded.payout_id == payout.id
    end
  end

  describe "prepare_payout/1 with susu holds (TC-3 cross-cutting guard)" do
    # A susu contribution is held under `payout_hold_reason: "susu_plan"` from
    # the moment `SusuChunks.confirm_chunk/1` records it, until
    # `SusuCompletion.complete/1` either releases it (unprotected store) or
    # converts it to a `buyer_protection` hold (protected store) — see both
    # modules' moduledocs. `outstanding_for_payout`'s `payout_held == false`
    # filter is what excludes it here, same mechanism as a buyer-protection
    # hold above — there is no susu-specific carve-out in the payout query.
    defp susu_held_payment!(store, attrs) do
      attrs = Map.new(attrs)
      amount = Map.get(attrs, :amount, 25_000)

      store
      |> Factory.create_payment!(
        Map.merge(
          %{
            susu_plan_id: Ash.UUID.generate(),
            amount: amount,
            payout_held: true,
            payout_hold_reason: "susu_plan",
            metadata: %{"susu_counted" => true}
          },
          attrs
        )
      )
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)
    end

    test "a still-held susu-plan payment never enters the backlog" do
      store = Factory.create_store!()
      momo_account!(store)
      susu_held_payment!(store, %{amount: 25_000})

      assert {:error, :nothing_outstanding} = PayoutService.prepare_payout(store.id)
    end

    test "excludes a susu-held payment while still paying out the store's other outstanding balance" do
      store = Factory.create_store!()
      momo_account!(store)
      susu_held_payment!(store, %{amount: 25_000})
      success_payment!(store, %{amount: 40_000})

      assert {:ok, payout} = PayoutService.prepare_payout(store.id)
      assert payout.amount == 40_000
    end
  end
end
