defmodule Emakola.Conversations.MessageNudgeWorkerTest do
  @moduledoc """
  The nudge: tell someone by SMS *only* if they still have not read the
  message.

  This is the piece that decides whether in-house messaging saves money or
  quietly costs more than it saves. Nudging on every message would mean each
  free message triggers a paid SMS — worse than not building it. So:

    * nothing is sent if they have already read it
    * a burst of messages produces ONE nudge, not one each
    * the author is never nudged about their own message
  """
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory
  import Mox

  alias Emakola.Conversations
  alias Emakola.Conversations.MessageNudgeWorker

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    # create_merchant_with_store!/1 takes STORE attrs, so the merchant's own
    # phone is set afterwards.
    {merchant, store} = create_merchant_with_store!()

    merchant =
      merchant
      |> Ash.Changeset.for_update(:update_profile, %{phone: "+233201234567"})
      |> Ash.update!(authorize?: false)

    customer = create_customer!(store, %{name: "Ama", phone: "+233209876543"})
    {:ok, thread} = Conversations.open_shop_thread(store.id, customer.id)

    %{merchant: merchant, store: store, customer: customer, thread: thread}
  end

  defp run(thread, side) do
    MessageNudgeWorker.perform(%Oban.Job{
      args: %{"thread_id" => thread.id, "side" => to_string(side)}
    })
  end

  test "sends nothing when the message has already been read", ctx do
    {:ok, _} = Conversations.post_message(ctx.thread, :customer, ctx.customer.id, "Hello")
    {:ok, thread} = Conversations.mark_read(ctx.thread, :merchant)

    # No SMS expectation at all — sending here is the bug.
    assert :ok = run(thread, :merchant)
  end

  test "tells the merchant when their buyer's message is still unread", ctx do
    {:ok, _} = Conversations.post_message(ctx.thread, :customer, ctx.customer.id, "Is it ready?")

    expect(Emakola.SMSProviderMock, :send_sms, 1, fn to, body, _opts ->
      assert to == "+233201234567"
      assert body =~ "message"
      {:ok, %{message_id: "sm_1"}}
    end)

    assert :ok = run(ctx.thread, :merchant)
  end

  test "a burst of messages is one nudge, not one each", ctx do
    for body <- ["One", "Two", "Three"] do
      {:ok, _} = Conversations.post_message(ctx.thread, :customer, ctx.customer.id, body)
    end

    # Three messages, three scheduled jobs — but Oban's uniqueness means only
    # one is actually enqueued, so the merchant is charged for one SMS.
    assert [_single] =
             all_enqueued(worker: MessageNudgeWorker)
             |> Enum.filter(&(&1.args["thread_id"] == ctx.thread.id))
  end

  test "posting schedules a nudge for the other side only", ctx do
    {:ok, _} = Conversations.post_message(ctx.thread, :customer, ctx.customer.id, "Hello")

    jobs =
      all_enqueued(worker: MessageNudgeWorker)
      |> Enum.filter(&(&1.args["thread_id"] == ctx.thread.id))

    # The buyer wrote it, so only the merchant is nudged.
    assert [job] = jobs
    assert job.args["side"] == "merchant"
  end

  test "a thread nobody can be reached on sends nothing", ctx do
    {_m, store} = create_merchant_with_store!()
    unreachable = create_customer!(store, %{name: "No Phone", email: "x@example.com"})
    {:ok, thread} = Conversations.open_shop_thread(store.id, unreachable.id)
    {:ok, _} = Conversations.post_message(thread, :merchant, ctx.merchant.id, "Ready")

    # Customer has an email but no phone: the nudge must not attempt an SMS.
    assert :ok = run(thread, :customer)
  end
end
