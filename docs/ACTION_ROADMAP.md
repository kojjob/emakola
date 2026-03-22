# Emakola — Action Roadmap

> Prioritized implementation plan based on codebase evaluation (March 2026).
> Builds on the existing [ROADMAP.md](./ROADMAP.md) with concrete next steps.

---

## 🔥 Phase 0: Fix Deployment Blockers

> Must be done before first deploy to Fly.io.

- [ ] Add `/health` route (referenced by Dockerfile + fly.toml but missing)
- [ ] Configure and start Oban in `application.ex` supervision tree + config files
- [ ] Add `/metrics` endpoint or remove from fly.toml
- [ ] Replace Phoenix branding in `layouts.ex` with Emakola branding

---

## 🏗️ Phase 1.1: Foundation (MVP Sprint 1)

> Merchants can sign up, verify, and create a store.

- [ ] Set up Ash domains — `Emakola.Accounts`, `Emakola.Catalog`, `Emakola.Orders`
- [ ] Create `Merchant` resource (email, password, phone, business name)
- [ ] Create `Store` resource (name, slug, description, logo, currency)
- [ ] Create `StoreConfig` resource (theme, checkout settings, notification prefs)
- [ ] Configure Ash Authentication (email/password, session management)
- [ ] Generate migrations for `merchants`, `stores`, `store_configs`
- [ ] Multi-tenancy plug — resolve store from subdomain, set Ash tenant context
- [ ] Store setup wizard LiveView (post-registration flow)
- [ ] Merchant admin LiveView shell with sidebar navigation

### Testing
- [ ] Set up ExMachina factories for Merchant, Store
- [ ] ConnCase helper with authenticated merchant setup
- [ ] LiveView tests for registration + store creation

---

## 📦 Phase 1.2: Product Management (MVP Sprint 2)

> Merchants can add, edit, and organize products.

- [ ] Create `Product` resource (title, description, slug, status, SEO fields)
- [ ] Create `Variant` resource (SKU, price in minor units, stock, option values)
- [ ] Create `Category` resource (name, slug, parent_id for hierarchy)
- [ ] Create `Image` resource (url, alt_text, position)
- [ ] Generate migrations for catalog tables
- [ ] Product CRUD LiveView (create, edit, list, archive)
- [ ] Image upload to S3-compatible storage (add `ex_aws` + `ex_aws_s3` deps)
- [ ] Inventory tracking with low-stock threshold alerts
- [ ] Category management LiveView

---

## 🏪 Phase 1.3: Storefront (MVP Sprint 3)

> Customers can browse a merchant's store.

- [ ] Tenant-resolved storefront LiveView (subdomain routing)
- [ ] Mobile-first product listing with grid view
- [ ] Category filtering + price/newest sorting
- [ ] Product detail page (images, variants, add-to-cart)
- [ ] Product search (pg_trgm or full-text search)
- [ ] SEO: meta tags, Open Graph, structured data (JSON-LD)
- [ ] Performance target: full page load < 3s on 3G

---

## 🛒 Phase 1.4: Cart & Checkout (MVP Sprint 4)

> Customers can add items to cart and checkout.

- [ ] Cart (LiveView assigns or session-based, guest-friendly)
- [ ] Guest checkout (no account required)
- [ ] Address form (Ghana regions)
- [ ] Checkout flow: contact → shipping → payment → review
- [ ] Create `Order`, `LineItem` resources
- [ ] Create `Customer`, `Address` resources
- [ ] Generate migrations for orders + customers

---

## 💰 Phase 1.5: Payments — Ghana (MVP Sprint 5)

> Customers can pay with cards and mobile money.

- [ ] Abstract payment behaviour (gateway-agnostic interface)
- [ ] Paystack integration (cards)
- [ ] MTN Mobile Money via Paystack
- [ ] Vodafone Cash via Paystack
- [ ] AirtelTigo Money via Paystack
- [ ] Cash on delivery option
- [ ] Create `Payment` resource with gateway reference tracking
- [ ] Webhook handler for Paystack callbacks (signature verification)
- [ ] "Waiting for payment" screen with polling for mobile money
- [ ] Order confirmation page
- [ ] Oban worker: process payment webhooks

---

## 📋 Phase 1.6: Order Management (MVP Sprint 6)

> Merchants can view and manage orders.

- [ ] Order list LiveView with status filters
- [ ] Order detail LiveView (items, customer, payment info)
- [ ] Status workflow: pending → confirmed → processing → shipped → delivered
- [ ] COD: mark as paid on delivery
- [ ] SMS notifications on status change (Oban worker + SMS gateway)
- [ ] Basic email receipts
- [ ] Create `Refund` resource + refund processing

---

## 📊 Phase 1.7: Dashboard (MVP Sprint 7)

> Merchants can see how their store is performing.

- [ ] Revenue overview (today, week, month)
- [ ] Order count + status breakdown
- [ ] Top products by revenue
- [ ] Recent orders table
- [ ] Low-stock alerts
- [ ] Basic visitor/conversion analytics

---

## 📱 Phase 1.8: PWA (MVP Sprint 8)

> App-like experience without Play Store.

- [ ] Web app manifest (name, icons, theme color)
- [ ] Service worker for offline storefront caching
- [ ] "Add to Home Screen" prompt
- [ ] Offline product browsing

---

## 🔐 Production Hardening (Ongoing)

- [ ] Rate limiting on auth endpoints (PlugAttack or custom)
- [ ] Structured logging with request metadata
- [ ] Error tracking (Sentry — DSN in .env.example but not configured)
- [ ] Prometheus metrics exporter (fly.toml expects port 9091)
- [ ] Resolve DaisyUI vs custom Tailwind decision (AGENTS.md contradiction)
- [ ] Database connection pooling tuning for production load

---

## Build Order Dependency Chain

```
Phase 0 (blockers)
  └─→ Phase 1.1 (auth + stores)
        └─→ Phase 1.2 (products)
              └─→ Phase 1.3 (storefront)
                    └─→ Phase 1.4 (cart + checkout)
                          └─→ Phase 1.5 (payments)
                                └─→ Phase 1.6 (orders)
                                      └─→ Phase 1.7 (dashboard)
                                            └─→ Phase 1.8 (PWA)
```

Each phase is a deployable increment. Production hardening runs in parallel throughout.
