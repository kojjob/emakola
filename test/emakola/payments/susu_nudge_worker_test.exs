defmodule Emakola.Payments.Workers.SusuNudgeWorkerTest do
  @moduledoc """
  TC-3 Task 8: the daily cron sweep — 7-day-quiet nudges and 7d/1d
  deadline warnings, each dedup'd via `SusuPlan`'s
  `last_nudged_at`/`warned_7d_at`/`warned_1d_at` timestamps.
  """

  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  alias Emakola.Notifications.Workers.SusuNotificationWorker
  alias Emakola.Orders.SusuPlan
  alias Emakola.Payments.Workers.SusuNudgeWorker

  defp future_deadline(days \\ 30), do: DateTime.add(DateTime.utc_now(), days, :day)

  defp create_plan!(store, attrs) do
    attrs = Map.new(attrs) |> Map.put_new(:deadline, future_deadline())

    SusuPlan
    |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
    |> Ash.create!(authorize?: false)
  end

  defp activate!(plan, customer) do
    plan
    |> Ash.Changeset.for_update(:activate, %{
      customer_id: customer.id,
      delivery_address: %{"name" => "Ama Mensah", "phone" => "0201234567", "address" => "Accra"}
    })
    |> Ash.update!(authorize?: false)
  end

  defp force_deadline!(plan, deadline) do
    plan
    |> Ash.Changeset.for_update(:update_delivery, %{delivery_address: plan.delivery_address})
    |> Ash.Changeset.force_change_attribute(:deadline, deadline)
    |> Ash.update!(authorize?: false)
  end

  defp reload_plan(plan), do: Ash.get!(SusuPlan, plan.id, authorize?: false)

  # A counted contribution whose `inserted_at` is `days_ago` days in the
  # past — the signal `SusuNudgeWorker` uses to decide "hasn't chunked in
  # 7 days". Mirrors `SusuCompletionTest.create_contribution!/4`'s
  # force-stamped `inserted_at` technique.
  defp create_contribution!(store, plan, amount, days_ago) do
    payment =
      create_payment!(store, %{
        susu_plan_id: plan.id,
        amount: amount,
        payout_held: true,
        payout_hold_reason: "susu_plan",
        metadata: %{"susu_counted" => true}
      })

    payment
    |> Ash.Changeset.for_update(:mark_success, %{gateway_response: %{}})
    |> Ash.Changeset.force_change_attribute(
      :inserted_at,
      DateTime.add(DateTime.utc_now(), -days_ago, :day)
    )
    |> Ash.update!(authorize?: false)
  end

  defp active_plan_with_last_contribution!(store, days_ago) do
    customer = create_customer!(store)
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
    plan = activate!(plan, customer)
    create_contribution!(store, plan, 5_000, days_ago)

    plan
    |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 5_000})
    |> Ash.update!(authorize?: false)
  end

  defp active_plan_with_deadline!(store, deadline) do
    customer = create_customer!(store)
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
    plan = activate!(plan, customer)
    force_deadline!(plan, deadline)
  end

  defp deadline_warning_jobs do
    [worker: SusuNotificationWorker]
    |> all_enqueued()
    |> Enum.filter(&(&1.args["event"] == "susu_deadline_warning"))
  end

  setup do
    store = create_store!()
    %{store: store}
  end

  # ── 7-day-quiet nudge ────────────────────────────────────────────

  describe "perform/1 — 7-day-quiet nudge" do
    test "nudges a plan whose last contribution is 7+ days old", %{store: store} do
      plan = active_plan_with_last_contribution!(store, 8)

      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})

      assert_enqueued(
        worker: SusuNotificationWorker,
        args: %{"susu_plan_id" => plan.id, "event" => "susu_nudge"}
      )

      assert reload_plan(plan).last_nudged_at
    end

    test "does not nudge a plan whose last contribution is recent", %{store: store} do
      plan = active_plan_with_last_contribution!(store, 2)

      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})

      assert all_enqueued(worker: SusuNotificationWorker) == []
      refute reload_plan(plan).last_nudged_at
    end

    test "nudges exactly once across repeated runs (dedup via last_nudged_at)", %{store: store} do
      active_plan_with_last_contribution!(store, 10)

      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})
      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})

      jobs =
        [worker: SusuNotificationWorker]
        |> all_enqueued()
        |> Enum.filter(&(&1.args["event"] == "susu_nudge"))

      assert length(jobs) == 1
    end
  end

  # ── Deadline warnings ────────────────────────────────────────────

  describe "perform/1 — deadline warnings" do
    test "warns once at the 7-day window", %{store: store} do
      plan = active_plan_with_deadline!(store, DateTime.add(DateTime.utc_now(), 5, :day))

      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})

      assert_enqueued(
        worker: SusuNotificationWorker,
        args: %{"susu_plan_id" => plan.id, "event" => "susu_deadline_warning"}
      )

      updated = reload_plan(plan)
      assert updated.warned_7d_at
      refute updated.warned_1d_at
    end

    test "warns once at the 1-day window, and NOT the 7-day window (non-overlapping)", %{
      store: store
    } do
      plan = active_plan_with_deadline!(store, DateTime.add(DateTime.utc_now(), 12, :hour))

      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})

      assert length(deadline_warning_jobs()) == 1

      updated = reload_plan(plan)
      refute updated.warned_7d_at
      assert updated.warned_1d_at
    end

    test "warns exactly once across repeated runs (dedup via warned_7d_at)", %{store: store} do
      active_plan_with_deadline!(store, DateTime.add(DateTime.utc_now(), 4, :day))

      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})
      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})

      assert length(deadline_warning_jobs()) == 1
    end

    # Both dedup timestamps get set correctly as the deadline approaches
    # across two sweep runs. (Not asserting on `all_enqueued` job COUNT
    # here: `SusuNotificationWorker`'s `unique: [period: 600, fields:
    # [:args]]` collapses the two dispatches into one Oban row when they
    # land within the same 10-minute window — as they do back-to-back in
    # this test — even though each still marks its own dedup flag. In
    # production the two runs are a real day apart, well outside that
    # window, so this never happens there.)
    test "fires both windows independently as the deadline gets closer", %{store: store} do
      plan = active_plan_with_deadline!(store, DateTime.add(DateTime.utc_now(), 5, :day))

      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})
      assert reload_plan(plan).warned_7d_at

      updated = force_deadline!(reload_plan(plan), DateTime.add(DateTime.utc_now(), 12, :hour))
      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})

      final = reload_plan(updated)
      assert final.warned_7d_at
      assert final.warned_1d_at
    end

    test "does not warn once the deadline has already passed", %{store: store} do
      plan = active_plan_with_deadline!(store, DateTime.add(DateTime.utc_now(), -1, :hour))

      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})

      assert deadline_warning_jobs() == []

      updated = reload_plan(plan)
      refute updated.warned_7d_at
      refute updated.warned_1d_at
    end
  end

  describe "perform/1 — ignores non-active plans" do
    test "a :pending plan is never nudged or warned", %{store: store} do
      create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

      assert :ok = SusuNudgeWorker.perform(%Oban.Job{})

      assert all_enqueued(worker: SusuNotificationWorker) == []
    end
  end
end
