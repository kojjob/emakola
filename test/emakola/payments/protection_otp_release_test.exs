defmodule Emakola.Payments.ProtectionOtpReleaseTest do
  @moduledoc """
  Verifying a delivery OTP (`FulfillmentDeliveryProof.:verify`) is the
  strongest signal that an order was actually delivered — it must release
  the order's buyer-protection hold (TC-2), same as a buyer's own tracking
  page confirmation or the auto-release timer.

  The release is wired as an `after_transaction` hook so a release failure
  never fails the verify — the buyer is standing in front of a courier
  waiting on it. Multi-fulfillment orders (dropship splits) only release
  once EVERY fulfillment has confirmed — v1 orders carry a single
  fulfillment, but the hook has to get the "all of them" case right too.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Payments
  alias Emakola.Payments.ProtectionHolds

  defp protected_order!(store, attrs) do
    amount = Map.get(attrs, :amount, 25_000)
    order = Factory.create_order!(store, %{total: amount})

    payment =
      store
      |> Factory.create_payment!(%{
        order_id: order.id,
        amount: amount,
        payout_held: true,
        payout_hold_reason: "buyer_protection"
      })
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)

    :ok = ProtectionHolds.ensure_hold(payment)

    {:ok, hold} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    {order, payment, hold}
  end

  defp shipped_fulfillment!(order, store) do
    Factory.create_fulfillment!(order, store, %{status: :shipped})
  end

  defp issue_proof!(fulfillment) do
    %{
      fulfillment_id: fulfillment.id,
      code_hash: "test-hash",
      expires_at: DateTime.add(DateTime.utc_now(), 600, :second),
      sent_to: "•••1234"
    }
    |> Emakola.Orders.issue_fulfillment_delivery_proof(authorize?: false)
  end

  defp verify!(proof) do
    proof
    |> Ash.Changeset.for_update(:verify, %{})
    |> Ash.update!(authorize?: false)
  end

  test "verifying the OTP on a protected single-fulfillment order releases the hold and pays out net" do
    store = Factory.create_store!()
    {order, payment, _hold} = protected_order!(store, %{amount: 25_000})
    fulfillment = shipped_fulfillment!(order, store)
    {:ok, proof} = issue_proof!(fulfillment)

    verified = verify!(proof)
    assert %DateTime{} = verified.verified_at

    {:ok, released_hold} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert released_hold.status == :released
    assert released_hold.release_reason == :delivery_otp

    reloaded_payment = Ash.get!(Payments.Payment, payment.id, authorize?: false)
    assert reloaded_payment.payout_held == false
    assert reloaded_payment.payable_amount == released_hold.net
    assert %DateTime{} = reloaded_payment.payout_released_at
  end

  test "verifying the OTP on an unprotected order's fulfillment is a no-op" do
    store = Factory.create_store!()
    order = Factory.create_order!(store, %{total: 25_000})

    payment =
      store
      |> Factory.create_payment!(%{order_id: order.id, amount: 25_000})
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)

    fulfillment = shipped_fulfillment!(order, store)
    {:ok, proof} = issue_proof!(fulfillment)

    verified = verify!(proof)
    assert %DateTime{} = verified.verified_at

    reloaded_payment = Ash.get!(Payments.Payment, payment.id, authorize?: false)
    assert reloaded_payment.payout_held == false
    assert is_nil(reloaded_payment.payable_amount)
  end

  test "a FROZEN hold is not released by OTP verification — a complaint outranks physical delivery" do
    store = Factory.create_store!()
    {order, payment, hold} = protected_order!(store, %{amount: 25_000})

    {:ok, frozen_hold} =
      Payments.freeze_protection_hold(
        hold,
        %{complaint_reason: :not_as_described, complaint_text: "Wrong color entirely."},
        authorize?: false
      )

    assert %DateTime{} = frozen_hold.frozen_at

    fulfillment = shipped_fulfillment!(order, store)
    {:ok, proof} = issue_proof!(fulfillment)
    verify!(proof)

    {:ok, still_held} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert still_held.status == :held
    assert %DateTime{} = still_held.frozen_at

    reloaded_payment = Ash.get!(Payments.Payment, payment.id, authorize?: false)
    assert reloaded_payment.payout_held == true
  end

  test "a multi-fulfillment order only releases once EVERY fulfillment has confirmed" do
    store = Factory.create_store!()
    {order, payment, _hold} = protected_order!(store, %{amount: 40_000})

    fulfillment_a = shipped_fulfillment!(order, store)
    fulfillment_b = shipped_fulfillment!(order, store)

    {:ok, proof_a} = issue_proof!(fulfillment_a)
    verify!(proof_a)

    {:ok, still_held} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert still_held.status == :held

    reloaded_payment = Ash.get!(Payments.Payment, payment.id, authorize?: false)
    assert reloaded_payment.payout_held == true

    {:ok, proof_b} = issue_proof!(fulfillment_b)
    verify!(proof_b)

    {:ok, released_hold} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert released_hold.status == :released
    assert released_hold.release_reason == :delivery_otp
  end
end
