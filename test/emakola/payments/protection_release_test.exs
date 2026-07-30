defmodule Emakola.Payments.ProtectionReleaseTest do
  @moduledoc """
  `ProtectionRelease.release/2` releases a buyer-protection hold in one
  transaction: the hold transitions to `:released`, and the payment gets
  `payable_amount: hold.net` plus the existing `:release_payout_hold` action
  (clearing `payout_held` so it re-enters `PayoutService`'s backlog).

  `net` is snapshotted at hold-creation time (`ProtectionHolds.ensure_hold/1`),
  so release must pay exactly that snapshot regardless of the platform fee
  rate at release time — see the fee-rate immunity test below.
  """
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Factory
  alias Emakola.Payments
  alias Emakola.Payments.{Payment, ProtectionHolds, ProtectionRelease}
  alias Emakola.Notifications.Workers.OrderNotificationWorker

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

  test "release transitions the hold, snapshots payable_amount == hold.net, and clears the payout hold" do
    store = Factory.create_store!()
    {payment, hold} = protected_payment!(store, %{amount: 25_000})

    assert :ok = ProtectionRelease.release(hold, :buyer_confirmed)

    {:ok, released_hold} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert released_hold.status == :released
    assert released_hold.release_reason == :buyer_confirmed
    assert %DateTime{} = released_hold.released_at

    reloaded = Ash.get!(Payment, payment.id, authorize?: false)
    assert reloaded.payable_amount == hold.net
    assert reloaded.payout_held == false
    assert %DateTime{} = reloaded.payout_released_at
  end

  test "releasing an already-released hold returns :ok without touching the payment again" do
    store = Factory.create_store!()
    {payment, hold} = protected_payment!(store, %{amount: 25_000})

    assert :ok = ProtectionRelease.release(hold, :buyer_confirmed)
    after_first = Ash.get!(Payment, payment.id, authorize?: false)

    {:ok, released_hold} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    # Second release call, with a different reason — must be a pure no-op:
    # neither the hold's release_reason nor the payment change.
    assert :ok = ProtectionRelease.release(released_hold, :staff)

    after_second = Ash.get!(Payment, payment.id, authorize?: false)
    assert after_second.payout_released_at == after_first.payout_released_at
    assert after_second.payable_amount == after_first.payable_amount

    {:ok, hold_after_second} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert hold_after_second.release_reason == :buyer_confirmed
  end

  test "a stale (pre-release) hold struct reused for a second release call is caught by the fresh FOR UPDATE read, not the struct's own status" do
    store = Factory.create_store!()
    {payment, hold} = protected_payment!(store, %{amount: 25_000})

    # `hold` is the ORIGINAL struct — its in-memory `status` is still :held.
    # This simulates two concurrent release triggers (e.g. the auto-release
    # timer firing alongside a buyer confirming delivery) racing on the same
    # hold, both starting from the same stale read.
    assert :ok = ProtectionRelease.release(hold, :buyer_confirmed)
    after_first = Ash.get!(Payment, payment.id, authorize?: false)

    {:ok, hold_after_first} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    # Reuse the SAME stale `hold` (status: :held in memory) for the "losing"
    # concurrent call — a struct-only idempotency check would sail past its
    # own `%{status: :released}` guard clause and re-run the release,
    # clobbering release_reason/released_at/payout_released_at with :staff's
    # values. The FOR UPDATE-locked fresh read must catch this instead.
    assert :ok = ProtectionRelease.release(hold, :staff)

    after_second = Ash.get!(Payment, payment.id, authorize?: false)
    assert after_second.payout_released_at == after_first.payout_released_at
    assert after_second.payable_amount == after_first.payable_amount

    {:ok, hold_after_second} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    assert hold_after_second.release_reason == :buyer_confirmed
    assert hold_after_second.released_at == hold_after_first.released_at
  end

  # A deterministic, non-flaky guard (mirrors PayLinkClaimTest) against
  # someone dropping `lock: "FOR UPDATE"` from the release query — a genuine
  # two-connection race test isn't feasible in the ExUnit sandbox.
  test "the release query holds a FOR UPDATE lock on the protection_holds row" do
    {sql, _params} =
      Ecto.Adapters.SQL.to_sql(
        :all,
        Emakola.Repo,
        ProtectionRelease.locked_row_query(Ash.UUID.generate())
      )

    assert sql =~ "FOR UPDATE"
  end

  test "fee-rate immunity: release pays the hold's snapshotted net, not a recomputed one" do
    original_rate = Application.get_env(:emakola, :platform_fee_rate_bps)

    on_exit(fn ->
      case original_rate do
        nil -> Application.delete_env(:emakola, :platform_fee_rate_bps)
        rate -> Application.put_env(:emakola, :platform_fee_rate_bps, rate)
      end
    end)

    Application.put_env(:emakola, :platform_fee_rate_bps, 200)

    store = Factory.create_store!()
    {payment, hold} = protected_payment!(store, %{amount: 25_000})

    # Snapshotted at 2%: fee=500, net=24_500.
    assert hold.fee == 500
    assert hold.net == 24_500

    # Configured fee rate changes AFTER the hold snapshot — release must not
    # recompute against it.
    Application.put_env(:emakola, :platform_fee_rate_bps, 5_000)

    assert :ok = ProtectionRelease.release(hold, :auto_timer)

    reloaded = Ash.get!(Payment, payment.id, authorize?: false)
    assert reloaded.payable_amount == hold.net
    assert reloaded.payable_amount == 24_500
    refute reloaded.payable_amount == payment.amount - div(payment.amount * 5_000, 10_000)
  end

  # ── Task 10: :protection_released dispatch ─────────────────────

  describe ":protection_released dispatch" do
    test "dispatches :protection_released to the merchant after an actual release" do
      store = Factory.create_store!()
      {_payment, hold} = protected_payment!(store, %{amount: 25_000})

      assert :ok = ProtectionRelease.release(hold, :buyer_confirmed)

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: hold.order_id, event: "protection_released"},
        queue: :notifications
      )
    end

    test "does not dispatch again when releasing an already-released hold (no-op)" do
      store = Factory.create_store!()
      {_payment, hold} = protected_payment!(store, %{amount: 25_000})

      assert :ok = ProtectionRelease.release(hold, :buyer_confirmed)
      assert :ok = ProtectionRelease.release(hold, :staff)

      jobs =
        all_enqueued(
          worker: OrderNotificationWorker,
          args: %{order_id: hold.order_id, event: "protection_released"}
        )

      assert length(jobs) == 1
    end

    test "does not dispatch when a frozen hold is skipped (respect_freeze default)" do
      store = Factory.create_store!()
      {_payment, hold} = protected_payment!(store, %{amount: 25_000})

      {:ok, frozen} =
        Payments.freeze_protection_hold(
          hold,
          %{complaint_reason: :other, complaint_text: "test"},
          authorize?: false
        )

      assert :ok = ProtectionRelease.release(frozen, :auto_timer)

      refute_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: hold.order_id, event: "protection_released"}
      )
    end
  end
end
