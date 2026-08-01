# TC-3 Susu Lay-away Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merchant-created susu links: buyers pay flexible MoMo chunks toward a snapshotted total with a deadline; stock reserves at activation; completion creates an ordinary fully-paid order (contributions retroactively stamped); expiry/cancel refunds every pesewa.

**Architecture:** `SusuPlan` mirrors `PayLink` (code/type/status, global-unique code). Chunks are ordinary gateway charges with `susu_plan_id` (NO `order_id` — already nullable), `payout_held: "susu_plan"`, no split — money accumulates in the platform account. All plan-state mutations (chunk claim, accumulation, activation, completion detection) run under a `FOR UPDATE` plan-row lock (the branch's established `locked_row_query` pattern, 3rd use). Completion creates the order via a slim CheckoutService path, stamps `order_id` onto contributions, apportions the platform fee across contributions (largest-remainder; `Σfee_i == PlatformFee.calculate(total)`), stamps `payable_amount`, and either releases to payout (unprotected) or converts to per-contribution `ProtectionHold`s (protected — TC-2 composition). Stock model: **decrement at activation**, re-increment on expiry/cancel, and `DecrementStock` skips susu orders at confirm (they pre-decremented) — no availability-query changes anywhere (the silent-leak-free choice).

**Tech Stack:** Elixir/Phoenix 1.8 LiveView, Ash 3.x, Oban (+Cron), Mox, Phoenix.Token.

**Spec:** `docs/superpowers/specs/2026-07-30-susu-layaway-design.md` (on main). JSON:API exposure is NOT in the spec — deliberately out of scope.

**Documented spec deviation (carry to PR body):** the spec said stock holds "mirror the suppliers-domain InventoryReservation pattern" (a reservation-rows table). This plan uses **decrement-at-activation** instead: reservation rows would require availability-query changes across every storefront/stock surface (the silent-leak failure class), while decrementing the real counter at activation + re-incrementing on expiry/cancel + skipping the confirm-time decrement keeps ALL existing stock math untouched. Same guarantee, strictly smaller blast radius.

## Global Constraints

- Money: integer minor units. Fee apportionment invariant: `Σfee_i == PlatformFee.calculate(total_amount, plan.fee_rate_bps).fee`, per-contribution `fee_i` floored with the final contribution absorbing the remainder; `payable_amount_i = amount_i - fee_i`; never negative.
- **One pending chunk at a time**, amounts clamped `min_chunk <= amount <= remaining` (min stops applying when `remaining < min_chunk`); final chunk auto-capped to land exactly on total; completion fires exactly once — ALL enforced under the plan-row `FOR UPDATE` claim.
- All workers/hooks idempotent; webhook redelivery safe at every step.
- `unique_code` identity MUST be `all_tenants?: true` (TC-1 lesson — /susu/:code is a global lookup).
- Truthy checks on nullable booleans/enums; no `== false`.
- Storefront LiveViews have no catch-all `handle_event` — every rendered control needs a handler, AND the storefront layout's search overlay (`phx-keyup="search_overlay"`) needs its handler on every new page (TC-1 Critical).
- Signed-link authority: the public `/susu/:code` page can start a plan; ALL post-activation buyer actions (chunk, delivery edit, cancel) require the signed plan token (order-number/code knowledge alone never moves or reclaims money).
- Refund initiation follows the no-blind-retry POST discipline (claim before gateway call); refunds confirm at the `refund.processed` webhook terminal (TC-2 lesson — never treat "request accepted" as terminal).
- `mix ash.codegen` broken repo-wide — `mix ash_postgres.generate_migrations --domains <Domain>` + trim drift, or hand-write per precedent; snapshots synced; migrate BOTH envs.
- Toggle-free feature (no ship-dark flag) but zero behavior change for non-susu flows — pin byte-identical guards where paths are shared (webhook success block, DecrementStock, payout gathering).
- TDD RED/GREEN; `mix format` + `credo --strict` per commit; read Result: lines.

**Precedent files (the implementer's pattern library — cite, copy, adapt):**
`lib/emakola/orders/resources/pay_link.ex` (+ its tests) · `lib/emakola/orders/pay_link_claim.ex` + `lib/emakola/payments/protection_release.ex` (locked_row_query + to_sql guard tests) · `lib/emakola/payments/protection_holds.ex` (ensure_hold idempotency, stash pattern) · `lib/emakola/payments/workers/protection_sweep_worker.ex` (cron sweep shape) · `lib/emakola_web/live/storefront/pay_link_live.ex` (+ tests: states, search_overlay, Mox gateway) · `lib/emakola_web/tracking_tokens.ex` (token module shape) · `lib/emakola/orders/checkout_service.ex` (`checkout_custom!` slim path) · TC-2's notification wiring in `lib/emakola/notifications/`.

---

### Task 1: SusuPlan resource

**Files:**
- Create: `lib/emakola/orders/resources/susu_plan.ex`, `lib/emakola/orders/changes/generate_susu_code.ex` (or reuse/generalize `GeneratePayLinkCode` — decide, document)
- Modify: `lib/emakola/orders/orders.ex` (register + interfaces), `lib/emakola/orders/resources/order.ex` (`susu_plan_id` uuid nil + accept)
- Create: migration (susu_plans + orders.susu_plan_id + index; unique code index all_tenants)
- Test: `test/emakola/orders/susu_plan_test.exs`

**Interfaces (produces):**
- `Emakola.Orders.SusuPlan` — tenant attribute/store_id/global?(true): `code` (8-char lower base32, `identity(:unique_code, [:code], all_tenants?: true)`), `type :catalog|:custom`, `variant_id` (catalog; tenant-validated like PayLink's), `quantity` (merchant-set, default 1, > 0), `title` (custom), `total_amount` (>= 100), `min_chunk` (default 1_000, > 0), `deadline :utc_datetime_usec` (required; must be in the future at create), `fee_rate_bps` (snapshotted at create from the same config source OrderSettlement uses), `collect_delivery` (default true), `status :pending|:active|:completed|:expired|:cancelled` (default :pending), `customer_id` (nil until activation), `contributed_amount` (default 0), `delivery_address :map` (nil), `stock_reserved :boolean default false` (set by Task 4's reserve, read by release), `last_nudged_at` / `warned_7d_at` / `warned_1d_at` (nullable timestamps — Task 8's notification dedup), `note`, `created_by_user_id`, timestamps.
- Actions: `:create` (validations: catalog↔variant_id+tenant check / custom↔title, total>=100, deadline future, min_chunk>0); `:get_by_code` (get?, load-bearing comment re global uniqueness); `:activate` (pending→active; accepts customer_id, delivery_address); `:record_contribution` (accepts amount_delta; atomic add to contributed_amount; only while :active — the webhook path uses this under the plan lock); `:complete` (active→completed; only when contributed_amount == total_amount — validated); `:cancel` (pending|active→cancelled); `:expire` (active→expired); `:extend_deadline` (accepts new deadline; only :active; must be LATER than current — forward-only); `:update_delivery` (accepts delivery_address; only :active).
- Helpers: `SusuPlan.usable_for_start?/1` (:pending + not past deadline), `remaining/1`, `chunk_bounds/1` (min/max for the next chunk per the clamping rules).
- `Order.susu_plan_id` — provenance + the DecrementStock skip key + funnel queries.
- Code interfaces: create/get_by_code/cancel/expire/extend/complete/record_contribution/activate/update_delivery (+ list_for_admin with paid-orders-style aggregates in Task 9).

- [ ] **Step 1: failing tests** — mirror `pay_link_test.exs`'s structure: creation both types + validations (deadline past rejected; foreign variant rejected; total < 100 rejected), global-uniqueness pg_indexes structural test, status transitions (each action's guard), extend forward-only (earlier deadline rejected), record_contribution only while active, complete only at exact total, tenant isolation.
- [ ] **Step 2: implement** (policy posture = PayLink's verbatim).
- [ ] **Step 3: migration** (workaround; snapshots; both envs).
- [ ] **Step 4:** green → commit `feat(orders): SusuPlan resource with forward-only lifecycle`

---

### Task 2: Payment.susu_plan_id + parent validation

**Files:**
- Modify: `lib/emakola/payments/resources/payment.ex`
- Create: migration (+ index on susu_plan_id)
- Test: `test/emakola/payments/payment_susu_parent_test.exs`

**Interfaces (produces):** `Payment.susu_plan_id :uuid` nil, accepted on `:create`; a resource validation: exactly one of `order_id`/`susu_plan_id` may be set at create (both-nil rejected, both-set rejected) — EXCEPT completion later stamps `order_id` onto susu payments, so the rule is create-time only and the update path that stamps order_id must remain legal (implement the validation on the `:create` action only, NOT resource-global; add an `:attach_order` update action accepting order_id, only when susu_plan_id is set and order_id is nil).

- [ ] **Step 1: failing tests** — create with plan only ✓; order only ✓ (byte-identical existing behavior); both ✗; neither ✗; `:attach_order` stamps once and refuses re-stamping.
- [ ] **Step 2-3: implement + migration.** Verify no existing Payment creation path breaks (grep create_payment callers — all pass order_id; pin one with a test).
- [ ] **Step 4:** green → commit `feat(payments): susu plan parentage for chunk payments`

---

### Task 3: Chunk charge path + webhook accumulation (the money core)

**Files:**
- Create: `lib/emakola/orders/susu_chunks.ex` (claim + initiation orchestration), `lib/emakola/orders/susu_completion.ex` placeholder module NOT included — completion is Task 5; this task ends at accumulation.
- Modify: `lib/emakola/payments/workers/paystack_webhook_handler.ex`, `lib/emakola/payments/hubtel_webhook.ex` (success blocks)
- Test: `test/emakola/orders/susu_chunks_test.exs`

**Interfaces (produces):**
- `SusuChunks.locked_plan_query/1` (raw FOR UPDATE on susu_plans row — mirror `ProtectionRelease.locked_row_query/1` including the `to_sql` guard-test style).
- `SusuChunks.initiate_chunk(plan_code_or_struct, amount, buyer_params, gateway)` → `{:ok, %{payment: p, gateway: resp}} | {:error, reason}`: inside a transaction with the plan row locked — re-check status/deadline on the FRESH row; enforce one-pending-chunk (no existing `:pending` payment for the plan — query under the lock); clamp amount per `chunk_bounds` (`:amount_below_min`, `:amount_above_remaining` errors; final auto-cap applies the exact remaining); FIRST chunk carries buyer_params (name/phone required, email optional, delivery per collect_delivery) but customer resolution happens at CONFIRM (webhook), not initiation — stash buyer_params in the payment's `metadata["susu_buyer"]` (the TC-2 stash precedent); gateway initiation mirrors `pay_link_live`'s (no split, `payout_held: true, payout_hold_reason: "susu_plan"`, `susu_plan_id`, NO order_id, unrestricted channels). The gateway HTTP call happens AFTER the lock is released (initiate → create pending payment under lock → COMMIT → then call gateway and update payment with reference — examine how checkout_live orders these steps and mirror; if the existing pattern calls the gateway before payment creation, follow the existing pattern and document — do not invent a new ordering).
- Webhook success block (both handlers), after the existing pay-link/protection calls: `SusuChunks.confirm_chunk(payment)` — when `payment.susu_plan_id` is set: lock the plan row; idempotency: skip if this payment already counted (stamp `metadata["susu_counted"] = true` under the same transaction — redelivery-safe); `record_contribution`; on FIRST confirmed chunk → `:activate` (customer find-or-create by phone from the stashed buyer_params — reuse `CheckoutService.phone_placeholder_email/1` + the Customers find_or_create; store delivery_address on the plan) + `SusuStock.reserve/1` for catalog plans (Task 4's real function — Task 4 is implemented BEFORE this task; see the binding ordering note); completion detection: `contributed_amount == total_amount` → `:complete` + enqueue `SusuCompletionWorker` (this task asserts only `assert_enqueued`; Task 5 makes the worker real). A chunk confirming against a plan that is NOT `:active` (expired/cancelled between initiation and webhook) is counted NOWHERE and flagged for refund: append the dedup'd refund-attention note to the payment (PayLinkClaim's pattern) and log — the money must never silently vanish into a dead plan. Never raises into the worker (ensure_hold discipline).

**TASK ORDERING NOTE (binding):** implement in order 1, 2, **4 (stock)**, 3 (this task), 5 (completion). Task 3's activation calls Task 4's real `SusuStock.reserve/1`; Task 3's completion-detection enqueues Task 5's worker — Task 3 lands AFTER 4, and its completion test asserts only "worker enqueued" (`assert_enqueued`), with Task 5 making the worker real. The controller dispatches in this order.

- [ ] **Step 1: failing tests** — initiation: clamps (below-min, above-remaining, final-cap exact), one-pending-chunk (second initiation while one pending → `:chunk_in_flight`), expired/cancelled/completed plan → status error, deadline-passed active plan → error; confirmation: accumulation math under redelivery (confirm same payment twice → counted once), first-chunk activation (customer created by phone, delivery stored, stock reserved — Task 4's function asserted), completion detection enqueues exactly once (two racing final... sequential re-confirm → single enqueue via counted-stamp + Oban uniqueness); `to_sql` FOR UPDATE guard.
- [ ] **Step 2: implement.** **Step 3:** green → commit `feat(orders): susu chunk initiation and webhook accumulation under plan lock`

---

### Task 4: Stock — decrement at activation (IMPLEMENTED BEFORE TASK 3)

**Files:**
- Create: `lib/emakola/orders/susu_stock.ex`
- Modify: `lib/emakola/orders/changes/decrement_stock.ex`
- Test: `test/emakola/orders/susu_stock_test.exs`

**Interfaces (produces):**
- `SusuStock.reserve(plan)` → `:ok | {:error, :insufficient_stock}` — catalog plans with a `track_inventory` variant: atomically decrement `stock_quantity` by `plan.quantity` (find the existing atomic-decrement idiom `DecrementStock` uses and reuse the exact mechanism); custom plans / untracked variants: `:ok` no-op. Called at activation (first confirmed chunk) — an insufficient-stock activation CANCELS the plan and flags the payment for refund attention (dedup'd note pattern from PayLinkClaim — the buyer paid a chunk for stock that vanished between link creation and first payment; the refund itself is merchant/staff action, notification in Task 8's events).
- `SusuStock.release(plan)` → `:ok` — re-increment on expiry/cancel (only if reserve succeeded — track via `plan.metadata`? SusuPlan has no metadata map; add `stock_reserved :boolean default false` to Task 1's resource — AMEND Task 1: include the attribute there).
- `DecrementStock` change: skip the ENTIRE decrement for orders with `susu_plan_id` set (they pre-decremented at activation) — one guard clause + comment; byte-identical for all other orders (pin test).

- [ ] **Step 1: failing tests** — reserve decrements tracked catalog stock exactly once; insufficient → error; custom/untracked no-op; release re-increments only when reserved; DecrementStock skips susu orders (build an order with susu_plan_id + variant line, confirm, stock unchanged) and is byte-identical otherwise (existing tests stay green).
- [ ] **Step 2-3: implement + green** → commit `feat(orders): susu stock reservation via activation-time decrement`

---

### Task 5: Completion — order creation + retroactive stamping + fee apportionment

**Files:**
- Create: `lib/emakola/orders/susu_completion.ex`, `lib/emakola/payments/workers/susu_completion_worker.ex`
- Modify: `lib/emakola/orders/checkout_service.ex` (slim `create_susu_order!` internal), `lib/emakola/payments/payments.ex` (interfaces as needed)
- Test: `test/emakola/orders/susu_completion_test.exs`

**Interfaces (produces):**
- `SusuCompletionWorker` (Oban, unique by plan_id args, idempotent): calls `SusuCompletion.complete(plan_id)`.
- `SusuCompletion.complete/1` — idempotent (order already exists for plan → :ok): in one transaction: create the order (catalog: variant line via existing `:create` line action, NO stock decrement — skipped via susu_plan_id; custom: `:create_custom` line), `susu_plan_id` + `pay_link_id`-style provenance, shipping_address from plan.delivery_address, customer from plan.customer_id; stamp `order_id` onto every contribution (`:attach_order`); **fee apportionment**: `total_fee = PlatformFee.calculate(plan.total_amount, plan.fee_rate_bps).fee`; per contribution `fee_i = div(amount_i * bps, 10_000)` floored, remainder `total_fee - Σfee_i` added to the LAST contribution's fee; assert `Σ(fee_i) == total_fee` and every `payable_i = amount_i - fee_i >= 0` (a validation error here is a bug — raise loudly, the worker retries); stamp `payable_amount_i` and release each payment's `"susu_plan"` hold (`:release_payout_hold` — verify it clears payout_held for this reason string; group-buy precedent); **protection composition**: when `Emakola.Payments.Protection.applies?(store, nil)` (store-level — susu orders have no pay link) → per-contribution `ProtectionHold` rows (`amount: amount_i, fee: fee_i, net: payable_i` — invariant holds per row) and payments KEEP `payout_held` under reason `"buyer_protection"` (update the reason; verify `ensure_hold`'s webhook path won't double-create — these are created here, unique payment_id protects) — release then flows through TC-2's machinery when delivery confirms; order status: confirm the order (`:confirm` — DecrementStock skips) so fulfillment/notification flows fire normally.
- Order-`:confirm` side effects: verify what `maybe_confirm_order` does (notifications, fulfillment dispatch) and let the standard flow run — a completed susu order behaves like any paid order downstream (the spec's core promise). `order_placed` notification fires via the existing dispatcher path — verify which call site owns it for webhook-confirmed orders and ensure susu completion triggers the same.

- [ ] **Step 1: failing tests** — completion creates a confirmed order with correct total; contributions stamped (all order_id set); apportionment: 3 uneven chunks → Σfee == PlatformFee(total), last absorbs remainder, no negative payable; unprotected store → payments payable at amount-fee and hold flag cleared; protected store → N ProtectionHolds each honoring fee+net==amount, payments held under buyer_protection; idempotent re-run (worker performs twice → one order, stamps unchanged); DecrementStock skip proven again end-to-end (stock unchanged at confirm).
- [ ] **Step 2-3: implement + green** → commit `feat(orders): susu completion creates the order and apportions fees across contributions`

---

### Task 6: Expiry/cancel engine + refunds

**Files:**
- Create: `lib/emakola/payments/susu_refunds.ex`, `lib/emakola/orders/susu_lifecycle.ex` (the shared cancel path), `lib/emakola/payments/workers/susu_expiry_worker.ex` (cron hourly, matching ProtectionSweepWorker's config style)
- Modify: `config/config.exs` (cron entry)
- Test: `test/emakola/payments/susu_expiry_test.exs`

**Additional sweep duty (spec edge case):** the hourly sweep ALSO auto-cancels `:active` catalog plans whose product has been archived or moderation-taken-down (the spec's "product taken down mid-plan → auto-cancel + full refund + notify both"); sweep-detected with hourly latency is the accepted v1 mechanism — same cancel path, test included.

**Interfaces (produces):**
- `SusuExpiryWorker`: sweeps `:active` plans with `deadline < now`; SKIPS plans with an in-flight pending chunk (re-swept next run); transitions `:expire`, releases stock, initiates per-contribution refunds, notifies (Task 8 event).
- `SusuRefunds.refund_all_contributions(plan)` — per confirmed contribution: claim discipline BEFORE the gateway call (stamp `metadata["susu_refund_claimed"]` under a payment-row claim — no blind retry POSTs, the refunds-PR lesson; re-runs skip claimed payments); full-amount `gateway.process_refund`; terminal confirmation stays with the EXISTING `refund.processed` webhook (payment :refunded) — this module only initiates. A failed initiation logs and leaves the payment claimable... NO: claimed-but-failed must be retryable — release the claim stamp on gateway `{:error, _}` (initiation failed = safe to retry; the no-retry rule protects against ambiguous outcomes — read how RefundService treats gateway errors vs timeouts and mirror its exact claim-release semantics, cite lines).
- Buyer cancel (signed page, Task 7) and merchant cancel (admin, Task 9) both call one `SusuLifecycle.cancel(plan, by)` → same path: `:cancel`, stock release, refund_all, notify.
- Plans expiring/cancelled with ZERO contributions: no refunds, no stock (never activated) — clean transition.

- [ ] **Step 1: failing tests** — sweep expires due plans, skips in-flight-chunk plans, idempotent re-run; refunds: every confirmed contribution gets exactly one gateway call across re-runs (claim), gateway error → claim released → retryable, already-:refunded payment skipped; zero-contribution expiry clean; stock released once; cancel converges (buyer + merchant paths produce identical end state).
- [ ] **Step 2-3: implement + green** → commit `feat(payments): susu expiry sweep and claim-disciplined contribution refunds`

---

### Task 7: Buyer pages — /susu/:code + signed "My susu"

**Files:**
- Create: `lib/emakola_web/live/storefront/susu_link_live.ex`, `lib/emakola_web/susu_tokens.ex`
- Modify: `lib/emakola_web/router.ex` (apex live_session, `/susu/:code`)
- Test: `test/emakola_web/live/storefront/susu_link_live_test.exs`

**Interfaces (produces):**
- `SusuTokens.sign_susu_plan/1` / `verify_susu_plan/1` (salt `"susu_plan_v1"`, 120-day max_age — plans live up to 8 weeks + slack; mirror `TrackingTokens`' shape).
- ONE LiveView serving both faces of `/susu/:code`: **public face** (no/invalid `t` param): plan summary (item, total, deadline, progress %), and — ONLY while `:pending` — the start form (first chunk amount within bounds, name+phone required, email optional, delivery per collect_delivery) driving `SusuChunks.initiate_chunk` + gateway redirect (mirror pay_link_live's initiation/redirect + friendly `{:error, _}` mapping); `:active`+ public face shows progress + "resend my link" (phone entry → sends the signed link to the phone ON FILE, always claims success — no enumeration); terminal states → friendly closed message. **Signed face** (`?t=` verifies AND matches this plan): progress bar, next-chunk form (bounds shown), delivery edit (while active), cancel button (confirm dialog → `SusuLifecycle.cancel`), post-completion → link to the order's tracking page.
- Event-completeness incl. `search_overlay` (TC-1 Critical — implement + test on THIS page); threat tests: unsigned face cannot chunk/cancel/edit (direct event push asserted no-op on money), wrong-plan valid token unauthorized.

**Store lifecycle:** the page performs the same live-store check `pay_link_live` does — a suspended/blocked store renders the unavailable state on BOTH faces (chunk initiation pauses per the spec; existing contributions untouched — expiry handles the rest).

- [ ] **Step 1: failing tests** — states × faces matrix (pending public form; active public progress+resend; signed chunk/edit/cancel; terminal closed); catalog start form re-checks variant stock and renders "sold out" when stock < quantity (activation's cancel-and-flag remains the backstop — this is the friendlier upfront block); store-unavailable state both faces; initiation drives Mox gateway with correct params (no split, susu reason); search_overlay; threat suite; resend no-enumeration.
- [ ] **Step 2-3: implement + green** → commit `feat(web): susu link page with signed buyer progress and chunk payments`

---

### Task 8: Notifications

**Files:**
- Modify: `lib/emakola/notifications/dispatcher.ex`, `templates.ex`, `order_notification_worker.ex` (event gating — TC-2's pattern), trigger sites (activation/chunk/completion/expiry in Tasks 3/5/6), `config/config.exs` (weekly-nudge cron)
- Create: `lib/emakola/notifications/workers/susu_nudge_worker.ex` (cron: daily scan → nudge active plans not chunked in 7 days; deadline warnings at 7d and 1d — dedupe via plan metadata timestamps... SusuPlan needs `last_nudged_at`/`warned_7d_at`/`warned_1d_at` — AMEND Task 1: add the three nullable timestamps)
- Test: extend `test/emakola/notifications/`

**Interfaces (produces):** buyer events `:susu_activated` (receipt + signed link), `:susu_chunk_received` (progress + signed link), `:susu_nudge`, `:susu_deadline_warning` (days interpolated), `:susu_completed` (order number + tracking link), `:susu_refunded` (expiry/cancel confirmation); merchant events `:susu_merchant_activated`, `:susu_merchant_completed`, `:susu_merchant_expired`. SMS-only (WhatsApp/push follow the TC-2 template follow-up). Dispatcher contract: events are order-based — susu events pre-completion have NO order; verify Dispatcher's dispatch signature and either (a) extend it with a plan-based variant or (b) build susu SMS sends through the same worker with plan args — read how Dispatcher/worker couple to Order and choose the smaller honest change; document.

- [ ] **Step 1: failing tests** — worker perform/1 per event (TC-2's end-to-end lesson — test through the worker from day one: body content incl. signed link, channel gating buyer/merchant); nudge worker: 7-day-quiet plans nudged once (timestamps dedupe), warnings fire once each at their windows; triggers wired (assert_enqueued at each lifecycle site).
- [ ] **Step 2-3: implement + green** → commit `feat(notifications): susu lifecycle notifications with dedup'd nudges`

---

### Task 9: Admin — third link type + extension + reserved visibility

**Files:**
- Modify: `lib/emakola_web/live/admin/pay_link_live/index.ex` (+ its test), `lib/emakola/orders/resources/susu_plan.ex` (list_for_admin + aggregates), inventory surface (find where variant stock renders in `Admin.InventoryLive` and add a reserved-by-susu count)
- Test: extend `test/emakola_web/live/admin/pay_link_live_test.exs` + inventory test

**Interfaces (produces):** create-modal type toggle gains "Susu plan" (total GH₵→pesewas via the page's existing Decimal parse, deadline date input, min-chunk optional, quantity for catalog, delivery toggle, note); list rows for susu plans show progress (`contributed/total` + status incl. :pending/:active) and funnel aggregates (opened-equivalent = activation; completed count); actions: Copy/WhatsApp share (existing helpers, /susu/:code URL), **Cancel** (→ `SusuLifecycle.cancel`), **Extend deadline** (date input, forward-only errors surfaced); reserved-by-susu = sum of quantity over :active catalog plans per variant on the inventory page (query, no schema).

- [ ] **Step 1: failing tests** — create susu plan via modal (both types); progress columns; cancel refunds-and-releases (assert via SusuLifecycle effects); extend forward-only error rendering; reserved count on inventory; tenant isolation (existing pattern).
- [ ] **Step 2-3: implement + green** → commit `feat(web): susu plans in the pay-links admin with extension and reserved-stock visibility`

---

### Task 10: Cross-cutting guards + full gate + PR

**Files:** guard tests + `TODO.md`/`docs/ACTION_ROADMAP.md` flips.

- [ ] **Step 1: guard tests** — susu order renders in admin order show/emails/confirmation (provenance badge optional, snapshot fields carry custom lines — extend `custom_order_rendering_test` with a susu-completed order); webhook success block byte-identical for plain orders (no susu_plan_id → zero new queries — pin with a targeted assertion or code-reading note in the test); payout gathering unaffected by `"susu_plan"`-held payments (excluded via payout_held — pin).
- [ ] **Step 2:** `mix format --check-formatted` && `mix credo --strict` && full `mix test` (Result: 0 failures) → rebase onto origin/main → re-run.
- [ ] **Step 3:** TODO.md + ACTION_ROADMAP TC-3 flips → commit `docs: mark TC-3 susu lay-away implemented`.
- [ ] **Step 4:** EXCLUDED from implementer scope — controller runs the final whole-branch review, fix wave, then push/PR.
