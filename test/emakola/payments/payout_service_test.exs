defmodule Emakola.Payments.PayoutServiceTest do
  @moduledoc """
  Prepares a merchant payout: resolves a MoMo transfer destination, gathers the
  store's outstanding un-split successful payments, creates a pending Payout and
  stamps the covered payments so they leave the backlog (no double-pay).
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Payments
  alias Emakola.Payments.PayoutService

  defp success_payment!(store, attrs \\ %{}) do
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
  end
end
