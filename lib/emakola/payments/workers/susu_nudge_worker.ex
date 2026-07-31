defmodule Emakola.Payments.Workers.SusuNudgeWorker do
  @moduledoc """
  Daily cron sweep (TC-3 Task 8) — nudges active susu plans that have gone
  quiet, and warns buyers as their plan's deadline approaches. Mirrors
  `SusuExpiryWorker`'s exact cron shape and per-plan failure isolation
  (one plan's raise is logged and does not stop the rest of the sweep).

  Two independent, dedup'd duties over every `:active` plan:

    1. **7-day-quiet nudge** — a plan whose most recent COUNTED
       contribution is 7+ days old gets ONE `:susu_nudge` SMS, ever
       (`SusuPlan.last_nudged_at` is the dedup guard, set only AFTER a
       successful dispatch — a failed send is retried on the next day's
       run instead of being silently marked done).
    2. **Deadline warnings** — `:susu_deadline_warning` fires once when
       the deadline is 2-7 days away (`warned_7d_at`) and once more when
       it's 0-1 days away (`warned_1d_at`). The two windows are
       non-overlapping by construction, so a plan created with a very
       short deadline gets exactly ONE of the two on its first sweep, not
       both at once. Both are skipped once the deadline has already
       passed — `SusuExpiryWorker`'s hourly sweep handles that plan next
       as a genuine expiry, and "your deadline is in N days" would be
       nonsensical once N is negative.
  """

  use Oban.Worker, queue: :notifications, max_attempts: 3, unique: [period: 3600, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Dispatcher
  alias Emakola.Orders.SusuPlan
  alias Emakola.Payments.Payment

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()
    plans = active_plans()

    nudge_due_plans(plans, now)
    Enum.each(plans, &warn_plan(&1, now))

    :ok
  end

  defp active_plans do
    SusuPlan
    |> Ash.Query.filter(status == :active)
    |> Ash.read!(authorize?: false)
  end

  # -- 7-day-quiet nudge --------------------------------------------------

  defp nudge_due_plans(plans, now) do
    candidates = Enum.filter(plans, &is_nil(&1.last_nudged_at))
    last_activity = last_contribution_at_by_plan(Enum.map(candidates, & &1.id))

    Enum.each(candidates, fn plan ->
      last = Map.get(last_activity, plan.id, plan.inserted_at)

      if not is_nil(last) and DateTime.diff(now, last, :day) >= 7 do
        nudge_plan(plan)
      end
    end)
  end

  # Batched (not one query per plan) — the most recent COUNTED contribution
  # per candidate plan, in one query. `metadata["susu_counted"]` filtering
  # happens in Elixir, same as `SusuCompletion.load_contributions/1` — the
  # candidate set here is every quiet active plan, small in practice.
  defp last_contribution_at_by_plan([]), do: %{}

  defp last_contribution_at_by_plan(plan_ids) do
    Payment
    |> Ash.Query.filter(susu_plan_id in ^plan_ids)
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&counted?/1)
    |> Enum.group_by(& &1.susu_plan_id)
    |> Map.new(fn {plan_id, payments} ->
      {plan_id, payments |> Enum.map(& &1.inserted_at) |> Enum.max(DateTime)}
    end)
  end

  defp counted?(%Payment{metadata: metadata}),
    do: Map.get(metadata || %{}, "susu_counted") == true

  defp nudge_plan(plan) do
    case Dispatcher.dispatch_susu(plan, :susu_nudge) do
      {:ok, _job} ->
        plan |> Ash.Changeset.for_update(:mark_nudged, %{}) |> Ash.update!(authorize?: false)

      {:error, reason} ->
        Logger.error("[susu_nudge] nudge dispatch failed for plan=#{plan.id}: #{inspect(reason)}")
    end
  rescue
    error -> log_error("nudge", plan.id, error, __STACKTRACE__)
  end

  # -- Deadline warnings ----------------------------------------------------

  defp warn_plan(plan, now) do
    maybe_warn(plan, now, plan.warned_7d_at, 2, 7, :mark_warned_7d)
    maybe_warn(plan, now, plan.warned_1d_at, 0, 1, :mark_warned_1d)
  rescue
    error -> log_error("deadline-warning", plan.id, error, __STACKTRACE__)
  end

  defp maybe_warn(plan, now, dedup_timestamp, min_days, max_days, mark_action) do
    if is_nil(dedup_timestamp) and due_for_warning?(plan.deadline, now, min_days, max_days) do
      case Dispatcher.dispatch_susu(plan, :susu_deadline_warning) do
        {:ok, _job} ->
          plan |> Ash.Changeset.for_update(mark_action, %{}) |> Ash.update!(authorize?: false)

        {:error, reason} ->
          Logger.error(
            "[susu_nudge] deadline warning dispatch failed for plan=#{plan.id}: #{inspect(reason)}"
          )
      end
    end
  end

  defp due_for_warning?(deadline, now, min_days, max_days) do
    if DateTime.compare(deadline, now) == :gt do
      days_left = DateTime.diff(deadline, now, :day)
      days_left <= max_days and days_left >= min_days
    else
      false
    end
  end

  defp log_error(step, plan_id, error, stacktrace) do
    Logger.error(
      "[susu_nudge] #{step} failed for plan=#{plan_id}: " <>
        Exception.format(:error, error, stacktrace)
    )
  end
end
