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
- [x] **Sanitize URL-position block content** — DONE 2026-07-12. Page-builder
      block content (`hero_banner`, `image_banner`, `split`, `audio`, `video`)
      rendered merchant-controlled URLs straight into `href`/`src`/`poster`
      with no scheme validation — a `javascript:` value would render as a
      live link. Fixed at the render boundary with
      `Emakola.PageBuilder.SafeUrl.safe_url/1` (http(s) or site-relative
      only; everything else, including all protocol-relative spellings,
      becomes `nil` and HEEx omits the attribute), applied at all nine URL
      sinks. Covers both write paths in one move — the pre-existing page
      editor and the section block-bridge — plus all already-stored data.
      Design: `docs/superpowers/specs/2026-07-12-block-url-sanitization-design.md`.

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
- [x] **`components/layouts/app.html.heex` decomposed** — DONE 2026-07-11: 907 → 99
      lines. `admin_sidebar/1` (overlay + aside + user popover) and `admin_topbar/1`
      (search, quick add, notifications, user dropdown) extracted verbatim into
      `SidebarComponents`; the shared display helpers (`user_initials`,
      `notification_*`, `relative_time`) moved to a new leaf `LayoutHelpers`
      module (with `Layouts` delegates) to break the circular dependency.
- [ ] **`storefront/checkout_live.ex` (645 lines)** — down from 1517 via
      `CheckoutService`. Optional: extract `payment_method_card/1` and a poll
      helper if it grows again. (No `PollService` was created — payment now uses
      a PubSub bridge, so it may not be needed. Lower priority.)

## OPEN — Component library consistency

- [x] **Brand-token sweep** — DONE 2026-07-11, rescoped after measurement. The
      "~1968 literals" were mostly per-theme palettes (a theme's identity IS its
      hex palette — flattening them to global tokens would be wrong), so only
      true brand colors were swept: all WhatsApp (`#25D366`/`#1FAF55` → 
      `-whatsapp`/`-whatsapp-dark`, 22×) and Telecel (`#E60000` → `-voda`, 3×)
      literals everywhere, plus spelling normalizations in `lib/emakola_web`
      (non-theme) files (`#B45309` → `amber-700`, `#0F172A` → `slate-900`).
      MTN/emerald/gold literals were already fully swept by earlier passes.
- [x] **Resolve color drift** — RESOLVED-AS-STALE 2026-07-11: only 3 `#CA8A04`
      uses remain and all are deliberate (the `emakola-gold` token definition,
      Atelier's `--theme-gold`, and a merchant color-picker option). No scattered
      drift exists; earlier passes already standardised the storefront on
      `#B45309`.
- [ ] **Add the two missing shared admin components** — `admin_page_header/1`
      and `empty_state/1` exist in `admin_components.ex`; add `table_toolbar/1`
      and reconcile the `status_pill/1` vs the planned `status_badge/1` name.
- [ ] **Unify the duplicate KPI primitives** — `stat_card/1`
      (`inventory_components.ex:49`) and `kpi_card` (`metric_components.ex:55`)
      overlap; pick one and update usages in customer/revenue/report/campaign
      admin LiveViews.

## PARTIAL — Feature gaps

- [x] **Real SMS provider** — DONE 2026-07-11. The channel was already wired in
      prod (`runtime.exs` sets `:sms_provider` to `Channels.SMS`); it now speaks
      Arkesel v2 natively via `SMS_PROVIDER=arkesel` (api-key header,
      sender/message/recipients payload, endpoint defaulted — closes the
      LAUNCH_TODO header warning). Generic Bearer gateways remain the default.
      Ship-dark: dev/test stay on LogSMS/Mox.
- [x] **Delivery fee beyond flat-per-zone** — DONE 2026-07-11. `DeliveryZone`
      gained `free_above_pesewas` (order subtotal free-shipping threshold) and
      `per_kg_fee_pesewas` (surcharge per started kg of `variant.weight_grams`);
      `calculate_fee/3` accepts subtotal/weight context (free-above wins),
      checkout passes both, zone admin form has the two GHS inputs.
      Follow-up: merchants can't set variant weights via UI yet (API/CSV only) —
      add a weight input to the product/variant admin form.
- [x] **Low-stock WhatsApp channel** — DONE 2026-07-11. The daily digest now also
      goes to `store.whatsapp_number` via the `low_stock_digest` template,
      tolerating an unapproved Meta template exactly like the announcement
      worker (ship-dark until the template goes live — submit it alongside the
      LAUNCH_TODO step-1 batch).
- [ ] **Hubtel refund automation** — `gateways/hubtel.ex` `process_refund/2`
      returns `:not_supported` (manual today); automate if/when Hubtel supports it.

## OPEN — Architecture

- [x] **Promote `Emakola.Inventory` to a real Ash domain** — CORE DONE
      2026-07-11 (full multi-location per decision). Domain owns `Location`
      (one default per store, partial unique index), `StockLevel`
      (variant × location, non-negative CHECK), and the insert-only
      `StockMovement` ledger. Invariant: `variant.stock_quantity` stays the
      fast-read total == Σ levels, maintained by the single write funnel
      (`restock/adjust/transfer/decrement_for_sale!`) under a FOR UPDATE
      variant lock; sales cascade default-first then stock-descending.
      Migration backfilled a "Main" location + level per tracked variant;
      later variants seed lazily. All four writers rewired (checkout
      decrement, Earn reservations hold/release, admin adjust, catalog
<<<<<<< HEAD
      interface unused). UI follow-up SHIPPED 2026-07-11: admin inventory
      page gained the locations manager (add/rename/set-default/deactivate
      with guard flashes), per-location breakdown lines on variant rows,
      a location picker on the stock editor, and the transfer modal.
- [ ] **Extract remaining inline Ash anonymous functions into Change modules** —
      `LineItem` price snapshot already uses `Changes.DenormalizeVariant`; the
      `Order` number generation (`order.ex:274`) and status-transition
      `after_action` notification dispatches are still inline `change(fn …)`.
||||||| 1daf9ab
      interface unused). REMAINING (UI follow-up): locations management,
      per-location stock matrix, restock location picker, transfer modal.
- [ ] **Extract remaining inline Ash anonymous functions into Change modules** —
      `LineItem` price snapshot already uses `Changes.DenormalizeVariant`; the
      `Order` number generation (`order.ex:274`) and status-transition
      `after_action` notification dispatches are still inline `change(fn …)`.
=======
      interface unused). REMAINING (UI follow-up): locations management,
      per-location stock matrix, restock location picker, transfer modal.
- [x] **Extract remaining inline Ash anonymous functions into Change modules** —
      DONE 2026-07-11. `Changes.GenerateOrderNumber` (create), parameterized
      `Changes.NotifyStatusChange` (shipped/delivered/cancelled dispatches), and
      `Changes.NotifyConfirmation` (confirm fanout: notification + Earn
      conversion + supplier fulfillments); the Order module's dispatch helpers
      moved with them. Behavior-preserving — 234 order tests unchanged.
>>>>>>> origin/main

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
        *(Harness shipped 2026-07-11: `RadarEvaluation` deterministic arms + baseline
        ranking + `mix emakola.radar_eval` report; the live run awaits pilot traffic.)*
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

- [ ] **Phase 2 — Section editor (Shopify-style)**
  - [x] Core infrastructure + two reference themes — DONE 2026-07-11: section
        contract/registry (`Emakola.Themes.Section`, `Sections`), the
        block-bridge (`block/<type>` into the page-builder library),
        `HomeSections` per-theme layout storage (sanitized: type resolution,
        URL scoping, padding/color allowlists), and `SectionRenderer` (style
        wrapper only for styled entries — byte-identical defaults); Starter
        and Atelier decomposed into registered sections. Spec:
        `docs/superpowers/specs/2026-07-11-section-editor-design.md`.
  - [x] Admin Section Editor UI — DONE 2026-07-12:
        `EmakolaWeb.Admin.DesignSectionsLive` at `/admin/design/sections`
        (rows with hand-rolled drag-and-drop + keyboard reorder, toggle,
        per-section settings/style forms, add/remove for custom instances,
        in-process live preview, draft/publish/reset with an unsaved-changes
        guard), linked from the Design tab. End-to-end sealed: a reorder
        published through the editor renders on the live storefront
        (`home_sections_integration_test.exs`).
  - [ ] Remaining: the seven new themes (Sika, Fie, Chale, Dede, Depot, Pace,
        Ntoma — locked 2026-07-11), and the cull-gated fan-out of surviving
        existing themes into sections.
      *(Phase 1 page coverage and most of Phase 3 — `DesignTokens`,
      `design_tokens` config, the admin Design tab — are DONE; only a standalone
      `FontLoader` was folded into `DesignTokens`.)*
- [ ] **Security: sanitize URL-position block content (href/src) at the
      block-render boundary** — `block/<type>` section entries bridge the
      page-builder block library verbatim (`BlockSection.settings_schema/0`
      is `[]`, so `HomeSections` URL scoping is skipped by design — see
      `home_sections_integration_test.exs`). A `javascript:`/`data:` value
      in a block's href/src-position field (e.g. `hero_banner`'s `cta_url`,
      or the equivalent on `split`/`image_banner`/`audio`) renders as a
      live, clickable link — a stored-XSS vector, and the same pre-existing
      gap in the page builder's own unsanitized content bar. Closing both
      paths MUST land before or with the section-editor UI PR (above),
      which makes `put_layout` merchant-reachable for the first time.

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

- [x] **Collapse the duplicate SMS hierarchy** — DONE 2026-07-11. Single
      `SMSProvider` behaviour (`send_sms/3` + optional `send_order_sms/2`);
      `Channels.SMSBehaviour` deleted, `Channels.SMS` declares `SMSProvider`,
      `SMSChannelMock` repointed. Workers' `:sms_provider` resolution unchanged.

---

## PLANNED — Ghana trust-commerce features (specs started 2026-07-30)

Revenue-first feature series for IG/WhatsApp social sellers (see
`docs/REVENUE-FIRST-90-DAY-PLAN.md`). Build order agreed: pay links first
(standalone, validates demand earliest), protection layered second, susu
reuses protection's held-funds ledger, addressing is independent.

- [ ] **Pay Links** — shareable DM checkout links, catalog + custom-amount
      (single-use); ad-hoc line items via nullable `LineItem.variant_id`.
      Spec: `docs/superpowers/specs/2026-07-30-pay-links-design.md` ✅ specced
      → implemented (TC-1 branch, PR pending)
- [ ] **Buyer Protection** — escrow-lite payout hold until delivery
      confirmation; builds on settlement engine + refund liability.
      Spec: `docs/superpowers/specs/2026-07-30-buyer-protection-design.md` ✅ specced
      → implemented (TC-2 branch, PR pending)
- [ ] **Susu lay-away** — installment purchase (MoMo chunks, goods release
      when fully paid, balance refundable); shares held-funds design
      with Buyer Protection.
      Spec: `docs/superpowers/specs/2026-07-30-susu-layaway-design.md` ✅ specced
- [ ] **GhanaPost GPS + landmark addressing** — digital address code
      (GA-183-8164) + landmark field on address forms/checkout/dispatch views.
      Spec: `docs/superpowers/specs/2026-07-30-ghanapost-addressing-design.md` ✅ specced
      → implemented (TC-4 branch, PR pending)
- [ ] **Makola Book (pay later, TC-5)** — merchant trade credit digitized:
      deposit + flexible balance chunks, two-tier earned eligibility keyed on
      phone, platform-wide default freeze; spine invariant = limit ≤ profit
      already generated. No interest/late fees (trade credit, not lending).
      Spec: `docs/superpowers/specs/2026-07-30-pay-later-book-design.md` ✅ specced

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
- [ ] Telecel Cash direct integration
- [ ] Rider/delivery tracking integration
- [ ] Decide: build a dedicated mobile admin view, or declare the responsive
      admin sufficient
- [ ] Decommission the legacy User/Organisation auth path (dead since #108;
      `resolve_user`'s `current_store: nil` stub is a trap) — see `LAUNCH_TODO.md`
- [ ] Seed digital-downloads demo data — see `LAUNCH_TODO.md`

