defmodule Emakola.Payments.InternalPayoutServiceTest do
  @moduledoc """
  Allocation-basis payouts: claim payable internal splits under FOR UPDATE and
  pay the Σ of frozen paid_amounts (CONTRACT 1: never amount − reversed).
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

  test "claims payable splits, pays Σ frozen paid_amount, stamps payout_id" do
    store = create_store!()
    momo_destination!(store)
    payment = create_payment!(store)

    plain = settled_internal_split!(store, payment, %{amount: 10_000})

    partially =
      settled_internal_split!(store, payment, %{role: :dropshipper, amount: 8_000})
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 3_000})
      |> Ash.update!(authorize?: false)

    {:ok, payout} = PayoutService.prepare_internal_payout(store.id)

    # CONTRACT 1: 10_000 + (8_000 − 3_000) — frozen paid_amounts, not raw sums.
    assert payout.amount == 15_000
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
end
