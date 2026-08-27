defmodule Emakola.Conversations.PlatformCustomerThreadsTest do
  @moduledoc """
  Makola talking to a buyer, and a buyer writing in.

  A third thread kind. The awkward part is uniqueness: a platform↔customer
  thread carries a customer_id and no store_id, and Postgres treats NULLs as
  distinct, so the existing one-per-buyer index gives these rows no
  uniqueness whatsoever — every "open" would make another thread.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Conversations

  setup do
    {merchant, store} = create_merchant_with_store!()
    customer = create_customer!(store, %{name: "Ama"})
    %{merchant: merchant, store: store, customer: customer}
  end

  describe "opening" do
    test "a buyer gets one thread with Makola", ctx do
      assert {:ok, thread} = Conversations.open_platform_customer_thread(ctx.customer.id)

      assert thread.kind == :platform_customer
      assert thread.customer_id == ctx.customer.id
      assert is_nil(thread.store_id)
    end

    test "opening twice reuses it rather than making a second", ctx do
      {:ok, first} = Conversations.open_platform_customer_thread(ctx.customer.id)
      {:ok, second} = Conversations.open_platform_customer_thread(ctx.customer.id)

      assert first.id == second.id
    end

    test "it does not collide with the buyer's shop thread", ctx do
      {:ok, shop} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
      {:ok, platform} = Conversations.open_platform_customer_thread(ctx.customer.id)

      refute shop.id == platform.id
      assert shop.kind == :shop_buyer
      assert platform.kind == :platform_customer
    end

    test "two buyers get two different threads", ctx do
      other = create_customer!(ctx.store, %{name: "Kofi"})

      {:ok, ama} = Conversations.open_platform_customer_thread(ctx.customer.id)
      {:ok, kofi} = Conversations.open_platform_customer_thread(other.id)

      refute ama.id == kofi.id
    end

    test "a buyer in two shops still has one Makola thread", ctx do
      {_other_merchant, other_store} = create_merchant_with_store!()
      # Same person, a second shop — two shop threads, still one Makola thread.
      {:ok, _} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
      second_shop_customer = create_customer!(other_store, %{name: "Ama"})
      {:ok, _} = Conversations.open_shop_thread(other_store.id, second_shop_customer.id)

      {:ok, first} = Conversations.open_platform_customer_thread(ctx.customer.id)
      {:ok, again} = Conversations.open_platform_customer_thread(ctx.customer.id)

      assert first.id == again.id
    end
  end

  describe "talking" do
    test "a buyer writing in reaches staff", ctx do
      {:ok, thread} = Conversations.open_platform_customer_thread(ctx.customer.id)

      assert {:ok, message} =
               Conversations.post_message(
                 thread,
                 :customer,
                 ctx.customer.id,
                 "My order never came"
               )

      assert message.body == "My order never came"
    end

    test "staff replying notifies the buyer", ctx do
      {:ok, thread} = Conversations.open_platform_customer_thread(ctx.customer.id)
      staff = create_platform_owner!()

      {:ok, _} = Conversations.post_message(thread, :platform, staff.id, "We are looking into it")

      types = ctx.customer |> Emakola.Notifications.list_for() |> Enum.map(& &1.type)
      assert types == [:new_message]
    end

    test "a buyer's own message does not notify them", ctx do
      {:ok, thread} = Conversations.open_platform_customer_thread(ctx.customer.id)

      {:ok, _} = Conversations.post_message(thread, :customer, ctx.customer.id, "Hello")

      assert Emakola.Notifications.list_for(ctx.customer) == []
    end

    test "it never raises a shop's unread badge", ctx do
      # The thread has no store_id, so a shop must not see it in its inbox.
      {:ok, thread} = Conversations.open_platform_customer_thread(ctx.customer.id)
      {:ok, _} = Conversations.post_message(thread, :customer, ctx.customer.id, "Hello")

      assert Conversations.unread_total_for_store(ctx.store.id) == 0
    end
  end

  describe "staff inbox" do
    test "lists customer threads alongside merchant ones", ctx do
      {:ok, _} = Conversations.open_platform_customer_thread(ctx.customer.id)
      {:ok, _} = Conversations.open_platform_thread(ctx.merchant.id)

      {:ok, threads} = Conversations.list_platform_threads()

      kinds = threads |> Enum.map(& &1.kind) |> Enum.sort()
      assert kinds == [:platform_customer, :platform_merchant]
    end

    test "a shop thread never appears in the staff inbox", ctx do
      {:ok, _} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)

      {:ok, threads} = Conversations.list_platform_threads()

      assert threads == []
    end
  end
end
