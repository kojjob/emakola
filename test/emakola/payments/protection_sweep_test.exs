defmodule Emakola.Payments.ProtectionSweepTest do
  @moduledoc """
  TC-2 auto-release timer (Task 9). Once every fulfillment on a protected
  order has delivered, `Fulfillment.:mark_delivered`'s after_action hook
  stamps the order's `:held` hold with `release_after` (5 days out) — but
  only if the hold is unfrozen and hasn't already been stamped. The hourly
  `ProtectionSweepWorker` cron sweep then releases any hold whose timer has
  elapsed, unless a complaint has frozen it in the meantime.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Payments
  alias Emakola.Payments.ProtectionHolds
  alias Emakola.Payments.Workers.ProtectionSweepWorker

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

  defp reload_hold(payment, store) do
    {:ok, hold} =
      Payments.get_protection_hold_by_payment(payment.id, tenant: store.id, authorize?: false)

    hold
  end

  defp deliver!(order, store) do
    fulfillment = Factory.create_fulfillment!(order, store, %{status: :shipped})
    Emakola.Orders.mark_fulfillment_delivered!(fulfillment, authorize?: false)
  end

  describe "stamping release_after on delivery" do
    test "delivering a protected order's only fulfillment stamps release_after ~5 days out" do
      store = Factory.create_store!()
      {order, payment, _hold} = protected_order!(store, %{amount: 25_000})

      deliver!(order, store)

      hold = reload_hold(payment, store)
      expected = DateTime.add(DateTime.utc_now(), 5, :day)
      assert %DateTime{} = hold.release_after
      assert_in_delta DateTime.diff(hold.release_after, expected, :second), 0, 5
      assert hold.status == :held
    end

    test "a multi-fulfillment order only stamps once EVERY fulfillment has delivered" do
      store = Factory.create_store!()
      {order, payment, _hold} = protected_order!(store, %{amount: 40_000})

      fulfillment_a = Factory.create_fulfillment!(order, store, %{status: :shipped})
      fulfillment_b = Factory.create_fulfillment!(order, store, %{status: :shipped})

      Emakola.Orders.mark_fulfillment_delivered!(fulfillment_a, authorize?: false)
      assert reload_hold(payment, store).release_after == nil

      Emakola.Orders.mark_fulfillment_delivered!(fulfillment_b, authorize?: false)
      assert %DateTime{} = reload_hold(payment, store).release_after
    end

    test "a second stamp attempt on an already-stamped hold does not push release_after later" do
      store = Factory.create_store!()
      {order, payment, _hold} = protected_order!(store, %{amount: 25_000})

      :ok = ProtectionHolds.stamp_release_after_for_order(order.id, store.id)
      first = reload_hold(payment, store).release_after
      assert %DateTime{} = first

      :ok = ProtectionHolds.stamp_release_after_for_order(order.id, store.id)
      second = reload_hold(payment, store).release_after

      assert DateTime.compare(first, second) == :eq
    end

    test "a FROZEN hold is not stamped even though its fulfillment delivered" do
      store = Factory.create_store!()
      {order, payment, hold} = protected_order!(store, %{amount: 25_000})

      {:ok, _frozen} =
        Payments.freeze_protection_hold(
          hold,
          %{complaint_reason: :not_received, complaint_text: "Never arrived"},
          authorize?: false
        )

      deliver!(order, store)

      assert reload_hold(payment, store).release_after == nil
    end

    test "delivering an unprotected order's fulfillment is a no-op — no hold, no crash" do
      store = Factory.create_store!()
      order = Factory.create_order!(store, %{total: 25_000})
      fulfillment = Factory.create_fulfillment!(order, store, %{status: :shipped})

      assert %{status: :delivered} =
               Emakola.Orders.mark_fulfillment_delivered!(fulfillment, authorize?: false)
    end
  end

  describe "hourly sweep" do
    defp due_hold!(store, opts) do
      {order, payment, hold} = protected_order!(store, Map.new(opts))

      release_after =
        Keyword.get(opts, :release_after, DateTime.add(DateTime.utc_now(), -1, :hour))

      stamped =
        hold
        |> Ash.Changeset.for_update(:set_release_after, %{release_after: release_after})
        |> Ash.update!(authorize?: false)

      if Keyword.get(opts, :frozen, false) do
        {:ok, stamped} =
          Payments.freeze_protection_hold(
            stamped,
            %{complaint_reason: :other, complaint_text: "test"},
            authorize?: false
          )

        {order, payment, stamped}
      else
        {order, payment, stamped}
      end
    end

    test "releases a due, unfrozen hold with reason :auto_timer and pays out net" do
      store = Factory.create_store!()
      {_order, payment, _hold} = due_hold!(store, amount: 25_000)

      assert :ok = ProtectionSweepWorker.perform(%Oban.Job{})

      released = reload_hold(payment, store)
      assert released.status == :released
      assert released.release_reason == :auto_timer

      reloaded_payment = Ash.get!(Payments.Payment, payment.id, authorize?: false)
      assert reloaded_payment.payout_held == false
      assert reloaded_payment.payable_amount == released.net
    end

    test "skips a frozen hold even though it is due" do
      store = Factory.create_store!()
      {_order, payment, _hold} = due_hold!(store, amount: 25_000, frozen: true)

      assert :ok = ProtectionSweepWorker.perform(%Oban.Job{})

      still_held = reload_hold(payment, store)
      assert still_held.status == :held
      assert %DateTime{} = still_held.frozen_at
    end

    test "skips a hold that is not yet due" do
      store = Factory.create_store!()
      future = DateTime.add(DateTime.utc_now(), 1, :hour)
      {_order, payment, _hold} = due_hold!(store, amount: 25_000, release_after: future)

      assert :ok = ProtectionSweepWorker.perform(%Oban.Job{})

      assert reload_hold(payment, store).status == :held
    end

    test "a second sweep run releases nothing new" do
      store = Factory.create_store!()
      {_order, payment, _hold} = due_hold!(store, amount: 25_000)

      assert :ok = ProtectionSweepWorker.perform(%Oban.Job{})
      released_once = reload_hold(payment, store)

      assert :ok = ProtectionSweepWorker.perform(%Oban.Job{})
      released_twice = reload_hold(payment, store)

      assert released_twice.released_at == released_once.released_at
      assert released_twice.release_reason == released_once.release_reason
    end

    test "reaches due holds across multiple stores in one sweep" do
      store_a = Factory.create_store!()
      store_b = Factory.create_store!()
      {_order_a, payment_a, _hold_a} = due_hold!(store_a, amount: 10_000)
      {_order_b, payment_b, _hold_b} = due_hold!(store_b, amount: 15_000)

      assert :ok = ProtectionSweepWorker.perform(%Oban.Job{})

      assert reload_hold(payment_a, store_a).status == :released
      assert reload_hold(payment_b, store_b).status == :released
    end
  end
end
