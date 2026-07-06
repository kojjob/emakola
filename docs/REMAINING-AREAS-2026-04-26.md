# Emakola — Remaining Work (post-2026-04-25 hardening pass)

> ⚠️ **SUPERSEDED (2026-06-25).** This was the same April-pass backlog as
> `TODO.md`. It has been re-audited against current code (31 of these items
> shipped since) and folded into the re-audited **[`TODO.md`](../TODO.md)** —
> the engineering backlog of record. Operational hub: **[`checklist.md`](../checklist.md)**.
> Kept for history; **do not track work here.**

**Updated:** 2026-04-26

This is the residual after the 11-commit hardening session on
`feature/product-reviews`. Items here are scoped, prioritised, and
intended for parallel execution.

---

## P0 — Required before launch

### A. Multitenancy residual (closes 6 outstanding test failures)

- [ ] **TrackingLive tenant resolution** — `lib/emakola_web/live/storefront/tracking_live.ex`
      reads `Order` without `Ash.Query.set_tenant(store.id)`. Set tenant from
      `socket.assigns.store.id` on every read.
- [ ] **Stricter create policies** — Replace `bypass action_type(:create) do
      authorize_if(always()) end` on these resources with an actor-required
      policy:
  - [ ] `lib/emakola/orders/resources/order.ex`
  - [ ] `lib/emakola/customers/resources/customer.ex`
  - [ ] `lib/emakola/orders/resources/line_item.ex`
  - [ ] Update service/worker callers (`CheckoutService`, `OrderNotificationWorker`,
        webhook handlers) to opt in via `authorize?: false` where they
        legitimately operate without an actor.
- [ ] **Catalog public-read tightening** — Add `filter(expr(status == :published))`
      to the public bypass; add an admin `read :all` action requiring Merchant
      ownership:
  - [ ] `lib/emakola/catalog/resources/product.ex`
  - [ ] `lib/emakola/catalog/resources/variant.ex`
  - [ ] `lib/emakola/catalog/resources/category.ex`
  - [ ] `lib/emakola/catalog/resources/review.ex`

### B. Checkout / order lifecycle correctness

- [ ] **Verify `tracking_number` field on `Order`** — schema appears to have
      it now; confirm "Mark as Shipped" handler in `order_live/show.ex`
      saves it and `OrderNotificationWorker` reads it correctly.
- [ ] **Wire `CachedCatalog.invalidate_store/1`** into product/category admin
      mutations — add to `product_live/{form,index}.ex`, `category_live/index.ex`
      `save_product`/`archive_product`/`activate_product`/`save_category`.
- [ ] **Fix order-number collision handling** — `CheckoutService.run_checkout/4`
      rescue maps `Ash.Error.Invalid` (collision) to `:insufficient_stock`.
      Use `:crypto.strong_rand_bytes/1` for randomness; pattern-match on
      collision specifically.

### C. Operational safety

- [ ] **Audit silent rescue blocks** — ~30 instances of `rescue _ -> []`
      across `lib/emakola/`, `lib/emakola_web/`. Add `Logger.error` with the
      exception before returning fallback. Most invasive in
      `product_live/index.ex:1174`, `checkout_live.ex:34-38`, etc.
- [ ] **Deduplicate Paystack webhook handlers** — `PaystackWebhook` and
      `PaystackWebhookHandler` have divergent duplicate logic. Pick one as
      authoritative; add unique constraint to webhook handler Oban job.

---

## HIGH — Pre-launch

### D. Decomposition follow-throughs

- [ ] **`product_live/index.ex` (1439 LOC)** — extract `ProductLive.FormComponent`
      (slide-over, ~800 lines), `BulkUploadComponent` (UI for the new
      `CsvImporter`), `product_card/1` function component.
- [ ] **`atelier/shared.ex` (957 LOC)** — extract `navbar/1` (~415 lines),
      then `product_card`/`hero_product_card`/`category_circle` family.
- [ ] **`landing_live.ex` (1052 LOC)** — extract `landing_nav/1`; consider
      conversion to dead `Phoenix.Component` (mobile menu via `Phoenix.LiveView.JS`).
- [ ] **`layouts/app.html.heex` (1044 lines)** — extract `admin_sidebar/1` +
      `admin_topbar/1` into `sidebar_components.ex`.

### E. Component library expansion

- [ ] Migrate remaining admin LiveViews to `AdminComponents.admin_page_header`,
      `status_pill`, `empty_state`. Currently only `review_live.ex` migrated.
      Targets: `customer_live/index`, `order_live/index`, `coupon_live`,
      `inventory_live`, `delivery_live/index`, `payments_live`, `theme_live`,
      `discount_live/index`, `revenue_live/index`, `report_live/index`,
      `campaign_live/index`, `return_live`, `settings_live`.
- [ ] Consolidate `dashboard/metric_components.ex` `kpi_card` and
      `inventory_components.ex` `stat_card` — pick one canonical primitive.
- [ ] Add `table_toolbar/1` (search + filter chips + actions) used across
      customer/order/product index pages.

### F. Security hardening (P2)

- [ ] Migrate `style-src 'unsafe-inline'` to nonced styles in
      `content_security_policy.ex`.
- [ ] Rate-limit unauthenticated `Store` creation (Hammer integration).

---

## UP NEXT (high impact for launch)

### G. Notifications
- [ ] WhatsApp Business API integration (order confirmations, shipping)
- [ ] SMS gateway via Hubtel SMS (or alternative)
- [ ] Email templates for order lifecycle (confirmation, shipped, delivered)
- [ ] Rate limiting on SMS/WhatsApp channel calls
- [ ] Replace hardcoded `v18.0` WhatsApp Graph API version

### H. Operations
- [ ] Shipping zone configuration admin UI (backend `Emakola.Shipping.calculate_fee/2`
      now exists — needs CRUD UI for merchants)
- [ ] Inventory low-stock alerts (Oban worker + email/WhatsApp)
- [ ] Customer reviews / ratings storefront UI (resource exists; UI missing)

### I. Payments expansion
- [ ] Hubtel payment gateway integration (Paystack done)
- [ ] Payment reconciliation dashboard (admin view of all payments)
- [ ] Admin UI for initiating refunds (backend `process_refund/2` exists)

---

## ARCHITECTURE — Structural

### J. Domain restructuring
- [ ] Extract `Store` into `Emakola.Stores` domain (currently in `Emakola.Accounts`)
- [ ] Create `Emakola.Inventory` Ash domain (currently just `stock_quantity` on `Variant`)
- [ ] Create `Emakola.Marketing` context (move `Coupon` out of `Emakola.Orders`)

### K. Ash-specific
- [ ] Evaluate `require_atomic?(false)` suppression on every update action
- [ ] Extract inline anonymous functions from Ash resources (`Order` number
      generation, `LineItem` price snapshot) into `Ash.Resource.Actions.Implementation`
      modules per `CLAUDE.md`.

---

## INFRASTRUCTURE

### L. CI/CD
- [ ] Raise `test_coverage threshold` from 50 → 90 (`mix.exs:15`)
- [ ] Add `mix dialyzer` to CI
- [ ] `mix sobelow --config` `.sobelow-conf` file
- [ ] Separate `deps` and `_build` cache keys in CI

### M. Scaling preparation
- [ ] **Replace ETS cart with persistent storage** — `CartStore` is node-local;
      breaks multi-node deployment.
- [ ] **Webhook → LiveView PubSub bridge** — payment polling currently keeps
      customer page open 3 min. Webhook should broadcast.
- [ ] Parallelize `Dashboard.Stats.load_stats/1` (6 sequential queries) using
      `Task.async_stream` or `assign_async`.

### N. Database
- [ ] Index on `orders.coupon_id` (foreign key, missing index)
- [ ] Fix non-reversible migration `20260326` (uses `def change` where `up`/`down` required)
- [ ] Add `gen_random_uuid()` default to `coupons.id`

### O. Repo hygiene
- [ ] Delete `erl_crash.dump` (46 MB) and `firebase-debug.log` from repo root
- [ ] Add both to `.gitignore` if missing
- [ ] Resolve weird `docs/business-plan/appendices 2/` directory

---

## WHITE-LABEL DESIGN SYSTEM (multi-phase)

> Full plan: `docs/superpowers/plans/2026-03-28-white-label-design-system.md`

### P. Phase 1: Full Page Coverage
- [ ] Create `ThemeRenderer` dispatcher with `function_exported?` fallback
- [ ] Extend `ThemeBehaviour` with `@optional_callbacks` for 13 new pages
- [ ] Create `DefaultRenderers.Shared` wrapper (navbar + CSS vars + footer)
- [ ] Extract default renderers for: Cart, Checkout, BlogList, BlogPost,
      RecipeList, RecipeDetail, OrderConfirmation, Tracking, Category,
      Wishlist, Account
- [ ] Wire all 13 LiveViews to delegate render through `ThemeRenderer.render/3`

### Q. Phase 2: Section Editor (Shopify-style)
- [ ] Section type registry (15+ blocks)
- [ ] Per-type renderer components
- [ ] `home_sections` JSON array in `theme_config`
- [ ] `SectionSortable` JS hook (SortableJS)
- [ ] Section Editor admin UI

### R. Phase 3: Component Variant System
- [ ] `DesignTokens` module (pure functions returning class strings)
- [ ] `FontLoader` (Google Fonts URL mapping)
- [ ] `design_tokens` in `theme_config` (10 dimensions)
- [ ] Tailwind safelist for variant fragments
- [ ] Design tab in admin theme customizer

---

## BACKLOG (post-launch)

### Storefront
- [ ] Real Emakola brand logo (replace placeholder SVG)
- [ ] Functional WhatsApp login/signup
- [ ] Store search / marketplace browsing page
- [ ] Wishlist persistence (currently session-only)
- [ ] Theme preview screenshots for selection UI
- [ ] Additional theme designs beyond initial 3
- [ ] Mobile responsiveness QA pass

### Admin
- [ ] Analytics charts (sales, orders, revenue over time) — partial today
- [ ] Customer management export
- [ ] Bulk product import/export UI (CSV backend done; needs richer admin UX)
- [ ] Staff accounts and permissions

### Infrastructure
- [ ] OG image generation for stores and products
- [ ] Performance profiling
- [ ] MTN MoMo / Vodafone Cash direct integrations (bypass Paystack)
- [ ] Rider/delivery tracking integration
- [ ] Clean up duplicate `SMSProvider` / `SMSBehaviour` hierarchy
- [ ] Fix `RawBodyReader` moduledoc (references Stripe — copy-paste artifact)
- [ ] Build `emakola-admin-mobile.html` prototype's dedicated mobile admin view
