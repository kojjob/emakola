# Money Surfaces PR-1 "Elevation" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The three existing money pages get one pass each — correctness (misleading states killed) and the Makola Admin design language applied together — plus the domain reads/metadata they need.

**Architecture:** Branch `money-surfaces-uiux` off main `e6cec21f` (internal settlement fully merged). Task 1 lands the domain layer (remediation read, merchant payout history read, approval_ref grouping); Tasks 2-4 are one page-pass each (payouts → supplier → finance), UI-heavy with LiveView tests; Task 5 is browser QA + gate + PR. Spec: docs/superpowers/specs/2026-08-03-money-surfaces-uiux-design.md §3 A-C.

**Tech Stack:** Phoenix LiveView, existing components (`stat_card`/`stat_tile`/`empty_state`/`metric_components` skeletons), TailwindCSS, Ash reads.

## Global Constraints (BINDING)

- Worktree `/Users/kojo/Projects/emakola/.claude/worktrees/internal-settlement`, branch `money-surfaces-uiux`. TDD for domain + LiveView state logic; `mix format` + `mix credo --strict` per commit; parse `Result:` lines.
- **UI implementers MUST load the `frontend-design` skill before writing any markup**, and REUSE the named components — `stat_card`/`empty_state` (admin_components.ex:195/:332), `stat_tile`/`page_header` (platform_components.ex), skeleton pattern (metric_components.ex:25). Re-inventing a tile/pill/empty-state is a spec violation. Read each component's attr/slot signature before use.
- Money display: `EmakolaWeb.Helpers.Currency.format_price/2` ONLY. Amount math: `PaymentSplit.frozen_paid_amount/1` ONLY (never inline).
- No misleading states: every async surface has a skeleton (loading), an honest failure state (a "—"/couldn't-load treatment, NOT zero), and an `empty_state` where a list can be empty. **A zero-fallback that can render "GHS 0.00" while money exists is a Critical review finding.**
- Iron Law: no new sync DB reads in `mount/3` — `assign_async`/`start_async` (pre-existing violations stay untouched).
- LiveView gotchas (memory-verified): client state via `Phoenix.LiveView.JS`; storefront-style catch-all crashes don't apply here but check each new `phx-click` has a handler; `assert_redirect` takes binaries.
- Demo-data pages (revenue_live, report_live) are style references ONLY — copy no data wiring from them; `metric_components.ex` is the honest exemplar.

## Verified grounding (2026-08-03 exploration — re-verify line numbers, they may drift)

- payout_live.ex: accrued `stat_card` :176 + nudge :188, held `stat_card` :197 (sync `held_net_total` in mount :37 — MOVE into async), static amber notice :206, form :213, local `text_field/1` :287, async-zero fallback :57 (**the bug**), splits summed-and-discarded :50.
- finance_live.ex: `stat_tile` strip :188, tables :216/:275, `approve_both_bases/3` :97, confirm :262, raw-atom Basis :305, `loaded == false` bare text :182, local `format_amount/1` :336, two local pill families :348/:356.
- supplier_live/show.ex: hand-rolled tiles :171 (`text-4xl font-extrabold`, red-on-red You-owe), ledger list :209, pills :248/:255/:262, Mark-Paid gate :239, sync loads :26, in-memory `paid_total/1` :85.
- `Supplier.outstanding_balance` filter (supplier.ex:103) = `:owed and :manual` — the Settling-tile amount is Σ over `:owed and settlement_source != :manual` entries (compute from the loaded ledger list — it's already fetched).
- `unreclaimable_release` stamp: payment_split.ex:484 in `recovery_breakdown` map. Remediation read = jsonb filter; grep lib/ for an existing Ash jsonb-key filter precedent (e.g. `metadata["..."]` in expr) before inventing syntax; if `expr(recovery_breakdown["unreclaimable_release"] == true)` fails to compile, use a fragment — note which in the report.
- Payout resource: multitenancy store_id; merchant read policy exists? CHECK (payout.ex policies ~:102) — platform finance uses `list_recent_payouts` (authorize?: false). Merchant history needs a tenant-scoped read + policy allowing store members (mirror PaymentSplit's read-only membership policy at payment_split.ex:~209).
- `goal_progress.ex:55` — the role-filter query shape for per-role breakdowns.

---

### Task 1: Domain foundations

**Files:** Modify `lib/emakola/payments/resources/payment_split.ex`, `lib/emakola/payments/resources/payout.ex`, `lib/emakola/payments/payments.ex`, `lib/emakola_web/live/platform/finance_live.ex` (approval_ref stamping only); Tests: `test/emakola/payments/money_surfaces_domain_test.exs` (create).

**Interfaces — Produces:**
- `PaymentSplit.read :needs_remediation` (no args): splits where `recovery_breakdown["unreclaimable_release"] == true`, sorted `updated_at desc`. Domain: `list_remediation_splits/1`.
- `Payout.read :recent_by_store` (arg `store_id`, sorted inserted_at desc, prepared limit 20) + a policy letting store MEMBERS read their store's payouts (mirror PaymentSplit's merchant read-only policy — actor Merchant + ActorHasStoreAccess, reads only). Domain: `list_store_payouts/2`.
- `approve_both_bases/3` stamps a shared `approval_ref` ("appr_" <> 8-char suffix of an Ecto.UUID) into each created payout's `metadata` map before enqueue (Payout `:create` already accepts `metadata`; thread it through `PayoutService.prepare_payout/prepare_internal_payout`?? NO — those build the payout internally. Simplest honest mechanism: after each `{:ok, payout}`, `Payments.update_payout_metadata(payout, %{"approval_ref" => ref})` via a new narrow `update :stamp_approval_ref` accepting metadata merge — check Payout's `:update` action surface first; if a generic metadata update exists reuse it, else add the narrow action).

- [ ] **Step 1 (RED):** tests: (a) a split with the stamp appears in `list_remediation_splits`, unstamped/settled ones don't; (b) `list_store_payouts` returns only that store's payouts newest-first and a Merchant actor with membership CAN read while a non-member CANNOT (policy test — mirror an existing membership-policy test's fixture, grep `ActorHasStoreAccess` in test/); (c) approving a both-bases store yields two payouts sharing one `metadata["approval_ref"]` (fixture: the dual-basis approve test shape from finance_live_internal_test.exs).
- [ ] **Step 2 (GREEN):** implement per Produces. jsonb filter: try `filter(expr(recovery_breakdown["unreclaimable_release"] == true))`; fragment fallback documented.
- [ ] **Step 3:** suites + format/credo → commit `feat(payments): remediation read, merchant payout history, approval grouping`

### Task 2: Merchant payouts page (spec §3.A)

**Files:** Modify `lib/emakola_web/live/admin/payout_live.ex` (+ its test file); load `frontend-design` skill first.

**Interfaces — Consumes:** Task 1's `list_store_payouts/2`; existing `list_payable_internal_splits/2`, `frozen_paid_amount/1`, `momo_destination?/1`, `outstanding_for_payout` (Payment read, store-scoped — for the legacy tile), `metric_components` skeleton pattern.

- [ ] **Step 1 (RED):** LiveView tests for the new contract: (a) while async pending → skeleton markers render, NO "0.00" anywhere (assert skeleton test-id present, `refute html =~ "0.00"`); (b) failure state renders "—"/couldn't-load (arrange: make the async raise via a deleted store id or an injectable failure — if un-arrangeable cheaply, assert the failed-clause markup via a direct render of the state, note approach); (c) populated: three tiles (accrued/held/legacy-outstanding) with distinct test-ids + correct amounts; (d) breakdown card lists per-role rows w/ counts from seeded splits of 2+ roles; (e) history table shows a seeded payout w/ basis+status pills; (f) notice: destination-saved vs verified vs none render distinct copy (state-driven, no fixed amber string).
- [ ] **Step 2 (GREEN):** ONE combined async (`assign_async(:money, ...)`) loading payable splits + held total + legacy outstanding + history + destination state in one function; tiles in `grid grid-cols-1 sm:grid-cols-3` using `stat_card` with DISTINCT icons/colors (accrued=emerald/savings, held=amber/lock, legacy=slate/history — check stat_card's icon attr contract); skeleton via metric_components' pattern while `!money.ok?`; failed → "—" treatment; breakdown card (role label map: merchant→"Your sales", wholesaler→"Resales of your stock", dropshipper→"Dropship margin", credit_partner→"Credit repayment") with count + oldest `inserted_at` age line; history table (date, amount via format_price, basis pill "Gateway"/"Ledger", status pill — reuse finance pill CLASSES? No: define ONE shared pill helper in this page consistent w/ house pills; Task 4 unifies platform-side separately); notice from destination state. Keep the existing form + `text_field`. The pre-existing sync `load_account/1` stays (untouched violation).
- [ ] **Step 3:** full payout_live suite + format/credo → commit `feat(web): merchant payouts page — honest states, full money picture`

### Task 3: Supplier ledger page (spec §3.B)

**Files:** Modify `lib/emakola_web/live/admin/supplier_live/show.ex` (+ test); `frontend-design` skill first.

- [ ] **Step 1 (RED):** tests: (a) tile row = You-owe (manual only) + **Settling via Makola** (Σ owed-and-claimed rows) + Paid, distinct test-ids, amounts correct with mixed fixtures (manual-owed + platform_payout-owed + paid + voided); (b) arithmetic coherence: you_owe + settling == Σ unpaid row amounts (the contradiction-killer assertion); (c) claimed rows are NOT red (assert class absence) and carry the rail copy "Settling — Makola pays them directly"; (d) empty ledger renders `empty_state` component markup; (e) status filter (All/Owed/Settling/Paid/Voided) filters the stream.
- [ ] **Step 2 (GREEN):** adopt `stat_card` for the three tiles (You-owe calm styling — slate/neutral, NOT red-on-red; red only on individual overdue... not modeled → no red tiles); Settling tile computed from the loaded entries (`status == :owed and settlement_source != :manual`); row amount color keyed on settlement_source (manual-owed = rose-600 text, claimed = slate-900 + amber pill, paid = emerald, voided = slate-400 line-through-free); pill copy gains rail wording; convert the `:for` list to a stream + status filter via `phx-click` chips (JS-free assigns filter is fine — small lists); `empty_state/1` for the empty branch; label `paid_total` "Paid (recent)". Sync mount loads stay (pre-existing).
- [ ] **Step 3:** supplier_live suite + format/credo → commit `feat(web): supplier ledger — coherent arithmetic, honest states`

### Task 4: Platform finance page (spec §3.C)

**Files:** Modify `lib/emakola_web/live/platform/finance_live.ex` (+ test); `frontend-design` skill first.

**Interfaces — Consumes:** Task 1's `list_remediation_splits/1` + `approval_ref` stamps; `page_header/1` + `stat_tile/1` (platform_components).

- [ ] **Step 1 (RED):** tests: (a) `page_header` renders (its first consumer); (b) loading → skeleton tiles not bare text; (c) Basis renders as pill text "Gateway"/"Ledger" (assert both, refute raw ":payments"); (d) recent payouts sharing an approval_ref render grouped (one visual group container / shared ref badge — assert the ref appears once for two rows); (e) per-store row expands (phx-click) to show legacy vs internal amounts BEFORE approve, and the confirm names both; (f) Pay-out button DISABLED with reason when no destination (assert disabled attr + title/tooltip text); (g) remediation: a stamped split renders in a "Needs remediation" tile+table w/ severity pill; unstamped → tile shows 0 + rich empty state; (h) clawback exposure figure renders from recoverable totals.
- [ ] **Step 2 (GREEN):** implement per spec §3.C: fifth tile + remediation table (columns: store, split amount, reversed, recovered+reserved, flagged-at; severity pill family REUSED from an existing platform pill set — pick supply_network's ring-based family per the exemplar, extract to `platform_components.ex` as `severity_pill/1` and use it for basis + status + remediation pills — THIS is the pill unification); expandable per-store breakdown (assigns-toggled, JS-free); confirm dialog text lists both amounts; disabled button + reason; skeletons; `empty_state`-equivalent for platform (add a minimal `empty_state/1` to platform_components mirroring admin's — platform side lacks one); replace local `format_amount/1` with `Helpers.Currency.format_price/2` (delete the local); clawback figure = Σ (reversed − netted − recovered − reserved posture — REUSE `recoverable_by_recipient` read summed over stores... simplest honest: new domain fn? NO — compute from `list_remediation_splits` scope only if cheap; otherwise display remediation only and drop clawback to a follow-up note in the report if it needs a new read — do NOT invent un-reviewed money math).
- [ ] **Step 3:** finance suites + format/credo → commit `feat(platform): finance page — dual-basis visible, remediation surfaced`

### Task 5: Gate + PR

- [ ] Full `mix test` (Result line), format/credo/warnings; guarded money suites untouched (`git diff origin/main --stat` over test/emakola/payments/ core suites — only the LiveView/domain test files this plan names may change).
- [ ] Browser QA: unregister the dev service worker first (known stale-CSS gotcha); walk all three pages in the three states (empty / populated / loading via throttle) on mobile viewport; screenshot each for the PR.
- [ ] Whole-branch review (most capable model; point it at the ledger + spec §3 A-C + the census: this PR must NOT change any money behavior — display/reads only except approval_ref metadata stamping); ONE fix wave max; push; PR to main titled `feat(web): money surfaces elevation — honest states, full money picture` with before/after screenshots, noting PR-2 (earnings page + notifications) follows.
