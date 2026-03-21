# Emakola — Project Report

**Date**: March 21, 2026
**Status**: Design & Planning Complete, Prototyping In Progress

---

## Executive Summary

Emakola is a Shopify-like ecommerce platform built for West Africa, launching in Ghana first then expanding to Nigeria and francophone West Africa. The platform enables merchants (primarily Instagram/WhatsApp sellers) to create professional online stores with native mobile money payments, WhatsApp/SMS communication, and a built-in rider delivery marketplace.

**Tech Stack**: Elixir, Phoenix 1.8+, Ash 3.x, LiveView, PostgreSQL 15+, TailwindCSS, Oban

**Key Differentiator**: Mobile money as primary checkout (MTN MoMo, Vodafone Cash), WhatsApp-first communication, rider delivery marketplace, 3G-optimized performance — things Shopify doesn't do.

---

## What's Been Completed

### 1. Design System & Brand Identity
- **Personality**: Clean & Professional — platform disappears, merchant's brand is the star
- **Colors**: Emakola Green (#059669) primary, Dark Emerald (#064E3B) sidebar, Gold (#CA8A04) warnings
- **Typography**: Inter (UI) + JetBrains Mono (numbers/prices)
- **Admin**: Dark emerald sidebar accent with white content area
- **Storefront**: Instagram-Native theme (circle avatar, story categories, card-based products)
- **Checkout**: Payment-First flow (familiar MoMo/Vodafone logos before any form input)
- **Mobile Admin**: Hybrid approach (quick actions on phone, full management on desktop)

### 2. Architecture Documentation (~/Projects/emakola/docs/)

| Document | Size | Content |
|----------|------|---------|
| `ARCHITECTURE.md` | 9KB | System design, multi-tenant strategy, tech stack rationale |
| `DOMAIN_MODEL.md` | 7KB | Complete Ash resource definitions — Accounts, Catalog, Orders, Customers, Shipping, Marketing, Billing |
| `ROADMAP.md` | 4KB | 4-phase rollout: MVP Ghana → Growth Ghana → Nigeria → Platform |
| `PAYMENTS.md` | 6KB | Payment gateway strategy, mobile money flow diagrams, currency handling |
| `DELIVERY.md` | 8KB | Rider marketplace design, WhatsApp dispatch, GPS tracking, zone pricing |
| `API.md` | 15KB | REST endpoints, webhooks, rate limiting, error formats |
| `SECURITY.md` | 19KB | OWASP mitigations, multi-tenant isolation, PCI compliance |
| `COMPLIANCE.md` | 5KB | Ghana DPA, Nigeria NDPA, payment regulations, tax (VAT/NHIL) |
| `DEPLOYMENT.md` | 13KB | Fly.io Johannesburg setup, Dockerfile, zero-downtime deploys |
| `MONITORING.md` | 5KB | Metrics, alerting rules (P1-P4), incident runbooks |
| `TESTING.md` | 8KB | TDD strategy, test pyramid, factories with Ghanaian data, critical scenarios |
| `MESSAGING.md` | 4KB | WhatsApp/SMS/Email templates, Oban workers, fallback chain |
| `SEO.md` | 3KB | Structured data, sitemaps, Core Web Vitals targets |
| `BUSINESS_MODEL.md` | 3KB | Pricing tiers, unit economics, go-to-market strategy |
| `BRAND.md` | 2KB | Colors, typography, voice, cultural considerations |
| `FEATURE_FLAGS.md` | 2KB | FunWithFlags strategy, release/ops/market/experiment categories |
| `COMPETITIVE_ANALYSIS.md` | 4KB | Positioning vs Paystack Commerce, Flutterwave, Jumia, Shopify |
| `SETUP.md` | 11KB | Development environment setup guide |

### 3. UI Design Specification
- **Spec file**: `docs/superpowers/specs/2026-03-21-emakola-ui-design.md`
- **Decisions documented**: 6 major design choices with rationale
- **Design tokens**: Complete color, typography, spacing, and radius system
- **Component library**: Defined components for admin + storefront
- **Accessibility**: WCAG 2.1 AA requirements documented
- **Performance budget**: < 200KB page weight, < 3s on 3G

### 4. Infrastructure Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project conventions for Claude Code |
| `CONTRIBUTING.md` | Contributor guidelines |
| `CHANGELOG.md` | Version history |
| `LICENSE` | MIT License |
| `Dockerfile` | Multi-stage production build |
| `fly.toml` | Fly.io deployment config (Johannesburg region) |
| `.env.example` | All environment variables documented |
| `.gitignore` | Elixir/Phoenix ignores |
| `.github/workflows/ci.yml` | GitHub Actions CI pipeline |

### 5. UI Prototypes

#### Existing Reference Prototypes (from Atelier Store theme)
12 production-ready HTML pages in `design/prototypes/`:
- Storefront: store, shop, product, cart, checkout, wishlist, account
- Admin: dashboard, orders, products, customers, settings
- **Total**: ~727KB of production HTML

#### Emakola-Branded Prototypes (in progress)
Building from the approved design spec:
- `emakola-admin-dashboard.html` — Dark emerald sidebar, GH₵ KPIs, Ghanaian data
- `emakola-admin-orders.html` — Orders with MTN MoMo/Vodafone payment icons
- `emakola-admin-products.html` — West African fashion products grid
- `emakola-storefront-home.html` — Instagram-native layout (planned)
- `emakola-storefront-product.html` — Product detail (planned)
- `emakola-checkout.html` — Payment-first with MoMo branding (planned)
- `emakola-admin-mobile.html` — Mobile quick-actions (planned)
- `emakola-delivery-tracking.html` — Customer delivery tracking (planned)
- `emakola-admin-delivery.html` — Rider dispatch admin (planned)

---

## Key Design Decisions

### 1. Instagram-Native Storefront Theme
**Why**: Target merchants are Instagram sellers. Their customers already browse Instagram daily. A store that feels like a natural extension removes friction. Story-style categories, circle avatars, and card-based products are patterns 100% of users understand.

### 2. Payment-First Checkout
**Why**: Showing familiar MTN MoMo and Vodafone Cash logos immediately builds trust before asking for personal info. Critical for first-time online shoppers in Ghana who may be anxious about digital payments.

### 3. Rider Marketplace for Delivery
**Why**: Delivery in Ghana is fragmented — individual motorbike riders with no central dispatch. Emakola solves this by connecting merchants with independent riders via WhatsApp dispatch. We don't employ riders (no liability), we provide matching and tracking. This is a differentiator Shopify can't touch.

### 4. Hybrid Mobile Admin
**Why**: Merchants check orders on their phone throughout the day but sit down at a laptop for product management. Mobile gets quick actions (order status, notifications, revenue snapshot). Full management stays on desktop.

### 5. WhatsApp-First Communication
**Why**: 93% WhatsApp penetration in Ghana. SMS as fallback. Email as supplementary. This matches actual user behavior rather than Western assumptions.

### 6. 3G Performance Target
**Why**: Many customers and merchants access the internet via 3G. LiveView's server-rendered approach means tiny JS payloads (~30KB vs 300KB+ for React). Target: < 3s full page load on 300kbps.

---

## Business Model Summary

### Pricing (Ghana Launch)
| Plan | Monthly | Transaction Fee | Products | Key Features |
|------|---------|----------------|----------|--------------|
| Free | GH₵ 0 | 3.5% | 25 | Basic store, 1 theme |
| Growth | GH₵ 49 | 2.0% | 1,000 | Custom domain, WhatsApp, discounts |
| Pro | GH₵ 149 | 1.5% | Unlimited | GPS tracking, API, all themes |
| Enterprise | Custom | Custom | Unlimited | Dedicated support, custom integrations |

### Unit Economics (Growth Merchant)
- Monthly revenue per merchant: GH₵ 449 (subscription + transaction fees)
- Monthly cost per merchant: ~GH₵ 65
- Gross margin: ~85%
- CAC target: < GH₵ 200
- LTV target: > GH₵ 5,000

### Market Size
- Ghana ecommerce: ~$2B (2025, growing 25% YoY)
- Nigeria ecommerce: ~$12B
- West Africa total addressable: ~$20B+
- Year 1 target: 5,000 active merchants

---

## Delivery Marketplace Summary

### Model
- **Rider marketplace** — we connect merchants with independent motorbike riders
- **Communication**: WhatsApp-based dispatch (rider gets request, accepts/declines)
- **Tracking**: SMS status updates (all plans) + live GPS tracking (Pro plan)
- **Revenue**: 10% commission on delivery fees
- **Payouts**: Daily MoMo settlement to riders

### Zone Pricing (Accra Defaults)
| Zone | Distance | Fee |
|------|----------|-----|
| Same area | < 3km | GH₵ 10-15 |
| Cross-city | 3-10km | GH₵ 15-25 |
| Long distance | 10-25km | GH₵ 25-40 |

---

## Competitive Advantages

1. **Mobile Money Native** — MTN MoMo is primary, not an afterthought plugin
2. **WhatsApp-First** — Order updates, support, abandoned cart via WhatsApp
3. **Rider Marketplace** — Built-in delivery logistics for fragmented market
4. **Local Pricing** — GH₵ 49/mo, not $39/mo
5. **3G-Optimized** — LiveView = fast on slow connections
6. **Cash on Delivery** — Proper workflow, not just a payment label
7. **Cultural Fit** — Built by West Africans, for West Africans

---

## Phased Rollout

| Phase | Focus | Key Deliverables |
|-------|-------|-----------------|
| **1 — MVP** | Ghana Launch | Store creation, products, checkout (MoMo + cards + COD), orders, SMS notifications, basic dashboard, rider marketplace |
| **2 — Growth** | Ghana Expansion | WhatsApp integration, discounts, shipping zones, customer accounts, 3-5 themes, analytics, GPS tracking |
| **3 — Nigeria** | Market Expansion | NGN currency, Nigerian gateways, Nigerian logistics, localized onboarding |
| **4 — Platform** | Scale | API + marketplace, custom theme builder, multi-language, francophone WA, POS |

---

## Next Steps

1. Complete Emakola-branded UI prototypes (Phase A admin pages building now)
2. Build storefront + checkout + delivery prototypes (Phase B + C)
3. Scaffold Phoenix application with Ash multitenancy
4. Implement MVP following TDD — domain model first, then web layer
5. Integrate Paystack + Hubtel for payments
6. Build WhatsApp bot for rider dispatch
7. Deploy to Fly.io (Johannesburg region)
8. Beta launch with 10-20 Accra merchants

---

## File Inventory

### Project Root
```
~/Projects/emakola/
├── CLAUDE.md                          (12KB)
├── CONTRIBUTING.md                     (2KB)
├── CHANGELOG.md                        (2KB)
├── LICENSE                             (1KB)
├── Dockerfile                          (4KB)
├── fly.toml                            (3KB)
├── .env.example                        (4KB)
├── .gitignore                          (3KB)
├── .github/workflows/ci.yml            (2KB)
├── docs/
│   ├── ARCHITECTURE.md                 (9KB)
│   ├── ROADMAP.md                      (4KB)
│   ├── DOMAIN_MODEL.md                 (7KB)
│   ├── PAYMENTS.md                     (6KB)
│   ├── DELIVERY.md                     (8KB)
│   ├── API.md                         (15KB)
│   ├── SECURITY.md                    (19KB)
│   ├── COMPLIANCE.md                   (5KB)
│   ├── DEPLOYMENT.md                  (13KB)
│   ├── MONITORING.md                   (5KB)
│   ├── TESTING.md                      (8KB)
│   ├── MESSAGING.md                    (4KB)
│   ├── SEO.md                          (3KB)
│   ├── BUSINESS_MODEL.md               (3KB)
│   ├── BRAND.md                        (2KB)
│   ├── FEATURE_FLAGS.md                (2KB)
│   ├── COMPETITIVE_ANALYSIS.md         (4KB)
│   ├── SETUP.md                       (11KB)
│   ├── PROJECT_REPORT.md              (this file)
│   └── superpowers/specs/
│       └── 2026-03-21-emakola-ui-design.md  (design spec)
├── specs/
│   └── MVP_SPEC.md                     (4KB)
└── design/
    ├── prototypes/                    (12 reference + 9 Emakola-branded)
    ├── design-system/                 (5 persisted design systems)
    └── assets/                        (brand assets)
```

**Total documentation**: ~160KB across 20+ documents
**Total prototypes**: ~727KB across 12 reference pages + Emakola pages in progress
