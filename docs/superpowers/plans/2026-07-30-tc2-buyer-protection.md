# TC-2 Buyer Protection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Escrow-lite payout hold — a protected order's money stays in the platform account until delivery confirms (OTP, signed-link buyer confirmation, or 5-day timer), then the merchant is paid the snapshotted net through the existing payout engine.

**Architecture:** Charge-time: `OrderSettlement.prepare` returns a `:hold` mode for protected orders → no gateway share; the payment is created `payout_held: true, payout_hold_reason: "buyer_protection"` (the exact pattern group-buys and protected preorders already use). Webhook confirm creates a `ProtectionHold` (fee/net snapshot, state machine, complaint anchor). Release flips the hold, stamps `payable_amount = net` on the payment, and calls the **existing** `Payment.:release_payout_hold`; `PayoutService` pays `payable_amount || amount`. Triggers: a hook on `FulfillmentDeliveryProof.:verify`, a signed-tracking-link buyer confirmation, and an Oban cron sweep.

**Tech Stack:** Elixir/Phoenix 1.8 LiveView, Ash 3.x (attribute multitenancy), Oban (+Cron plugin, already configured), Mox, Phoenix.Token (via the `EmakolaWeb.AuthTokens` salt-module pattern).

**Spec:** `docs/superpowers/specs/2026-07-30-buyer-protection-design.md` (on main).

## Global Constraints

- Money: integer minor units; the hold invariant `fee + net == amount` must hold at creation and never drift (fee snapshotted via `PlatformFee.calculate/2` at hold creation).
- With the store toggle OFF, behavior everywhere is byte-identical to today — guard-tested.
- Dropship split orders are NEVER protected (spec exclusion); `:dropship_split` settlement always wins over protection.
- All workers idempotent (Oban retries): hold creation, release, sweep — every one must be safely re-runnable.
- A bare order-number tracking URL must NEVER move money — buyer actions require the signed token (merchant self-release threat).
- Storefront LiveViews have no catch-all `handle_event/3` — every rendered control needs a handler; tests must exercise each.
- `mix ash.codegen` is broken repo-wide (PreorderDeposit identity) — use `mix ash_postgres.generate_migrations --domains <Domain> --name <name>` then trim unrelated drift, or hand-write single-column migrations per repo precedent; keep resource snapshots in sync for pay_links/protection tables; migrate BOTH envs.
- TDD with RED/GREEN evidence; `mix format` + `credo --strict` before each commit; read "Result:" lines, never piped exit codes.
- Conventional commits; scopes: `payments`, `orders`, `web`, `stores`, `jobs`, `docs`, `test`.

---

### Task 1: TC-1 follow-up cluster

**Files:**
- Modify: `docs/API.md` (add pay_links section), `priv/resource_snapshots/repo/pay_links/<latest>.json` (add claimed_order_id), `lib/emakola/orders/checkout_service.ex` (:phone_required), `lib/emakola/orders/resources/pay_link.ex` (variant-tenant validation), `lib/emakola_web/live/storefront/pay_link_live.ex` (phone format validation), `docs/superpowers/specs/2026-07-30-buyer-protection-design.md` (rate-limit wording)
- Test: extend `test/emakola/orders/checkout_custom_test.exs`, `test/emakola/orders/pay_link_test.exs`, `test/emakola_web/live/storefront/pay_link_live_test.exs`

**Interfaces:**
- Produces: `checkout_custom!` returns `{:error, :phone_required}` when `customer_phone` is nil/blank (instead of raising via the eager placeholder derivation).
- Produces: PayLink `:create` validation — a catalog link's `variant_id` must belong to the tenant (closes the JSON:API gap; admin UI already guards).
- Produces: buyer form rejects phones that normalize to fewer than 9 significant digits with a friendly error before checkout.

Six independent items, one commit each, all small. TDD where behavior changes (items c, d, e); docs-only items (a, b, f) commit directly.

- [ ] **Step 1 (a): docs/API.md pay_links section** — mirror the orders section's format: endpoints (GET /api/v1/pay_links, GET /:id, POST, PATCH /:id/cancel), auth (bearer + X-Store-ID), one example request/response pair for POST create (custom type), note that `mark_paid` is webhook-internal and not exposed. Commit: `docs(orders): document pay_links mobile API endpoints`
- [ ] **Step 2 (b): snapshot patch** — add `claimed_order_id` (uuid, nullable) to the pay_links resource snapshot JSON exactly as the other uuid columns are represented there (copy `variant_id`'s entry shape). Verify with `mix ash_postgres.generate_migrations --domains Emakola.Orders --name snapshot_check --dry-run` if supported, else by inspection that the column list now matches the resource. Commit: `chore(orders): sync pay_links snapshot with claimed_order_id`
- [ ] **Step 3 (c): :phone_required** — failing test first:

```elixir
test "returns {:error, :phone_required} when phone is missing" do
  store = Emakola.Factory.create_store!()

  assert {:error, :phone_required} =
           Emakola.Orders.CheckoutService.checkout_custom!(
             store.id,
             %{title: "A", unit_price: 500},
             customer_name: "Ama",
             customer_email: "ama@example.com"
           )
end
```

Implementation: in `checkout_custom!/3`, before the placeholder derivation:

```elixir
      phone = Keyword.get(opts, :customer_phone)

      cond do
        not is_binary(phone) or String.trim(phone) == "" ->
          {:error, :phone_required}
        ...existing cond clauses...
```

and only derive the placeholder inside the happy branch. Commit: `fix(orders): checkout_custom returns :phone_required instead of raising`
- [ ] **Step 4 (d): variant-tenant validation** — failing test: creating a catalog PayLink under store A with store B's variant_id returns `{:error, %Ash.Error.Invalid{}}`. Implement as a change on the `:create` action (after the existing validations):

```elixir
      change(fn changeset, _ctx ->
        with :catalog <- Ash.Changeset.get_attribute(changeset, :type),
             variant_id when not is_nil(variant_id) <-
               Ash.Changeset.get_attribute(changeset, :variant_id),
             store_id when not is_nil(store_id) <-
               Ash.Changeset.get_attribute(changeset, :store_id),
             {:ok, variant} <-
               Ash.get(Emakola.Catalog.Variant, variant_id, authorize?: false) do
          if variant.store_id == store_id do
            changeset
          else
            Ash.Changeset.add_error(changeset,
              field: :variant_id,
              message: "does not belong to this store"
            )
          end
        else
          {:error, _} ->
            Ash.Changeset.add_error(changeset, field: :variant_id, message: "not found")

          _ ->
            changeset
        end
      end)
```

Commit: `fix(orders): pay-link catalog variant must belong to the tenant`
- [ ] **Step 5 (e): buyer phone validation** — failing LiveView test: submitting the pay form with phone "abc" renders a friendly error and creates no order. Implement in the `"pay"` handler before checkout: normalize via `Emakola.Accounts.PhoneAuth.normalize/1`, count digits (`String.replace(normalized, ~r/\D/, "")`), reject < 9 digits with form error "Enter a valid phone number". Commit: `fix(web): validate buyer phone format on pay-link checkout`
- [ ] **Step 6 (f): TC-2 spec wording** — replace the spec's rate-limiting sentence with: "Payment initiation is a LiveView event with the same posture as storefront checkout (no dedicated rate-limit plumbing exists on either); unguessable codes are the primary abuse control." Commit: `docs(payments): honest rate-limit wording in buyer-protection spec`
- [ ] **Step 7:** Run `mix test test/emakola/orders/ test/emakola_web/live/storefront/pay_link_live_test.exs` — Result: 0 failures.

---

### Task 2: Store toggle + PayLink.protected + admin controls

**Files:**
- Modify: `lib/emakola/stores/resources/store.ex`, `lib/emakola/orders/resources/pay_link.ex`, `lib/emakola_web/live/admin/settings_live.ex` (verify exact module path first), `lib/emakola_web/live/admin/pay_link_live/index.ex`
- Create: migration (both columns)
- Test: `test/emakola/stores/`, extend `test/emakola/orders/pay_link_test.exs`, `test/emakola_web/live/admin/`

**Interfaces:**
- Produces: `Store.buyer_protection_enabled :boolean, default: false` (flat attribute, matching `active`'s style), accepted on the settings update action merchants use (verify its name in the settings LiveView).
- Produces: `PayLink.protected :boolean` — defaulted **at creation** from the store's setting via a change (explicit param wins); accepted in `:create`.
- Produces: settings toggle UI ("Buyer Protection — hold payments until delivery is confirmed. Slower cash-out, stronger buyer trust.") and a per-link override checkbox in the pay-link create modal shown only when the store setting is on.

- [ ] **Step 1: failing tests** — (i) store toggle persists via the merchant settings action; (ii) PayLink created with store toggle ON has `protected == true`, with toggle OFF has `false`, explicit `protected: false` param wins over an ON store; (iii) modal shows the override checkbox only when enabled (LiveView render test).
- [ ] **Step 2: implement** — Store attribute + accept; PayLink attribute + accept + change:

```elixir
      change(fn changeset, _ctx ->
        case Ash.Changeset.get_attribute(changeset, :protected) do
          nil ->
            store_id = Ash.Changeset.get_attribute(changeset, :store_id)
            store = Ash.get!(Emakola.Stores.Store, store_id, authorize?: false)

            Ash.Changeset.force_change_attribute(
              changeset,
              :protected,
              store.buyer_protection_enabled == true
            )

          _explicit ->
            changeset
        end
      end)
```

(Note: `accept` + a nil-check means the attribute must NOT have `default: false` at the resource level — leave it nullable in the resource with the change guaranteeing a boolean, and `null: false, default: false` only at the DB level is fine if the change always sets it. Keep it simple: attribute with no default, change always resolves nil.) Settings toggle + modal checkbox follow the neighboring controls' exact markup; every new control gets a handler.
- [ ] **Step 3: migration** (both columns, both envs), snapshot sync for pay_links.
- [ ] **Step 4:** tests green → commit: `feat(stores): buyer-protection store toggle and per-link override`

---

### Task 3: ProtectionHold resource + Payment.payable_amount

**Files:**
- Create: `lib/emakola/payments/resources/protection_hold.ex`
- Modify: `lib/emakola/payments/payments.ex` (register + interfaces), `lib/emakola/payments/resources/payment.ex` (payable_amount)
- Create: migration (protection_holds table + payments.payable_amount + index on protection_holds(status, release_after))
- Test: `test/emakola/payments/protection_hold_test.exs`

**Interfaces:**
- Produces: `Emakola.Payments.ProtectionHold` — tenant-scoped (attribute strategy on store_id, global?(true)):
  attributes `store_id`, `payment_id` (unique identity — idempotent hold creation), `order_id`, `amount`, `fee`, `net` (all integers), `status :atom (:held | :released | :refunded) default :held`, `frozen_at`, `release_after`, `released_at`, `release_reason :atom (:delivery_otp | :buyer_confirmed | :auto_timer | :staff)`, `complaint_reason :atom (:not_received | :not_as_described | :other)`, `complaint_text :string (max 1000)`, `resolution :atom (:merchant_refunded | :released_by_staff | :refunded_by_staff)`, timestamps.
- Produces: actions — `:create` (accepts all money fields + ids; validation `fee + net == amount` via a change that adds an error on mismatch); `:release` (accepts `release_reason`; only from `:held`; sets `released_at`); `:mark_refunded` (accepts optional `resolution`; only from `:held`); `:freeze` (accepts complaint_reason + complaint_text; only while `:held` and not already frozen — a second complaint updates text via `:update_complaint`); `:unfreeze` (clears frozen_at; internal); `:set_release_after` (accepts the datetime; only while :held).
- Produces: `Payment.payable_amount :integer` nullable — when set, PayoutService pays this instead of `amount` (Task 5).
- Produces: domain code interfaces: `create_protection_hold`, `release_protection_hold`, `freeze_protection_hold`, `get_protection_hold_by_payment`.

- [ ] **Step 1: failing tests** — invariant (fee+net==amount rejected on mismatch); state machine (release only from held; refund only from held; freeze blocks nothing structurally but sets frozen_at; double-freeze routes to update_complaint); unique payment_id (second create for same payment errors); tenant isolation.
- [ ] **Step 2: implement resource** (mirror PayLink's policy posture: merchant store-membership for reads via actor, internal writes `authorize?: false` at call sites; platform staff read policy added in Task 12).
- [ ] **Step 3: migration** (+ payments.payable_amount; index `(status, release_after)` for the sweep; unique index on payment_id), snapshots synced, both envs.
- [ ] **Step 4:** green → commit: `feat(payments): ProtectionHold resource and Payment.payable_amount`

---

### Task 4: Charge path — :hold mode + webhook hold creation

**Files:**
- Modify: `lib/emakola/payments/order_settlement.ex`, `lib/emakola_web/live/storefront/checkout_live.ex` (maybe_attach_split/split-mode helpers + payment create), `lib/emakola_web/live/storefront/pay_link_live.ex` (same, it's a copy), `lib/emakola/payments/workers/paystack_webhook_handler.ex`, `lib/emakola/payments/hubtel_webhook.ex`
- Test: `test/emakola/payments/order_settlement_test.exs` (extend), `test/emakola/payments/protection_charge_test.exs` (new)

**Interfaces:**
- Produces: a tiny pure predicate module `Emakola.Payments.Protection` with `applies?(store, pay_link_or_nil) :: boolean` — order has a pay link → the link's `protected` field governs; otherwise → `store.buyer_protection_enabled`. Built HERE (Task 11's badges consume the same function, so settlement and badge can never disagree).
- Produces: `OrderSettlement.prepare/2` checks protection FIRST via that predicate, EXCEPT dropship: reuse the exact check that routes to `:dropship_split` — if dropship applies, dropship wins unconditionally. Returns `{:hold, :buyer_protection}`.
- Produces: in both checkout LiveViews — `maybe_attach_split(params, {:hold, _}), do: params` (no split attached); `split_mode({:hold, _}), do: :none`; payment create map gains `payout_held: true, payout_hold_reason: "buyer_protection"` when settlement is a hold (mirror the group-buy literal). `record_splits(payment, {:hold, _}), do: :ok`.
- Produces: in BOTH webhook confirm sites (immediately after the PayLinkClaim call): `Emakola.Payments.ProtectionHolds.ensure_hold(payment)` — a small module function that, when `payment.payout_hold_reason == "buyer_protection"`, computes `%{fee: fee, net: net} = PlatformFee.calculate(payment.amount, fee_rate_bps())` (read the bps the same way OrderSettlement does — verify its source) and creates the ProtectionHold (unique payment_id makes retries no-ops — rescue the identity violation into :ok). Never raises into the worker.

- [ ] **Step 1: failing tests** — (i) store toggle ON + own-stock order → prepare returns `{:hold, :buyer_protection}`; (ii) toggle ON + dropship order → dropship split wins; (iii) toggle OFF → today's result byte-identical (pin the exact current return for a fixture order); (iv) pay-link order with `protected: false` on an enabled store → no hold; `protected: true` on a disabled store → hold; (v) webhook confirm on a held payment creates exactly one hold with `fee + net == amount`, and re-running the handler creates no second hold; (vi) unheld payment → no hold created.
- [ ] **Step 2: implement** per interfaces. The helpers exist twice (checkout_live + pay_link_live copies) — update both; add a shared test asserting both pages' initiate paths produce `payout_held` payments for a protected order (Mox gateway).
- [ ] **Step 3:** green (`order_settlement_test`, `protection_charge_test`, both LiveView test files) → commit: `feat(payments): protection hold mode at charge and webhook hold creation`

---

### Task 5: Payout integration + release core

**Files:**
- Modify: `lib/emakola/payments/payout_service.ex`, `lib/emakola/payments/resources/payment.ex` (verify `:release_payout_hold` accepts nothing — extend or pair with a set of payable_amount)
- Create: `lib/emakola/payments/protection_release.ex`
- Test: `test/emakola/payments/protection_release_test.exs`, extend `test/emakola/payments/payout_service_test.exs` (find its actual filename)

**Interfaces:**
- Produces: `Emakola.Payments.ProtectionRelease.release(hold, reason)` → `:ok | {:error, term}` — in one transaction: hold `:release` (reason), payment gets `payable_amount: hold.net` then `:release_payout_hold`. Idempotent: an already-released hold returns :ok without touching the payment again.
- **Verify-first (load-bearing):** read `PayoutService.prepare_payout`'s payment-gathering query. (a) Confirm it excludes `payout_held: true` payments — group-buy correctness implies it must; if it does NOT, add the filter (that's a live bug for group-buys too — note it prominently in your report). (b) Change the sum and the per-payment stamping to use `payment.payable_amount || payment.amount`.
- Produces: payout test — a released protected payment enters the backlog at **net**; a still-held one never enters; an unprotected payment is unaffected (`payable_amount` nil → full amount, byte-identical).

- [ ] **Step 1: failing tests** per the three payout cases + release idempotency + release writes `payable_amount == hold.net` + **fee-rate immunity**: create a hold, change the configured fee rate, release — the payout still uses the hold's snapshotted net, not a recomputed one.
- [ ] **Step 2: implement**; if `:release_payout_hold` doesn't accept `payable_amount`, add an accepted argument or a preceding `:update` — smallest honest change, following how group_buys calls it.
- [ ] **Step 3:** green → commit: `feat(payments): protection release pays the snapshotted net through the payout engine`

---

### Task 6: Trigger — delivery OTP

**Files:**
- Modify: `lib/emakola/orders/resources/fulfillment_delivery_proof.ex` (`update :verify`, ~line 61)
- Test: `test/emakola/payments/protection_otp_release_test.exs`

**Interfaces:**
- Consumes: `ProtectionRelease.release(hold, :delivery_otp)`.
- Produces: an after-transaction hook on `:verify` — when the proof's fulfillment's order has a payment with a `:held` ProtectionHold AND **all** of the order's fulfillments are delivered/verified (spec: multi-fulfillment orders release when all confirm; v1 orders have one), release with `:delivery_otp`. Frozen holds are NOT released by OTP (a complaint outranks physical delivery — the dispute is usually "not as described"). Use `Ash.Changeset.after_transaction/2` so a release failure logs but never fails the verify itself.

- [ ] **Step 1: failing tests** — verify on a protected order's proof releases the hold with reason `:delivery_otp` and the payment becomes payable at net; verify on an unprotected order is a no-op; a FROZEN hold stays held after verify.
- [ ] **Step 2: implement + green** → commit: `feat(orders): delivery-OTP verification releases protection holds`

---

### Task 7: Signed tracking link + buyer confirm on TrackingLive

**Files:**
- Modify: `lib/emakola_web/auth_tokens.ex` (or create `lib/emakola_web/tracking_tokens.ex` if AuthTokens' moduledoc scopes it to sessions — read it and decide, note the choice), `lib/emakola_web/live/storefront/tracking_live.ex`
- Test: `test/emakola_web/live/storefront/tracking_live_test.exs` (extend)

**Interfaces:**
- Produces: `sign_order_tracking(order_id)` / `verify_order_tracking(token)` — Phoenix.Token with a dedicated salt `"order_tracking_v1"`, max_age 90 days.
- Produces: TrackingLive mount reads the optional `"t"` query param; `buyer_authorized? = match?({:ok, ^order_id}, verify_order_tracking(t))` (token must verify AND match THIS order). The protection strip renders for any viewer when a hold exists (status: held/frozen/released/refunded + release ETA); the **"I received my order"** and **"Report a problem"** controls render ONLY when `buyer_authorized?`.
- Produces: `handle_event("confirm_received", ...)` → re-check `buyer_authorized?` from assigns (defense in depth), release via `ProtectionRelease.release(hold, :buyer_confirmed)` unless frozen; `handle_event("open_complaint"/"file_complaint", ...)` → freeze with reason + text (Task 8 wires the freeze action; here render + confirm only if Task 8 not yet merged — NO: tasks land in order, Task 8 depends on this one's authorized context; implement confirm here, complaint UI shell here with the freeze call, coordinating on the same `:freeze` action from Task 3).
- **Threat test (required):** mounting with the bare order number renders the strip but NO confirm/complaint controls, and pushing `"confirm_received"` directly (render_hook/render_click bypass) on an unauthorized socket does NOT release the hold.

- [ ] **Step 1: failing tests** — authorized mount shows controls; bare mount hides them; direct event push unauthorized → hold unchanged; authorized confirm releases (`:buyer_confirmed`); frozen hold → confirm shows "complaint under review" and stays held.
- [ ] **Step 2: implement + green** → commit: `feat(web): signed tracking link with buyer confirm for protection holds`

---

### Task 8: Complaints — freeze + refund closes the hold

**Files:**
- Modify: `lib/emakola_web/live/storefront/tracking_live.ex` (complaint form), `lib/emakola/payments/refund_service.ex`
- Test: extend `test/emakola_web/live/storefront/tracking_live_test.exs`, `test/emakola/payments/refund_service_test.exs` (find actual filename)

**Interfaces:**
- Produces: complaint form (reason select from the enum + textarea) on the authorized tracking page → `:freeze`; a frozen hold shows "Complaint under review — the money stays held" to the buyer and blocks `:auto_timer` and `:delivery_otp` releases (already enforced in Tasks 6/9; here the UI + freeze wiring).
- Produces: in RefundService — **verify-first** where a refund reaches its terminal success state; at that point, if the payment has a `:held` ProtectionHold, transition it `:mark_refunded` (resolution `:merchant_refunded` when the actor is the merchant flow; staff resolution set in Task 12). Full refunds only (spec) — verify how RefundService distinguishes full vs partial and only close the hold on full.

- [ ] **Step 1: failing tests** — filing freezes (frozen_at set, reason+text stored); double-filing updates text, single complaint row semantics; full refund on a held payment → hold `:refunded`; partial refund (if reachable) leaves the hold held; refund on an unprotected payment untouched behavior.
- [ ] **Step 2: implement + green** → commit: `feat(payments): complaints freeze holds and refunds close them`

---

### Task 9: Timer — release_after + cron sweep

**Files:**
- Modify: `lib/emakola/orders/resources/fulfillment.ex` (delivered transition hook — find the `mark_delivered`/status action), `config/config.exs` (cron entry)
- Create: `lib/emakola/payments/workers/protection_sweep_worker.ex`
- Test: `test/emakola/payments/protection_sweep_test.exs`

**Interfaces:**
- Produces: when a fulfillment reaches `:delivered`, **all** of the order's fulfillments are now delivered (spec: multi-fulfillment orders confirm when ALL do), and the order has a `:held` unfrozen hold with `release_after == nil`, set `release_after = DateTime.add(DateTime.utc_now(), 5, :day)` (constant `@release_days 5` on the worker module, referenced from the hook via a public function — single source). After-transaction hook, never fails the transition.
- Produces: `ProtectionSweepWorker` (Oban, queue: default, cron `"0 * * * *"` — hourly, matching the config's existing cron entry style): releases every hold with `status: :held, frozen_at: nil, release_after < now` via `ProtectionRelease.release(hold, :auto_timer)`. Idempotent by construction (release is). Unique job config mirroring the repo's other cron workers.
- Stale surfacing is a QUERY, not a schema change: Task 12's queue lists holds `:held` with `release_after: nil` older than 30 days.

- [ ] **Step 1: failing tests** — delivered sets release_after once (second delivery event doesn't push it later); sweep releases due unfrozen holds with `:auto_timer`; frozen holds skipped; not-yet-due skipped; sweep re-run releases nothing new.
- [ ] **Step 2: implement + green** → commit: `feat(jobs): protection auto-release timer and hourly sweep`

---

### Task 10: Notifications

**Files:**
- Modify: `lib/emakola/notifications/dispatcher.ex` (@valid_events), `lib/emakola/notifications/templates.ex`, the trigger sites from Tasks 4/7/8/9 (hold created → buyer "payment held" + signed link; delivered with hold → buyer confirm nudge; released → merchant; complaint filed → merchant)
- Test: `test/emakola/notifications/` (find the templates/dispatcher test files and extend)

**Interfaces:**
- **Verify-first:** read the dispatcher's event list + how templates map events to SMS/WhatsApp bodies and how existing order events embed URLs. Add events: `:protection_held` (buyer; body includes `#{EmakolaWeb.Endpoint.url()}/s/#{store.slug}/track/#{order.order_number}?t=#{token}` — verify the tracking route's real path shape first), `:protection_delivery_nudge` (buyer, on delivered: "confirm receipt — releases automatically in 5 days"), `:protection_released` (merchant), `:protection_complaint` (merchant). Wire each dispatch at its trigger site, always outside transactions, never failing the caller (the established Dispatcher contract).

- [ ] **Step 1: failing tests** — template render per event (assert the signed link appears in :protection_held); dispatch fired per lifecycle event (Oban assertions per the repo's notification-test idiom).
- [ ] **Step 2: implement + green** → commit: `feat(notifications): protection lifecycle notifications`

---

### Task 11: Storefront badges + merchant admin surfaces

**Files:**
- Modify: `lib/emakola/themes/default_renderers/checkout.ex` (badge), `lib/emakola_web/live/storefront/pay_link_live.ex` (badge), `lib/emakola_web/live/admin/order_live/show.ex` (hold card), `lib/emakola_web/live/admin/payout_live.ex` (held total — verify actual module name from the router: `Admin.PayoutLive`)
- Test: extend the corresponding test files

**Interfaces:**
- Buyer badge (both checkout surfaces, only when the order WILL be protected — same predicate the settlement uses; extract `Emakola.Payments.Protection.applies?(store, pay_link_or_nil)` as a tiny pure helper used by both the badge and OrderSettlement so they can never disagree): "🛡 Protected by Makola — payment held until you confirm delivery."
- Admin order show: when a hold exists — status pill (held/frozen/released/refunded), amounts (held/fee/net), release ETA (`release_after`), release reason when released.
- Payouts page: a "Held by Buyer Protection" stat tile = sum of `net` over the store's `:held` holds.

- [ ] **Step 1: failing tests** — badge renders on protected checkout and pay-link pages, absent when toggle off / link unprotected; order show renders each hold state; payouts tile sums correctly (two held, one released → only the two).
- [ ] **Step 2: implement + green** → commit: `feat(web): protection badges and merchant hold visibility`

---

### Task 12: Platform staff queue

**Files:**
- Create: `lib/emakola_web/live/platform/protection_live.ex` (follow `Platform.ModerationLive.Index`'s structure — read it first)
- Modify: `lib/emakola_web/router.ex` (platform live_session), `lib/emakola/payments/resources/protection_hold.ex` (platform read policy), sidebar/nav for platform (find where platform nav lives)
- Test: `test/emakola_web/live/platform/protection_live_test.exs`

**Interfaces:**
- Route: `live "/platform/protection", Platform.ProtectionLive` in the platform live_session; page gates itself with `{Hooks.RequirePermission, :manage_billing}` on_mount (mirror the billing page's exact idiom).
- Lists: **Frozen** (complaint details, order/store context, buyer phone last-4 only) and **Stale** (`:held`, `release_after: nil`, inserted 30+ days). Actions per row: **Force release** (`ProtectionRelease.release(hold, :staff)`, additionally setting `resolution: :released_by_staff` when the hold was frozen) and **Refund buyer** (full refund via the same RefundService entry the merchant flow uses — verify its function signature; resolution `:refunded_by_staff` via the Task 8 hook, passing actor context so the hook picks the right resolution).
- Every action writes `Emakola.Accounts.PlatformAudit` — verify-first its recording API (grep how platform store lifecycle actions record audit entries) and mirror it.
- Test with `use Emakola.LiveViewHelpers` + `setup_platform_staff(conn, permissions: [:manage_billing])`; include a permission-denied test (staff without the permission).

- [ ] **Step 1: failing tests** — frozen + stale listing; force-release releases + audits; refund path refunds + closes hold + audits; permission gate.
- [ ] **Step 2: implement + green** → commit: `feat(web): platform protection queue with force-release and staff refund`

---

### Task 13: Full verification + PR

- [ ] **Step 1:** `mix format --check-formatted` && `mix credo --strict` && full `mix test` — all clean, Result: 0 failures.
- [ ] **Step 2:** `git fetch origin main && git rebase origin/main` → re-run full suite.
- [ ] **Step 3:** TODO.md: append `→ implemented (TC-2 branch, PR pending)` to the Buyer Protection PLANNED line. ACTION_ROADMAP.md TC-2 line: append implementation status. Commit `docs: mark TC-2 buyer protection implemented`.
- [ ] **Step 4:** Push, `gh pr create` (base main) — body: summary per surface, the toggle-off byte-identical guarantee, the payout_held verify-first finding (if the filter was missing, call it out as a group-buy bug fixed in passing), follow-ups, standard footer. Check `mergeStateStatus` before telling anyone it's merged.
