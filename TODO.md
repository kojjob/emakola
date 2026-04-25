# Emakola — Project TODO

**Last updated:** 2026-04-25 (post-audit refresh)

> This list reflects the 2026-04-25 codebase audit. Items previously listed as P0
> were re-verified; many were already fixed and have been removed (address
> `line_1` mismatch, Coupon authorizer, `/health` DB query, `String.to_atom`
> claim, secrets-at-compile-time claim, storefront `on_mount` tenant resolver).

---

## RECENTLY COMPLETED (since last refresh)

- Address `line_1` key consistency between writer and reader — verified
- Coupon resource `authorizers: [Ash.Policy.Authorizer]` — verified at `lib/emakola/orders/resources/coupon.ex:17`
- `/health` controller queries `SELECT 1` — verified
- Secrets resolved via `runtime.exs` not compile-time — verified
- Storefront `live_session` calls `EmakolaWeb.Hooks.ResolveStore` `on_mount` — verified
- Paystack gateway integration with HMAC verification (PR #36)
- Theme engine + customizer (PRs #34/#35)
- N+1 query elimination across dashboard / catalog (`edbf564`)
- 5 deployment blockers resolved (`e1cecab`)
- Sitemap / robots.txt / llms.txt (`9041293`)
- `theme_styles/1` for all 5 non-Atelier themes (`20d4e60`)

---

## CRITICAL — Fix Before Launch

### P0: Multi-Tenant Read Isolation (NEW, audit finding)

**Systemic finding:** every tenant-scoped Ash resource declares
`bypass action_type(:read) do authorize_if(always()) end`. Cross-tenant
isolation depends entirely on callers passing `store_id` arguments. There is
no `multitenancy do strategy :attribute end` block on any resource. One
forgotten filter exposes every store's data.

- [ ] Add `multitenancy do strategy :attribute; attribute :store_id; global? true end` to every tenant-scoped resource:
  - [ ] `lib/emakola/customers/resources/customer.ex`
  - [ ] `lib/emakola/customers/resources/address.ex`
  - [ ] `lib/emakola/customers/resources/customer_note.ex`
  - [ ] `lib/emakola/customers/resources/wishlist_item.ex`
  - [ ] `lib/emakola/orders/resources/order.ex`
  - [ ] `lib/emakola/orders/resources/line_item.ex`
  - [ ] `lib/emakola/orders/resources/return.ex`
  - [ ] `lib/emakola/orders/resources/coupon.ex`
  - [ ] `lib/emakola/payments/resources/payment.ex`
- [ ] Replace `bypass action_type(:read)` with scoped policies that authorize on
      `actor.current_store_id == store_id` for merchants and `customer_id == ^actor(:id)`
      for customers.
- [ ] Tighten catalog reads to `filter(expr(status == :published))` for the public
      bypass; add a separate admin read action that requires merchant ownership:
  - [ ] `lib/emakola/catalog/resources/product.ex`
  - [ ] `lib/emakola/catalog/resources/variant.ex`
  - [ ] `lib/emakola/catalog/resources/category.ex`
  - [ ] `lib/emakola/catalog/resources/review.ex`
- [ ] Write integration tests proving `store_a` actor cannot read `store_b` data
      across all resources above.

### P0: Store Update Bypass

- [ ] `lib/emakola/accounts/resources/store.ex:99-115` — `bypass always() do
      authorize_unless(actor_present()) end` allows nil-actor (system) writes to
      any store. Move bypass below ownership check or require explicit system
      actor; ensure background workers carry an explicit actor.

### P0: Checkout Correctness

- [ ] **Wire `DeliveryZone` resource into checkout** — `CheckoutLive` line 1431-1441
      hardcodes a region→fee map (`"greater_accra" -> 1500`, `"ashanti" -> 2500`,
      etc.). The admin `DeliveryZone` config is unused. Move calculation to
      `Emakola.Shipping` context.
- [ ] **Replace fake-email Paystack pattern** — `checkout_live.ex:1337` synthesizes
      `"#{phone}@checkout.emakola.com"` and sends to Paystack, polluting their
      customer DB and breaking receipts. Collect a real email or use a single
      store-owned address.
- [ ] **Add `connected?(socket)` guard** for `Process.send_after` in
      `checkout_live.ex:1385-1386` — timer leaks on disconnected static renders.
- [ ] **Add `tracking_number` field to `Order` resource** — "Mark as Shipped"
      modal collects it but the handler discards it; `OrderNotificationWorker`
      reads a non-existent field.
- [ ] **Wire `CachedCatalog.invalidate_store/1`** into product/category admin
      actions — cache currently never invalidated; stale storefront for up to
      5 minutes after edit.
- [ ] **Fix order number collision error mapping** — collision raises
      `Ash.Error.Invalid` which `CheckoutService` rescue maps to
      `:insufficient_stock`. Use `:crypto.strong_rand_bytes/1`; handle collision
      explicitly.

### P0: Operational Safety

- [ ] **Audit silent rescue blocks** — `lib/emakola_web/live/admin/product_live/index.ex:1174`
      and ~30 other `rescue _ -> []` blocks across the codebase. At minimum
      `Logger.error` before returning fallback. Merchants currently see empty
      states on auth/DB failures with no signal.
- [ ] **Deduplicate Paystack webhook handlers** — `PaystackWebhook` and
      `PaystackWebhookHandler` contain divergent duplicate logic. Add unique
      constraint to webhook handler Oban job.

---

## HIGH — Fix Before Launch

### Architecture / Code Decomposition

Files exceeding the project's 200-line guideline (per `CLAUDE.md`):

- [ ] **`lib/emakola/themes/atelier/shared.ex` (1692 lines)** — split into
      `Atelier.{Nav, Footer, ThemeStyles, ProductComponents}`. Move static CSS
      out of `theme_styles/1` into a stylesheet; keep only CSS variable
      overrides inline.
- [ ] **`lib/emakola_web/live/admin/product_live/index.ex` (1564 lines)** —
      extract `ProductLive.FormComponent` (slide-over, lines 160-964),
      `Emakola.Catalog.CSVImporter` + `BulkUploadComponent` (lines 273-358 +
      1218-1400), `product_card/1` function component. Move `archive_product`,
      `activate_product`, `save_product` Ash mutations into `Emakola.Catalog`
      context functions.
- [ ] **`lib/emakola_web/live/storefront/checkout_live.ex` (1517 lines)** —
      collapse `place_order`/`create_order`/`handle_payment`/`initiate_gateway_payment`
      (lines 161-401) into `CheckoutService.initiate_checkout/1`. Extract
      `payment_method_card/1`. Extract `Emakola.Payments.PollService`.
- [ ] **`lib/emakola_web/live/landing_live.ex` (1221 lines)** — convert to a
      dead Phoenix.Component (mobile menu via `Phoenix.LiveView.JS` only).
      Move inline `<style>` block to `app.css`. Eliminates one LV process per
      visitor.
- [ ] **`lib/emakola_web/components/layouts/app.html.heex` (1044 lines)** —
      extract `admin_sidebar/1` + `admin_topbar/1` into `sidebar_components.ex`.

### Component Library

- [ ] Add named Tailwind tokens (replace inline `bg-[#hex]` literals): `emakola-emerald`, `emakola-gold`, `mtn`, `voda`, `whatsapp`, `store-accent`, `cta-dark`.
- [ ] **Reconcile color drift** — storefront accent should be `#B45309` per
      `storefront_components.ex:7`, but cart/checkout/product-detail use
      `#CA8A04`. Standardise on `#B45309`.
- [ ] Extract shared admin components: `admin_page_header/1`, `status_badge/1`,
      `empty_state/1`, `table_toolbar/1`.
- [ ] Consolidate parallel KPI primitives — `dashboard/metric_components.ex`
      `kpi_card` and `inventory_components.ex` `stat_card` overlap; pick one.
- [ ] Update KPI grid usage in: `admin/customer_live/index.ex`,
      `admin/revenue_live/index.ex` (7 cards), `admin/report_live/index.ex`
      (8 cards), `admin/campaign_live/index.ex`.

### Security Hardening

- [ ] Migrate from `'unsafe-inline'` `style-src` to nonced styles in
      `lib/emakola_web/plugs/content_security_policy.ex` (P2).
- [ ] Re-evaluate `bypass action_type(:create)` allowing nil-actor on
      `Emakola.Accounts.Store` — onboarding must be possible but unauthenticated
      store creation should be rate-limited (already in Hammer? verify).

---

## UP NEXT (high impact for launch)

### Notifications
- [ ] WhatsApp Business API integration (order confirmations, shipping updates)
- [ ] SMS gateway for order updates (Hubtel SMS or alternative)
- [ ] Email templates for order lifecycle (confirmation, shipped, delivered)
- [ ] Rate limiting on SMS/WhatsApp channel calls
- [ ] WhatsApp Graph API version no longer hardcoded `v18.0`

### Operations
- [ ] Shipping zone configuration UI (regions, delivery areas)
- [ ] Delivery fee calculation by zone/weight/flat rate (depends on `DeliveryZone` wiring above)
- [ ] Inventory low-stock alerts (Oban worker + email/WhatsApp)
- [ ] Customer reviews and ratings (resource exists; storefront UI missing)

### Payments (expand)
- [ ] Hubtel payment gateway integration
- [ ] Payment reconciliation dashboard (admin view of all payments)
- [ ] Admin UI for initiating refunds (backend `process_refund/2` exists)

---

## WHITE-LABEL DESIGN SYSTEM

> Full plan: `docs/superpowers/plans/2026-03-28-white-label-design-system.md`

### Phase 1: Full Page Coverage
- [ ] Create `ThemeRenderer` dispatcher with `function_exported?` fallback
- [ ] Extend `ThemeBehaviour` with `@optional_callbacks` for 13 new pages
- [ ] Create `DefaultRenderers.Shared` wrapper (navbar + CSS vars + footer)
- [ ] Extract `DefaultRenderers.Cart` from `cart_live.ex`
- [ ] Extract `DefaultRenderers.Checkout` from `checkout_live.ex`
- [ ] Extract `DefaultRenderers.BlogList` / `BlogPost`
- [ ] Extract `DefaultRenderers.RecipeList` / `RecipeDetail`
- [ ] Extract `DefaultRenderers.OrderConfirmation`
- [ ] Extract `DefaultRenderers.Tracking`
- [ ] Extract `DefaultRenderers.Category`
- [ ] Extract `DefaultRenderers.Wishlist`
- [ ] Extract `DefaultRenderers.Account`
- [ ] Wire all 13 LiveViews to delegate render through `ThemeRenderer.render/3`
- [ ] Tests for dispatcher fallback + all default renderers

### Phase 2: Section Editor (Shopify-style)
- [ ] Define section type registry (15+ blocks)
- [ ] Per-type renderer components
- [ ] `home_sections` JSON array in `theme_config`
- [ ] `SectionSortable` JS hook (SortableJS)
- [ ] Section Editor admin UI
- [ ] Per-section settings forms
- [ ] Backwards compatibility for stores without `home_sections`
- [ ] Tests

### Phase 3: Component Variant System
- [ ] `DesignTokens` module (pure functions returning class strings)
- [ ] `FontLoader` (Google Fonts URL mapping)
- [ ] `design_tokens` in `theme_config` (10 dimensions)
- [ ] Refactor `DefaultRenderers` to use `DesignTokens`
- [ ] Tailwind safelist for variant fragments
- [ ] Design tab in admin theme customizer
- [ ] Tests

---

## ARCHITECTURE — Structural Improvements

### Domain Restructuring
- [ ] **Extract `Store` into `Emakola.Stores` domain** — Store resource currently lives in `Emakola.Accounts`. Move with `StoreSettings` and `Domains`.
- [ ] **Create `Emakola.Inventory` Ash domain** — currently just `stock_quantity` on `Variant`. Add stock levels + multi-location.
- [ ] **Create `Emakola.Marketing` context** — `Coupon` currently in `Emakola.Orders`. Move to its own bounded context.

### Ash-Specific
- [ ] Evaluate `require_atomic?(false)` suppression on every update action — identify which transitions could use atomic updates for performance.
- [ ] Extract inline anonymous functions from Ash resources (`Order` number generation, `LineItem` price snapshot) into `Ash.Resource.Actions.Implementation` modules per `CLAUDE.md`.

---

## INFRASTRUCTURE

### CI/CD
- [ ] Raise `test_coverage threshold` from 50 → 90 (`mix.exs:15`) as tests are added.
- [ ] `mix dialyzer` in CI (referenced in CLAUDE.md but absent).
- [ ] `mix sobelow --config` requires `.sobelow-conf` to exist or errors.
- [ ] Separate `deps` and `_build` cache keys in CI.

### Scaling Preparation
- [ ] **Replace ETS cart with persistent storage** — `CartStore` is node-local; breaks horizontal scaling.
- [ ] **Webhook → LiveView PubSub bridge** — payment polling currently keeps customer page open 3 min. Webhook should broadcast via PubSub.
- [ ] Parallelize `Dashboard.Stats.load_stats/1` (6 sequential queries) using `Task.async_stream` or `assign_async`.

### Database
- [ ] Index on `orders.coupon_id` (foreign key, missing index).
- [ ] Fix non-reversible migration `20260326` (uses `def change` where `up`/`down` is required).
- [ ] Add `gen_random_uuid()` default to `coupons.id`.

### Repo Hygiene
- [ ] Delete `erl_crash.dump` (46 MB, March 28) and `firebase-debug.log` from repo root.
- [ ] Add both to `.gitignore` if missing.
- [ ] Resolve weird directory `docs/business-plan/appendices 2/` (likely OS duplicate).

---

## BACKLOG

### Storefront Enhancements
- [ ] Real Emakola brand logo (replace placeholder SVG)
- [ ] Functional WhatsApp login/signup (currently "Coming Soon")
- [ ] Store search / marketplace browsing page
- [ ] Wishlist persistence (currently session-only)
- [ ] Theme preview screenshots for selection UI
- [ ] Additional theme designs beyond initial 3
- [ ] Mobile responsiveness QA pass

### Admin Dashboard
- [ ] Analytics charts (sales, orders, revenue over time) — partial today
- [ ] Customer management (view, export)
- [ ] Bulk product import/export (CSV) — depends on CSV extraction above
- [ ] Staff accounts and permissions

### Infrastructure
- [ ] OG image generation for stores and products
- [ ] Performance profiling and optimization
- [ ] MTN MoMo direct integration (bypass Paystack)
- [ ] Vodafone Cash direct integration
- [ ] Rider/delivery tracking integration
- [ ] Clean up duplicate `SMSProvider` / `SMSBehaviour` hierarchy
- [ ] Fix `RawBodyReader` moduledoc (references Stripe — copy-paste artifact)
- [ ] Build `emakola-admin-mobile.html` prototype's dedicated mobile admin view, OR declare existing responsive admin sufficient.
