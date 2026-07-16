# Emakola — Platform Architecture

> Ecommerce platform for West Africa. Shopify-level experience built for local realities.

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Language | Elixir | Concurrency, fault-tolerance, hot code reloading |
| Web Framework | Phoenix 1.8+ | LiveView for real-time, low-bandwidth UI |
| Domain Framework | Ash 3.x | Multi-tenant resources, authorization, API generation |
| Frontend | LiveView + TailwindCSS | Server-rendered, tiny payloads, works on 3G |
| Database | PostgreSQL 15+ | Multi-tenant schemas, JSONB for flexible data |
| Background Jobs | Oban | Reliable job processing (SMS, webhooks, payments) |
| Real-time | Phoenix PubSub | Live order updates, inventory sync |
| Hosting | Fly.io (Johannesburg region) | ~80ms to West Africa vs 200ms+ from US/EU |

## System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        EMAKOLA PLATFORM                       │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────┐    ┌──────────────────────────────┐ │
│  │   MERCHANT ADMIN     │    │   STOREFRONT ENGINE          │ │
│  │   (LiveView)         │    │   (LiveView + CDN)           │ │
│  │                      │    │                              │ │
│  │  • Dashboard         │    │  • Tenant-resolved themes    │ │
│  │  • Products          │    │  • Product catalog           │ │
│  │  • Orders            │    │  • Cart + Checkout           │ │
│  │  • Customers         │    │  • Mobile money flow         │ │
│  │  • Store Settings    │    │  • Customer accounts         │ │
│  │  • Analytics         │    │  • Search                    │ │
│  │  • Marketing         │    │  • WhatsApp/SMS updates      │ │
│  └────────┬─────────────┘    └──────────────┬───────────────┘ │
│           │                                  │                │
│  ┌────────▼──────────────────────────────────▼───────────────┐│
│  │                    CORE DOMAIN (Ash)                       ││
│  │                                                           ││
│  │  Accounts        Products         Orders                  ││
│  │  ├── Merchant    ├── Product      ├── Order               ││
│  │  ├── Store       ├── Variant      ├── LineItem            ││
│  │  ├── Plan        ├── Category     ├── Payment             ││
│  │  └── StoreConfig ├── Image        ├── Refund              ││
│  │                  └── Inventory    └── Fulfillment         ││
│  │                                                           ││
│  │  Customers       Shipping         Billing                 ││
│  │  ├── Customer    ├── ShipMethod   ├── Subscription        ││
│  │  ├── Address     ├── ShipZone     ├── Invoice             ││
│  │  └── Segment     └── Tracking     └── UsageRecord        ││
│  │                                                           ││
│  │  Marketing       Analytics                                ││
│  │  ├── Discount    ├── Event                                ││
│  │  ├── Campaign    ├── Report                               ││
│  │  └── Coupon      └── Metric                               ││
│  └───────────────────────────────────────────────────────────┘│
│                              │                                │
│  ┌───────────────────────────▼───────────────────────────────┐│
│  │                    INTEGRATIONS                            ││
│  │                                                           ││
│  │  Payments           Messaging        Logistics            ││
│  │  ├── Paystack       ├── WhatsApp     ├── Ghana Post       ││
│  │  ├── Flutterwave    ├── SMS (Hubtel) ├── Korier           ││
│  │  ├── Hubtel         └── Email        ├── GIG Logistics    ││
│  │  ├── MTN MoMo                        └── Kwik Delivery    ││
│  │  ├── Telecel Cash                                        ││
│  │  ├── AirtelTigo                                           ││
│  │  └── Cash on Delivery                                     ││
│  └───────────────────────────────────────────────────────────┘│
│                                                               │
│  ┌───────────────────────────────────────────────────────────┐│
│  │                    INFRASTRUCTURE                          ││
│  │                                                           ││
│  │  PostgreSQL (multi-tenant) │ Oban (jobs)                  ││
│  │  Phoenix PubSub (realtime) │ ExAws S3 (images)            ││
│  │  Fly.io (Johannesburg)     │ Cloudflare CDN               ││
│  └───────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────┘
```

## Multi-Tenant Strategy

Using Ash's built-in multitenancy with PostgreSQL schemas:

```elixir
# Each merchant store gets isolated data
# URL: {store-slug}.emakola.com or custom domain

defmodule Emakola.Accounts.Store do
  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer

  multitenancy do
    strategy :context
    # Tenant resolved from subdomain/custom domain
  end
end
```

**Tenant Resolution Flow:**
1. Request hits `{slug}.emakola.com` or custom domain
2. Plug resolves tenant from domain → store_id
3. Ash context carries tenant through all queries
4. Data completely isolated per store

## Key Design Decisions

### 1. Mobile-First, Low-Bandwidth
- LiveView server-rendering = minimal JS payload (~30KB vs 300KB+ React)
- Images served via CDN with WebP + srcset
- Critical CSS inlined, non-critical deferred
- Target: full page load < 3s on 3G

### 2. Payment Architecture
- Abstract payment interface (behaviour) with multiple implementations
- Mobile money has different flow (USSD prompt → callback) vs card payments
- Cash on delivery needs separate fulfillment workflow
- All payment events logged for reconciliation

### 3. Communication Priority
- WhatsApp > SMS > Email (matches West African user behavior)
- Order confirmations, shipping updates, abandoned cart — all via WhatsApp first
- SMS fallback for non-WhatsApp users
- Email for receipts and merchant admin notifications

### 5. No Public API in MVP — LiveView First
- LiveView handles ALL user-facing experiences (storefront + admin + checkout)
- Server-rendered HTML = works on 3G, no heavy JS bundles, no native app needed
- Internal service modules handle payment webhooks (not a public API)
- Phase 2: Internal API for WhatsApp bot + rider dispatch only
- Phase 4: Public API via Ash auto-generation (JSON:API + GraphQL) when merchants need it
- PWA (Progressive Web App) replaces native mobile app — "Add to Home Screen", offline caching, push notifications

### 6. PWA Strategy (replaces native app)
- Service worker for offline product browsing
- Web app manifest for "Add to Home Screen"
- Push notifications via Web Push API (order alerts for merchants)
- Caches storefront pages for instant navigation
- Zero Play Store friction — critical for West African user adoption

### 4. Currency & Localization
- GHS (Ghana Cedi) as launch currency
- NGN (Nigerian Naira) for Phase 3
- XOF (CFA Franc) for francophone expansion
- All prices stored in minor units (pesewas/kobo)
- Exchange rates via API for cross-border (future)
