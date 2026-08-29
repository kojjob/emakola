defmodule Emakola.Notifications.NotifyTest do
  @moduledoc """
  Who can be told something.

  `Notification` was foreign-keyed to `users` — platform staff only — while
  the bell that renders it lives in the merchant layout, and merchants are in
  a different table entirely. The one actor who could own a row could not see
  it, and the one actor with a bell could not own a row.

  Recipients are polymorphic now, the same `kind` + `id` pair `Message` uses
  to name an author across three tables.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Notifications

  setup do
    {merchant, store} = create_merchant_with_store!()
    %{merchant: merchant, store: store}
  end

  describe "notify/3" do
    test "a merchant can be told something", ctx do
      assert {:ok, notification} =
               Notifications.notify(ctx.merchant, :order_placed, %{
                 title: "New order",
                 body: "Ama ordered 2 items"
               })

      assert notification.recipient_kind == :merchant
      assert notification.recipient_id == ctx.merchant.id
      assert is_nil(notification.read_at)
    end

    test "platform staff can be told something" do
      user = create_platform_owner!()

      assert {:ok, notification} = Notifications.notify(user, :system, %{title: "Deploy done"})

      assert notification.recipient_kind == :user
      assert notification.recipient_id == user.id
    end

    test "a customer can be told something", ctx do
      customer = create_customer!(ctx.store, %{name: "Ama"})

      assert {:ok, notification} =
               Notifications.notify(customer, :order_status_changed, %{title: "Order shipped"})

      assert notification.recipient_kind == :customer
      assert notification.recipient_id == customer.id
    end

    test "carries an action url so the bell can lead somewhere", ctx do
      assert {:ok, notification} =
               Notifications.notify(ctx.merchant, :new_message, %{
                 title: "Ama sent a message",
                 action_url: "/admin/messages/abc"
               })

      assert notification.action_url == "/admin/messages/abc"
    end

    test "a long title is trimmed rather than refused", ctx do
      # Titles are built from user data — "#{product.title} was taken down" —
      # and `title` caps at 255. Refusing would mean a merchant with a long
      # product name silently gets no notification at all.
      long = String.duplicate("Adweneasa Kente ", 40)

      assert {:ok, notification} =
               Notifications.notify(ctx.merchant, :product_moderated, %{title: long})

      assert String.length(notification.title) <= 255
      assert String.starts_with?(notification.title, "Adweneasa Kente")
      assert String.ends_with?(notification.title, "…")
    end

    test "a title that fits is left alone", ctx do
      assert {:ok, notification} =
               Notifications.notify(ctx.merchant, :order_placed, %{title: "New order ORD-1"})

      assert notification.title == "New order ORD-1"
    end

    test "refuses a type that is not in the vocabulary", ctx do
      assert {:error, _} = Notifications.notify(ctx.merchant, :not_a_real_event, %{title: "Hi"})
    end
  end

  describe "reading a recipient's notifications" do
    test "returns only that recipient's rows", ctx do
      {_other_merchant, _} = create_merchant_with_store!()
      other = create_merchant!()

      {:ok, _} = Notifications.notify(ctx.merchant, :order_placed, %{title: "Yours"})
      {:ok, _} = Notifications.notify(other, :order_placed, %{title: "Theirs"})

      titles = ctx.merchant |> Notifications.list_for() |> Enum.map(& &1.title)

      assert titles == ["Yours"]
    end

    test "never crosses actor kinds even on an id collision", ctx do
      # recipient_id is a bare uuid with no foreign key, so kind is the only
      # thing separating a merchant's rows from a customer's.
      customer = create_customer!(ctx.store, %{name: "Ama"})
      {:ok, _} = Notifications.notify(customer, :order_placed, %{title: "Buyer's"})

      assert Notifications.list_for(ctx.merchant) == []
    end

    test "newest first", ctx do
      {:ok, _} = Notifications.notify(ctx.merchant, :order_placed, %{title: "First"})
      {:ok, _} = Notifications.notify(ctx.merchant, :order_placed, %{title: "Second"})

      titles = ctx.merchant |> Notifications.list_for() |> Enum.map(& &1.title)

      assert titles == ["Second", "First"]
    end

    test "counts what is unread", ctx do
      {:ok, first} = Notifications.notify(ctx.merchant, :order_placed, %{title: "One"})
      {:ok, _} = Notifications.notify(ctx.merchant, :order_placed, %{title: "Two"})

      assert Notifications.unread_count_for(ctx.merchant) == 2

      {:ok, _} = Notifications.mark_read(first)

      assert Notifications.unread_count_for(ctx.merchant) == 1
    end

    test "marking all read clears the count in one go", ctx do
      for i <- 1..3 do
        {:ok, _} = Notifications.notify(ctx.merchant, :order_placed, %{title: "N#{i}"})
      end

      assert :ok = Notifications.mark_all_read_for(ctx.merchant)
      assert Notifications.unread_count_for(ctx.merchant) == 0
    end

    test "marking all read leaves another recipient alone", ctx do
      other = create_merchant!()
      {:ok, _} = Notifications.notify(ctx.merchant, :order_placed, %{title: "Mine"})
      {:ok, _} = Notifications.notify(other, :order_placed, %{title: "Theirs"})

      :ok = Notifications.mark_all_read_for(ctx.merchant)

      assert Notifications.unread_count_for(other) == 1
    end
  end

  describe "broadcasts" do
    test "a notification reaches its recipient's subscribers", ctx do
      Notifications.subscribe(ctx.merchant)

      {:ok, notification} =
        Notifications.notify(ctx.merchant, :order_placed, %{title: "New order"})

      assert_receive {:new_notification, received}
      assert received.id == notification.id
    end

    test "one recipient's notification does not reach another's subscribers", ctx do
      other = create_merchant!()
      Notifications.subscribe(ctx.merchant)

      {:ok, _} = Notifications.notify(other, :order_placed, %{title: "Theirs"})

      refute_receive {:new_notification, _}, 100
    end

    test "a merchant and a customer sharing an id do not share a topic", ctx do
      customer = create_customer!(ctx.store, %{name: "Ama"})
      Notifications.subscribe(ctx.merchant)

      {:ok, _} = Notifications.notify(customer, :order_placed, %{title: "Buyer's"})

      refute_receive {:new_notification, _}, 100
    end
  end
end
