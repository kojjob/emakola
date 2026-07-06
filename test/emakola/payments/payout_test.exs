defmodule Emakola.Payments.PayoutTest do
  @moduledoc """
  Payout ledger — one row per merchant disbursement and its lifecycle
  (:pending → :processing → :paid | :failed). Money in minor units; the
  transfer_reference is our gateway idempotency key.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Payments

  defp pending_payout!(store, attrs \\ %{}) do
    Payments.create_payout!(
      Map.merge(
        %{
          store_id: store.id,
          amount: 80_000,
          currency: "GHS",
          transfer_reference: "PO-#{store.id}"
        },
        attrs
      ),
      authorize?: false
    )
  end

  test "create/1 builds a pending payout" do
    store = Factory.create_store!()
    payout = pending_payout!(store, %{amount: 50_000, transfer_reference: "PO-abc"})

    assert payout.status == :pending
    assert payout.amount == 50_000
    assert payout.currency == "GHS"
    assert payout.transfer_reference == "PO-abc"
    assert payout.store_id == store.id
  end

  test "mark_processing/3 records the gateway codes and moves to :processing" do
    store = Factory.create_store!()
    payout = pending_payout!(store)

    {:ok, processing} =
      Payments.mark_payout_processing(
        payout,
        %{recipient_code: "RCP_x", transfer_code: "TRF_x"},
        authorize?: false
      )

    assert processing.status == :processing
    assert processing.recipient_code == "RCP_x"
    assert processing.transfer_code == "TRF_x"
  end

  test "mark_paid/2 moves to :paid" do
    store = Factory.create_store!()
    payout = pending_payout!(store)

    {:ok, paid} =
      Payments.mark_payout_paid(payout, %{gateway_response: %{"status" => "success"}},
        authorize?: false
      )

    assert paid.status == :paid
  end

  test "mark_failed/2 records the reason and moves to :failed" do
    store = Factory.create_store!()
    payout = pending_payout!(store)

    {:ok, failed} =
      Payments.mark_payout_failed(payout, %{failure_reason: "insufficient balance"},
        authorize?: false
      )

    assert failed.status == :failed
    assert failed.failure_reason == "insufficient balance"
  end

  test "list_recent returns payouts newest-first with the store loaded" do
    store = Factory.create_store!(%{name: "Recent Co"})
    pending_payout!(store, %{transfer_reference: "po_recent"})

    payouts = Payments.list_recent_payouts!(load: [:store], authorize?: false)
    assert [%{transfer_reference: "po_recent"} = payout | _] = payouts
    assert payout.store.name == "Recent Co"
  end

  test "by_store lists a store's payouts; by_transfer_reference finds one" do
    store = Factory.create_store!()
    pending_payout!(store, %{transfer_reference: "PO-find-me"})

    assert [_one] = Payments.list_payouts_by_store!(store.id, authorize?: false)

    assert {:ok, found} =
             Payments.get_payout_by_transfer_reference("PO-find-me", authorize?: false)

    assert found.transfer_reference == "PO-find-me"
  end
end
