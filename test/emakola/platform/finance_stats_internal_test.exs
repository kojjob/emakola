defmodule Emakola.Platform.FinanceStatsInternalTest do
  @moduledoc """
  Internal (allocation-basis) balances join the money truth: a payable
  `PaymentSplit` contributes its frozen-formula net to `total_outstanding_payouts/0`
  and to the RECIPIENT store's row in `per_store_finance/0` — even when the
  split's tenant `store_id` is a different store (a dropship seller settling a
  wholesaler). `payouts_ready?` switches to a live MoMo-destination check.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Platform.FinanceStats
  alias Emakola.Payments.PaymentSplit

  defp internal_split!(store, payment, attrs) do
    %{
      store_id: store.id,
      payment_id: payment.id,
      role: :wholesaler,
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

  test "a settled internal split's payable net joins the RECIPIENT store's row, not the tenant's" do
    seller = Factory.create_store!()
    wholesaler = Factory.create_store!()
    payment = Factory.create_payment!(seller)

    seller
    |> internal_split!(payment, %{recipient_store_id: wholesaler.id, amount: 10_000})
    |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 4_000})
    |> Ash.update!(authorize?: false)
    |> Ash.Changeset.for_update(:update_recovery_tracking, %{recovered_amount: 1_000})
    |> Ash.update!(authorize?: false)

    # payable_net = amount - (reversed - recovered - reserved) = 10_000 - (4_000 - 1_000 - 0) = 7_000
    assert FinanceStats.total_outstanding_payouts() == 7_000

    rows = FinanceStats.per_store_finance()
    by_id = Map.new(rows, &{&1.store.id, &1})

    assert by_id[wholesaler.id].outstanding_owed == 7_000
    refute Map.has_key?(by_id, seller.id)
  end

  test "reserved_recovery_amount also nets out of the payable amount, same as recovered" do
    seller = Factory.create_store!()
    payment = Factory.create_payment!(seller)

    seller
    |> internal_split!(payment, %{amount: 10_000})
    |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 4_000})
    |> Ash.update!(authorize?: false)
    |> Ash.Changeset.for_update(:update_recovery_tracking, %{
      recovered_amount: 1_000,
      reserved_recovery_amount: 500
    })
    |> Ash.update!(authorize?: false)

    # payable_net = amount - (reversed - recovered - reserved) = 10_000 - (4_000 - 1_000 - 500) = 7_500
    assert FinanceStats.total_outstanding_payouts() == 7_500
  end

  test "a claimed internal split (already paid out) contributes nothing" do
    store = Factory.create_store!()
    payment = Factory.create_payment!(store)

    store
    |> internal_split!(payment, %{amount: 10_000})
    |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ecto.UUID.generate()})
    |> Ash.update!(authorize?: false)

    assert FinanceStats.total_outstanding_payouts() == 0
    assert FinanceStats.per_store_finance() == []
  end

  test "payouts_ready? is true for a MoMo-destination store, even without a verified subaccount" do
    store = Factory.create_store!()
    momo_destination!(store)
    payment = Factory.create_payment!(store)

    internal_split!(store, payment, %{amount: 5_000})

    row = Enum.find(FinanceStats.per_store_finance(), &(&1.store.id == store.id))
    assert row.payouts_ready? == true
  end

  test "per_store_finance/0 keeps the legacy and internal (ledger) amounts separate, not just summed" do
    store = Factory.create_store!()

    store
    |> Factory.create_payment!(%{amount: 80_000})
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)

    payment = Factory.create_payment!(store, %{amount: 20_000})
    internal_split!(store, payment, %{amount: 15_000})

    row = Enum.find(FinanceStats.per_store_finance(), &(&1.store.id == store.id))

    assert row.legacy_owed == 80_000
    assert row.internal_owed == 15_000
    assert row.outstanding_owed == 95_000
  end
end
