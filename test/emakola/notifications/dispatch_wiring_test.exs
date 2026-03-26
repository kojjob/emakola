defmodule Emakola.Notifications.DispatchWiringTest do
  @moduledoc """
  Tests that notification dispatch is wired into the order lifecycle:
  - CheckoutService dispatches :order_placed after successful checkout
  - Order resource actions dispatch corresponding events on status change
  - Webhook handlers dispatch :order_confirmed after payment confirmation
  """

  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  alias Emakola.Notifications.Workers.OrderNotificationWorker
  alias Emakola.Orders.CheckoutService

  # ── CheckoutService dispatch ─────────────────────────────────

  describe "CheckoutService dispatches :order_placed" do
    setup do
      store = create_store!()
      product = create_product!(store, title: "Dispatch Test Product")

      variant =
        create_variant!(product, store, price: 10_000, sku: "DW-001", stock_quantity: 50)

      customer = create_customer!(store, email: "dispatch@example.com", name: "Dispatch Test")
      {:ok, store: store, variant: variant, customer: customer}
    end

    test "enqueues order_placed notification after successful checkout", %{
      store: store,
      variant: variant,
      customer: customer
    } do
      items = [%{variant_id: variant.id, quantity: 1}]
      opts = [customer_id: customer.id]

      assert {:ok, order} = CheckoutService.checkout!(store.id, items, opts)

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: order.id, event: "order_placed"},
        queue: :notifications
      )
    end

    test "does not enqueue notification on failed checkout", %{store: store} do
      # Empty cart should fail without enqueueing
      assert {:error, :empty_cart} = CheckoutService.checkout!(store.id, [], [])

      refute_enqueued(worker: OrderNotificationWorker)
    end

    test "order succeeds even if notification dispatch were to fail conceptually", %{
      store: store,
      variant: variant,
      customer: customer
    } do
      items = [%{variant_id: variant.id, quantity: 1}]
      opts = [customer_id: customer.id]

      # The checkout should succeed regardless of notification outcome
      assert {:ok, order} = CheckoutService.checkout!(store.id, items, opts)
      assert order.status == :pending
      assert order.total == 10_000
    end
  end

  # ── Order resource action hooks ──────────────────────────────

  describe "Order resource actions dispatch notifications" do
    setup do
      store = create_store!()
      {:ok, store: store}
    end

    test ":confirm dispatches :order_confirmed", %{store: store} do
      order = create_order!(store, %{status: :pending})

      order
      |> Ash.Changeset.for_update(:confirm, %{})
      |> Ash.update!()

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: order.id, event: "order_confirmed"},
        queue: :notifications
      )
    end

    test ":mark_shipped dispatches :order_shipped", %{store: store} do
      order = create_order!(store, %{status: :processing})

      order
      |> Ash.Changeset.for_update(:mark_shipped, %{})
      |> Ash.update!()

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: order.id, event: "order_shipped"},
        queue: :notifications
      )
    end

    test ":mark_delivered dispatches :order_delivered", %{store: store} do
      order = create_order!(store, %{status: :shipped})

      order
      |> Ash.Changeset.for_update(:mark_delivered, %{})
      |> Ash.update!()

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: order.id, event: "order_delivered"},
        queue: :notifications
      )
    end

    test ":cancel dispatches :order_cancelled", %{store: store} do
      order = create_order!(store, %{status: :pending})

      order
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!()

      assert_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: order.id, event: "order_cancelled"},
        queue: :notifications
      )
    end

    test ":start_processing does not dispatch a notification", %{store: store} do
      order = create_order!(store, %{status: :confirmed})

      order
      |> Ash.Changeset.for_update(:start_processing, %{})
      |> Ash.update!()

      refute_enqueued(
        worker: OrderNotificationWorker,
        args: %{order_id: order.id, event: "order_processing"}
      )
    end
  end

  # ── PubSub broadcast from order actions ──────────────────────

  describe "PubSub broadcast on order status changes" do
    setup do
      store = create_store!()
      {:ok, store: store}
    end

    test "broadcasts :order_confirmed on confirm action", %{store: store} do
      order = create_order!(store, %{status: :pending})
      Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{store.id}:orders")

      order
      |> Ash.Changeset.for_update(:confirm, %{})
      |> Ash.update!()

      assert_receive {:order_event, :order_confirmed, _order}
    end

    test "broadcasts :order_shipped on mark_shipped action", %{store: store} do
      order = create_order!(store, %{status: :processing})
      Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{store.id}:orders")

      order
      |> Ash.Changeset.for_update(:mark_shipped, %{})
      |> Ash.update!()

      assert_receive {:order_event, :order_shipped, _order}
    end

    test "broadcasts :order_cancelled on cancel action", %{store: store} do
      order = create_order!(store, %{status: :pending})
      Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{store.id}:orders")

      order
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!()

      assert_receive {:order_event, :order_cancelled, _order}
    end
  end

  # ── Merchant phone lookup ────────────────────────────────────

  describe "merchant phone lookup uses store.contact_phone" do
    test "skips merchant SMS when store has no contact_phone" do
      {_merchant, store} = create_merchant_with_store!()
      # No contact_phone set on store

      customer = create_customer!(store, %{phone: nil, name: "No Phone"})
      order = create_order!(store, %{customer_id: customer.id, total: 5_000})

      # Should not crash and should not send merchant SMS
      result =
        OrderNotificationWorker.perform(%Oban.Job{
          args: %{"order_id" => order.id, "event" => "order_placed"}
        })

      assert result == :ok
    end
  end
end
