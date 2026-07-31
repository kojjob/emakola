# Emakola — Action Roadmap

> Prioritized implementation plan based on codebase evaluation (March 2026).
> Last updated: 2026-06-24 — Phases 0–1.8 complete; bulk product upload shipped; **Revenue
> rails + payout engine complete** (#206–#213, see new section below). Per
> [`REVENUE-FIRST-90-DAY-PLAN.md`](REVENUE-FIRST-90-DAY-PLAN.md), Phase 0 build is done and the
> constraint is now **activation + go-to-market**, not engineering.

---

## ✅ Bulk Product Upload (web) — COMPLETE (2026-06)

> Three ways for a merchant to add products. **Mobile parity is now a Phase 1 sprint item for
> the Flutter merchant app — see `docs/mobile-app-research.md` Phase 1 item 5.** Build the
> photo-first flow first; it was designed for the phone.

- [x] **Single add** — `Admin.ProductLive.Form`: price (→ sellable `track_inventory: false` default
      variant) + image upload. (PRs #132, #133)
- [x] **Photo-first bulk** — `Admin.ProductLive.BulkPhoto` at `/admin/products/bulk`: pick many
      phone photos → name + price per card → publish all as live products.
      Spec `docs/superpowers/specs/2026-06-13-bulk-photo-upload-design.md`. (PRs #137, #138)
- [x] **CSV bulk with images** — `Catalog.CsvImporter`: 8-column template, semicolon multi-value
      cells, filename-matched image upload; fixed price→cedis, activation, inventory policy, and
      silent-failure gaps. Spec `docs/superpowers/specs/2026-06-14-csv-bulk-import-design.md`. (PR #139)

**Verified in production** (emakola.fly.dev): all three create live, sellable products with images.
**Mobile dependency:** the Phase 0 API is order-centric today; product-create + variant +
image-upload endpoints must be added before the Flutter merchant app can build these.

---

## ✅ Phase 0: Fix Deployment Blockers — COMPLETE

> Must be done before first deploy to Fly.io.

- [x] Add `/health` route (`/api/health` returns `{"status": "ok"}`)
- [x] Configure and start Oban in `application.ex` supervision tree + config files
- [x] Replace Phoenix branding in `layouts.ex` with Emakola branding
- [x] Strip FounderPad boilerplate (7 LiveViews, 3 controllers, API modules)
- [x] Fix compilation errors (duplicate modules, missing deps)
- [x] Add missing deps: swoosh, phoenix_live_dashboard, hammer, req
- [ ] Add `/metrics` endpoint or remove from fly.toml

**Tests:** 145 passing | **PR:** #7

---

## ✅ Phase 1.1: Foundation (MVP Sprint 1) — COMPLETE

> Merchants can sign up, verify, and create a store.

- [x] Set up Ash domains — `Emakola.Accounts`, `Emakola.Catalog`, `Emakola.Orders`, `Emakola.Payments`, `Emakola.Customers`, `Emakola.Shipping`
- [x] Create `Merchant` resource (email, password, phone, business name) with AshAuthentication
- [x] Create `Store` resource (name, slug, currency, description, contact info, WhatsApp, region)
- [x] Create `StoreMembership` resource (merchant ↔ store with roles)
- [x] Dual auth system: Merchant + User with store session resolution
- [x] Multi-tenancy via `store_id` on all resources (Ash attribute-based)
- [x] Onboarding wizard: 3-step store creation (Name → Product → Ready)
- [x] Merchant admin LiveView shell with sidebar navigation
- [x] ExMachina factories for all resources
- [x] ConnCase helpers with authenticated merchant/user setup

**Tests:** 314 passing | **PRs:** #7, #8

---

## ✅ Phase 1.2: Product Management (MVP Sprint 2) — COMPLETE

> Merchants can add, edit, and organize products.

- [x] Create `Product` resource (title, slug, status lifecycle, SEO fields, tags)
- [x] Create `Variant` resource (SKU, price in pesewas, atomic stock adjustments, DB CHECK constraint)
- [x] Create `Category` resource (unlimited nesting via parent_id, Unicode-aware auto-slug)
- [x] Create `OptionType` + `OptionValue` resources (max 3 per product, Shopify-style)
- [x] Create `VariantOptionValue` join resource (variant ↔ option matrix)
- [x] Create `Image` resource (S3 pipeline, processing status, content type validation)
- [x] Storage behaviour + S3 implementation (ExAws)
- [x] ImageProcessorWorker (Oban, idempotent)
- [x] Product CRUD LiveView (list with search/filter, create/edit form)
- [x] Category management LiveView (tree view, inline add)
- [x] Product aggregates (variant_count, min_price, max_price) in admin UI
- [x] HasVariants validation (product must have variants to activate)

**Resources:** Category, Product, OptionType, OptionValue, Variant, VariantOptionValue, Image
**Reusable modules:** GenerateSlug, NotBlank, NoSelfParent, MaxOptionTypes, HasVariants, OneOf, MaxValue
**Tests:** 316 passing | **PRs:** #7

---

## ✅ Phase 1.3: Storefront (MVP Sprint 3) — COMPLETE

> Customers can browse a merchant's store.

- [x] Storefront LiveView session (public, no auth required) at `/s/:store_slug`
- [x] Store landing page (StoreLive) — featured products, category cards
- [x] Mobile-first product listing (ProductListLive) — search, category filter, pagination
- [x] Product detail page (ProductDetailLive) — variant selector, stock status, add to cart
- [x] Category browsing (CategoryLive) — breadcrumb navigation
- [x] Cart page (CartLive) — quantity management, checkout integration
- [x] StoreResolver (slug → store lookup)
- [x] Currency helper (GH₵/₦/$ formatting from pesewas)
- [ ] SEO: meta tags, Open Graph, structured data (JSON-LD)
- [ ] Performance target: full page load < 3s on 3G (needs profiling)

**Tests:** 37 storefront + 16 currency | **PR:** #11

---

## ✅ Phase 1.4: Cart & Checkout (MVP Sprint 4) — COMPLETE

> Customers can add items to cart and checkout.

- [x] Cart in LiveView assigns (guest-friendly, ephemeral)
- [x] CheckoutService — transactional: validate stock → create order → create line items → decrement stock
- [x] Create `Order` resource (auto ORD-YYYYMMDD-XXXXXX numbers, status lifecycle)
- [x] Create `LineItem` resource (snapshots variant price/title at order time)
- [x] Create `Customer` resource (email per store, ci_string uniqueness)
- [x] Concurrent checkout safety (atomic SQL + DB CHECK constraint)
- [ ] Guest checkout (no account required) — partially done
- [ ] Address form (Ghana regions) — DeliveryZone exists, form TBD
- [ ] Full checkout flow UI: contact → shipping → payment → review

**Tests:** 34 orders + 27 integration | **PR:** #11

---

## ✅ Phase 1.5: Payments — Ghana (MVP Sprint 5) — COMPLETE

> Customers can pay with cards and mobile money.

- [x] Abstract `Gateway` behaviour (gateway-agnostic interface)
- [x] Paystack integration (initiate, verify, refund, HMAC webhook verification)
- [x] Hubtel integration (pesewas↔cedis conversion, status-check webhook verification)
- [x] Create `Payment` resource (status lifecycle, gateway reference tracking)
- [x] PaystackWebhookHandler (Oban, idempotent)
- [x] HubtelWebhookHandler (Oban, idempotent)
- [x] Webhook controller with signature verification
- [x] HTTPClient behaviour for testability (Mox in tests)
- [ ] MTN Mobile Money via Paystack (API ready, needs mobile money channel config)
- [ ] Telecel Cash / AirtelTigo (same — channel config)
- [ ] Cash on delivery option
- [ ] "Waiting for payment" screen with polling

**Tests:** 33 Paystack + 21 Hubtel + 11 Payment | **PR:** #11

---

## ✅ Phase 1.6: Order Management (MVP Sprint 6) — COMPLETE

> Merchants can view and manage orders.

- [x] Order list LiveView with status filter tabs (7 statuses)
- [x] Order detail LiveView (line items, customer, payment, addresses, notes)
- [x] Status workflow buttons: Confirm → Process → Ship → Deliver
- [x] Cancel order (with validation — only from valid states)
- [x] SMS notifications on status change (Oban worker + SMS provider behaviour)
- [x] WhatsApp notifications (provider behaviour + templates)
- [x] Notification dispatcher for event routing
- [x] Customer management admin (list, search, detail, order history)
- [x] Design matched to `emakola-admin-orders.html` prototype
- [ ] COD: mark as paid on delivery
- [ ] Refund resource + refund processing
- [ ] Email receipts

**Tests:** 44 order admin + 37 notifications + 25 customers | **PR:** #17

---

## ✅ Phase 1.7: Dashboard (MVP Sprint 7) — COMPLETE

> Merchants can see how their store is performing.

- [x] Revenue overview (sum of successful payments)
- [x] Order count + active products + customer count
- [x] Top products by variant count with price range
- [x] Recent orders table (last 10)
- [x] Low-stock alerts (variants below threshold)
- [x] Dashboard.Stats module (per-store analytics)
- [x] Store settings page (tabbed: General, Contact, Delivery, Notifications)
- [x] Delivery zones with Ghana region presets (Greater Accra, Kumasi, etc.)
- [x] Shipping domain with DeliveryZone resource
- [x] Design matched to `emakola-admin-dashboard.html` prototype
- [ ] Revenue time-series chart (placeholder exists)
- [ ] Percentage change indicators (placeholder exists)

**Tests:** 25 dashboard + 23 settings/delivery | **PR:** #17

---

## ✅ Phase 1.8: Prototype-Matched UI + Modals (MVP Sprint 8) — COMPLETE

> All admin and storefront pages pixel-matched to design prototypes.

- [x] Dashboard: SVG revenue chart, donut chart, activity feed, KPI cards
- [x] Products: card grid layout, filter bar, status/stock badges, quick view modal
- [x] Orders: stat cards, bulk selection, payment method badges, status confirmation modals
- [x] Customers: KPI cards, segment badges, detail slide-over, add/edit modals
- [x] Settings: 7-tab layout (General, Profile, Payments, Delivery, Notifications, Team, Billing)
- [x] Delivery: tracking timeline, rider selection, zone management
- [x] Categories: tree view with modal add/edit/delete
- [x] Storefront home: story-style categories, featured hero card, product grid with hover
- [x] Product detail: image gallery, pill variant selectors, quantity stepper, WhatsApp CTA
- [x] Product list: sidebar categories, quick-view overlay, search + filters
- [x] Cart: shopping bag layout, order summary sidebar, trust badges
- [x] Checkout: 3-step flow (Payment → Details → Confirm), MTN MoMo/Telecel/Card selection
- [x] Reusable modal + confirm_modal components (centered, slide-over, destructive)
- [ ] Campaigns page (matching `emakola-admin-campaigns.html`)
- [ ] Discounts page (matching `emakola-admin-discounts.html`)
- [ ] Reports page (matching `emakola-admin-reports.html`)
- [ ] Revenue page (matching `emakola-admin-revenue.html`)
- [ ] Customer account page (matching `account.html`)
- [ ] Wishlist page (matching `wishlist.html`)
- [ ] Delivery tracking page (matching `emakola-delivery-tracking.html`)
- [ ] Mobile admin shell (matching `emakola-admin-mobile.html`)

**Design tokens:** Admin: emerald-900 sidebar, slate-50 bg, rounded-2xl cards, font-mono numbers | Storefront: #FAFAF9 bg, #B45309 accent, stone-900 CTAs, WhatsApp #25D366

**Tests:** 618 total passing | **PR:** #17, #19

---

## 📱 Phase 1.9: PWA (MVP Sprint 9)

> App-like experience without Play Store.

- [ ] Web app manifest (name, icons, theme color)
- [ ] Service worker for offline storefront caching
- [ ] "Add to Home Screen" prompt
- [ ] Offline product browsing
- [ ] Push notifications for order updates

---

## 🔐 Production Hardening (Ongoing)

- [x] Rate limiting on API endpoints (Hammer ETS backend)
- [ ] Rate limiting on auth endpoints specifically
- [ ] Structured logging with request metadata
- [ ] Error tracking (Sentry — DSN in .env.example but not configured)
- [ ] Prometheus metrics exporter (fly.toml expects port 9091)
- [ ] Database connection pooling tuning for production load
- [ ] Session-based cart persistence (currently ephemeral in LiveView assigns)
- [ ] Subdomain-based store resolution (currently URL slug)
- [ ] Store switcher for multi-store merchants
- [ ] Over-refund protection (business rule)
- [ ] Full checkout flow UI (contact → shipping → payment → review)
- [ ] Image processing with libvips (currently stubbed)

---

## 🟡 Dropship Trustless Settlement (SP-series) — IN REVIEW (2026-06)

> Split a customer charge **at the gateway** so the wholesaler's cut never lands in the
> dropshipper's account first — solving the manual-ledger fraud gap and unlocking
> zero-capital dropshipping. PRs #158 (core) + #159 (integration), stacked. Full detail in
> [`ROADMAP-dropshipping.md`](ROADMAP-dropshipping.md) § Trustless Split Settlement.

**Built (TDD, full suite green — 3097 passing):**
- [x] `SplitCalculator` — pure 3-way split off margin (wholesaler cost / platform fee / dropshipper), integer minor units, reconciles exactly
- [x] `StorePayoutAccount` + `Supplier.linked_store_id` — per-store payout subaccount + verification
- [x] `PaymentSplit` (`pending→settled→reversed`) + `Payment.split_mode/split_code`
- [x] Gateway `create_subaccount/1` + `:split` on `initiate_payment/1` (Paystack flat split; Hubtel falls back)
- [x] `DropshipSettlement` / `OrderSettlement` — resolve→split or manual-ledger fallback; reconciles to `order.total`
- [x] `CheckoutLive` wired + `PaystackWebhookHandler` settle-on-success / reverse-on-refund

**Remaining:**
- [x] SP1 merchant payout-onboarding UI (calls `create_subaccount`) — shipped
- [x] Ops: verify Paystack Ghana MoMo-as-subaccount support — ✅ confirmed (2026-06-24)
- [ ] Refund clawback against future payouts (splits currently only flip to `:reversed`)
- [ ] SP2–SP4 supplier-network marketplace (connections, catalog sourcing, cross-store fulfillment)
- [ ] Paystack fee bearer (config decision at activation)

---

## ✅ Revenue Rails & Payout Engine — COMPLETE (2026-06-24)

> Monetization end-to-end: **collect → split → fee → track → pay out → observe → retry →
> notify.** All merged to `main`. Specs in `docs/superpowers/specs/2026-06-24-*`.

- [x] **Subaccount creation** (#206) — `SubaccountCreationWorker` turns a saved MoMo payout into a verified Paystack subaccount (async, idempotent).
- [x] **Platform fee on normal orders** (#207) — `OrderSettlement` routes the merchant net to their subaccount and keeps a **2%** fee as the split remainder (`platform_fee_rate_bps: 200`); graceful `:no_split` fallback so fee logic can never break a sale.
- [x] **Finance oversight page** (#208) — `/platform/finance`: fees collected, GMV, take rate, outstanding-payout backlog + per-store breakdown.
- [x] **Payout-execution engine** (#210 rails/ledger + #211 gated execution) — Paystack Transfer rails, `Payout` ledger, admin-approved disbursement (idempotent via `transfer_reference`), `transfer.success/failed` webhook confirmation.
- [x] **Payout operations** (#212) — recent-payouts table + status, retry for failed payouts, merchant SMS/email on `:paid`.
- [x] **Stat-tile icon fix** (#213) — valid Material Symbols on the finance/payments tiles.

**Next (not engineering):** activation (real provider keys → `LAUNCH_TODO.md`) + go-to-market.
**Next buildable toward revenue:** Smart Link / link-in-bio store page (`SOCIAL_COMMERCE.md`).

---

## 🧵 Ghana Trust Commerce (TC-series) — SPECCING (2026-07-30)

> Revenue-first features for IG/WhatsApp social sellers: move the DM deal's
> money through Makola instead of a direct MoMo transfer. Composes rails that
> already shipped (checkout, settlement splits, refund liability). Related but
> distinct: the Smart Link bio page (`SOCIAL_COMMERCE.md`) is a storefront
> surface; TC-1 pay links are per-deal checkout URLs — they complement, not
> overlap. Specs in `docs/superpowers/specs/`, tracked in `TODO.md` §PLANNED.

- [ ] **TC-1: Pay Links** — 📝 SPECCED (`2026-07-30-pay-links-design.md`).
      Shareable DM checkout links (catalog + single-use custom amount),
      express checkout at `/pay/:code`, admin funnel (created → opened → paid),
      JSON:API exposure. Ships standalone.
- [ ] **TC-2: Buyer Protection** — 📝 SPECCED (`2026-07-30-buyer-protection-design.md`).
      Escrow-lite payout hold until delivery confirmation; the trust reason a
      stranger pays through Makola. No merchant gateway share at charge; release
      via delivery OTP / buyer confirm / 5-day timer; freeze-on-complaint.
      → implemented (TC-2 branch, PR pending)
- [ ] **TC-3: Susu lay-away** — 📝 SPECCED (`2026-07-30-susu-layaway-design.md`).
      Merchant-created susu links; flexible chunks + deadline; stock reserved at
      activation; auto-refund in full on expiry/cancel; order created at
      completion and stamped onto the contributions; fee once on the total.
- [ ] **TC-4: GhanaPost GPS + landmark addressing** — 📝 SPECCED
      (`2026-07-30-ghanapost-addressing-design.md`). Optional validated digital
      address + nudged landmark via one shared address fieldset across all four
      buyer surfaces; format-only validation v1.
      → implemented (TC-4 branch, PR pending)
- [ ] **TC-5: Makola Book (pay later)** — 📝 SPECCED
      (`2026-07-30-pay-later-book-design.md`). Digitized trade credit (merchant
      risk, no interest): deposit link → ship → flexible balance chunks to a
      deadline; two-tier earned eligibility (2 delivered orders or 1 susu
      platform-wide; ≥3 orders per store) keyed on verified phone; default =
      platform-wide freeze; invariant: limit ≤ profit already generated. Rung
      one of the credit ladder toward partner/platform BNPL. All five TC specs
      written — series ready for implementation planning.

---

## 📊 Progress Summary

| Phase | Status | Tests | Key Deliverables |
|-------|--------|-------|-----------------|
| Phase 0 | ✅ Complete | 145 | Health endpoint, cleanup, Store resource |
| Phase 1.1 | ✅ Complete | 314 | Auth, onboarding, multi-tenancy |
| Phase 1.2 | ✅ Complete | 316 | 7 Ash resources, admin UI, S3 pipeline |
| Phase 1.3 | ✅ Complete | +53 | 5 storefront LiveViews, currency helper |
| Phase 1.4 | ✅ Complete | +61 | CheckoutService, Order/LineItem/Customer |
| Phase 1.5 | ✅ Complete | +65 | Paystack, Hubtel, Payment, webhooks |
| Phase 1.6 | ✅ Complete | +106 | Order admin, notifications, customers |
| Phase 1.7 | ✅ Complete | +48 | Dashboard, settings, delivery zones |
| Phase 1.8 | ✅ Complete | +6 | All pages prototype-matched, modals, checkout |
| Dropship Settlement (SP) | 🟡 In review | #158/#159 | Gateway split, PaymentSplit, OrderSettlement, webhook reconcile |
| **Total** | **8/9 phases** | **618** | **17 Ash resources, 21 LiveViews** |

---

## Build Order Dependency Chain

```
✅ Phase 0 (blockers)
  └─→ ✅ Phase 1.1 (auth + stores)
        └─→ ✅ Phase 1.2 (products)
              └─→ ✅ Phase 1.3 (storefront)
                    └─→ ✅ Phase 1.4 (cart + checkout)
                          └─→ ✅ Phase 1.5 (payments)
                                └─→ ✅ Phase 1.6 (orders)
                                      └─→ ✅ Phase 1.7 (dashboard)
                                            └─→ ✅ Phase 1.8 (prototype UI + modals)
                                                  └─→ ⬜ Phase 1.9 (PWA)
```

Each phase is a deployable increment. Production hardening runs in parallel throughout.
