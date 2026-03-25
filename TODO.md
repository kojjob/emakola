# Emakola — Project TODO

**Last updated:** 2026-03-25

---

## COMPLETED

### Landing Page Redesign (PR #31 — merged)
- [x] Replace generic SaaS boilerplate with Emakola ecommerce landing page
- [x] Split-screen hero: merchants (dark) + shoppers (light)
- [x] Deep Navy & Gold color palette across landing + auth pages
- [x] Trust bar with payment partner badges (MTN MoMo, Vodafone Cash, AirtelTigo, Paystack, Hubtel)
- [x] How It Works — visual-first with step images for low-literacy users
- [x] Features grid — 6 cards with images (Mobile Money, WhatsApp, Dashboard, Multi-Store, Inventory, Shipping)
- [x] Pricing — 4-tier hybrid model in GHS (Starter free/3.5%, Growth GHS 29/2%, Pro GHS 79/1.2%, Enterprise custom)
- [x] Testimonials — 6 merchants across Ghana (Accra, Kumasi, Takoradi, Cape Coast, Koforidua, Tamale)
- [x] Merchant hero: dashboard preview mockup, gold CTA, payment badges
- [x] Shopper hero: search bar, category pills, product cards, trust signals
- [x] Production polish: image compression, lazy loading, trust signals

### Auth Pages Redesign (PR #31 — merged)
- [x] Split-screen login page (Stitch design reference)
- [x] Split-screen register page
- [x] WhatsApp button disabled with "Coming Soon" label
- [x] Trust badges (SSL Secured, MoMo Integrated)

### Admin Features (PR #33 — merged)
- [x] Notification dropdown with live data in admin sidebar
- [x] User dropdown with interactive popover menu (fixed overflow clipping)
- [x] Product slide-over panels for add/edit and bulk CSV upload
- [x] Product image upload and rendering
- [x] Category page redesign — visual cards with auto-detected icons and colors
- [x] Seed data with sample stores, products, and images
- [x] Build artifacts removed from git tracking

### Storefront Theme Engine (PR #34 — CI passed, pending merge)
- [x] Task 1: Migration — `theme_config` jsonb column on stores
- [x] Task 2: ThemeConfig validation module (12 tests)
- [x] Task 3: ThemeBehaviour + ThemeResolver + 3 theme stubs (12 tests)
- [x] Task 4: Storefront layout CSS variable injection + LiveView dispatch
- [x] Task 5: Market theme — refactored from existing storefront
- [x] Task 6: Atelier theme — premium editorial fashion (from store.html prototype)
- [x] Task 7: Vibrant theme — bold colorful West African design
- [x] 892 tests, 0 failures

### Security & Infrastructure
- [x] Content-Security-Policy headers with nonce support
- [x] Rate limiting on auth endpoints
- [x] Tenant-scoped Ash authorization policies
- [x] ETS caching layer for storefront queries
- [x] Webhook HMAC verification
- [x] Input length constraints on Ash resources
- [x] Dashboard refactored into focused components
- [x] Logout route moved out of rate-limited pipeline
- [x] Dark body background fix for admin pages

---

## IN PROGRESS

### PR #34: Storefront Theme Engine
- [x] CI passed
- [ ] Merge to main
- [ ] Task 8: Manual verification — test all 3 themes visually

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
- [ ] Theme preview screenshots for selection UI
- [ ] Additional theme designs beyond initial 3

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
- [ ] OG image generation for stores and products
- [ ] Mobile responsiveness QA pass
- [ ] Performance profiling and optimization
