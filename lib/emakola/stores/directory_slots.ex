defmodule Emakola.Stores.DirectorySlots do
  @moduledoc """
  Assigns eligible shops to the directory's four featured slots.

  Money and staff taste can change the order INSIDE a slot; neither can
  change eligibility. That is the whole product decision: the floor
  (`DirectoryEligibility`) bars a shop from every slot including the paid
  one, and nothing in this module can readmit it.

  Precedence, applied in order:

    1. Ineligible → no slot, whatever the score, pin or payment.
    2. `override_excluded` → no slot. A safety decision.
    3. A live pin (`override_slot` with `override_until` unset or in the
       future) → that slot, at its head, bypassing the starvation minimums
       — staff said show it, so it shows.
    4. Otherwise computed: staff picks fill `:editors_pick`, young shops
       fill `:rising`, and everyone left competes for `:spotlight` on
       merit.

  Starvation is handled per slot, not papered over:

    * `:spotlight` never hides while anyone is eligible — an empty hero is
      a broken page, so it backfills from the whole eligible pool.
    * `:rising` hides below #{4} computed members rather than padding with
      old shops. A "new shops" rail full of veterans is a lie to the
      shopper and destroys the slot's only value.
    * `:editors_pick` hides below #{3}; its shops fall back into the
      spotlight pool rather than vanishing.
    * `:promoted` is written in its final form — eligible, paid, ordered
      by weight — and returns `[]` until something actually sells
      placement. Payment can never override eligibility, because the
      eligibility check runs first and this function cannot be reached
      around it.

  `partition_slots?: false` suspends rule 4's categories: staff picks and
  young shops stop getting slots of their own and compete for the spotlight
  like everyone else. It travels with the eligibility floor's platform switch
  (`Emakola.Stores.featuring_floor_enforced?/0`), because a directory young
  enough to need the floor suspended is one where `young?` is true of nearly
  every shop — the growth rail swallows the population and the hero is left
  with a handful of veterans. In production that meant 34 of 41 live shops
  went to `:rising`, a slot /stores does not render, and one photo-bearing
  shop was left to fill a five-shop spotlight. The categories return
  untouched the day the floor does — which re-creates that starved hero
  unless `:rising` and `:editors_pick` have somewhere to render by then.
  Today /stores reads `:spotlight` alone, so those two slots are written to
  a cache no page displays.

  Pure: entries in, `%{spotlight: [...], rising: [...], editors_pick:
  [...], promoted: [...]}` out. Ordering is deterministic — score
  descending, then name — so the page does not reshuffle between
  identical runs.
  """

  @spotlight_target 6
  @rising_minimum 4
  @editors_minimum 3

  @type entry :: %{
          required(:id) => term(),
          required(:name) => String.t(),
          required(:eligible?) => boolean(),
          required(:score) => integer(),
          required(:young?) => boolean(),
          required(:staff_pick?) => boolean(),
          required(:override_slot) => atom() | nil,
          required(:override_excluded) => boolean(),
          required(:override_until) => DateTime.t() | nil,
          required(:paid_weight) => integer(),
          required(:paid_until) => DateTime.t() | nil
        }

  @spec assign([entry()], DateTime.t(), keyword()) :: %{atom() => [entry()]}
  def assign(entries, %DateTime{} = now, opts \\ []) do
    partition? = Keyword.get(opts, :partition_slots?, true)

    admitted =
      entries
      |> Enum.filter(& &1.eligible?)
      |> Enum.reject(& &1.override_excluded)

    {pinned, unpinned} = Enum.split_with(admitted, &live_pin?(&1, now))
    pins_by_slot = Enum.group_by(pinned, & &1.override_slot)

    {picks, rest} = Enum.split_with(unpinned, & &1.staff_pick?)
    {young, pool} = Enum.split_with(rest, & &1.young?)

    editors = if partition? and length(picks) >= @editors_minimum, do: picks, else: []
    rising = if partition? and length(young) >= @rising_minimum, do: young, else: []

    # Shops whose slot starved fall back into the spotlight pool — they are
    # eligible, so they compete on merit like everyone else.
    spotlight_pool = pool ++ (picks -- editors) ++ (young -- rising)

    %{
      spotlight:
        build(pins_by_slot, :spotlight, Enum.take(rank(spotlight_pool), @spotlight_target)),
      rising: build(pins_by_slot, :rising, rank(rising)),
      editors_pick: build(pins_by_slot, :editors_pick, rank(editors)),
      promoted: build(pins_by_slot, :promoted, promoted(admitted -- pinned, now))
    }
  end

  # ── Internals ──────────────────────────────────────────────────────────

  defp live_pin?(%{override_slot: nil}, _now), do: false
  defp live_pin?(%{override_until: nil}, _now), do: true

  defp live_pin?(%{override_until: until}, now),
    do: DateTime.compare(until, now) == :gt

  # Pins lead their slot; computed members follow. Both halves keep the
  # deterministic score-then-name order among themselves.
  defp build(pins_by_slot, slot, computed) do
    rank(Map.get(pins_by_slot, slot, [])) ++ computed
  end

  # The paid branch in its final form, so the first person to wire billing
  # cannot accidentally let payment outrank the eligibility filter that
  # already ran. Nothing sets paid_until today, so this is [].
  defp promoted(entries, now) do
    entries
    |> Enum.filter(fn entry ->
      is_struct(entry.paid_until, DateTime) and DateTime.compare(entry.paid_until, now) == :gt
    end)
    |> Enum.sort_by(fn entry -> {-entry.paid_weight, -entry.score, entry.name} end)
  end

  defp rank(entries), do: Enum.sort_by(entries, fn entry -> {-entry.score, entry.name} end)
end
