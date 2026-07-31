defmodule Emakola.Payments.Workers.SusuExpiryWorker do
  @moduledoc """
  Hourly cron sweep (TC-3 Task 6) — the deadline half of susu lay-away's
  expiry/cancel engine, mirroring `ProtectionSweepWorker`'s exact cron
  shape (`use Oban.Worker, ..., unique: [period: 3600, fields: [:args]]`,
  registered in `config/config.exs`'s `Oban.Plugins.Cron` crontab).

  Three independent sweep duties, all funnelling into
  `Emakola.Orders.SusuLifecycle`'s one convergent end-of-life path (the
  first two) or its underlying refund engine directly (the third):

    1. **Deadline expiry** — every `:active` plan whose `deadline` has
       passed is expired (`SusuLifecycle.expire/1`), UNLESS it has an
       "in-flight" chunk: precisely, a `:pending` payment tied to the
       plan (a buyer mid-payment, gateway redirect not yet resolved).
       Expiring out from under that payment would strand it —
       `SusuChunks.confirm_chunk/1` already has a safety net for a chunk
       confirming against a dead plan (flags it for refund instead of
       counting it), but skipping here gives the buyer's already-started
       payment a chance to land normally first. Skipped plans are
       re-swept next run.

    2. **Takedown auto-cancel** (the spec's "product taken down mid-plan
       → auto-cancel + full refund + notify both" edge case) — every
       `:active` `:catalog` plan whose variant's product has been
       archived or moderation-taken-down is cancelled
       (`SusuLifecycle.cancel(plan, :takedown)`), using the same
       predicate `Emakola.Orders.CheckoutService`'s private
       `product_available?/1` uses at checkout (checkout_service.ex:412-414:
       `status: :archived` or `moderation_status != :ok` -> unavailable).
       Sweep-detected with hourly latency, not event-driven — the
       accepted v1 mechanism.

    3. **Stranded refund retry** (final-review finding: a released claim
       had no sweep covering it) — every ALREADY-terminal (`:expired` or
       `:cancelled`) plan with a `:success`, unclaimed payment gets
       `Emakola.Payments.SusuRefunds.refund_all_contributions/1` called on
       it again. Two ways a plan ends up here: (a) `converge/1`'s refund
       attempt hit a transient gateway error and released its claim (see
       `SusuRefunds`'s moduledoc — nothing previously retried that), or
       (b) a chunk payment's webhook confirms LATE, after the plan already
       went terminal — `SusuChunks.confirm_chunk/1`'s own guard flags it
       for refund instead of counting it, but never claims or refunds it.
       Both leave a `:success` payment sitting unclaimed on a plan nothing
       else will ever touch again. Deliberately EXCLUDES plans duties 1
       and 2 JUST transitioned this same run (their `converge/1` call
       already attempted the refund once) — only plans that were ALREADY
       terminal before this tick started are eligible, so a same-tick
       transient failure is retried on the NEXT hourly run, not
       immediately re-attempted in a tight loop within one tick.

  Idempotent by construction, the same shrinking-due-set reasoning
  `ProtectionSweepWorker` documents: once a plan expires or cancels it is
  no longer `:active`, so it drops out of duties 1 and 2's queries, and a
  re-run (the next hourly tick, an Oban retry) touches it again only if
  the database still says it's due — nothing here is re-applied. Duty 3
  is idempotent by the same claim discipline `SusuRefunds` itself
  documents: an already-claimed or already-`:refunded` payment is skipped,
  so re-sweeping a plan whose refund already succeeded is a no-op.

  A single plan's failure (an unexpected raise — not an ordinary business
  outcome, which `SusuLifecycle`'s callees already handle without
  raising) is logged and does not stop the rest of the sweep, the same
  discipline `SusuChunks`'s `guarded_*` helpers use.
  """

  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 3600, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Catalog.Variant
  alias Emakola.Orders.SusuLifecycle
  alias Emakola.Orders.SusuPlan
  alias Emakola.Payments.Payment
  alias Emakola.Payments.SusuRefunds

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    expired_ids = due_expiring_plans() |> Enum.map(&expire_plan/1) |> Enum.reject(&is_nil/1)
    taken_down_ids = sweep_takedowns()
    sweep_stranded_refunds(expired_ids ++ taken_down_ids)
    :ok
  end

  # -- Deadline expiry ---------------------------------------------------

  defp due_expiring_plans do
    now = DateTime.utc_now()

    SusuPlan
    |> Ash.Query.filter(status == :active and deadline < ^now)
    |> Ash.read!(authorize?: false)
    |> Enum.reject(&in_flight_chunk?/1)
  end

  # "In-flight" is precisely: a :pending payment tied to this plan — a
  # chunk the buyer has started but the gateway hasn't confirmed yet.
  # `Ash.read!/2` + `Enum.any?/1` (a tolerant existence check), NOT
  # `read_one!` — `SusuChunks.initiate_chunk/4`'s own moduledoc documents
  # that two genuinely concurrent initiations can both pass the
  # one-pending-chunk guard and both reach the gateway, so more than one
  # `:pending` payment for the same plan is an accepted, real possibility,
  # not a bug. `read_one!` raises on >1 row — exactly the shape this race
  # produces — which would crash the whole sweep run (including
  # `sweep_takedowns/0`, never reached) over ONE racy plan. Matches
  # `active_catalog_plans/0`'s plain `Ash.read!` style.
  defp in_flight_chunk?(%SusuPlan{id: plan_id}) do
    Payment
    |> Ash.Query.filter(susu_plan_id == ^plan_id and status == :pending)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end

  defp expire_plan(plan) do
    SusuLifecycle.expire(plan)
    plan.id
  rescue
    error ->
      log_error("expire", plan.id, error, __STACKTRACE__)
      nil
  end

  # -- Takedown auto-cancel -----------------------------------------------

  defp sweep_takedowns do
    plans = active_catalog_plans()
    variants = variants_by_id(plans)

    plans
    |> Enum.map(fn plan ->
      case Map.get(variants, plan.variant_id) do
        %{product: product} -> if product_unavailable?(product), do: cancel_taken_down(plan)
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp active_catalog_plans do
    SusuPlan
    |> Ash.Query.filter(status == :active and type == :catalog)
    |> Ash.read!(authorize?: false)
  end

  # Batched (not one query per plan) — belongs_to lookups join, they don't
  # loop (Iron Law: separate queries for has_many, join for belongs_to).
  defp variants_by_id([]), do: %{}

  defp variants_by_id(plans) do
    variant_ids = plans |> Enum.map(& &1.variant_id) |> Enum.uniq()

    Variant
    |> Ash.Query.filter(id in ^variant_ids)
    |> Ash.Query.load(:product)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.id, &1})
  end

  # Mirrors `Emakola.Orders.CheckoutService`'s private `product_available?/1`
  # (checkout_service.ex:412-414) — inverted (this asks "unavailable?").
  defp product_unavailable?(%{status: :archived}), do: true
  defp product_unavailable?(%{moderation_status: moderation}), do: moderation != :ok
  defp product_unavailable?(_), do: false

  defp cancel_taken_down(plan) do
    SusuLifecycle.cancel(plan, :takedown)
    plan.id
  rescue
    error ->
      log_error("takedown-cancel", plan.id, error, __STACKTRACE__)
      nil
  end

  # -- Stranded refund retry ----------------------------------------------

  # `excluded_plan_ids` are the plans duties 1 and 2 JUST transitioned this
  # run — their own `converge/1` call already attempted a refund once, so
  # re-attempting them again in the SAME tick would just retry a fresh
  # transient failure immediately instead of on the next hourly run (see
  # moduledoc). Every other terminal plan with a stranded payment is fair
  # game regardless of how long ago it went terminal.
  defp sweep_stranded_refunds(excluded_plan_ids) do
    excluded = MapSet.new(excluded_plan_ids)

    stranded_plan_ids()
    |> Enum.reject(&MapSet.member?(excluded, &1))
    |> terminal_plans()
    |> Enum.each(&retry_stranded_refund/1)
  end

  # Broad load + Elixir filter (matches `SusuRefunds.claimed?/1`'s own
  # style) — Ash's filter DSL has no supported way to query into a jsonb
  # `metadata` column's keys, and no other call site in this codebase does
  # either (see `SusuCompletion.counted?/1`, `SusuRefunds.claimed?/1`).
  defp stranded_plan_ids do
    Payment
    |> Ash.Query.filter(status == :success and not is_nil(susu_plan_id))
    |> Ash.read!(authorize?: false)
    |> Enum.reject(&refund_claimed?/1)
    |> Enum.map(& &1.susu_plan_id)
    |> Enum.uniq()
  end

  defp refund_claimed?(%Payment{metadata: metadata}),
    do: Map.get(metadata || %{}, "susu_refund_claimed") == true

  defp terminal_plans([]), do: []

  defp terminal_plans(plan_ids) do
    SusuPlan
    |> Ash.Query.filter(id in ^plan_ids and status in [:expired, :cancelled])
    |> Ash.read!(authorize?: false)
  end

  defp retry_stranded_refund(plan) do
    SusuRefunds.refund_all_contributions(plan)
    :ok
  rescue
    error -> log_error("stranded-refund-retry", plan.id, error, __STACKTRACE__)
  end

  defp log_error(step, plan_id, error, stacktrace) do
    Logger.error(
      "[susu_expiry] #{step} failed for plan=#{plan_id}: " <>
        Exception.format(:error, error, stacktrace)
    )
  end
end
