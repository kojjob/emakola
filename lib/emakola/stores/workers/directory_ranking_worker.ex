defmodule Emakola.Stores.Workers.DirectoryRankingWorker do
  @moduledoc """
  The nightly run that decides who is featured.

  Loads every live store with all thirteen merit signals in one query,
  evaluates the floor (`DirectoryEligibility`) and the score
  (`DirectoryScore`) per store, assigns slots across the population
  (`DirectorySlots`), and writes the verdicts — standings upserted, Store
  cache columns updated — in one transaction.

  O(a handful of queries), never O(stores): one batch read of the audit log
  for conduct marks, one stream of the population with aggregate subqueries,
  one read of existing standings for overrides, two bulk writes. The
  n-plus-one suite holds the line on the signal load.

  Idempotent by construction: pure functions over the same inputs plus an
  identity upsert produce identical rows, so a re-run after a crash is safe.
  Cron-driven at 02:30 UTC (config.exs), matching every other poller here —
  no worker in this codebase uses `{:snooze, _}`.

  Expired pins are cleared here — the nightly run is when an editorial
  decision quietly lapses back to the computed answer — and each clearance
  is audited as :directory_override_expired so the Directory Studio
  timeline explains why a pin vanished overnight.
  """

  use Oban.Worker, queue: :default, max_attempts: 1

  require Ash.Query

  alias Emakola.Stores.DirectoryEligibility
  alias Emakola.Stores.DirectoryScore
  alias Emakola.Stores.DirectorySlots
  alias Emakola.Stores.DirectoryStanding
  alias Emakola.Stores.Workers.DirectoryRankingWorker.DropEmail
  alias Emakola.Stores.Store

  # A shop is "young" — eligible for the rising slot — for its first month.
  @young_days 30

  @conduct_actions [:store_suspended, :store_blocked]
  @conduct_window_days 180

  @signals [
    :product_count,
    :delivered_order_count_90d,
    :cancelled_order_count_90d,
    :last_order_at,
    :last_product_published_at,
    :successful_payment_count_90d,
    :refunded_payment_count_90d,
    :taken_down_product_count_90d,
    :verified_review_count,
    :verified_review_rating_sum,
    :merchant_fault_return_count_90d,
    :staff_refunded_hold_count_90d,
    :payout_verified,
    :kyc_approved
  ]

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()
    clear_expired_pins!(now)
    conduct_marks = conduct_marks(now)
    overrides = existing_overrides()

    verdicts =
      Store
      |> Ash.Query.filter(active == true and status == :active)
      |> Ash.Query.load(@signals)
      |> Ash.stream!(authorize?: false, batch_size: 500)
      |> Enum.map(&assess(&1, conduct_marks, overrides, now))

    slots = verdicts |> Enum.map(& &1.entry) |> DirectorySlots.assign(now)

    slot_by_id =
      for {slot, entries} <- slots, entry <- entries, into: %{} do
        {entry.id, slot}
      end

    write!(verdicts, slot_by_id, now)
    notify_drops(verdicts, overrides)
    :ok
  end

  # A shop that HELD eligibility and lost it tonight gets told why, once.
  # First assessments and shops staying ineligible are not news. Runs after
  # the transaction commits — a mail failure never rolls back a verdict.
  defp notify_drops(verdicts, previous) do
    Enum.each(verdicts, fn verdict ->
      was_eligible? = get_in(previous, [verdict.store.id, :eligible]) == true

      if was_eligible? and not verdict.eligible? do
        DropEmail.send_drop(verdict.store, verdict.disqualifiers)
      end
    end)
  end

  # ── Assessment ─────────────────────────────────────────────────────────

  defp assess(store, conduct_marks, overrides, now) do
    conduct_flagged? = MapSet.member?(conduct_marks, store.id)

    {eligible?, disqualifiers} =
      DirectoryEligibility.evaluate(
        %{
          logo_url: store.logo_url,
          cover_image_url: store.cover_image_url,
          tagline: store.tagline,
          description: store.description,
          contact_phone: store.contact_phone,
          whatsapp_number: store.whatsapp_number,
          contact_email: store.contact_email,
          region: store.region,
          product_count: store.product_count,
          payout_verified?: store.payout_verified,
          inserted_at: store.inserted_at,
          last_product_published_at: store.last_product_published_at,
          last_order_at: store.last_order_at,
          taken_down_products_90d: store.taken_down_product_count_90d,
          conduct_flagged?: conduct_flagged?
        },
        now
      )

    {score, breakdown} =
      DirectoryScore.compute(%{
        delivered_orders_90d: store.delivered_order_count_90d,
        cancelled_orders_90d: store.cancelled_order_count_90d,
        successful_payments_90d: store.successful_payment_count_90d,
        refunded_payments_90d: store.refunded_payment_count_90d,
        review_count: store.verified_review_count,
        review_rating_sum_centi: (store.verified_review_rating_sum || 0) * 100,
        product_count: store.product_count,
        days_since_last_publish: days_since(store.last_product_published_at, now),
        kyc_approved?: store.kyc_approved,
        taken_down_products_90d: store.taken_down_product_count_90d,
        merchant_fault_returns_90d: store.merchant_fault_return_count_90d,
        staff_refunded_holds_90d: store.staff_refunded_hold_count_90d
      })

    override = Map.get(overrides, store.id, %{})

    %{
      store: store,
      eligible?: eligible?,
      disqualifiers: disqualifiers,
      score: score,
      breakdown: breakdown,
      entry: %{
        id: store.id,
        name: store.name,
        eligible?: eligible?,
        score: score,
        young?: DateTime.diff(now, store.inserted_at, :day) <= @young_days,
        staff_pick?: store.featured,
        override_slot: Map.get(override, :override_slot),
        override_excluded: Map.get(override, :override_excluded, false),
        override_until: Map.get(override, :override_until),
        paid_weight: Map.get(override, :paid_placement_weight, 0),
        paid_until: Map.get(override, :paid_placement_until)
      }
    }
  end

  defp days_since(nil, _now), do: nil
  defp days_since(stamp, now), do: DateTime.diff(now, stamp, :day)

  # ── Batch reads ────────────────────────────────────────────────────────

  # One jsonb query over the whole population's conduct history — plain SQL,
  # like StoreVisits, because the audit log's read actions are paginated for
  # humans and this is a batch fold. Suspensions and blocks leave a mark for
  # 180 days even after reactivation.
  defp conduct_marks(now) do
    import Ecto.Query, only: [from: 2]

    since = DateTime.add(now, -@conduct_window_days, :day)
    actions = Enum.map(@conduct_actions, &Atom.to_string/1)

    from(l in "platform_audit_logs",
      where: l.action in ^actions and l.inserted_at > ^since,
      where: not is_nil(fragment("? ->> 'store_id'", l.metadata)),
      select: fragment("? ->> 'store_id'", l.metadata)
    )
    |> Emakola.Repo.all()
    |> MapSet.new()
  end

  # An expired pin lapses back to the computed answer, audited so the
  # timeline explains why it vanished overnight.
  defp clear_expired_pins!(now) do
    DirectoryStanding
    |> Ash.Query.filter(not is_nil(override_slot) and override_until < ^now)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn standing ->
      standing
      |> Ash.Changeset.for_update(:override, %{override_slot: nil, override_until: nil})
      |> Ash.update!(authorize?: false)

      Emakola.Accounts.PlatformAudit.log(:directory_override_expired, nil, %{
        "store_id" => standing.store_id,
        "expired_slot" => standing.override_slot && Atom.to_string(standing.override_slot)
      })
    end)
  end

  defp existing_overrides do
    DirectoryStanding
    |> Ash.read!(authorize?: false)
    |> Map.new(fn standing ->
      {standing.store_id,
       Map.take(standing, [
         :eligible,
         :override_slot,
         :override_excluded,
         :override_until,
         :paid_placement_weight,
         :paid_placement_until
       ])}
    end)
  end

  # ── The write ──────────────────────────────────────────────────────────

  defp write!(verdicts, slot_by_id, now) do
    Emakola.Repo.transaction(fn ->
      Enum.each(verdicts, fn verdict ->
        slot = Map.get(slot_by_id, verdict.store.id)

        DirectoryStanding
        |> Ash.Changeset.for_create(:record, %{
          store_id: verdict.store.id,
          eligible: verdict.eligible?,
          disqualifiers: verdict.disqualifiers,
          score: verdict.score,
          score_breakdown: verdict.breakdown,
          slot: slot,
          computed_at: now
        })
        |> Ash.create!(authorize?: false)

        verdict.store
        |> Ash.Changeset.for_update(:set_directory_standing, %{
          directory_eligible: verdict.eligible?,
          directory_score: verdict.score,
          directory_slot: slot
        })
        |> Ash.update!(authorize?: false)
      end)
    end)
  end
end
