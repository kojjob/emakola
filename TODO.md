# Emakola — Project TODO

**Last updated:** 2026-03-25

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

## UP NEXT (high impact for launch)

### Notifications
- [ ] WhatsApp Business API integration (order confirmations, shipping updates)
- [ ] SMS gateway for order updates
- [ ] Email templates for order lifecycle (confirmation, shipped, delivered)

### Operations
- [ ] Shipping zone configuration (regions, delivery areas)
- [ ] Delivery fee calculation (by zone, weight, or flat rate)
- [ ] Inventory low-stock alerts (Oban worker + email/WhatsApp)

### Payments (expand)
- [ ] Hubtel payment gateway integration
- [ ] Payment reconciliation dashboard (admin view of all payments)

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
