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
- [ ] **Consolidate the two Paystack webhook code paths** —
      `lib/.../paystack_webhook.ex` (synchronous) and
      `paystack_webhook_handler.ex` (Oban worker) contain divergent logic; the
      worker has the settle/reverse-splits + PubSub broadcasts the sync one
      lacks. Pick one authority; the worker already has a 24h `unique` dedup.
- [ ] **Tighten permissive `bypass action_type(:create) → always()`** on
      `Emakola.Stores.Store` (`store.ex:235`) and review the same pattern on
      `Order`/`Customer`/`LineItem`. Onboarding must stay possible — add
      rate-limiting (confirm Hammer is/ isn't applied to store creation) rather
      than just opening it. *(This is the residual of the old "6 multitenancy
      test failures" item — verify against the current suite, which CI reports
      green.)*
- [ ] **Catalog default `:read` lacks a status filter** — resources use
      `authorize_unless(actor_present())` (not the feared `always()`), and all
      storefront calls go through safe scoped actions, so risk is LOW. But the
      bare `:read` action could surface draft/hidden rows to a future caller.
      Either add `filter(expr(status == :published))` to the public read or
      document that public read must use the scoped actions only.
      Files: `product.ex:172`, `variant.ex:136`, `category.ex:90`, `review.ex:121`.
- [ ] **CSP: migrate `style-src 'unsafe-inline'` → nonced styles** (P2) —
      `lib/emakola_web/plugs/content_security_policy.ex:39` (nonce is already
      generated on line 26 but unused for style-src).
- [ ] **Fix `RawBodyReader` moduledoc** — `lib/emakola_web/plugs/raw_body_reader.ex:2`
      still says "Stripe webhook signature verification" (copy-paste artifact;
      the module is generic). Trivial.

## OPEN — Refactor / decomposition (still over the 200-line guideline)

> The earlier pass cut these hard; they're reduced but not finished.

- [ ] **`landing_live.ex` (680 lines, still a LiveView)** — convert to a dead
      `Phoenix.Component` (mobile menu via `Phoenix.LiveView.JS`). Eliminates one
      LV process per anonymous visitor. *(Inline `<style>` block already removed.)*
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

## OPEN — White-label design system (remaining phases)

- [ ] **Phase 2 — Section editor (Shopify-style)** — not started: section type
      registry, `home_sections` JSON array, `SectionSortable` JS hook, the
      admin Section Editor UI, per-section settings, backwards-compat, tests.
      *(Phase 1 page coverage and most of Phase 3 — `DesignTokens`,
      `design_tokens` config, the admin Design tab — are DONE; only a standalone
      `FontLoader` was folded into `DesignTokens`.)*

## OPEN — Infrastructure / CI

- [ ] **Add `mix dialyzer` to CI** (`.github/workflows/ci.yml`) — configured in
      `mix.exs` but never run in CI.
- [ ] **Create `.sobelow-conf`** — CI runs `mix sobelow --config` but the config
      file is absent at repo root.
- [ ] **Separate `deps` and `_build` CI cache keys** — currently one combined key.
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

---

## RESOLVED since 2026-04-25 (verified DONE 2026-06-25)

> Kept here briefly for traceability; safe to delete once consolidated.

**Checkout / orders:** DeliveryZone wired into checkout (`Shipping.calculate_fee/2`)
· fake-email Paystack pattern removed · `connected?` guard on payment polling ·
`tracking_number` added to `Order` + wired through ship flow + notification worker ·
`CachedCatalog.invalidate_store/1` called on product/category create/update/archive ·
order number via `:crypto.strong_rand_bytes`, collisions no longer mis-mapped to
`:insufficient_stock`.

**Notifications / payments:** WhatsApp Business API channel · order lifecycle email
templates (order/shipping/delivery) · rate limiting on SMS + WhatsApp · WhatsApp
Graph API version configurable (`v21.0` default, env override) · shipping-zone admin
UI · customer reviews & ratings storefront UI + admin moderation · Hubtel gateway ·
payment reconciliation dashboard · admin refund/return UI.

**White-label / architecture:** `ThemeRenderer` dispatcher + `ThemeBehaviour`
optional callbacks + `DefaultRenderers` (11 pages) wired through storefront LiveViews ·
`DesignTokens` + `design_tokens` config + admin Design tab · `Store` extracted to
`Emakola.Stores` domain (with `StoreSettings`/`StoreDomain`) · `Coupon` extracted to
`Emakola.Marketing`.

**Refactor:** `atelier/shared.ex` 1692→509 (Nav/Footer extracted).

**Infra / DB / hygiene:** Postgres-backed carts (ETS removed) · webhook→LiveView
PubSub bridge (no more 3-min poll) · `Dashboard.Stats.load_stats/1` parallelized ·
`orders.coupon_id` index added · `coupons.id` `gen_random_uuid()` default · April
migration made reversible (`up`/`down`) · `erl_crash.dump`/`firebase-debug.log`
gitignored & gone · duplicate `appendices 2/` dir removed · WhatsApp storefront
login (phone OTP) shipped · wishlist persisted to `wishlist_items` table.
