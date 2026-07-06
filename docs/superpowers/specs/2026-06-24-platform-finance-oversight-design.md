# Platform Finance Oversight Page — Design

## Context

The revenue rails (platform transaction fee, dropship margin split) now produce
`PaymentSplit` rows with `role: :platform` (fees the platform keeps) and `role: :merchant`
(merchant net). Nothing surfaces this money to the platform owner. This page is the
**money/revenue view** for platform staff.

It is distinct from the two existing pages:
- `/platform/payments` (`Platform.PaymentLive.Index`) — transaction *ops* (success rate,
  gateway breakdown, failed/refund worklists).
- `/platform/billing` (`Platform.BillingLive`) — legacy Stripe *subscription* billing (USD),
  unrelated to platform fees.

New page: `/platform/finance` (`Platform.FinanceLive`), gated `:manage_billing` (same as the
other two). No new resources, no migration.

Branch: `feature/platform-finance-oversight`. TDD throughout.

## Key concepts (confirmed with the user)

- **Platform fees collected** = `sum(PaymentSplit.amount where role == :platform)`. Covers the
  2% normal-order fee and the 10% dropship margin fee.
- **Outstanding payout owed** = `sum(Payment.amount where status == :success and
  split_mode == :none)`, per store. With split-at-source, a merchant on a split order is paid
  directly by Paystack — the platform owes nothing. The only money the platform holds and owes
  is from **un-split** successful orders (the manual-payout backlog). Initially this ≈ total
  historical GMV (no merchant has a subaccount yet); that is correct and is exactly the
  liability the rails eliminate going forward.

## Data layer — `Emakola.Platform.FinanceStats` (new module)

A dedicated module (keeps `Platform.Stats` under the ~200-line guideline). All reads
`authorize?: false`; both `Payment` and `PaymentSplit` are `global?: true`, so cross-store
aggregation needs no tenant. Money returned as integer minor units (display formats in the
LiveView).

- `total_platform_fees/0` → `PaymentSplit |> filter(role == :platform) |> Ash.sum(:amount)`
  (0 when none).
- `total_outstanding_payouts/0` →
  `Payment |> filter(status == :success and split_mode == :none) |> Ash.sum(:amount)` (0 when none).
- `per_store_finance/0` → one row per store that has fees **or** outstanding, sorted by
  `outstanding_owed` desc:
  `%{store: %Store{}, fees_collected: int, outstanding_owed: int, payouts_ready?: bool}`.
  Implementation reads three small sets once (no N+1) and groups in Elixir:
  - platform-fee splits → sum amount by `store_id`,
  - un-split successful payments → sum amount by `store_id`,
  - verified payout accounts → MapSet of `store_id` (`verification_status == :verified` and
    `subaccount_code` present) for the `payouts_ready?` flag.
  Stores that fail to load (defensively) are filtered out.

GMV reuses the existing `Platform.Stats.total_gmv/0`. The effective take rate (fees ÷ GMV) is
derived in the LiveView (presentation), guarding divide-by-zero.

**Currency caveat (v1):** amounts are summed across stores regardless of currency and displayed
as GHS — matching the existing `Stats.total_gmv` behavior (Ghana-only launch). Multi-currency
breakdown is deferred.

## Web layer — `EmakolaWeb.Platform.FinanceLive`

- Route: `live "/platform/finance", Platform.FinanceLive` inside the `:platform` live_session,
  `on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}`.
- **Iron Law #1:** no DB on disconnected mount — render a loading shell; load via
  `FinanceStats` only when `connected?(socket)` (mirror `PaymentLive.Index`).
- Render (reuse the Makola Admin design language — `PlatformComponents.stat_tile`,
  `page_header`, `rounded-2xl` cards, status pills, empty state):
  - Stat strip (4 tiles): Platform fees collected, GMV, Effective take rate (%), Outstanding
    merchant payouts.
  - Per-store finance table: Store | Fees collected | Outstanding owed | Payouts set up?
    (a green "Ready" pill vs an amber "No payout set up" pill from `payouts_ready?`).
  - Empty state when there are no stores with finance activity.
- Add a "Finance" link to the platform sidebar nav (with the existing `active_nav` pattern).

## Build sequence (tests → impl → green)

1. `FinanceStats` → unit tests (DataCase): no data → zeros / empty list; a platform-fee split →
   counted in `total_platform_fees` and the store's `fees_collected`; an un-split successful
   payment → counted in `total_outstanding_payouts` and the store's `outstanding_owed`; a split
   (`:platform_fee`/`:dropship_split`) payment → **not** counted as outstanding; `payouts_ready?`
   true only with a verified subaccount; rows sorted by outstanding desc.
2. `FinanceLive` + route + sidebar link → LiveView tests (`setup_platform_staff`): renders the
   stat strip and a store row with its fees/outstanding; staff without `:manage_billing`
   redirected; empty state with no data; Iron-Law-1 loading shell on disconnected mount.
3. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`, new files clean
   under `--warnings-as-errors`. PR.

## Out of scope (v1)
Settlement-status flipping (`:pending → :settled` — the deferred payout-execution engine; nothing
flips splits yet), time-series charts, supplier-balance view, CSV export, per-currency breakdown,
per-store drill-down page.
