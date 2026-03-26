defmodule Emakola.Notifications.DispatcherTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Notifications.Dispatcher
  alias Emakola.Notifications.Workers.OrderNotificationWorker

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
end
