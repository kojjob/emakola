# Money Surfaces PR-2 "Earnings Narrative" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The `/admin/earnings` unified money-narrative page ("GHS X arrived because Store Y resold your product") + the `:earnings_accrued` notification — the initiative's flagship.

**Architecture:** Branch `money-surfaces-earnings` off main `83936940` (#372-375 all merged). Task 1 = earnings domain reads; Task 2 = the flagship page; Task 3 = the dispatcher event fired from webhook settlement; Task 4 = gate/QA/PR. Spec §3 D-E.

**Tech Stack:** Phoenix LiveView, Ash reads, existing Dispatcher/Oban notification rail, TailwindCSS via the Makola Admin design language.

## Global Constraints (BINDING)

- Worktree `/Users/kojo/Projects/emakola/.claude/worktrees/internal-settlement`, branch `money-surfaces-earnings`. TDD; format/credo per commit; parse `Result:` lines. UI implementers load `frontend-design` BEFORE markup; reuse `stat_card`/`empty_state`/skeleton patterns (payout_live.ex is now the house exemplar for async money pages — mirror its `async_result` + `money_tile` discipline). Money display via `Currency.format_price/2`; amounts via `PaymentSplit.frozen_paid_amount/1`. No misleading states (skeleton/failure/empty for every async surface — zero-fallbacks are Critical). No new sync mount reads. Zero money-BEHAVIOR change (reads + one notification dispatch).
- **PR-1 tripwire (inherited):** do NOT add any mutation path touching flagged splits without stamping `flagged_at` — this PR adds none (verify at gate).
- Notification discipline: dark templates (house pattern — SMS/WhatsApp send only when keys live); dispatch NEVER raises into the webhook (log-and-continue); idempotent under webhook replay.

## Verified grounding

- Dispatcher (lib/emakola/notifications/dispatcher.ex): `@valid_events` whitelist + `dispatch(order, event)` → OrderNotificationWorker + PubSub; **`dispatch_susu/2` (~:186) is the precedent for a non-order dispatch arm** — mirror it for `dispatch_earnings/2` (own valid-events list, own worker or a clause on an existing one). Templates live in lib/emakola/notifications/templates.ex (e.g. `protection_held_sms(order, store)` :56). Workers under lib/emakola/notifications/workers/.
- `settle_splits/1` (lib/emakola/payments/workers/paystack_webhook_handler.ex ~:377-430): settles `:pending` splits, then recoveries/partner-credit/supplier-claims. **It re-runs on every webhook redelivery** — the notification must fire only for splits THIS call transitioned `:pending → :settled` (the loop knows its freshly-settled set) + Oban `unique` on (payment_id, recipient_store_id) as belt-and-braces.
- **Attribution simplification (deviation from spec §3.D's supplier-chain description — note in PR):** a wholesaler's resale-earnings split has `recipient_store_id` = wholesaler, `store_id` (tenant) = the RESELLER's store — the source store IS the split's tenant. No supplier→linked-store resolution needed: attribution = `Store` name lookup of `split.store_id` when it differs from the recipient. Roles label the flavor (wholesaler row = "resale of your stock by <source>"; dropshipper = "dropship margin"; credit_partner = "credit repayment"; merchant = "your sale").
- PaymentSplit already has the merchant read-only membership policy (reads allowed via `ActorHasStoreAccess`) — new reads inherit it; test both directions anyway.
- Nav: find the admin sidebar entry for Payouts (grep `admin/payouts` in lib/emakola_web/components/ + layouts) and add Earnings beside it. **Unread-badge state is DEFERRED** (needs a seen-marker model — YAGNI now): the in-app half = the nav entry + the live feed (PubSub already broadcasts on dispatch). Name this deviation in the PR body.

---

### Task 1: Earnings domain reads

**Files:** Modify `lib/emakola/payments/resources/payment_split.ex`, `lib/emakola/payments/payments.ex`; Test `test/emakola/payments/earnings_reads_test.exs` (create).

**Interfaces — Produces:**
- `PaymentSplit.read :earnings_by_recipient` — arg `recipient_store_id` (required); filter `recipient_store_id == arg AND role != :platform AND status in [:settled, :partially_reversed, :reversed]` (reversed included — the narrative shows history, net computed via frozen formula; claimed AND unclaimed both included); sort `inserted_at desc`; prepared `limit 100` (bounded — the feed paginates later if ever needed, note the cap in a comment). Domain: `list_earnings_splits(recipient_store_id, opts)`.
- LiveView-side aggregation contract (Task 2 computes in Elixir from ONE read): total earned (Σ frozen over non-reversed), this-month, payable-now (unclaimed settled/partial), paid-out (Σ paid_amount where claimed) — all from the same rows; NO new SQL aggregates.

- [ ] **Step 1 (RED):** tests: (a) recipient's wholesaler+dropshipper+merchant rows returned newest-first, platform rows excluded, other stores' rows excluded; (b) the 100-cap (create 3, assert 3 — cap is a prepare, assert via a comment-pinned `limit: 100` presence… assert behaviorally only if cheap, else skip count-101 fixtures — note choice); (c) membership policy both directions (member reads, non-member refused) — mirror payout `recent_by_store`'s policy test fixture from money_surfaces_domain era (grep test/ for ActorHasStoreAccess payout fixture).
- [ ] **Step 2 (GREEN):** implement the read (mirror `payable_internal`'s shape; add after it) + domain define.
- [ ] **Step 3:** payments suite + format/credo → commit `feat(payments): earnings-by-recipient read`

### Task 2: /admin/earnings — the flagship page

**Files:** Create `lib/emakola_web/live/admin/earnings_live.ex`; Modify router (`lib/emakola_web/router.ex` — add `live "/admin/earnings", Admin.EarningsLive` beside the payouts route, same pipeline/scope) + the admin nav component (find it — add "Earnings" beside "Payouts", same styling); Test `test/emakola_web/live/admin/earnings_live_test.exs` (create). **Load `frontend-design` first — this is the flagship: gradient-hero energy per supply_network_live's exemplar (~:1400), honest data only.**

**Interfaces — Consumes:** `list_earnings_splits/2`, `frozen_paid_amount/1`, `format_price/2`, `stat_card`, `empty_state`, payout_live's `async_result`/`money_tile` discipline (copy the state-handling pattern, not the literal markup).

- [ ] **Step 1 (RED):** LiveView tests: (a) skeleton while loading, no "0.00" (payout_live test pattern); (b) failure → "—"; (c) hero strip four tiles (total earned / this month / payable now / paid out) with exact amounts from mixed fixtures (seed: merchant own-sale split, wholesaler resale split from ANOTHER tenant store, dropshipper split, one claimed+paid, one reversed — assert each tile's arithmetic per the Task 1 contract, all via frozen formula); (d) by-source cards: the resale card names the SOURCE store ("resale of your stock by <StoreName>" or the card grouping shows the source store's name — assert the other store's name appears); (e) recent accruals feed rows (order-less splits render too — susu contributions have no order; date + net + source label); (f) empty state (new store: rich empty_state with copy pointing at listings). Route + nav: (g) authenticated merchant reaches /admin/earnings; nav renders the Earnings entry.
- [ ] **Step 2 (GREEN):** one combined `assign_async` (earnings splits + source-store name map — batch the Store lookups: `Ash.read` stores where id in distinct source ids, ONE query); aggregations per the Task 1 contract computed in the async fn; hero = 4 distinct stat_cards in a grid; by-source section = cards per role-group (label map from grounding; resale card lists per-source-store subtotals); feed = last N rows (date via the house relative/absolute pattern payout_live uses, net via frozen formula, source label); empty/failure/skeleton per house discipline; nav entry + route.
- [ ] **Step 3:** suite + format/credo → commit `feat(web): /admin/earnings — the money narrative`

### Task 3: `:earnings_accrued` notification

**Files:** Modify `lib/emakola/notifications/dispatcher.ex` (new `dispatch_earnings/2` arm mirroring `dispatch_susu/2`), `lib/emakola/notifications/templates.ex` (dark SMS template: net amount + source description + MoMo nudge when no destination), a worker (read the susu worker's shape — either a clause on OrderNotificationWorker's pattern or a small `EarningsNotificationWorker` mirroring SusuNotificationWorker — pick what the susu precedent actually does and mirror it; Oban `unique: [fields: [:args]]` on (payment_id, recipient_store_id)); Modify `lib/emakola/payments/workers/paystack_webhook_handler.ex` (`settle_splits/1` fires once per payment per recipient for FRESHLY-settled non-platform recipients, log-and-continue); Tests: `test/emakola/notifications/earnings_notification_test.exs` (create) + a webhook-replay idempotency case in the existing webhook suite file if cheaper.

- [ ] **Step 1 (RED):** tests: (a) settling a payment with wholesaler+dropshipper recipients enqueues one earnings job PER recipient (all_enqueued count 2, args matched); (b) webhook REPLAY enqueues nothing new (unique + freshly-settled guard — replay leaves splits already :settled → zero fresh); (c) the worker's template renders net amount + source store name + the MoMo nudge line when `momo_destination?` false, omits it when true; (d) dispatch failure cannot raise into the webhook (arrange per prior patterns or assert the rescue shape — the settle_splits helpers' log-and-continue discipline; state approach).
- [ ] **Step 2 (GREEN):** implement per grounding. The freshly-settled set: `settle_splits` already walks `:pending` splits it settles — collect `{payment, recipient_store_id}` pairs (non-platform, distinct) from that walk and dispatch after the loop (before/after supplier-claims — order irrelevant, but AFTER apply_recoveries so netted state is final for the amount in the payload; compute payload net via frozen formula at dispatch time). Dark behavior: the worker sends via the SMS provider behaviour exactly like susu's — with dummy keys it no-ops/logs (verify the house behavior, mirror it).
- [ ] **Step 3:** notifications + webhook suites + format/credo → commit `feat(notifications): earnings-accrued — merchants learn money arrived`

### Task 4: Gate + QA + PR

- [ ] Full `mix test` (Result line), format/credo/warnings; tripwire check: `git diff origin/main -- lib/` contains NO mutation touching `recovery_breakdown`-flagged splits.
- [ ] Browser QA (service-worker gotcha; alt-port from worktree): /admin/earnings in empty + populated (seed splits if dev DB allows) + mobile 390px; screenshots to the workspace qa/ dir.
- [ ] Whole-branch review (most capable model; lenses: zero-money-behavior, notification idempotency under replay, the flagship design against the language, spec §3 D-E line-by-line incl. the TWO named deviations — attribution simplification + badge-state deferral); ONE fix wave; push; PR to main titled `feat(web): the earnings narrative — merchants see where every cedi came from`, body naming both deviations + the dark-notification activation note (goes loud with SMS keys).
