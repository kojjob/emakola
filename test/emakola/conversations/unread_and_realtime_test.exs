defmodule Emakola.Conversations.UnreadAndRealtimeTest do
  @moduledoc """
  Unread counts for a whole inbox, and the broadcast that makes a new message
  appear without a refresh.

  The inbox previously counted unread per thread, which is one query per row
  — fine for ten conversations and wrong for a thousand.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Conversations

  setup do
    {merchant, store} = create_merchant_with_store!()
    %{merchant: merchant, store: store}
  end

  describe "unread_counts/2" do
    test "counts every thread in the store in one pass", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      kofi = create_customer!(ctx.store, %{name: "Kofi"})

      {:ok, ama_thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)
      {:ok, kofi_thread} = Conversations.open_shop_thread(ctx.store.id, kofi.id)

      {:ok, _} = Conversations.post_message(ama_thread, :customer, ama.id, "One")
      {:ok, _} = Conversations.post_message(ama_thread, :customer, ama.id, "Two")
      {:ok, _} = Conversations.post_message(kofi_thread, :customer, kofi.id, "Hello")

      counts = Conversations.unread_counts(ctx.store.id, :merchant)

      assert counts[ama_thread.id] == 2
      assert counts[kofi_thread.id] == 1
    end

    test "respects each thread's own read mark", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      kofi = create_customer!(ctx.store, %{name: "Kofi"})

      {:ok, ama_thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)
      {:ok, kofi_thread} = Conversations.open_shop_thread(ctx.store.id, kofi.id)

      {:ok, _} = Conversations.post_message(ama_thread, :customer, ama.id, "One")
      {:ok, _} = Conversations.post_message(kofi_thread, :customer, kofi.id, "Hello")

      {:ok, _} = Conversations.mark_read(ama_thread, :merchant)

      counts = Conversations.unread_counts(ctx.store.id, :merchant)

      assert counts[ama_thread.id] == 0
      assert counts[kofi_thread.id] == 1
    end

    test "never counts the merchant's own messages", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)
      {:ok, _} = Conversations.post_message(thread, :merchant, ctx.merchant.id, "Ready")

      assert Conversations.unread_counts(ctx.store.id, :merchant)[thread.id] == 0
    end

    test "a store with no threads returns an empty map", ctx do
      assert Conversations.unread_counts(ctx.store.id, :merchant) == %{}
    end
  end

  describe "broadcasts" do
    test "a new message reaches subscribers of its thread", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)

      Conversations.subscribe(thread.id)

      {:ok, message} = Conversations.post_message(thread, :customer, ama.id, "Are you open?")

      assert_receive {:new_message, received}
      assert received.id == message.id
      assert received.body == "Are you open?"
    end

    test "a thread's messages do not reach another thread's subscribers", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      kofi = create_customer!(ctx.store, %{name: "Kofi"})
      {:ok, ama_thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)
      {:ok, kofi_thread} = Conversations.open_shop_thread(ctx.store.id, kofi.id)

      Conversations.subscribe(ama_thread.id)

      {:ok, _} = Conversations.post_message(kofi_thread, :customer, kofi.id, "Private")

      refute_receive {:new_message, _}, 100
    end
  end
end
