defmodule Emakola.Notifications.EventWiringTest do
  @moduledoc """
  The events that actually put something in a bell.

  A correct notification centre nobody writes to is still an empty bell.
  These pin the sources: a message, an order, a payout, and the three
  platform decisions a merchant needs to hear about.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Conversations
  alias Emakola.Notifications

  setup do
    {merchant, store} = create_merchant_with_store!()
    %{merchant: merchant, store: store}
  end

  defp titles_for(recipient), do: recipient |> Notifications.list_for() |> Enum.map(& &1.title)
  defp types_for(recipient), do: recipient |> Notifications.list_for() |> Enum.map(& &1.type)

  describe "messages" do
    test "a buyer writing to a shop notifies the merchant", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)

      {:ok, _} = Conversations.post_message(thread, :customer, ama.id, "Are you open?")

      assert types_for(ctx.merchant) == [:new_message]
      assert titles_for(ctx.merchant) == ["Ama sent you a message"]
    end

    test "a merchant replying notifies the buyer", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)

      {:ok, _} = Conversations.post_message(thread, :merchant, ctx.merchant.id, "Yes we are")

      assert types_for(ama) == [:new_message]
      assert Notifications.list_for(ctx.merchant) == []
    end

    test "an author is never notified of their own message", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)

      {:ok, _} = Conversations.post_message(thread, :customer, ama.id, "Hello")

      assert Notifications.list_for(ama) == []
    end

    test "Makola writing to a merchant notifies the merchant", ctx do
      {:ok, thread} = Conversations.open_platform_thread(ctx.merchant.id)
      staff = create_platform_owner!()

      {:ok, _} = Conversations.post_message(thread, :platform, staff.id, "About your payout")

      assert types_for(ctx.merchant) == [:new_message]
    end

    test "a merchant writing on their support thread notifies no one", ctx do
      # Staff work in the dashboard, not a bell, exactly as MessageNudgeWorker
      # declines to send them an SMS.
      {:ok, thread} = Conversations.open_platform_thread(ctx.merchant.id)

      {:ok, _} = Conversations.post_message(thread, :merchant, ctx.merchant.id, "Any update?")

      assert Notifications.list_for(ctx.merchant) == []
    end

    test "the notification leads to the conversation", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)

      {:ok, _} = Conversations.post_message(thread, :customer, ama.id, "Are you open?")

      [notification] = Notifications.list_for(ctx.merchant)
      assert notification.action_url == "/admin/messages/#{thread.id}"
    end
  end

  describe "notify_store/3" do
    test "reaches the store's merchant", ctx do
      :ok = Notifications.notify_store(ctx.store.id, :payout_sent, %{title: "Payout sent"})

      assert titles_for(ctx.merchant) == ["Payout sent"]
    end

    test "does not reach another store's merchant", ctx do
      {other_merchant, other_store} = create_merchant_with_store!()

      :ok = Notifications.notify_store(other_store.id, :payout_sent, %{title: "Theirs"})

      assert Notifications.list_for(ctx.merchant) == []
      assert titles_for(other_merchant) == ["Theirs"]
    end

    test "reaches every merchant who runs the store", ctx do
      staff_merchant = create_merchant!()

      Emakola.Accounts.StoreMembership
      |> Ash.Changeset.for_create(:create, %{
        merchant_id: staff_merchant.id,
        store_id: ctx.store.id,
        role: :staff
      })
      |> Ash.create!(authorize?: false)

      :ok = Notifications.notify_store(ctx.store.id, :order_placed, %{title: "New order"})

      assert titles_for(ctx.merchant) == ["New order"]
      assert titles_for(staff_merchant) == ["New order"]
    end

    test "a store with no members is not an error", ctx do
      orphan = create_store!()

      assert :ok = Notifications.notify_store(orphan.id, :order_placed, %{title: "Nobody"})
      assert Notifications.list_for(ctx.merchant) == []
    end
  end

  describe "orders" do
    test "a placed order rings the merchant's bell", ctx do
      order = create_order!(ctx.store)

      Emakola.Notifications.Dispatcher.dispatch(order, :order_placed)

      assert types_for(ctx.merchant) == [:order_placed]
      assert titles_for(ctx.merchant) == ["New order #{order.order_number}"]
    end

    test "later status changes do not, because the merchant made them", ctx do
      order = create_order!(ctx.store)

      Emakola.Notifications.Dispatcher.dispatch(order, :order_shipped)

      assert Notifications.list_for(ctx.merchant) == []
    end
  end

  describe "platform decisions" do
    test "a verification result reaches the merchant", ctx do
      Emakola.Notifications.Workers.VerificationStatusNotificationWorker.perform(%Oban.Job{
        args: %{"store_id" => ctx.store.id, "event" => "verification_approved"}
      })

      assert types_for(ctx.merchant) == [:verification_result]
      assert titles_for(ctx.merchant) == ["Your shop is verified"]
    end

    test "a takedown reaches the merchant", ctx do
      product = create_product!(ctx.store, %{title: "Kente Cloth"})

      Emakola.Notifications.Workers.ProductModerationNotificationWorker.perform(%Oban.Job{
        args: %{"product_id" => product.id, "event" => "product_taken_down"}
      })

      assert types_for(ctx.merchant) == [:product_moderated]
      assert titles_for(ctx.merchant) == ["Kente Cloth was taken down"]
    end
  end
end
