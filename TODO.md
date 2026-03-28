# Emakola — Project TODO

**Last updated:** 2026-03-26

---

## COMPLETED

### Landing Page + Auth (PR #31)
- [x] Dual-audience split-screen landing page with Deep Navy & Gold palette
- [x] Split-screen login/register pages (Stitch reference design)
- [x] Production polish: image compression, lazy loading, trust signals

### Admin Features (PR #33)
- [x] Notification + user dropdowns, product slide-over panels, seed data
- [x] Category page redesign with visual cards and auto-detected icons

### Storefront Theme Engine (PR #34)
- [x] 3 themes: Market, Atelier, Vibrant
- [x] ThemeBehaviour, ThemeResolver, CSS variable injection
- [x] LiveView dispatch to theme-specific render modules

### Theme Customizer (PR #35)
- [x] Admin page at `/admin/theme` with floating drawer + iframe preview
- [x] Theme selection, color inputs, hero settings, section toggles
- [x] Theme selection in onboarding flow (step 2)
- [x] Sidebar nav item with palette icon

### Paystack Payment Gateway (PR #36)
- [x] PaystackClient HTTP client with behaviour for Mox testing
- [x] Gateway implementation (initiate, verify, refund)
- [x] Webhook handler with HMAC SHA-512 signature verification
- [x] 25 new Paystack tests, all using Mox mocks

### Security & Infrastructure
- [x] CSP headers, rate limiting, Ash authorization policies
- [x] ETS caching, webhook HMAC, input constraints
- [x] Build artifacts removed from git tracking

---

## CRITICAL — Fix Before Launch

### P0: Multi-Tenant Security
- [ ] **Enforce row-level tenant isolation in Ash policies** — replace `authorize_if(always())` read bypass with `filter_with` policies that scope reads by `store_id == ^actor.current_store_id`. Currently all reads are unscoped; tenant isolation relies on caller discipline.
- [ ] **Add authorizer to Coupon resource** — `lib/emakola/orders/resources/coupon.ex` is missing `authorizers: [Ash.Policy.Authorizer]`, allowing any actor to CRUD any store's coupons.
- [ ] **Fix Store update policy** — `lib/emakola/accounts/resources/store.ex:106-109` allows any authenticated merchant to update any store. Add ownership check.
- [ ] **Add tenant resolution to storefront LiveSession** — storefront `live_session` has no `on_mount` hook for resolving the store from URL. Each LiveView is individually responsible, risking cross-tenant leaks.

### P0: Data Integrity Bugs
- [ ] **Fix address key mismatch** — `CheckoutService.address_to_map/1` stores `"line_1"` but `OrderLive.Show` reads `"line1"`. Shipping addresses render blank in admin order detail.
- [ ] **Fix order number collision error mapping** — collision raises `Ash.Error.Invalid` which `CheckoutService` rescue block maps to `:insufficient_stock`. Use `:crypto.strong_rand_bytes/1` and handle collision specifically.
- [ ] **Replace `String.to_atom` with explicit status maps** — `paystack.ex:134,139` and `hubtel.ex:114` call `String.to_atom` on external API strings. BEAM atom table memory leak / DoS vector.

### P0: Configuration
- [ ] **Move payment/notification secrets to `runtime.exs`** — currently resolved at compile time in `config.exs`, baked into release.
- [ ] **Remove hardcoded `token_signing_secret` fallback** — dev fallback is compiled into the release binary.

---

## HIGH — Fix Before Launch

### Security Hardening
- [ ] **Enable CSP enforcement** — currently report-only with `unsafe-inline`, which negates XSS protection.
- [ ] **Add DB connectivity to health check** — `/health` returns 200 unconditionally. Add `Emakola.Repo.query("SELECT 1")`.
- [ ] **Exclude `/health` from `force_ssl`** — Fly.io health probe may get redirected to HTTPS and fail.

### Checkout Correctness
- [ ] **Wire `DeliveryZone` into checkout** — `CheckoutLive` hardcodes fees at line 1313 and ignores the `DeliveryZone` Ash resource. Admin delivery zone config has no effect.
- [ ] **Add `tracking_number` field to Order resource** — "Mark as Shipped" modal collects it but handler discards it. `OrderNotificationWorker` tries to read it but it doesn't exist.
- [ ] **Wire `CachedCatalog.invalidate_store/1` into admin actions** — cache is never invalidated on product create/update/archive or category changes. Stale data served up to 5 minutes.

### Error Handling
- [ ] **Add logging to bare `rescue _ ->` blocks** — 30+ instances silently swallow errors including database failures. At minimum log before returning fallback.
- [ ] **Deduplicate Paystack webhook processing** — `PaystackWebhook` and `PaystackWebhookHandler` contain duplicate logic with divergence risk. Add unique constraint to webhook handler Oban job.

---

## UP NEXT (high impact for launch)

### Notifications
- [ ] WhatsApp Business API integration (order confirmations, shipping updates)
- [ ] SMS gateway for order updates
- [ ] Email templates for order lifecycle (confirmation, shipped, delivered)
- [ ] Add rate limiting on SMS/WhatsApp channel calls
- [ ] Update WhatsApp Graph API version from hardcoded `v18.0`

### Operations
- [ ] Shipping zone configuration (regions, delivery areas)
- [ ] Delivery fee calculation (by zone, weight, or flat rate)
- [ ] Inventory low-stock alerts (Oban worker + email/WhatsApp)

### Payments (expand)
- [ ] Hubtel payment gateway integration
- [ ] Payment reconciliation dashboard (admin view of all payments)
- [ ] Admin UI for initiating refunds (backend `process_refund/2` exists, no UI)

---

## WHITE-LABEL DESIGN SYSTEM

> Full plan: `docs/superpowers/plans/2026-03-28-white-label-design-system.md`

### Phase 1: Full Page Coverage
- [ ] Create `ThemeRenderer` dispatcher with `function_exported?` fallback
- [ ] Extend `ThemeBehaviour` with `@optional_callbacks` for 13 new pages
- [ ] Create `DefaultRenderers.Shared` wrapper (navbar + CSS vars + footer)
- [ ] Extract `DefaultRenderers.Cart` from cart_live.ex
- [ ] Extract `DefaultRenderers.Checkout` from checkout_live.ex
- [ ] Extract `DefaultRenderers.BlogList` from blog_list_live.ex
- [ ] Extract `DefaultRenderers.BlogPost` from blog_post_live.ex
- [ ] Extract `DefaultRenderers.RecipeList` from recipe_list_live.ex
- [ ] Extract `DefaultRenderers.RecipeDetail` from recipe_live.ex
- [ ] Extract `DefaultRenderers.OrderConfirmation` from order_confirmation_live.ex
- [ ] Extract `DefaultRenderers.Tracking` from tracking_live.ex
- [ ] Extract `DefaultRenderers.Category` from category_live.ex
- [ ] Extract `DefaultRenderers.Wishlist` from wishlist_live.ex
- [ ] Extract `DefaultRenderers.Account` from account_live.ex
- [ ] Wire all 13 LiveViews to delegate render through `ThemeRenderer.render/3`
- [ ] Tests for dispatcher fallback + all default renderers

### Phase 2: Section Editor (Shopify-style)
- [ ] Define section type registry (15+ blocks: hero, products, categories, testimonials, FAQ, banner, video, countdown, gallery, newsletter, trust, brand_story, text, divider, custom HTML)
- [ ] Create section renderer components (one per type)
- [ ] Store `home_sections` as JSON array in `theme_config` (no migration needed)
- [ ] Section-aware home rendering in `ThemeRenderer` (iterate sections array)
- [ ] Build `SectionSortable` JS hook for drag-and-drop (SortableJS)
- [ ] Build Section Editor admin UI (drag list, add/remove, per-section settings)
- [ ] Dynamic section settings forms based on section type schema
- [ ] Backwards compatible: stores without `home_sections` use existing `render_home`
- [ ] Tests for registry, renderers, editor LiveView

### Phase 3: Component Variant System
- [ ] Create `DesignTokens` module — pure function class maps (button, card, navbar, grid, hero, footer, product card, typography)
- [ ] Create `FontLoader` — font family token to Google Fonts URL mapping
- [ ] Store `design_tokens` in `theme_config` (10 dimensions: button_style, card_style, navbar_layout, product_grid_columns, hero_layout, footer_style, product_card_style, typography_scale, heading_font, body_font)
- [ ] Refactor all DefaultRenderers to use `DesignTokens` for component styling
- [ ] Add Tailwind safelist for all variant class fragments
- [ ] Build Design tab in admin theme customizer (visual variant pickers with previews)
- [ ] Tests for token resolution, class generation, font loading

---

## ARCHITECTURE — Structural Improvements

### Domain Restructuring
- [ ] **Extract `Store` into `Emakola.Stores` domain** — Store resource currently lives in `Emakola.Accounts`. Create proper Ash domain with Store, StoreSettings, Domains.
- [ ] **Create `Emakola.Inventory` Ash domain** — currently just `stock_quantity` on Variant. Need proper domain with stock levels and multi-location support.
- [ ] **Create `Emakola.Marketing` context** — Coupon currently lives in `Emakola.Orders`. Extract coupons/discounts to their own bounded context.

### Code Decomposition
- [ ] **Split `CheckoutLive` (1,384 lines)** — extract into: checkout form component, payment poller module, order summary component, MoMo waiting state component.
- [ ] **Split `ProductLive.Index` (1,374+ lines)** — extract image upload, CSV import, quick-view modal, and category loading into separate modules.
- [ ] **Split `OrderLive.Show` (606 lines)** — extract inline components and data loaders.
- [ ] **Extract inline anonymous functions from Ash resources** — Order number generation, LineItem price snapshot, and others should be `Ash.Resource.Actions.Implementation` modules per CLAUDE.md guidance.

### Ash-Specific
- [ ] **Evaluate `require_atomic?` suppression** — every `update` action uses `require_atomic?(false)`. Determine which status transitions could use atomic updates for better performance.

---

## INFRASTRUCTURE

### CI/CD
- [ ] **Enforce test coverage in CI** — `mix test` doesn't pass `--cover`. Coverage threshold in `mix.exs` is 40%, should be 90%.
- [ ] **Add `mix dialyzer` to CI** — referenced in CLAUDE.md but absent from pipeline.
- [ ] **Fix `mix sobelow --config`** — requires `.sobelow-conf` file to exist or will error.
- [ ] **Separate `deps` and `_build` cache keys in CI** — currently share the same key.

### Scaling Preparation
- [ ] **Replace ETS cart with persistent storage** — `CartStore` is node-local; breaks on horizontal scaling (multi-node deployment).
- [ ] **Add webhook-to-LiveView PubSub bridge** — payment polling requires customer to keep page open 3 min. Webhook should broadcast via PubSub to the LiveView process.
- [ ] **Parallelize dashboard stats queries** — `Dashboard.Stats.load_stats/1` makes 6 sequential DB queries. Use `assign_async` or `Task.async_stream`.

### Database
- [ ] **Add index on `orders.coupon_id`** — foreign key missing index.
- [ ] **Fix non-reversible migration** — `20260326` uses `def change` where `up`/`down` is required.
- [ ] **Add `gen_random_uuid()` default to `coupons.id`** — missing UUID generation default.

---

## BACKLOG

### Storefront Enhancements
- [ ] Real Emakola brand logo (replace placeholder SVG)
- [ ] Functional WhatsApp login/signup (currently "Coming Soon")
- [ ] Store search / marketplace browsing page
- [ ] Customer reviews and ratings on products
- [ ] Wishlist persistence (currently session-only)
- [ ] Theme preview screenshots for selection UI
- [ ] Additional theme designs beyond initial 3
- [ ] Customer authentication and portal (currently customers don't log in)

### Admin Dashboard
- [ ] Analytics charts (sales, orders, revenue over time)
- [ ] Customer management (view, export)
- [ ] Bulk product import/export (CSV)
- [ ] Staff accounts and permissions

### Infrastructure
- [ ] OG image generation for stores and products
- [ ] Mobile responsiveness QA pass
- [ ] Performance profiling and optimization
- [ ] MTN MoMo direct integration (bypass Paystack)
- [ ] Vodafone Cash direct integration
- [ ] Rider/delivery tracking integration
- [ ] Clean up duplicate `SMSProvider` / `SMSBehaviour` hierarchy
- [ ] Fix `RawBodyReader` moduledoc (references Stripe — copy-paste artifact)
