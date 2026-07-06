# Changelog

All notable changes to Emakola will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Trustless dropship split settlement (SP-series, in review — PRs #158/#159): customer charges are split at the gateway (Paystack Multi-Split) so a wholesaler's cut is paid directly and never lands in the dropshipper's account first. Includes `SplitCalculator` (pure 3-way split off margin), `StorePayoutAccount` + `Supplier.linked_store_id`, `PaymentSplit`, gateway `create_subaccount/1` + `:split` on `initiate_payment/1`, `DropshipSettlement`/`OrderSettlement` (with manual-ledger fallback), checkout wiring, and webhook settle/reverse. No platform fund custody; platform fee is a % of dropship margin.
- Project initialization and planning
- Architecture documentation (system design, tech stack, multi-tenant strategy)
- Domain model specification (Accounts, Catalog, Orders, Customers, Shipping, Marketing, Billing)
- Payment integration strategy (Paystack, Hubtel, mobile money flow diagrams)
- MVP specification with user stories and acceptance criteria
- Competitive analysis (Paystack Commerce, Flutterwave, Jumia, Shopify, WooCommerce)
- Design prototypes — 12 production-ready HTML pages (storefront + admin dashboard)
- Design systems persisted for 5 themes
- Deployment configuration (Fly.io Johannesburg region, Dockerfile, fly.toml)
- Security policy (OWASP mitigations, multi-tenant isolation, PCI via Paystack)
- Compliance documentation (Ghana DPA, Nigeria NDPA, payment regulations, tax)
- Testing strategy (TDD, test pyramid, factories with Ghanaian data, critical scenarios)
- CI/CD pipeline (GitHub Actions)
- Monitoring & observability plan (metrics, alerting, incident response runbooks)
- Messaging strategy (WhatsApp > SMS > Email, templates, Oban workers)
- SEO strategy (structured data, sitemaps, Core Web Vitals targets)
- Business model and pricing (Free/Growth/Pro/Enterprise tiers)
- Brand guidelines (colors, typography, voice, cultural considerations)
- Feature flag strategy (FunWithFlags, release/ops/market/experiment categories)
- API documentation (REST endpoints, webhooks, rate limiting)
- Development setup guide and environment configuration
