defmodule Emakola.ConversationsTest do
  @moduledoc """
  The messaging core, shared by both directions:

    * `:shop_buyer` — a merchant and one of their buyers
    * `:platform_merchant` — Makola staff and a merchant

  One core rather than two, because the parts that are hard (ordering,
  unread, isolation) are identical and the parts that differ are just who
  the two sides are.

  In-house messaging exists to avoid paying per SMS, so the rule that
  matters most is isolation: a thread must never leak to another store.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Conversations

  setup do
    {merchant, store} = create_merchant_with_store!()
    customer = create_customer!(store, %{name: "Ama", phone: "+233201234567"})
    %{merchant: merchant, store: store, customer: customer}
  end

  describe "shop threads" do
    test "a buyer and a shop share one thread", ctx do
      assert {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)

      assert thread.kind == :shop_buyer
      assert thread.store_id == ctx.store.id
      assert thread.customer_id == ctx.customer.id
    end

    test "opening twice returns the same thread, not a second one", ctx do
      {:ok, first} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
      {:ok, second} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)

      assert first.id == second.id
      assert {:ok, [_only_one]} = Conversations.list_shop_threads(ctx.store.id)
    end

    test "never leaks to another store", ctx do
      {_other_merchant, other_store} = create_merchant_with_store!()
      {:ok, _thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)

      assert {:ok, []} = Conversations.list_shop_threads(other_store.id)
    end
  end

  describe "platform threads" do
    test "staff open a thread with a merchant", ctx do
      assert {:ok, thread} = Conversations.open_platform_thread(ctx.merchant.id)

      assert thread.kind == :platform_merchant
      assert thread.merchant_id == ctx.merchant.id
      assert is_nil(thread.store_id)
    end

    test "opening twice returns the same thread", ctx do
      {:ok, first} = Conversations.open_platform_thread(ctx.merchant.id)
      {:ok, second} = Conversations.open_platform_thread(ctx.merchant.id)

      assert first.id == second.id
    end
  end

  describe "messages" do
    setup ctx do
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
      Map.put(ctx, :thread, thread)
    end

    test "records who wrote what", ctx do
      assert {:ok, message} =
               Conversations.post_message(
                 ctx.thread,
                 :merchant,
                 ctx.merchant.id,
                 "Your cloth is ready."
               )

      assert message.author_kind == :merchant
      assert message.author_id == ctx.merchant.id
      assert message.body == "Your cloth is ready."
    end

    test "returns messages oldest first, the way a conversation reads", ctx do
      {:ok, _} = Conversations.post_message(ctx.thread, :merchant, ctx.merchant.id, "First")
      {:ok, _} = Conversations.post_message(ctx.thread, :customer, ctx.customer.id, "Second")

      assert {:ok, [first, second]} = Conversations.list_messages(ctx.thread.id)
      assert first.body == "First"
      assert second.body == "Second"
    end

    test "refuses an empty message", ctx do
      assert {:error, _} =
               Conversations.post_message(ctx.thread, :merchant, ctx.merchant.id, "   ")
    end
  end

  describe "unread" do
    setup ctx do
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
      Map.put(ctx, :thread, thread)
    end

    test "your own message is never unread to you", ctx do
      {:ok, _} = Conversations.post_message(ctx.thread, :merchant, ctx.merchant.id, "Hello")

      assert Conversations.unread_count(ctx.thread.id, :merchant) == 0
      assert Conversations.unread_count(ctx.thread.id, :customer) == 1
    end

    test "marking read clears it for that side only", ctx do
      {:ok, _} =
        Conversations.post_message(ctx.thread, :customer, ctx.customer.id, "Is it ready?")

      assert Conversations.unread_count(ctx.thread.id, :merchant) == 1

      {:ok, _} = Conversations.mark_read(ctx.thread, :merchant)

      assert Conversations.unread_count(ctx.thread.id, :merchant) == 0
    end

    test "a later message is unread again", ctx do
      {:ok, _} = Conversations.post_message(ctx.thread, :customer, ctx.customer.id, "One")
      {:ok, thread} = Conversations.mark_read(ctx.thread, :merchant)
      {:ok, _} = Conversations.post_message(thread, :customer, ctx.customer.id, "Two")

      assert Conversations.unread_count(thread.id, :merchant) == 1
    end
  end
end
