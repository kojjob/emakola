defmodule Emakola.Payments.Workers.SusuExpiryWorker do
  @moduledoc """
  Hourly cron sweep (TC-3 Task 6) — the deadline half of susu lay-away's
  expiry/cancel engine, mirroring `ProtectionSweepWorker`'s exact cron
  shape (`use Oban.Worker, ..., unique: [period: 3600, fields: [:args]]`,
  registered in `config/config.exs`'s `Oban.Plugins.Cron` crontab).

  Two independent sweep duties, both funnelling into
  `Emakola.Orders.SusuLifecycle`'s one convergent end-of-life path:

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

  Idempotent by construction, the same shrinking-due-set reasoning
  `ProtectionSweepWorker` documents: once a plan expires or cancels it is
  no longer `:active`, so it drops out of both queries above, and a
  re-run (the next hourly tick, an Oban retry) touches it again only if
  the database still says it's due — nothing here is re-applied.

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

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    due_expiring_plans() |> Enum.each(&expire_plan/1)
    sweep_takedowns()
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
    :ok
  rescue
    error -> log_error("expire", plan.id, error, __STACKTRACE__)
  end

  # -- Takedown auto-cancel -----------------------------------------------

  defp sweep_takedowns do
    plans = active_catalog_plans()
    variants = variants_by_id(plans)

    Enum.each(plans, fn plan ->
      case Map.get(variants, plan.variant_id) do
        %{product: product} -> if product_unavailable?(product), do: cancel_taken_down(plan)
        _ -> :ok
      end
    end)
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
    :ok
  rescue
    error -> log_error("takedown-cancel", plan.id, error, __STACKTRACE__)
  end

  defp log_error(step, plan_id, error, stacktrace) do
    Logger.error(
      "[susu_expiry] #{step} failed for plan=#{plan_id}: " <>
        Exception.format(:error, error, stacktrace)
    )
  end
end
