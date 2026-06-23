# Merchant Onboarding Health — Design

## Context

The platform owner has no view of where merchants are in setup — who's stuck before
they can sell, and where activation drops off. This is the first of three remaining
platform-admin features the user picked (the others — fraud/abuse monitoring, refund &
dispute oversight — follow in their own spec→plan→build cycles). It's sequenced first
because it's a **pure read over data already modeled** (`Store`, `Catalog.Product`,
`StorePayoutAccount`, `StoreVerification`, `Orders`) — no new persistence, useful with
any number of merchants, and aligned with the revenue-first activation lens (spot
merchants stuck before payout setup).

**Decisions made with the user (brainstorming):**
1. **Scope:** read-only health view **+ aggregate funnel analytics** (no nudge actions — deferred).
2. **Milestones (per store; "store created" is the implicit step 0):** Products added · Storefront live · Payout registered · KYC verified · First order.
3. **Permission:** reuse `:manage_merchants` (no new permission).
4. **Compute strategy:** set-based queries in a service module (approach A) — no N+1, no schema change.

Branch: `feature/merchant-onboarding-health`. TDD throughout (≥90% on new code).

## Milestones

Per store, each milestone is a boolean:
- **products** — `Catalog.Product` count for the store > 0
- **live** — `store.active == true and store.status == :active`
- **payout** — a `StorePayoutAccount` row exists for the store
- **kyc** — a `StoreVerification` with `status == :approved` for the store
- **first_order** — `Orders` count for the store > 0

`completed` = count of true milestones (0..5). Canonical display order: products → live →
payout → kyc → first_order (rough setup sequence; the funnel shows drop-off along it).

## Architecture — set-based service module (approach A)

`Emakola.Platform.Onboarding.overview/0` runs a handful of queries (NOT per-store):
- All stores (id, name, slug, active, status, inserted_at) via `list_for_admin` (or the base read), `authorize?: false`.
- The **set of store_ids** qualifying for each milestone:
  - products: distinct `store_id` from `Catalog.Product`
  - payout: `store_id` from `StorePayoutAccount`
  - kyc: `store_id` from `StoreVerification` where `status == :approved`
  - first_order: distinct `store_id` from `Orders`
  - live: computed in-memory from each store's `active`/`status`
- Then per store, milestone booleans = set membership (`MapSet`). Funnel totals = set sizes
  (live counted in-memory).

Returns:
```
%{
  total_stores: integer,
  funnel: %{products: n, live: n, payout: n, kyc: n, first_order: n},
  stores: [%{id, name, slug, milestones: %{products: bool, live: bool, payout: bool, kyc: bool, first_order: bool}, completed: 0..5}]
}
```

Rejected — **B (per-store loop, N+1)**: 5 queries × N stores; simple but scales badly.
Rejected — **C (denormalized columns on Store)**: fastest reads but adds write-path
coupling + a migration to keep fresh; premature.

The "distinct store_ids" reads: prefer existing domain interfaces / `Ash.read` + map+uniq
in memory (Ghana-scale data is small). If a resource lacks a convenient read, add a small
read action returning `store_id` only — keep queries in the resource, not the LiveView.

## Page — `/platform/onboarding` (`EmakolaWeb.Platform.OnboardingLive`)

In `live_session :platform`. `on_mount {RequirePermission, :manage_merchants}`. Iron Law
#1: no DB on disconnected mount — loading shell, load via `Onboarding.overview/0` only when
`connected?`.

- **Funnel (top):** one row per milestone in canonical order — label, count, and % of
  `total_stores`, drawn as a horizontal bar. Descending-ish bars make the drop-off visible.
- **Per-store table (below):** name (link to `/platform/stores/:id`), a ✓/✗ chip per
  milestone, and `completed/5`. Sorted **least-complete first** so stuck merchants surface.
- **Filter toggle:** "incomplete only" (`completed < 5`).
- **Nav:** "Onboarding" link in the platform sidebar (gated `:manage_merchants`).

## Files

- `lib/emakola/platform/onboarding.ex` (new service)
- `lib/emakola_web/live/platform/onboarding_live.ex` (new)
- `lib/emakola_web/router.ex` (route in `:platform`)
- `lib/emakola_web/components/layouts/platform.html.heex` (nav link)
- Tests for the service + LiveView.

## Build sequence (tests → impl → green)

1. `Emakola.Platform.Onboarding.overview/0` → service test: a store with none/some/all
   milestones yields correct `milestones`/`completed`; `funnel` counts == set sizes;
   `total_stores` counts every store; `live` reflects active+status. Fixtures via factories +
   the real `archive_store` / payout-create / verification-approve / product / order helpers.
2. `OnboardingLive` + route + nav → LiveView test: renders funnel + rows; permission gating
   (non-`:manage_merchants` redirected); "incomplete only" filter; loading shell.
3. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`, and
   `mix test --warnings-as-errors` on the new test files (CI parity — catches unused
   defaults/clauses that plain `mix test` misses).

## Verification

Automated: service test (milestone truth table + funnel counts), LiveView test (render +
gating + filter). Suite green + format + credo + own-files-warning-clean.

Manual: as platform owner open `/platform/onboarding` → funnel shows per-milestone counts;
table lists stores least-complete first; "incomplete only" filters; a store row links to its
detail page.

## Out of scope (v1)

Nudge actions (email/SMS the stuck merchant); time-based "stale/at-risk" thresholds;
historical funnel trends over time; CSV export; per-step timestamps ("time to first order").
