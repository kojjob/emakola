defmodule Emakola.Conversations.NudgeRespectsPreferencesTest do
  @moduledoc """
  The paid nudge asks permission first.

  This is the one notification in the system that costs the merchant money on
  every send, and it fires for the chattiest event there is. If any preference
  has to be honoured, it is this one.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Mox

  alias Emakola.Conversations
  alias Emakola.Conversations.MessageNudgeWorker
  alias Emakola.Notifications.Preferences

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    {merchant, store} = create_merchant_with_store!(%{name: "Nudge Shop"})

    merchant =
      merchant
      |> Ash.Changeset.for_update(:update_profile, %{phone: "+233241112222"})
      |> Ash.update!(authorize?: false)

    buyer = create_customer!(store, %{name: "Ama", phone: "+233243334444"})
    {:ok, thread} = Conversations.open_shop_thread(store.id, buyer.id)
    {:ok, _} = Conversations.post_message(thread, :customer, buyer.id, "Are you open?")

    %{merchant: merchant, store: store, buyer: buyer, thread: thread}
  end

  # `at` is passed in rather than read from the clock so a quiet-hours test
  # does not have to run at 2am to mean anything.
  defp run_nudge(thread, opts \\ []) do
    args = %{"thread_id" => thread.id, "side" => "merchant"}

    args =
      case Keyword.get(opts, :at) do
        nil -> args
        at -> Map.put(args, "at", DateTime.to_iso8601(at))
      end

    MessageNudgeWorker.perform(%Oban.Job{args: args})
  end

  test "sends by default", ctx do
    expect(Emakola.SMSProviderMock, :send_sms, fn _to, _message, _opts -> {:ok, %{}} end)

    assert :ok = run_nudge(ctx.thread)
  end

  test "stays silent when the merchant switched SMS off for messages", ctx do
    {:ok, _} = Preferences.put_channels(ctx.merchant, :new_message, [:in_app])

    # No expect/3 — verify_on_exit! fails the test if send_sms is called.
    assert :ok = run_nudge(ctx.thread)
  end

  test "still sends when they kept SMS on", ctx do
    {:ok, _} = Preferences.put_channels(ctx.merchant, :new_message, [:in_app, :sms])
    expect(Emakola.SMSProviderMock, :send_sms, fn _to, _message, _opts -> {:ok, %{}} end)

    assert :ok = run_nudge(ctx.thread)
  end

  describe "quiet hours" do
    test "a nudge inside the window is held, not sent", ctx do
      {:ok, _} = Preferences.put_quiet_hours(ctx.merchant, ~T[22:00:00], ~T[06:00:00])

      # No expect/3: sending at 2am is exactly what quiet hours forbid.
      assert :ok = run_nudge(ctx.thread, at: ~U[2026-08-26 02:00:00Z])
    end

    test "the held nudge is rescheduled for when the window ends", ctx do
      {:ok, _} = Preferences.put_quiet_hours(ctx.merchant, ~T[22:00:00], ~T[06:00:00])

      run_nudge(ctx.thread, at: ~U[2026-08-26 02:00:00Z])

      # Held, not dropped — the merchant still hears about it when the window
      # ends. One job, rescheduled: Oban's uniqueness means a second insert
      # would be discarded, so the hold has to move the existing job's clock.
      jobs =
        Oban.Job
        |> Emakola.Repo.all()
        |> Enum.filter(&(&1.worker =~ "MessageNudgeWorker" and &1.state == "scheduled"))

      assert [job] = jobs
      assert DateTime.compare(job.scheduled_at, ~U[2026-08-26 06:00:00Z]) == :eq
    end

    test "outside the window it sends normally", ctx do
      {:ok, _} = Preferences.put_quiet_hours(ctx.merchant, ~T[22:00:00], ~T[06:00:00])
      expect(Emakola.SMSProviderMock, :send_sms, fn _to, _message, _opts -> {:ok, %{}} end)

      assert :ok = run_nudge(ctx.thread, at: ~U[2026-08-26 14:00:00Z])
    end
  end

  test "one merchant's choice does not silence another's shop", ctx do
    {:ok, _} = Preferences.put_channels(ctx.merchant, :new_message, [:in_app])

    {other_merchant, other_store} = create_merchant_with_store!()

    other_merchant
    |> Ash.Changeset.for_update(:update_profile, %{phone: "+233245556666"})
    |> Ash.update!(authorize?: false)

    other_buyer = create_customer!(other_store, %{name: "Esi", phone: "+233247778888"})
    {:ok, other_thread} = Conversations.open_shop_thread(other_store.id, other_buyer.id)
    {:ok, _} = Conversations.post_message(other_thread, :customer, other_buyer.id, "Hello?")

    expect(Emakola.SMSProviderMock, :send_sms, fn _to, _message, _opts -> {:ok, %{}} end)

    assert :ok = run_nudge(other_thread)
  end
end
