# Pre-Deploy Audit — 2026-06-28

Read-only audit ahead of the launch (target ~2026-07-10). Seven parallel
specialist passes: tenant isolation/IDOR, Ash policies, authentication,
payments/money, injection/XSS, Oban + order/checkout correctness, deployment
config. Refactors are **flagged only** (deferred per the launch timetable).

**Static tooling baseline (clean):** no dependency CVEs (`mix deps.audit`), no
retired packages (`mix hex.audit`), no SQL injection (all 15 `fragment/` calls
parameterize via `^`), atoms from user input are `rescue`-guarded. Sobelow's
directory-traversal flag on review uploads is a **false positive** (filename is
sanitized `[^a-zA-Z0-9._-] -> _`, so `../` can't escape).

## Remediation status (2026-06-28)

| ID | Finding | Status |
|---|---|---|
| P0-1 | Payout double-pay | ✅ already on `main` (#220) |
| P0-2 | Stock decremented at creation, never released | ✅ PR #229 (decrement-on-payment) |
| P1-1 | Checkout removed-from-sale guard | ✅ PR #223 |
| P1-2 | Customer detail IDOR | ✅ PR #225 |
| P1-3 | Page editor IDOR | ✅ false positive (already guarded) |
| P1-4 | Coupon over-redemption race | ✅ PR #223 |
| P1-5 | Atelier hero-title stored XSS | ✅ PR #224 |
| P1-6 | Phone signup on unverified number | ✅ PR #226 |
| P1-7 | StoreMembership create permissive | ✅ PR #227 |
| P1-8 | No RemoteIp plug (rate-limit + Hubtel) | ✅ PR #228 (verify Hubtel 200 post-deploy) |

**All P0 + P1 resolved.** P2/P3 remain deferred per plan.

All fixes TDD, each its own PR off fresh `main`. P2/P3 deferred per plan.

---

> **Re-baseline note (2026-06-28):** this audit was first run against `acd439e`,
> *before* PR #220 (`fix/payout-money-safety`) merged to `main`. **P0-1 is already
> fixed by #220** (transaction + `FOR UPDATE` lock in `prepare_payout`, plus
> webhook/worker/finance hardening) — struck through below. Open fix scope is now
> **1 P0 + 8 P1**. All remaining findings re-confirmed against fresh `main` (`b925aed`).

| Severity | Count | Meaning |
|---|---|---|
| P0 | ~~2~~ → 1 open | Must fix before deploy — P0-1 resolved by #220 |
| P1 | 8 | Fix before real customers — real security/correctness, bounded blast radius |
| P2 | 13 | Post-launch hardening / minor correctness |
| P3 | 7 | Refactor / tech-debt — flagged, deferred |

---

## P0 — deploy-blockers

### ✅ P0-1 · Double-click / concurrent "Approve payout" double-pays a merchant — RESOLVED by PR #220 (already on `main`)
- **Where:** `lib/emakola_web/live/platform/finance_live.ex:57` → `lib/emakola/payments/payout_service.ex:58` (+ `payment.ex:211`, `payout_worker.ex:14`)
- **Category:** bug (money)
- **Impact:** `prepare_payout/1` runs SELECT outstanding → create payout → stamp `paid_out_at` with **no transaction and no row lock**. Two concurrent `approve_payout` events (admin double-click; no server-side idempotency on the event) both read the same un-stamped payments, each creates a payout with a *distinct* `"po_"<>UUID` reference, each enqueues `PayoutWorker`. Neither Oban-unique (keyed on differing `payout_id`) nor Paystack transfer-reference idempotency catches it → **the platform balance pays the merchant twice.** A mid-`Enum.each` crash also leaves payments partially stamped.
- **Fix:** Wrap select+create+stamp in `Repo.transaction` with `FOR UPDATE SKIP LOCKED` on the outstanding set (or guard `mark_paid_out` to stamp only rows where `paid_out_at IS NULL`), and refuse a new payout when a `:pending`/`:processing` payout already exists for the store. Add `phx-disable-with` + a server-side guard on `approve_payout`.
- **Confidence:** high

### P0-2 · Stock is decremented at order creation and never released
- **Where:** `lib/emakola/orders/checkout_service.ex:215` (decrement); `lib/emakola/orders/resources/order.ex:388` (`cancel` — no restock); no release path exists
- **Category:** bug
- **Impact:** `run_checkout` decrements `stock_quantity` the moment the `:pending` order row is created — **before** payment is initiated. Nothing ever restocks: `cancel` only flips status, and there's no payment-failure / pending-expiry release. Normal cart abandonment (the majority of checkouts) permanently bleeds inventory → phantom stockouts and lost real sales. An anonymous visitor can **zero a store's stock** by placing orders and never paying.
- **Fix (design decision needed):** either (a) move the decrement to payment confirmation (`charge.success`/`maybe_confirm_order`), or (b) keep reserve-on-create but add a compensating `:restock` in `Order.cancel` *and* a scheduled release for `:pending` orders whose payment never completes. Pick one model and make it consistent.
- **Confidence:** high

---

## P1 — fix before real customers

### P1-1 · Checkout doesn't re-validate product status / moderation
- **Where:** `lib/emakola/orders/checkout_service.ex:108` (`load_and_validate_variants`)
- **Category:** bug / vuln
- **Impact:** Order creation gates only on: variant exists, belongs to store, in stock. It never checks `product.status == :active` or `moderation_status == :ok`. A product later set to draft/archived by the merchant — or **taken down by platform moderation** — is still orderable through a stale cart, defeating the takedown control. This is the checkout-side analogue of the already-fixed add_to_cart leak.
- **Fix:** Reject any line item whose loaded `product.status != :active` or `moderation_status != :ok` (the catalog already exposes the gate via `Product.get_active_by_id` / `get_active_product`). **Quick win.**
- **Confidence:** high

### P1-2 · Cross-tenant customer PII read + write (admin customer detail)
- **Where:** `lib/emakola_web/live/admin/customer_live/show.ex:13,16,47` → `customers.ex:16` → `customer.ex:312`
- **Category:** vuln (IDOR)
- **Impact:** `get_customer_by_id(id, authorize?: false)` on a `global?(true)` resource filters on `id` only (no `store_id`, no tenant set). A merchant of Store A visiting `/admin/customers/<store-B-customer-uuid>` reads another store's customer PII + their **full order history in that store**, and `save_customer` **overwrites** the foreign record. P1 (not P0) only because customer UUIDs aren't enumerable and the index lists own-store only.
- **Fix:** Store-scoped read (`id == ^id and store_id == ^store.id`, treat mismatch as not-found), or set tenant + drop `authorize?: false` so `ActorHasStoreAccess` enforces it. **Quick win.**
- **Confidence:** high

### P1-3 · Unscoped `Pages.get_page` → cross-tenant CMS read/edit
- **Where:** `lib/emakola_web/live/admin/page_live/form.ex:312,1003` → `pages.ex:25`
- **Category:** vuln (IDOR)
- **Impact:** Same pattern as P1-2 — `get_page(id, authorize?: false)` then `update_page(... authorize?: false)`, no store scoping. If `Page` is `global?(true)` (the codebase default), a merchant can load/edit another store's page content.
- **Fix:** Store-scoped page read + assert `page.store_id == socket.assigns.store.id` before update. **Verify `Page`'s `multitenancy` block first.** Quick win.
- **Confidence:** med (call-site identical to P1-2; `Page` multitenancy unconfirmed)

### P1-4 · Coupon over-redemption race (`max_uses` not atomic)
- **Where:** `lib/emakola/orders/checkout_service.ex:241`; `lib/emakola/marketing/resources/coupon.ex:157`
- **Category:** bug (money)
- **Impact:** Coupon read with unlocked `Ash.get!`, validity-checked (`uses_count >= max_uses`), then `increment_usage`. No DB ceiling constraint. Concurrent checkouts both read `max_uses - 1`, both pass, both increment → cap exceeded. Margin loss on capped/single-use promos, scales with concurrency.
- **Fix:** Conditional atomic increment guarded by `uses_count < max_uses` (or a DB CHECK / `WHERE` at the cap); treat no-rows/constraint error as `:coupon_max_uses_reached` and roll back.
- **Confidence:** high

### P1-5 · Stored XSS via Atelier theme `hero_title`
- **Where:** `lib/emakola/themes/atelier/home.ex:201`
- **Category:** vuln (stored XSS)
- **Impact:** `{raw(String.replace(@hero_title, "\n", "<br>"))}` — `@hero_title` is merchant free-text saved unsanitized (`theme_live.ex:1088`). A merchant sets hero title to `<img src=x onerror=…>` and it executes in **every customer's browser** on the public storefront home (session/cart/checkout theft). The Vibrant theme escapes the same field — only Atelier is vulnerable.
- **Fix:** `@hero_title |> Phoenix.HTML.html_escape() |> safe_to_string() |> String.replace("\n", "<br>") |> raw()` (escape before injecting the `<br>`). **Quick win (one line).**
- **Confidence:** high

### P1-6 · Phone/WhatsApp registration creates accounts on UNVERIFIED numbers
- **Where:** `lib/emakola_web/live/auth/whats_app_live.ex:46`; `lib/emakola_web/live/storefront/customer_whats_app_live.ex:71`
- **Category:** vuln
- **Impact:** The OTP step is gated only by render-time `:if={@step == :email}`, but LiveView dispatches events by name regardless of step. A scripted socket can `send_code` (assigns `phone`) → `create_account` directly, skipping `verify_code`, producing a `confirmed_at`-stamped account on an unowned phone → number squatting + later takeover when the real owner logs in via WhatsApp.
- **Fix:** Set `phone_verified: true` only in the successful `verify_code` branch (clear it in `send_code`/`resend`); guard `create_account` on that flag. Both LiveViews. **Quick win.**
- **Confidence:** high

### P1-7 · `StoreMembership` create + read are globally open (`authorize_if(always())`)
- **Where:** `lib/emakola/accounts/resources/store_membership.ex:48`
- **Category:** vuln (privilege escalation)
- **Impact:** StoreMembership is the tenant-auth primitive `ActorHasStoreAccess` keys off. `always()` on create means any actor reaching it under `authorize?: true` could mint `{merchant: self, store: any, role: :owner}` → own an arbitrary store; open `read` enumerates the whole merchant→store graph. **Latent** today (only caller is onboarding via `authorize?: false`; no param-driven "add staff" action wired), but the most dangerous open policy.
- **Fix:** Owner-only create gate (mirror the Store create/lifecycle pattern); scope read to the actor's stores. Keep onboarding on `authorize?: false`.
- **Confidence:** high (policy); med (exploitability today)

### P1-8 · No RemoteIp plug — `conn.remote_ip` is Fly's proxy IP
- **Where:** `lib/emakola_web/endpoint.ex` (plug stack); `rate_limiter.ex:115`; `hubtel_allowlist.ex:35`
- **Category:** bug / security
- **Impact:** (a) **Per-IP rate limiting is ineffective** — every request carries Fly's internal IPv6 as `remote_ip`, so all clients share one bucket; the 10/min/IP auth limit applies to the whole proxy pool. (b) **HubtelAllowlist rejects every webhook** — it blocks IPv6 and Fly's address is always IPv6, so Hubtel payment events 403 the moment a real allowlist is set. (OTP brute-force is *not* exposed — those caps are per-phone in the DB, verified independent of IP.)
- **Fix:** Add `plug RemoteIp` (hex `remote_ip`) early in the endpoint stack, configured with Fly's proxy CIDRs, so rate limiter + Hubtel allowlist + security logging see the real client IP. Verify `/webhooks/hubtel` returns 200 post-fix.
- **Confidence:** high

---

## P2 — post-launch hardening / minor correctness

> **Status (2026-06-29):** the high-value P2s are shipped; the rest are a
> deliberate post-launch backlog. Decision: don't rush the remaining money/auth
> hardening before deploy — it's low-value and the worthwhile items (P2-4, P2-13)
> need careful, dedicated work.
>
> **✅ Done:** P2-1 (#231 webhook amount) · P2-5 (#234 wishlist add validation +
> guest-crash) · P2-9 (#233 dropship availability) · P2-10 (#232 coupon
> negative-total) · P2-11 + P2-12 (#230 secure cookie + key fail-fast).
>
> **⬜ Deferred (post-launch):** P2-2 Hubtel outbound float · P2-3 refund-approve
> no-float + bound · **P2-4 partial-refund accumulation (needs refund-event
> dedup — careful)** · P2-6 review-photo magic-bytes · P2-7 financial-action
> platform-`forbid` (latent) · P2-8 create-bypass survivors (latent) ·
> **P2-13 30-day token-in-URL (needs short-lived exchange-token redesign)**.
>
> Also noted while fixing P2-5: `WishlistLive.mount` reads `session["customer_id"]`
> but the storefront `live_session` only forwards `customer_token` — the
> authenticated wishlist path looks unreachable. Separate bug, worth a look.

| ID | Finding | Where |
|---|---|---|
| P2-1 | Webhooks don't assert paid `amount == payment.amount` (Paystack + Hubtel). Mitigated today (amount server-bound at init) but the documented defense-in-depth check | `paystack_webhook_handler.ex:95`, `hubtel_webhook.ex:31` |
| P2-2 | Float in the Hubtel **outbound** money path (`pesewas / 100.0`) — Iron-Law violation, latent rounding hazard | `gateways/hubtel.ex:113` |
| P2-3 | `Float.parse` + **unbounded** `refund_amount` on return approve (no `<= order.total`); no money moves (out-of-band) but data-integrity + no-float violation | `return_live.ex:87`, `return.ex:142` |
| P2-4 | Partial refunds **set** (not accumulate) `refunded_amount`; subsequent partials ignored after status flips `:refunded` → under-reports total refunded | `paystack_webhook_handler.ex:151` |
| P2-5 | `add_to_wishlist` persists an unvalidated client `product_id` (foreign/hidden product) — integrity, not leak; same class as the cart fix | `wishlist_live.ex:66` |
| P2-6 | Review-photo uploads lack content-type/magic-byte validation (served `nosniff`, so not XSS; reliability: route to S3/Tigris like product images) | `product_detail_live.ex:454` |
| P2-7 | Financial state-machine actions (Payment/Payout/PaymentSplit `mark_*`) lack a platform-only `forbid` above the generic Merchant policy — latent; not cross-tenant | `payment.ex:144`, `payout.ex:100`, `payment_split.ex:99` |
| P2-8 | Create-bypass survivors: `always()` create with caller-supplied `store_id` on coupon/return/address/customer_note/wishlist_item/membership/organisation — all live callers use `authorize?: false` + server store, so latent | (10 resources) |
| P2-9 | Unavailable dropship variant (`available: false`) orderable — checkout's `in_stock?` ignores `available` that `Inventory.stock_status` honors | `checkout_service.ex:132`, `variant.ex:325` |
| P2-10 | Coupon percentage cap enforced on create but not **update** → `discount_value` 150% → negative order total (no `>= 0` floor) | `coupon.ex:177` |
| P2-11 | Session cookie missing `secure: true` (narrow pre-HSTS window) | `endpoint.ex:7` |
| P2-12 | `PAYSTACK_PUBLIC_KEY` silently defaults to `""` (checkout JS fails with no boot error); same for `HUBTEL_CLIENT_SECRET` | `runtime.exs:165,171` |
| P2-13 | 30-day bearer subject token passed in `/auth/session?token=…` URL (logs/history/Referer leak; not single-use; survives logout) | `auth_tokens.ex:10` + 6 emit sites |

Also ops-flavored P2s: `server: true` gated on `PHX_SERVER` env var rather than hardcoded for prod (`runtime.exs:19`); single health endpoint + 30 s grace may be too short during a long migration (`fly.toml:65`).

---

## P3 — refactor / tech-debt (flagged, deferred per launch plan)

- No server-side idempotency on order creation (double-submit two-tab) — compounds P0-2/P1-4. `checkout_live.ex:180`
- Web layer leans on pervasive `authorize?: false` + server-resolved store → Ash policies aren't a second line of defense on hot paths (architectural). 
- OAuth `prevent_hijacking?(false)` + no email-confirmation add-on — **inert (ship-dark); must stay un-configured until fixed.** `merchant.ex:50`
- `live_view: [signing_salt: …]` hardcoded in compile-time config (can't rotate without redeploy). `config.exs:23`
- Dialyzer not in CI; no `.sobelow-conf` (security regressions can merge undetected).
- Big-file refactors already tracked in the launch timetable (Phase 3).

---

## Verified clean (checked, solid)

- **Webhooks:** Paystack HMAC-SHA512 over the **raw** body with `secure_compare`, verified before any side effect / enqueue; Hubtel fail-closed IP-allowlist + out-of-band status re-verify. `charge.success` handler is `unique: [:args]` + terminal-guarded.
- **Money:** integer minor units throughout the core path; split/fee pure integer math summing exactly to the charged total; order amounts recomputed server-side (`DenormalizeVariant`), client cart prices not trusted; stock decrement atomic with a `stock_non_negative` CHECK (no oversell on paid checkouts).
- **Auth:** session idle (24h) + absolute (14d) enforced server-side; session-id renewed on every login (fixation); TOTP unskippable + replay-protected; API refresh tokens atomically single-use (advisory lock + revoke-then-issue); OTP capped per-phone (5/OTP, 10/10min verify, 3/10min send); auth endpoints rate-limited; timing-safe comparisons throughout.
- **Authz reference pattern:** `Order` + `Store` create/lifecycle correctly gated (Merchant + `ActorHasStoreAccess`; platform-only actions `forbid_if(always())`). Mobile JSON:API tenant plug validates `X-Store-ID` against `StoreMembership`.
- **Deploy:** all critical secrets `|| raise` in the prod block (no hardcoded/dev-fallback); DB SSL `verify_peer` with OS trust store; `force_ssl` + HSTS preload; `check_origin` covers makola.io/`*.makola.io`/fly.dev; all 76 migrations additive; Dockerfile multi-stage, non-root, tini init; runtime.exs free of the `config/3` do-block trap.

---

## Recommended remediation order

**Before deploy (small, surgical, TDD — net-new bugs/vulns, not refactors):**
1. ~~P0-1 payout double-pay~~ — **done in #220.**
2. P0-2 stock release — decided: **decrement on payment confirmation.**
3. P1-1 checkout status re-validation — reuse `get_active_product`.
4. P1-5 Atelier XSS — one-line escape.
5. P1-2 + P1-3 IDOR store-scoping (customer + page reads).
6. P1-6 phone-verified gate.
7. P1-8 RemoteIp plug (+ deploy-verify Hubtel 200).
8. P1-7 StoreMembership owner-only policy.
9. P1-4 coupon atomic cap.

**Post-launch:** the P2 batch (start with P2-1 webhook amount assertion, P2-12 PAYSTACK_PUBLIC_KEY raise, P2-11 secure cookie — all tiny). **Deferred:** all P3.
