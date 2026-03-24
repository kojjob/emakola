# Emakola — Project TODO

**Last updated:** 2026-03-24

---

## COMPLETED

### Landing Page Redesign
- [x] Replace generic SaaS boilerplate with Emakola ecommerce landing page
- [x] Split-screen hero: merchants (dark) + shoppers (light)
- [x] Deep Navy & Gold color palette across landing + auth pages
- [x] Trust bar with payment partner badges (MTN MoMo, Vodafone Cash, AirtelTigo, Paystack, Hubtel)
- [x] How It Works — visual-first with step images for low-literacy users
- [x] Features grid — 6 cards with images (Mobile Money, WhatsApp, Dashboard, Multi-Store, Inventory, Shipping)
- [x] Pricing — 4-tier hybrid model in GHS (Starter free/3.5%, Growth GHS 29/2%, Pro GHS 79/1.2%, Enterprise custom)
- [x] Testimonials — 6 merchants across Ghana (Accra, Kumasi, Takoradi, Cape Coast, Koforidua, Tamale)
- [x] Footer with Product, Resources, Company, Legal columns
- [x] Merchant hero: dashboard preview mockup, gold CTA, payment badges
- [x] Shopper hero: search bar, category pills, product cards, trust signals

### Auth Pages Redesign
- [x] Split-screen login page (Stitch design reference)
- [x] Split-screen register page
- [x] WhatsApp button disabled with "Coming Soon" label
- [x] Trust badges (SSL Secured, MoMo Integrated)
- [x] Ghana-focused copy (Accra / Kumasi / Takoradi)

### Production Polish
- [x] Compress all landing page images (quality 60)
- [x] Lazy loading on below-fold images
- [x] Replace Phoenix logo with Emakola brand logo
- [x] Dark body background to prevent white flash on navigation
- [x] Solid gradient backgrounds (no image overlay issues)
- [x] Force image heights with inline styles
- [x] "No credit card needed" badge on Starter pricing
- [x] "No credit card required" on final CTA
- [x] Rename "Watch Demo" to "See Features"

### Security & Infrastructure (prior work)
- [x] Content-Security-Policy headers with nonce support
- [x] Rate limiting on auth endpoints
- [x] Tenant-scoped Ash authorization policies
- [x] ETS caching layer for storefront queries
- [x] Webhook HMAC verification
- [x] Input length constraints on Ash resources
- [x] Dashboard refactored into focused components

---

## IN PROGRESS

### PR #31: Landing Page + Auth Redesign
- [x] All code implemented and pushed
- [x] 32 tests passing (17 landing + 15 auth)
- [ ] Visual QA on mobile devices
- [ ] Merge to main

---

## TODO — Storefront Theme Engine (Sub-project 1 of 3)

**Spec:** `docs/superpowers/specs/2026-03-24-storefront-theme-engine-design.md`
**Plan:** `docs/superpowers/plans/2026-03-24-storefront-theme-engine.md`

### Foundation (sequential)
- [ ] Task 1: Migration — add `theme_config` jsonb column to stores table
- [ ] Task 2: ThemeConfig validation module with tests
- [ ] Task 3: ThemeBehaviour + ThemeResolver + 3 theme stubs with tests
- [ ] Task 4: Storefront layout CSS variable injection + LiveView dispatch integration

### Themes (parallel)
- [ ] Task 5: Market theme — refactor existing storefront into theme system
- [ ] Task 6: Atelier theme — premium editorial from store.html prototype
- [ ] Task 7: Vibrant theme — bold colorful West African design

### Verification
- [ ] Task 8: Full integration testing + manual verification of all 3 themes

---

## TODO — Theme Templates (Sub-project 2 of 3)

- [ ] Additional theme designs beyond the initial 3
- [ ] Theme preview screenshots for selection UI
- [ ] Theme-specific product card variations
- [ ] Theme-specific checkout styling (shared but themed)

---

## TODO — Theme Customizer Admin UI (Sub-project 3 of 3)

- [ ] Admin page for merchants to select a theme
- [ ] Color picker for primary, accent, background colors
- [ ] Hero image upload + text customization
- [ ] Section toggle switches (show/hide hero, categories, brand story, etc.)
- [ ] Live preview of customizations before saving
- [ ] Save/publish workflow

---

## TODO — Platform Features (Backlog)

### Storefront Enhancements
- [ ] Real Emakola brand logo (replace placeholder SVG)
- [ ] Functional WhatsApp login/signup (currently "Coming Soon")
- [ ] Store search / marketplace browsing page
- [ ] Customer reviews and ratings on products
- [ ] Wishlist persistence (currently session-only)

### Payments
- [ ] Paystack payment gateway integration
- [ ] Hubtel payment gateway integration
- [ ] MTN MoMo direct integration
- [ ] Vodafone Cash direct integration
- [ ] Payment reconciliation dashboard

### Notifications
- [ ] WhatsApp Business API integration (order confirmations)
- [ ] SMS gateway for order updates
- [ ] Email templates for order lifecycle

### Operations
- [ ] Shipping zone configuration
- [ ] Delivery fee calculation
- [ ] Rider/delivery tracking integration
- [ ] Inventory low-stock alerts

### Admin Dashboard
- [ ] Analytics charts (sales, orders, revenue over time)
- [ ] Customer management (view, export)
- [ ] Bulk product import/export (CSV)
- [ ] Staff accounts and permissions

### Infrastructure
- [ ] Fix pre-existing test failures (42 failures in payments, security, performance tests)
- [ ] Rate limiter: reset counters in test config to prevent flaky tests
- [ ] Move logout route out of rate-limited pipeline (done locally, needs merge)
- [ ] OG image generation for stores and products
- [ ] Seed data with sample stores, products, and images
