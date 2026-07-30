defmodule Emakola.Payments.ProtectionOtpReleaseTest do
  @moduledoc """
  Verifying a delivery OTP (`FulfillmentDeliveryProof.:verify`) is the
  strongest signal that an order was actually delivered — it must release
  the order's buyer-protection hold (TC-2), same as a buyer's own tracking
  page confirmation or the auto-release timer.

  The release itself never runs synchronously inside `:verify` — the hook
  only enqueues `ProtectionReleaseWorker` (see that module's moduledoc for
  why: a synchronous release nested inside a caller's own transaction, e.g.
  `Suppliers.InboundFulfillment.verify_delivery/4`, can poison the shared
  connection on failure). These tests drive the hook directly and perform
  the enqueued job explicitly, mirroring how it actually runs in
  production. Multi-fulfillment orders (dropship splits) only release once
  EVERY fulfillment has confirmed — v1 orders carry a single fulfillment,
  but the worker has to get the "all of them" case right too, re-checked at
  run time on every perform.
  """
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Factory
  alias Emakola.Payments
  alias Emakola.Payments.ProtectionHolds
  alias Emakola.Payments.Workers.ProtectionReleaseWorker, as: Worker

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

  defp release_args(order, store) do
    %{"order_id" => order.id, "store_id" => store.id, "reason" => "delivery_otp"}
  end

  test "verifying the OTP on a protected single-fulfillment order enqueues the release, which pays out net" do
    store = Factory.create_store!()
    {order, payment, _hold} = protected_order!(store, %{amount: 25_000})
    fulfillment = shipped_fulfillment!(order, store)
    {:ok, proof} = issue_proof!(fulfillment)

    verified = verify!(proof)
    assert %DateTime{} = verified.verified_at

    args = release_args(order, store)
    assert_enqueued(worker: Worker, args: args)
    assert :ok = perform_job(Worker, args)

    {:ok, released_hold} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert released_hold.status == :released
    assert released_hold.release_reason == :delivery_otp

    reloaded_payment = Ash.get!(Payments.Payment, payment.id, authorize?: false)
    assert reloaded_payment.payout_held == false
    assert reloaded_payment.payable_amount == released_hold.net
    assert %DateTime{} = reloaded_payment.payout_released_at
  end

  test "verifying the OTP on an unprotected order's fulfillment is a no-op — nothing is even enqueued" do
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

    refute_enqueued(worker: Worker)

    reloaded_payment = Ash.get!(Payments.Payment, payment.id, authorize?: false)
    assert reloaded_payment.payout_held == false
    assert is_nil(reloaded_payment.payable_amount)
  end

  test "a FROZEN hold is enqueued (the cheap check can't see the freeze) but the worker leaves it held — a complaint outranks physical delivery" do
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

    args = release_args(order, store)
    assert_enqueued(worker: Worker, args: args)
    assert :ok = perform_job(Worker, args)

    {:ok, still_held} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert still_held.status == :held
    assert %DateTime{} = still_held.frozen_at

    reloaded_payment = Ash.get!(Payments.Payment, payment.id, authorize?: false)
    assert reloaded_payment.payout_held == true
  end

  test "a multi-fulfillment order only releases once EVERY fulfillment has confirmed — re-checked when the job runs" do
    store = Factory.create_store!()
    {order, payment, _hold} = protected_order!(store, %{amount: 40_000})

    fulfillment_a = shipped_fulfillment!(order, store)
    fulfillment_b = shipped_fulfillment!(order, store)

    {:ok, proof_a} = issue_proof!(fulfillment_a)
    verify!(proof_a)

    args = release_args(order, store)
    assert_enqueued(worker: Worker, args: args)
    assert :ok = perform_job(Worker, args)

    {:ok, still_held} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert still_held.status == :held

    reloaded_payment = Ash.get!(Payments.Payment, payment.id, authorize?: false)
    assert reloaded_payment.payout_held == true

    {:ok, proof_b} = issue_proof!(fulfillment_b)
    verify!(proof_b)

    assert :ok = perform_job(Worker, args)

    {:ok, released_hold} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert released_hold.status == :released
    assert released_hold.release_reason == :delivery_otp
  end

  test "verifying twice only ever releases once — the second verify enqueues nothing new, and performing the job again is a safe no-op" do
    store = Factory.create_store!()
    {order, payment, _hold} = protected_order!(store, %{amount: 25_000})
    fulfillment = shipped_fulfillment!(order, store)
    {:ok, proof} = issue_proof!(fulfillment)

    verify!(proof)
    args = release_args(order, store)
    assert :ok = perform_job(Worker, args)

    {:ok, released_once} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert released_once.status == :released
    payment_after_first = Ash.get!(Payments.Payment, payment.id, authorize?: false)

    # Verifying again is structurally allowed (the resource doesn't guard
    # against a second verify) and must not raise — the hold is already
    # :released, not :held, so the cheap existence check finds nothing and
    # doesn't even enqueue a second job. (`perform_job/2`'s ephemeral
    # execution never marks the first job's real DB row complete, so we
    # compare counts rather than `refute_enqueued` — that leftover row
    # would always be found regardless of whether a new one was added.)
    jobs_before = all_enqueued(worker: Worker, args: args)

    verified_again = verify!(proof)
    assert %DateTime{} = verified_again.verified_at

    jobs_after = all_enqueued(worker: Worker, args: args)
    assert length(jobs_after) == length(jobs_before)

    # Directly re-performing the same job args (an Oban retry, or a second
    # fulfillment's verify racing before the first perform completes) must
    # be a pure no-op — ProtectionRelease's FOR-UPDATE fresh read catches
    # the already-released hold rather than re-releasing it.
    assert :ok = perform_job(Worker, args)

    {:ok, released_twice} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert released_twice.status == :released
    assert released_twice.released_at == released_once.released_at
    assert released_twice.release_reason == released_once.release_reason

    payment_after_second = Ash.get!(Payments.Payment, payment.id, authorize?: false)
    assert payment_after_second.payable_amount == payment_after_first.payable_amount
    assert payment_after_second.payout_released_at == payment_after_first.payout_released_at
  end
end
