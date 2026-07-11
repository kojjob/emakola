# Emakola — Project TODO

> **Re-audited 2026-06-25** against current code via 5 parallel verification
> passes. The previous list (2026-04-25) had drifted badly: of 58 verified
> claims, **31 were already DONE**, 15 PARTIAL, 12 OPEN. Done items have been
> removed and listed for traceability at the bottom.
>
> **Launch/go-live setups live in [`LAUNCH_TODO.md`](LAUNCH_TODO.md).**
> Master index: [`checklist.md`](checklist.md).

---

## CHANGELOG — 2026-06-25 re-audit

- **Removed (verified DONE):** the entire P0 checkout-correctness block
  (DeliveryZone wiring, fake-email Paystack pattern, `connected?` guard,
  `tracking_number`, `CachedCatalog.invalidate_store`, order-number collision
  mapping), most notifications/payments features (WhatsApp, email lifecycle,
  rate limiting, configurable Graph API version, Hubtel gateway, reviews UI,
  payment reconciliation dashboard, admin refund UI), the white-label Phase 1
  page-coverage work (ThemeRenderer + DefaultRenderers), the domain
  restructuring (`Emakola.Stores`, `Emakola.Marketing`), and all the
  infra/db/hygiene items (Postgres carts, webhook→PubSub bridge, parallelized
  dashboard stats, coupon index + UUID default, repo cleanup). Full list below.
- **Kept (still real):** security/correctness hygiene, the remaining ~70% of
  the file decomposition, a few feature gaps (real SMS provider, weight-based
  delivery, WhatsApp low-stock channel), `Emakola.Inventory` as a full domain,
  white-label Phase 2 section editor, and the CI gaps.

---

## OPEN — Security & correctness (do first)

- [x] **Audit silent `rescue _ -> []` blocks** — DONE 2026-06-25. 48 data-load
      rescues across 32 LiveView/hook files now `Logger.error("[ctx] fn raised: …")`
      before returning the (unchanged) fallback. ~11 benign sites left as-is
      (`safe_atom`, IP/user-agent → `"unknown"`, fire-and-forget `:ok` view counts,
      the documented optional-domain sitemap rescue). Compile/format/credo clean.
- [x] **Consolidate the two Paystack webhook code paths** — DONE 2026-06-25.
      The synchronous `Emakola.Payments.PaystackWebhook` was dead code (only its
      own test referenced it; the controller verifies via `Paystack.verify_webhook/2`
      and enqueues the `PaystackWebhookHandler` Oban worker) and carried stale
      logic missing split settlement/PubSub/notifications — a trap. Removed the
      module + its redundant test; the worker is now the documented single
      authority (signature coverage retained in `webhook_security_test`/`paystack_test`).
- [x] **Permissive `bypass action_type(:create)` across tenant resources** —
      DONE 2026-06-25. `Emakola.Stores.Store` was the last holdout (#217): it now
      requires a Merchant actor for `:create` (Merchant-scoped bypass that
      short-circuits the membership policy + explicit forbid for nil/Customer);
      onboarding is unaffected (`authorize?: false`, guarded by `is_nil(user)`).
      Reviewed `Order`/`Customer`/`LineItem` — **already hardened** by the
      2026-04 multitenancy pass: each has
      `policy action_type(:create) do forbid_unless(actor_present());
      forbid_unless(Merchant) … end`, and checkout/webhooks create via
      `authorize?: false`. NOTE: store/order creation is *authenticated*, so the
      old "rate-limit *unauthenticated* creation" premise is moot — a per-user
      anti-abuse limit is a separate optional follow-up.
- [x] **Catalog default `:read` contract documented** — resources use
      `authorize_unless(actor_present())` (not the feared `always()`), and all
      storefront calls go through safe scoped actions, so risk is LOW. But the
      bare `:read` action could surface draft/hidden rows to a future caller.
      Public storefront access is now explicitly documented on all four resources as requiring
      scoped actions; default reads are reserved for internal relationship/admin loads.
      Files: `product.ex:172`, `variant.ex:136`, `category.ex:90`, `review.ex:121`.
- [x] **CSP: `style-src 'unsafe-inline'`** (P2) — DONE 2026-06-25 as a
      **documented accepted risk**. Full removal is infeasible: ~760 inline
      `style="…"` attributes (CSP nonces can't cover attributes) and dynamic
      per-store theme CSS variables. `script-src` is already nonce-only (the real
      XSS vector is closed). Split into `style-src-attr` (permanent) /
      `style-src-elem` (deferred) with the rationale written into the plug
      moduledoc; future hardening = nonce the ~32 `<style>` blocks (needs a
      socket-stable nonce) then drop `'unsafe-inline'` from `style-src-elem`.
- [x] **Fix `RawBodyReader` moduledoc** — now accurately documents generic payment and
      third-party webhook signature verification.

## OPEN — Refactor / decomposition (still over the 200-line guideline)

> The earlier pass cut these hard; they're reduced but not finished.

- [x] **`landing_live.ex` → dead render** — DONE 2026-07-11. `LandingController` +
      `LandingHTML`; mobile menu is pure client state in the shared `landing_nav`
      (`Phoenix.LiveView.JS`, no parent handler — 10 caller LiveViews cleaned up);
      scroll effects bind via `data-scroll-glass`/`data-scroll-reveal` in app.js so
      they work on dead pages and live navigation alike. No LV process per
      anonymous visitor.
- [ ] **`admin/product_live/index.ex` (1337 lines)** — extraction started
      (`form.ex`, `bulk_upload_modal.ex`, `Catalog.CSVImporter` all exist).
      Finish: pull out `product_card/1` and move the remaining Ash mutations
      (`archive`/`activate`/`save`) into `Emakola.Catalog` context functions.
- [ ] **`components/layouts/app.html.heex` (901 lines)** — `sidebar_components.ex`
      exists but only holds the icon map; extract `admin_sidebar/1` +
      `admin_topbar/1` into it.
- [ ] **`storefront/checkout_live.ex` (645 lines)** — down from 1517 via
      `CheckoutService`. Optional: extract `payment_method_card/1` and a poll
      helper if it grows again. (No `PollService` was created — payment now uses
      a PubSub bridge, so it may not be needed. Lower priority.)

## OPEN — Component library consistency

- [ ] **Finish replacing inline hex literals with named tokens** — the 7 tokens
      (`emakola-emerald`, `emakola-gold`, `mtn`, `voda`, `whatsapp`,
      `store-accent`, `cta-dark`) are defined in `assets/css/app.css:164`, but
      ~1968 `bg-[#…]`/`text-[#…]`/`from-[#…]` literals still exist in `lib/`.
- [ ] **Resolve color drift** — both `#B45309` (66×, storefront default) and
      `#CA8A04` (15×, admin) are in use. Standardise per
      `storefront_components.ex` (`#B45309`).
- [ ] **Add the two missing shared admin components** — `admin_page_header/1`
      and `empty_state/1` exist in `admin_components.ex`; add `table_toolbar/1`
      and reconcile the `status_pill/1` vs the planned `status_badge/1` name.
- [ ] **Unify the duplicate KPI primitives** — `stat_card/1`
      (`inventory_components.ex:49`) and `kpi_card` (`metric_components.ex:55`)
      overlap; pick one and update usages in customer/revenue/report/campaign
      admin LiveViews.

## PARTIAL — Feature gaps

- [ ] **Real SMS provider** — `notifications/channels/sms.ex` + rate limiting
      exist, but only the `LogSMS` mock is wired; plug in Arkesel/Hubtel
      (overlaps `LAUNCH_TODO.md` item 4).
- [ ] **Delivery fee beyond flat-per-zone** — `Emakola.Shipping.calculate_fee/2`
      does zone lookup only; add weight-based / tiered rules if needed.
- [ ] **Low-stock WhatsApp channel** — `low_stock_alert_worker.ex` sends email
      + SMS digest; WhatsApp alerting not yet wired.
- [ ] **Hubtel refund automation** — `gateways/hubtel.ex` `process_refund/2`
      returns `:not_supported` (manual today); automate if/when Hubtel supports it.

## OPEN — Architecture

- [ ] **Promote `Emakola.Inventory` to a real Ash domain** — currently a service
      shell (`inventory.ex:23` says "intentionally NOT a `use Ash.Domain` yet");
      stock is still a single `stock_quantity` integer on `Variant`. Add stock
      levels + multi-location when warranted.
- [ ] **Extract remaining inline Ash anonymous functions into Change modules** —
      `LineItem` price snapshot already uses `Changes.DenormalizeVariant`; the
      `Order` number generation (`order.ex:274`) and status-transition
      `after_action` notification dispatches are still inline `change(fn …)`.

## OPEN — Makola Earn / zero-capital supplier network

> Canonical specification and status: [`docs/ROADMAP-dropshipping.md`](docs/ROADMAP-dropshipping.md).
> Private suppliers, split fulfillment, payout onboarding, and direct Paystack settlement
> already exist. This workstream builds the verified shared network.

- [x] Persist proportional partial/full refund reversal amounts on the existing
      `PaymentSplit` ledger (no duplicate liability table).
- [x] Recover reversal amounts from future recipient splits using row-locked
      reservations, success/failure reconciliation, and proportional reopening
      when a recovery-bearing earning is itself refunded.
- [x] **SP2 foundation:** wholesaler↔reseller connection resource, authorized service,
      lifecycle, migration, and tests.
- [x] **SP2 UI:** merchant invitations, approvals, active connections, suspension,
      reactivation, and termination at `/admin/settings/supply-network`.
- [x] **SP3:** shared physical/digital offers, markup/fixed commission, one-click listing,
      and source synchronization.
  - [x] Shared-offer foundation references existing products/variants, validates
        markup and fixed-commission terms, and limits discovery to active supply partners.
  - [x] Transactional reseller listing/import mapping for products, variants,
        option values, bounded pricing, and existing supplier fulfillment linkage.
  - [x] Retryable, SSRF-safe source-image replication into reseller-owned storage.
  - [x] Pilot-facing one-click listing UI with offer earnings and imported-listing status.
- [x] **SP4:** authorized cross-store supplier inbox, customer delivery OTP proof,
      and protected grants for imported digital products.
- [x] Add channel-ready Sales Kits, session-deduplicated tracked links, confirmed-order
      attribution, and the guided “First Money” journey.
- [x] Enforce Earn launch guards: both payout accounts verified before network checkout,
      no ordinary coupons on network items, and visible partner-fulfillment disclosure.
- [ ] Pass the concierge validation gate before broad network rollout.
- [ ] **Income Operating System:** deliver the phased program in
      [`docs/ROADMAP-income-operating-system.md`](docs/ROADMAP-income-operating-system.md),
      beginning with persistent income goals and the deterministic Hustle Autopilot.
  - [x] Persist authorized income goals and generate an explainable deterministic seven-day plan.
  - [x] Add goal creation and the seven-day plan to Earn Network using existing offer economics.
  - [x] Add fulfilled net-earnings progress and executable next actions to Earn Network.
  - [x] Add historical-signal ranking and expose supplier net, customer price, platform fee,
        reseller net earnings, evidence confidence, and ranking reason.
  - [x] Complete Phase A — Hustle Autopilot.
  - [x] Build Phase B — voice-first Business-in-a-Box and fact-grounded content drafts.
    - [x] Add supplier-fact snapshots, deterministic channel drafts, stale-content protection,
          and explicit merchant review in Earn Network.
    - [x] Add preview-first voice/text commands with explicit confirmation before mutations.
    - [x] Add one-action niche starter catalogs with products, tracked links, and content drafts.
    - [x] Add curated English/Twi variants and escaped social cards grounded in approved
          supplier images, titles, and prices.
  - [x] Build Phase C — privacy-safe Opportunity Radar, bounded ethical pricing, and
        aggregate-only supplier demand alerts.
  - [ ] Run Phase C's live controlled evaluation against the popularity-only baseline.
  - [x] Build Phase D — group buys, consent-based sales teams, and micro-franchises.
    - [x] Add Phase D schemas and authorized service foundations with threshold/payment checks,
          exact consented team splits, package terms, and explicit anti-MLM structure.
    - [x] Add Phase D merchant/customer UI, settlement integration, automatic refunds, and
          approved-package catalog activation.
      - [x] Add Earn Network merchant UI for group buys, exact-split team invitations/consent,
            and supplier/reseller micro-franchise publishing/discovery/application.
      - [x] Add supplier-only approval, atomic package-offer catalog activation, and enrollment
            evidence linking every activated reseller listing.
      - [x] Add UUID-safe sales-team attribution links, customer economics disclosure, exact
            consented settlement ledgers, webhook integration, and proportional refund reversals.
      - [x] Add customer group-buy discovery, capacity-reserving commitment/payment UI, and
            idempotent webhook funding on imported storefront products.
      - [x] Add scheduled, idempotent automatic gateway refunds for expired under-threshold
            group buys, including persisted claim, reference, and failure state.
  - [x] Build Phase E — trust, progression, and compliant partner credit.
    - [x] Add deterministic commerce passports with bounded tiers, aggregate evidence, reason
          codes, expiry, repeatable refresh, correction audit state, and merchant appeals.
    - [x] Add Earn Network inspection, evidence display, expiry visibility, refresh, and
          per-signal appeal UI.
    - [x] Add transparent passport-tier inventory eligibility, supplier-authored caps/reason
          codes, atomic stock holds, idempotent paid-order consumption, and automatic unused release.
    - [x] Add licensed-partner or explicit supplier trade credit with informed consent,
          external disbursement evidence, explainable passport decisions, and idempotent
          sales-only repayment/refund reconciliation through the payment-split ledger.
  - [x] Build Phase F — trust-protected preorders.
    - [x] Require complete customer disclosures, demand limits, delivery windows, milestone
          evidence, and independent legal/payment-provider approval references before launch.
    - [x] Quarantine deposits from payout until verified fulfillment; automatically refund
          deadline/milestone failures and add explainable supplier performance consequences.
  - [ ] Harden income-OS money paths per the 2026-07-11 post-merge review: group-buy
        refund claim races/crash recovery, trade-credit balance locking, transactional
        team-settlement persistence, reservation release races, and late-webhook
        refund coverage. (Fix-forward PRs in flight.)

## OPEN — White-label design system (remaining phases)

- [ ] **Phase 2 — Section editor (Shopify-style)** — not started: section type
      registry, `home_sections` JSON array, `SectionSortable` JS hook, the
      admin Section Editor UI, per-section settings, backwards-compat, tests.
      *(Phase 1 page coverage and most of Phase 3 — `DesignTokens`,
      `design_tokens` config, the admin Design tab — are DONE; only a standalone
      `FontLoader` was folded into `DesignTokens`.)*

## OPEN — Infrastructure / CI

- [x] **Add `mix dialyzer` to CI** and make Dialyxir available in the test environment.
- [x] **Create and triage `.sobelow-conf`** — CI now enforces medium findings.
      Narrow reviewed skips cover static JSON/escaped integer responses; the custom
      nonce CSP plug is documented because Sobelow cannot recognize it. The previously
      unprotected SEO pipeline now receives secure headers and the same CSP.
- [x] **Separate `deps` and `_build` CI cache keys**, including OTP/Elixir versions in
      the build cache key to prevent incompatible BEAM reuse.
- [ ] **Raise `test_coverage` threshold** — `mix.exs:15` is at 55; ratchet toward
      90 as tests are added.

## OPEN — Cleanup (low effort)

- [ ] **Collapse the duplicate SMS hierarchy** — `notifications/sms_provider.ex`
      (behaviour) and `channels/sms_behaviour.ex` (higher-level) both exist;
      consolidate or clearly document the split.

---

## BACKLOG (not re-verified — aspirational / future)

### Storefront
- [ ] Real Emakola brand logo (replace placeholder SVG)
- [ ] Store search / marketplace browsing page
- [ ] Theme preview screenshots for the selection UI
- [ ] Additional theme designs beyond the current set
- [ ] Mobile responsiveness QA pass

### Admin
- [ ] Deeper analytics charts (sales/orders/revenue over time)
- [ ] Customer export
- [ ] Staff accounts & permissions (merchant-side; platform staff auth shipped)

### Infrastructure / payments
- [ ] OG image generation for stores and products
- [ ] MTN MoMo direct integration (bypass Paystack)
- [ ] Vodafone Cash direct integration
- [ ] Rider/delivery tracking integration
- [ ] Decide: build a dedicated mobile admin view, or declare the responsive
      admin sufficient
- [ ] Decommission the legacy User/Organisation auth path (dead since #108;
      `resolve_user`'s `current_store: nil` stub is a trap) — see `LAUNCH_TODO.md`
- [ ] Seed digital-downloads demo data — see `LAUNCH_TODO.md`

