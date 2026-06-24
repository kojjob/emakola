defmodule Emakola.Platform.FinanceStatsTest do
  @moduledoc """
  Platform revenue aggregates: fees collected (PaymentSplit role :platform) and
  outstanding merchant payouts (successful un-split orders the platform still
  holds), plus the per-store breakdown.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Platform.FinanceStats

  defp success_payment!(store, attrs) do
    store
    |> Factory.create_payment!(attrs)
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)
  end

  defp platform_fee_split!(payment, amount) do
    Emakola.Payments.create_payment_split!(
      %{store_id: payment.store_id, payment_id: payment.id, role: :platform, amount: amount},
      authorize?: false
    )
  end

  defp verified_payout!(store, code) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{store_id: store.id})
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: code})
    |> Ash.update!(authorize?: false)
  end

  describe "total_platform_fees/0" do
    test "sums platform-role splits" do
      store = Factory.create_store!()
      payment = success_payment!(store, %{amount: 10_000, split_mode: :dropship_split})
      platform_fee_split!(payment, 200)

      assert FinanceStats.total_platform_fees() == 200
    end

    test "is zero with no splits" do
      assert FinanceStats.total_platform_fees() == 0
    end
  end

  describe "total_outstanding_payouts/0" do
    test "sums successful un-split (split_mode :none) payments" do
      store = Factory.create_store!()
      success_payment!(store, %{amount: 50_000})

      assert FinanceStats.total_outstanding_payouts() == 50_000
    end

    test "excludes split payments — the merchant was paid directly" do
      store = Factory.create_store!()
      success_payment!(store, %{amount: 50_000, split_mode: :dropship_split})

      assert FinanceStats.total_outstanding_payouts() == 0
    end

    test "excludes non-success payments" do
      store = Factory.create_store!()
      Factory.create_payment!(store, %{amount: 50_000})

      assert FinanceStats.total_outstanding_payouts() == 0
    end
  end

  describe "per_store_finance/0" do
    test "carries fees, outstanding and payout readiness; sorted by outstanding desc" do
      owed_store = Factory.create_store!(%{name: "Owed Co"})
      success_payment!(owed_store, %{amount: 80_000})

      fee_store = Factory.create_store!(%{name: "Fee Co"})
      verified_payout!(fee_store, "ACCT_fee")
      payment = success_payment!(fee_store, %{amount: 10_000, split_mode: :dropship_split})
      platform_fee_split!(payment, 200)

      rows = FinanceStats.per_store_finance()
      by_id = Map.new(rows, &{&1.store.id, &1})

      assert by_id[owed_store.id].outstanding_owed == 80_000
      assert by_id[owed_store.id].fees_collected == 0
      assert by_id[owed_store.id].payouts_ready? == false

      assert by_id[fee_store.id].fees_collected == 200
      assert by_id[fee_store.id].outstanding_owed == 0
      assert by_id[fee_store.id].payouts_ready? == true

      ids = Enum.map(rows, & &1.store.id)

      assert Enum.find_index(ids, &(&1 == owed_store.id)) <
               Enum.find_index(ids, &(&1 == fee_store.id))
    end

    test "omits stores with no finance activity" do
      Factory.create_store!(%{name: "Quiet Co"})

      assert FinanceStats.per_store_finance() == []
    end
  end
end
