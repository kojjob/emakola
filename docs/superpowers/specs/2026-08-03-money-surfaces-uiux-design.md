# Money Surfaces UI/UX — design spec

**Date:** 2026-08-03 · **Status:** pending Kojo review · **Owner:** Kojo
**Scope:** admin payouts, supplier ledger, platform finance, new /admin/earnings, accrual notifications. Stacks on `internal-settlement-p3` (#374).

## 1. Problem

The internal-settlement initiative built the money rails but its surfaces range from misleading to absent. Verified against the code (2026-08-03 exploration):

1. Payouts page can render **"GHS 0.00" to a merchant who has money** (async fallback; regresses the `f58e99aa` skeleton standard) and discards the per-split data it already loads. Merchants have **no payout history at all**, and only the internal half of their outstanding money is shown.
2. Supplier page's **arithmetic looks broken by design**: "Settling" rows carry amounts deliberately excluded from the "You owe" tile, unexplained; Settling rows are simultaneously red (owe) and amber (handled).
3. Platform finance: dual-basis approve is **invisible** (one button → two payouts, confirm names one amount, Basis renders as a raw atom); **`unreclaimable_release` has zero surfaces** despite its code comment promising finance can find them; empty/loading states below house standard; button renders for un-payable stores.
4. **Wholesalers get no earnings narrative**: resale earnings silently blend into an unattributed balance while dropshippers get "Real fulfilled earnings" from the same table (`goal_progress.ex:55` filters by role — the asymmetry is one query away from closable). No accrual notification exists anywhere.

House standard exists and is named in code: `platform_components.ex:31` ("the Makola Admin design language", `stat_tile/1`, unused `page_header/1`), `admin_components.ex:195` (`stat_card/1`, `empty_state/1`), `metric_components.ex:25` (skeleton money tiles — the honest exemplar; revenue_live/report_live are style-only, hardcoded demo data).

## 2. Decisions (Kojo, 2026-08-03)

- **Scope: everything** — three page elevations + the wholesaler narrative + accrual notification, one initiative.
- **Attribution home: dedicated `/admin/earnings` page** — the unified money-narrative surface (own sales, resale earnings by source store, dropship margin, credit repayments).
- **Notification: in-app + existing `Notifications.Dispatcher`** (SMS/WhatsApp templates ship dark until keys — house pattern).
- Correctness and beauty land together per page ("elevate as we go"). `frontend-design` skill governs visual implementation; components reused from the named design language, never re-invented.

## 3. Design

### A. Merchant payouts page (`admin/payout_live.ex`)

- Async loads get **skeleton states** (adopt `metric_components` pattern); kill the misleading `0` fallback; move `held_net_total` into the same async.
- Tile strip becomes a **grid**: Accrued (payable now) / Held by protection / **Legacy outstanding** (the un-split half merchants currently can't see — `outstanding_for_payout` scoped to store) — distinct icons/colors per meaning.
- **Accrual breakdown** card from the already-loaded splits: per-role rows (own sales / resales of your stock / dropship margin / credit), count + oldest-age line. Zero new queries.
- **Payout history** table: recent payouts for this store (basis-labeled pills, status pills, amounts) — merchant-scoped read of `Payout` (check the resource's merchant read policy; add a scoped read if missing).
- Destination notice becomes state-driven (saved-no-subaccount / verified / none) instead of the fixed amber string.

### B. Supplier ledger (`admin/supplier_live/show.ex`)

- Adopt `stat_card`; tile row becomes: **You owe** (manual only, calm styling — red reserved for overdue-ness if ever modeled) / **Settling via Makola** (the missing tile — kills the arithmetic contradiction) / **Paid**.
- Row coloring follows `settlement_source`: manual-owed red, claimed neutral+amber pill, voided slate, paid green. Pill copy gains the rail ("Settling — Makola pays them directly").
- `empty_state/1` component; stream + status filter for the list; `paid_total` labeled honestly ("paid (recent)" or made a real aggregate).

### C. Platform finance (`platform/finance_live.ex`)

- Adopt `page_header/1` (its first consumer) + skeleton `stat_tile`s.
- **Basis becomes a pill** ("Gateway" / "Ledger"); Recent payouts groups the two rows born of one approval (shared approval timestamp/actor metadata — add an `approval_group` to the audit metadata or group visually by store+minute; prefer explicit: stamp a shared `approval_ref` into both payouts' metadata at approve time).
- **Pre-approve breakdown**: per-store row expands to show legacy vs internal amounts BEFORE the button; confirm dialog names both. Button disabled (not hidden) with reason when no destination.
- **Remediation surface**: fifth tile "Needs remediation" + table driven by a new `PaymentSplit.read :needs_remediation` (filter `recovery_breakdown["unreclaimable_release"] == true` — jsonb containment; index only if slow) showing split/store/amounts/date. Closes the invisible-flag gap. Also a "Clawback exposure" figure from `recoverable_by_recipient` totals (display-only).
- One shared money formatter (`Helpers.Currency`) — delete the local `format_amount` copies this touches; rich `empty_state`s; keep tables stream-backed.

### D. `/admin/earnings` — the unified money narrative (NEW)

- Route + nav entry beside Payouts. Sections: **hero strip** (total earned, this-month, payable now, paid out — skeletons); **earnings by source**: own store sales / **resale earnings** ("from Store Y's resales" — wholesaler role rows resolved supplier→source store) / dropship margin / credit repayments — each a card with amount + recent rows (order #, date, net); **recent accruals** feed (per-payment granularity).
- Data: new domain reads on `PaymentSplit` (e.g. `read :earnings_by_recipient` — settled+payable+paid rows for `recipient_store_id`, loaded with payment→order for numbers/dates; supplier_id→Supplier→source store resolution for attribution). Merchant read policy mirrors the existing splits read-only policy. Aggregations computed in the LiveView from one read (volume is per-store small); revisit SQL aggregates only when real volume says so.
- Visual: this is the flagship — full design language (gradient hero per supply_network exemplar, honest data only). `frontend-design` skill at implementation.

### E. Accrual notification

- New Dispatcher event `:earnings_accrued`, fired from `settle_splits/1` (webhook, log-and-continue discipline) **once per payment per recipient store** (matches order-notification granularity; no digests/throttling until volume exists — YAGNI).
- Payload: recipient store, net amount (frozen-formula authority), source description ("resale via Store Y" / "your sale"). SMS/WhatsApp templates registered dark (house pattern); in-app = the earnings page's recent-accruals feed + a nav badge count (check-first: if an in-app notification center exists, use it; exploration found none — the badge+feed IS the in-app half, note in plan).
- The MoMo nudge joins the notification copy when the recipient has no destination.

## 4. Non-goals

Charts of demo data (revenue_live's hardcoded numbers stay untouched); notification digests/throttling; wholesaler-side standalone app surfaces; platform-finance pagination beyond streams; modeling "overdue"; NGN formatting (GHS-only until NGN activation).

## 5. Sub-project split & order

Two stacked PRs after #374 merges: **PR-1 "elevation"** = A+B+C (existing pages, correctness+design together); **PR-2 "earnings narrative"** = D+E (new surface + notification). Each gets its own implementation plan; PR-1 first (fixes shipping misleading states).

## 6. Verification

Per page: LiveView tests for every new state (skeleton, empty, populated, failure — the T7 failed-state indicator lands here for payouts); the supplier arithmetic test (tile + settling tile == sum of rows); remediation table shows a flagged split; earnings attribution test (wholesaler sees source store name); dispatcher test (one event per settled payment, dark-template registered). Browser QA pass with the dev service-worker unregistered (known stale-CSS gotcha) before each PR.
