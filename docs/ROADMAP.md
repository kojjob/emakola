# Emakola — Product Roadmap

> ⚠️ **HISTORICAL (as of 2026-03-22).** Phase-1 milestone record kept for
> reference — many unchecked boxes here have since shipped. **Forward product
> planning now lives in [`ACTION_ROADMAP.md`](ACTION_ROADMAP.md)**; the
> engineering backlog of record is **[`../TODO.md`](../TODO.md)**; the
> operational hub is **[`../checklist.md`](../checklist.md)**.

> Last updated: 2026-03-22 | Phase 1 MVP: 8 of 9 milestones complete | 618 tests | Phase 2 in progress

## Phase 1: MVP (Ghana Launch)
**Goal**: Merchants can create a store, add products, and accept payments from Ghanaian customers.
**Status**: 🟢 8/9 milestones complete | 618 tests passing | 17 Ash resources | 21 LiveViews

### ✅ Milestone 1.1 — Foundation
- [x] Phoenix app scaffold with Ash multitenancy
- [x] Merchant registration & authentication (email/password + magic link)
- [x] Store creation with slug-based routing (`/s/{slug}`)
- [x] Store settings (name, logo, description, currency GHS, contact info, WhatsApp, region)
- [x] TDD test infrastructure (ExMachina factories, Mox mocks, DataCase sandbox)
- [x] Dual auth system (Merchant + User) with store session resolution
- [x] StoreMembership (merchant ↔ store with roles: owner/admin/staff)
- [x] 3-step onboarding wizard (Name Store → Add Product → Ready)

### ✅ Milestone 1.2 — Product Management
- [x] Product CRUD (title, description, slug, status lifecycle, SEO fields, tags)
- [x] Product variants (price in pesewas, SKU, atomic stock adjustments)
- [x] Product options (OptionType + OptionValue, max 3 per product, Shopify-style)
- [x] Category management (unlimited nesting, Unicode-aware auto-slug)
- [x] Inventory tracking (stock levels, low-stock alerts, DB CHECK constraint)
- [x] Image resource with S3 pipeline (upload, processing status, content type validation)
- [x] Product aggregates (variant_count, min_price, max_price)
- [x] Admin UI: ProductLive.Index (search, status filter), ProductLive.Form, CategoryLive.Index

### ✅ Milestone 1.3 — Storefront
- [x] Mobile-first storefront at `/s/:store_slug` (public, no auth)
- [x] Product listing with category filter, search, pagination
- [x] Product detail page (variant selector, stock status, add to cart)
- [x] Category browsing with breadcrumb navigation
- [x] Search functionality (case-insensitive ILIKE)
- [x] Currency formatting (GH₵ / ₦ / $ from pesewas)
- [x] Store resolver (slug → store lookup)
- [ ] SEO fundamentals (meta tags, structured data) — partial
- [ ] Performance target: < 3s on 3G — needs profiling

### ✅ Milestone 1.4 — Cart & Checkout
- [x] Shopping cart (add, update qty, remove) in LiveView assigns
- [x] Customer resource (email per store, ci_string uniqueness)
- [x] Order resource (auto ORD-YYYYMMDD-XXXXXX numbers, status lifecycle)
- [x] LineItem resource (snapshots variant price/title at order time)
- [x] CheckoutService (transactional: validate stock → create order → decrement stock)
- [x] Concurrent checkout safety (atomic SQL + DB CHECK constraint)
- [ ] Guest checkout (no account required) — partially done
- [ ] Address management — DeliveryZone exists, address form TBD
- [ ] Full checkout UI flow (contact → shipping → payment → review)

### ✅ Milestone 1.5 — Payments (Ghana)
- [x] Paystack integration (initiate, verify, refund, HMAC webhook verification)
- [x] Hubtel integration (pesewas↔cedis conversion, status-check webhook)
- [x] Payment resource (status lifecycle, gateway reference tracking)
- [x] Payment webhook handling (Oban workers, idempotent, signature verification)
- [x] HTTPClient behaviour for testability (Mox in tests)
- [ ] MTN Mobile Money via Paystack (API ready, needs channel config)
- [ ] Vodafone Cash / AirtelTigo (same — channel config)
- [ ] Cash on delivery option
- [ ] "Waiting for payment" screen with polling

### ✅ Milestone 1.6 — Order Management
- [x] Order list admin (OrderLive.Index with 7 status filter tabs)
- [x] Order detail admin (OrderLive.Show with line items, customer, payment)
- [x] Order status workflow (pending → confirmed → processing → shipped → delivered)
- [x] Status change confirmation modals (with cancel destructive modal)
- [x] SMS notifications on status change (behaviour + templates + Oban worker)
- [x] WhatsApp notifications (behaviour + templates)
- [x] Customer management admin (CustomerLive.Index, CustomerLive.Show)
- [x] Notification dispatcher for event routing
- [ ] Email receipts
- [ ] Refund resource + processing

### ✅ Milestone 1.7 — Merchant Dashboard
- [x] Revenue overview (sum of successful payments)
- [x] Order count, active products, customer count KPI cards
- [x] Top products with progress bars
- [x] Recent orders table (with payment method: MoMo, Vodafone Cash, Card)
- [x] Low-stock alerts with severity coloring
- [x] SVG revenue area chart
- [x] Sales by category donut chart
- [x] Activity feed
- [x] Dashboard pixel-matched to `emakola-admin-dashboard.html` prototype
- [x] Dark emerald sidebar (bg-emerald-900) with responsive collapse
- [x] Store settings page (tabbed: General, Contact, Delivery, Notifications)
- [x] Delivery zones with Ghana region presets
- [ ] Revenue time-series with real data (chart currently uses placeholder data)
- [ ] Percentage change indicators (currently placeholder)

### ✅ Milestone 1.8 — All Pages Prototype-Matched + Modals
- [x] Dashboard pixel-matched to prototype with SVG charts
- [x] Products page: card grid, filter bar, status badges, quick view/archive/activate modals
- [x] Orders page: stat cards, bulk selection, payment badges, status confirmation modals
- [x] Customers page: KPI cards, segments, detail slide-over, add/edit customer modals
- [x] Settings page: tabbed layout (7 tabs), delete store confirmation modal
- [x] Delivery page: tracking timeline, rider selection, zone management modals
- [x] Categories: tree view with modal add/edit/delete
- [x] Storefront home: story-style categories, hero card, product grid with hover
- [x] Product detail: image gallery, pill variant selectors, quantity stepper, WhatsApp CTA
- [x] Product list: sidebar categories, quick-view overlay, search + filters
- [x] Cart: shopping bag layout, order summary sidebar, trust badges
- [x] Checkout: 3-step flow (Payment → Details → Confirm), MTN MoMo/Vodafone/Card
- [x] Reusable modal component (centered + slide-over), confirm_modal for destructive actions

### 🔄 Milestone 1.9 — Remaining Prototype Pages + Marketing
- [ ] Campaigns page (matching `emakola-admin-campaigns.html`)
- [ ] Discounts page (matching `emakola-admin-discounts.html`)
- [ ] Reports page (matching `emakola-admin-reports.html`)
- [ ] Revenue page (matching `emakola-admin-revenue.html`)
- [ ] Customer account page (matching `account.html`)
- [ ] Wishlist page (matching `wishlist.html`)
- [ ] Delivery tracking page (matching `emakola-delivery-tracking.html`)
- [ ] Mobile admin shell (matching `emakola-admin-mobile.html`)

### ⬜ Milestone 1.10 — PWA (Progressive Web App)
- [ ] Web app manifest (name, icons, theme color)
- [ ] Service worker for offline storefront caching
- [ ] "Add to Home Screen" prompt for merchants and customers
- [ ] Offline product browsing (cached catalog)
- [ ] Push notifications for order updates

---

## Phase 2: Growth (Ghana)
**Goal**: Full-featured platform competitive with any ecommerce solution in Ghana.

### Milestone 2.1 — WhatsApp Integration
- [x] WhatsApp Business API behaviour defined
- [x] WhatsApp notification templates for order lifecycle
- [ ] Order confirmation via WhatsApp
- [ ] Shipping update notifications
- [ ] Abandoned cart recovery messages
- [ ] Customer support chat

### 🔄 Milestone 2.2 — Marketing Tools
- [ ] Discount codes & coupons (admin UI in progress)
- [ ] Automatic discounts (buy X get Y, % off)
- [ ] Campaign management (admin UI in progress)
- [ ] Abandoned cart recovery (WhatsApp + SMS)

### Milestone 2.3 — Shipping & Logistics
- [x] Shipping zones & rates configuration (DeliveryZone resource)
- [x] Delivery fee in pesewas per zone
- [x] Ghana region presets (Greater Accra, Kumasi, etc.)
- [ ] Local courier integration (Korier, Ghana Post)
- [ ] Order tracking with live updates
- [ ] Pickup option (for local merchants)

### 🔄 Milestone 2.4 — Customer Experience
- [x] Customer accounts & order history (CustomerLive.Show)
- [ ] Wishlist / saved items (storefront UI in progress)
- [ ] Product reviews & ratings
- [ ] Recently viewed products
- [ ] Personalized recommendations (basic)

### Milestone 2.5 — Advanced Storefront
- [ ] Multiple theme templates (3-5 options)
- [ ] Theme customization (colors, fonts, layout)
- [ ] Custom pages (About, Contact, FAQ)
- [ ] Blog/content management
- [ ] Instagram catalog sync

### Milestone 2.6 — Platform Billing
- [ ] Subscription plans (Free, Growth, Pro)
- [ ] Transaction fee collection
- [ ] Usage-based billing
- [ ] Invoice generation
- [ ] Payment method management

---

## Phase 3: Nigeria Expansion
**Goal**: Launch in Nigeria with localized payments, logistics, and compliance.

- [x] NGN currency support (Store.currency supports "NGN")
- [x] Paystack supports NGN (kobo minor units)
- [ ] Nigerian payment gateways (Flutterwave)
- [ ] Nigerian mobile money (OPay, PalmPay)
- [ ] Nigerian logistics (GIG, Kwik, Kobo360)
- [ ] Nigeria-specific regulatory compliance
- [ ] Localized onboarding & support
- [ ] Naira pricing for platform subscriptions

---

## Phase 4: Platform & Scale
**Goal**: Become the ecommerce infrastructure for West Africa.

- [ ] REST + GraphQL API (auto-generated from Ash)
- [ ] App/plugin marketplace
- [ ] Custom theme builder (drag-and-drop)
- [ ] Francophone West Africa (XOF — Senegal, Ivory Coast, Cameroon)
- [ ] Multi-language support (English, French, Hausa, Twi, Yoruba)
- [ ] Advanced analytics & AI recommendations
- [ ] B2B / wholesale features
- [ ] Multi-vendor marketplace mode
- [ ] POS integration for physical stores

---

## Technical Debt & Production Hardening

### Completed
- [x] Rate limiting on API endpoints (Hammer ETS)
- [x] Multi-tenant data isolation verified across all resources
- [x] Atomic stock adjustments (SQL-level, no race conditions)
- [x] All money as integers (no floats anywhere in the chain)
- [x] 618 tests with TDD across all domains
- [x] Tailwind source scanning fixed (was pointing at founder_pad_web)

### Remaining
- [ ] Session-based cart persistence (currently ephemeral in LiveView assigns)
- [ ] Subdomain-based store resolution (currently URL slug `/s/:slug`)
- [ ] Store switcher for multi-store merchants
- [ ] Over-refund protection (business rule)
- [ ] Full checkout flow UI (contact → shipping → payment → review)
- [ ] Image processing with libvips (currently stubbed)
- [ ] Structured logging with request metadata
- [ ] Error tracking (Sentry)
- [ ] Prometheus metrics exporter
- [ ] Database connection pooling tuning
- [ ] CI coverage threshold (currently disabled)

---

## Architecture Summary

| Layer | Count | Examples |
|-------|-------|---------|
| **Ash Resources** | 17 | Store, Product, Variant, Order, Payment, Customer, DeliveryZone... |
| **Ash Domains** | 8 | Accounts, Catalog, Orders, Payments, Customers, Shipping, Notifications, Billing |
| **LiveView Pages** | 21 | Dashboard, Products (2), Orders (2), Customers (2), Settings, Delivery, Categories, Storefront (6), Checkout, Auth (2), Onboarding, Landing |
| **Oban Workers** | 5 | ImageProcessor, PaystackWebhook, HubtelWebhook, OrderNotification, WebhookDelivery |
| **Payment Gateways** | 2 | Paystack (card + mobile money), Hubtel (mobile money) |
| **Design Prototypes** | 27 | All admin + storefront pages designed in HTML |
| **Modal Components** | 2 | Reusable `modal/1` (centered + slide-over) and `confirm_modal/1` |
| **Tests** | 618 | Unit, integration, edge cases, concurrent, multi-tenant isolation |
