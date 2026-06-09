defmodule Emakola.Notifications.DispatcherTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Factory
  alias Emakola.Notifications.Dispatcher
  alias Emakola.Notifications.Workers.OrderNotificationWorker
  alias Emakola.Notifications.Workers.SupplierNotificationWorker

  # ── Helpers ────────────────────────────────────────────────────

  defp fake_order do
    %{id: Ash.UUID.generate(), store_id: Ash.UUID.generate()}
  end

  # ── Valid events ───────────────────────────────────────────────

  describe "dispatch/2 with valid events" do
    test "enqueues Oban job for order_placed" do
      order = fake_order()
      assert {:ok, %Oban.Job{}} = Dispatcher.dispatch(order, :order_placed)

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: order.id, event: "order_placed"},
        queue: :notifications
      )
    end

    test "enqueues Oban job for order_confirmed" do
      order = fake_order()
      assert {:ok, %Oban.Job{}} = Dispatcher.dispatch(order, :order_confirmed)

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: order.id, event: "order_confirmed"},
        queue: :notifications
      )
    end

    test "enqueues Oban job for order_shipped" do
      order = fake_order()
      assert {:ok, %Oban.Job{}} = Dispatcher.dispatch(order, :order_shipped)

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: order.id, event: "order_shipped"},
        queue: :notifications
      )
    end

    test "enqueues Oban job for order_delivered" do
      order = fake_order()
      assert {:ok, %Oban.Job{}} = Dispatcher.dispatch(order, :order_delivered)

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: order.id, event: "order_delivered"},
        queue: :notifications
      )
    end

    test "enqueues Oban job for order_cancelled" do
      order = fake_order()
      assert {:ok, %Oban.Job{}} = Dispatcher.dispatch(order, :order_cancelled)

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: order.id, event: "order_cancelled"},
        queue: :notifications
      )
    end
  end

  # ── PubSub broadcast ──────────────────────────────────────────

  describe "dispatch/2 PubSub broadcast" do
    test "broadcasts order event to store topic" do
      order = fake_order()
      Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{order.store_id}:orders")

      Dispatcher.dispatch(order, :order_placed)

      assert_receive {:order_event, :order_placed, ^order}
    end

    test "broadcasts different event types" do
      order = fake_order()
      Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{order.store_id}:orders")

      Dispatcher.dispatch(order, :order_shipped)

      assert_receive {:order_event, :order_shipped, ^order}
    end
  end

  # ── Invalid events ─────────────────────────────────────────────

  describe "dispatch/2 with unknown events" do
    test "returns error for unrecognized event" do
      order = fake_order()
      assert {:error, :unknown_event} = Dispatcher.dispatch(order, :order_refunded)
    end

    test "returns error for string event" do
      order = fake_order()
      assert {:error, :unknown_event} = Dispatcher.dispatch(order, "order_placed")
    end

    test "returns error for nil event" do
      order = fake_order()
      assert {:error, :unknown_event} = Dispatcher.dispatch(order, nil)
    end
  end

  # ── C2 regression: dispatch/2 must never raise ────────────────────
  # Dispatcher runs inside Ash after_action hooks. If it raised, a
  # successful order status transition would be rolled back by a
  # notification subsystem failure. These tests pin the no-raise contract.

  describe "dispatch/2 does not raise" do
    test "malformed order (no :id) returns {:error, :missing_order_id}" do
      order_without_id = %{store_id: Ash.UUID.generate()}

      assert {:error, :missing_order_id} = Dispatcher.dispatch(order_without_id, :order_placed)
    end

    test "order with nil :id returns {:error, :missing_order_id}" do
      order = %{id: nil, store_id: Ash.UUID.generate()}

      assert {:error, :missing_order_id} = Dispatcher.dispatch(order, :order_placed)
    end

    test "order without store_id still enqueues job (broadcast skipped)" do
      order = %{id: Ash.UUID.generate()}

      assert {:ok, %Oban.Job{}} = Dispatcher.dispatch(order, :order_placed)
    end

    test "nil order with valid event returns {:error, :dispatch_raised} (no crash)" do
      # nil is pattern-matched into do_dispatch/2 which fails the :id guard,
      # so this should land in the :missing_order_id branch via rescue.
      result = Dispatcher.dispatch(nil, :order_placed)

      assert match?({:error, _}, result),
             "expected dispatch(nil, valid_event) to return {:error, _}, got: #{inspect(result)}"
    end
  end

  # ── Supplier fulfillment dispatch ──────────────────────────────

  describe "dispatch_supplier_fulfillments/1" do
    test "enqueues one job per pending supplier fulfillment, none for merchant group" do
      {_merchant, store} = Factory.create_merchant_with_store!()
      order = Factory.create_order!(store, %{total: 10_000, currency: "GHS"})

      supplier_a = Factory.create_supplier!(store, %{whatsapp_number: "+233200000001"})
      supplier_b = Factory.create_supplier!(store, %{contact_phone: "+233200000002"})

      f_a = Factory.create_fulfillment!(order, store, %{supplier_id: supplier_a.id})
      f_b = Factory.create_fulfillment!(order, store, %{supplier_id: supplier_b.id})
      _merchant_group = Factory.create_fulfillment!(order, store, %{supplier_id: nil})

      assert :ok == Dispatcher.dispatch_supplier_fulfillments(order)

      jobs = all_enqueued(worker: SupplierNotificationWorker)
      assert length(jobs) == 2

      enqueued_ids = Enum.map(jobs, & &1.args["fulfillment_id"])
      assert f_a.id in enqueued_ids
      assert f_b.id in enqueued_ids
    end

    test "skips non-pending supplier fulfillments" do
      {_merchant, store} = Factory.create_merchant_with_store!()
      order = Factory.create_order!(store, %{total: 10_000, currency: "GHS"})
      supplier = Factory.create_supplier!(store, %{contact_phone: "+233200000003"})

      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})

      fulfillment
      |> Ash.Changeset.for_update(:mark_notified, %{notified_via: :manual})
      |> Ash.update!(authorize?: false)

      assert :ok == Dispatcher.dispatch_supplier_fulfillments(order)
      assert all_enqueued(worker: SupplierNotificationWorker) == []
    end

    test "returns :ok and enqueues nothing for an order with no :id" do
      assert :ok == Dispatcher.dispatch_supplier_fulfillments(%{store_id: Ash.UUID.generate()})
      assert all_enqueued(worker: SupplierNotificationWorker) == []
    end
  end

  describe "dispatch_supplier_fulfillment/1" do
    test "enqueues one job for the given fulfillment id" do
      fulfillment_id = Ash.UUID.generate()

      assert {:ok, %Oban.Job{}} = Dispatcher.dispatch_supplier_fulfillment(fulfillment_id)

      assert_enqueued(
        worker: SupplierNotificationWorker,
        args: %{fulfillment_id: fulfillment_id},
        queue: :notifications
      )
    end
  end
end
