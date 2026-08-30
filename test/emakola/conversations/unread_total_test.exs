defmodule Emakola.Conversations.UnreadTotalTest do
  @moduledoc """
  The number behind the sidebar badge.

  This runs on the connected mount of every admin page, so it has to be one
  query that does not grow with the store's message history.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Conversations

  setup do
    {merchant, store} = create_merchant_with_store!()
    %{merchant: merchant, store: store}
  end

  describe "unread_total_for_store/1" do
    test "is zero for a store with no conversations", ctx do
      assert Conversations.unread_total_for_store(ctx.store.id) == 0
    end

    test "counts buyer messages the merchant has not read", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)
      {:ok, _} = Conversations.post_message(thread, :customer, ama.id, "Are you open?")
      {:ok, _} = Conversations.post_message(thread, :customer, ama.id, "Hello?")

      assert Conversations.unread_total_for_store(ctx.store.id) == 2
    end

    test "sums across every thread in the store", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      kofi = create_customer!(ctx.store, %{name: "Kofi"})
      {:ok, ama_thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)
      {:ok, kofi_thread} = Conversations.open_shop_thread(ctx.store.id, kofi.id)

      {:ok, _} = Conversations.post_message(ama_thread, :customer, ama.id, "One")
      {:ok, _} = Conversations.post_message(kofi_thread, :customer, kofi.id, "Two")
      {:ok, _} = Conversations.post_message(kofi_thread, :customer, kofi.id, "Three")

      assert Conversations.unread_total_for_store(ctx.store.id) == 3
    end

    test "never counts the merchant's own messages", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)
      {:ok, _} = Conversations.post_message(thread, :merchant, ctx.merchant.id, "We are open")

      assert Conversations.unread_total_for_store(ctx.store.id) == 0
    end

    test "drops to zero once the merchant reads the thread", ctx do
      ama = create_customer!(ctx.store, %{name: "Ama"})
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)
      {:ok, _} = Conversations.post_message(thread, :customer, ama.id, "Are you open?")

      {:ok, thread} = Conversations.mark_read(thread, :merchant)
      assert Conversations.unread_total_for_store(ctx.store.id) == 0

      # ...and a message arriving after that read counts again.
      {:ok, _} = Conversations.post_message(thread, :customer, ama.id, "Still there?")
      assert Conversations.unread_total_for_store(ctx.store.id) == 1
    end

    test "ignores another store's unread messages", ctx do
      {_other_merchant, other_store} = create_merchant_with_store!()
      other_buyer = create_customer!(other_store, %{name: "Esi"})
      {:ok, other_thread} = Conversations.open_shop_thread(other_store.id, other_buyer.id)
      {:ok, _} = Conversations.post_message(other_thread, :customer, other_buyer.id, "Private")

      assert Conversations.unread_total_for_store(ctx.store.id) == 0
      assert Conversations.unread_total_for_store(other_store.id) == 1
    end

    test "does not count the merchant's own Makola support thread", ctx do
      {:ok, platform_thread} = Conversations.open_platform_thread(ctx.merchant.id)
      staff_id = Ecto.UUID.generate()
      {:ok, _} = Conversations.post_message(platform_thread, :platform, staff_id, "Hi")

      # The platform thread has no store_id, so a store total must not see it.
      assert Conversations.unread_total_for_store(ctx.store.id) == 0
    end
  end
end
