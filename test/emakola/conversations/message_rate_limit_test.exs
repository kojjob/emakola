defmodule Emakola.Conversations.MessageRateLimitTest do
  @moduledoc """
  A ceiling on how fast one author can post.

  Posting was unmetered: a script pointed at a shop thread could write rows
  until the disk filled, and every message schedules a nudge job. The limit is
  per author, so one abusive buyer cannot silence a shop's other conversations.
  """
  # async: false — the limiter's ETS counters are global, so a parallel test
  # posting messages would spend this test's allowance.
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Conversations

  setup do
    {merchant, store} = create_merchant_with_store!()
    customer = create_customer!(store, %{name: "Ama"})
    {:ok, thread} = Conversations.open_shop_thread(store.id, customer.id)

    %{merchant: merchant, store: store, customer: customer, thread: thread}
  end

  defp post_n(thread, kind, id, n) do
    Enum.map(1..n, fn i -> Conversations.post_message(thread, kind, id, "msg #{i}") end)
  end

  test "an ordinary exchange is never blocked", ctx do
    results = post_n(ctx.thread, :customer, ctx.customer.id, 5)

    assert Enum.all?(results, &match?({:ok, _}, &1))
  end

  test "a flood from one author is cut off", ctx do
    results = post_n(ctx.thread, :customer, ctx.customer.id, Conversations.message_limit() + 5)

    assert Enum.any?(results, &match?({:error, :rate_limited}, &1)),
           "expected the limiter to refuse at least one message"
  end

  test "one author's flood does not silence another", ctx do
    _flood = post_n(ctx.thread, :customer, ctx.customer.id, Conversations.message_limit() + 5)

    # The merchant shares the thread but not the author's allowance.
    assert {:ok, _} = Conversations.post_message(ctx.thread, :merchant, ctx.merchant.id, "Reply")
  end

  test "a refused message is not written", ctx do
    limit = Conversations.message_limit()
    post_n(ctx.thread, :customer, ctx.customer.id, limit + 10)

    {:ok, messages} = Conversations.list_messages(ctx.thread.id)

    assert length(messages) <= limit,
           "refused messages must not reach the database"
  end
end
