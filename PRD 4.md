# Emakola — Product Requirements Document

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Status** | Approved (MVP scope locked 2026-04-27) |
| **Last updated** | 2026-04-27 |
| **Owner** | Kojo (Founder) |
| **Engineering lead** | TBD |
| **Design lead** | TBD |
| **Related documents** | [Approved plan](~/.claude/plans/think-of-the-project-quizzical-boot.md), [TODO.md](./TODO.md), [CLAUDE.md](./CLAUDE.md) |

---

## 1. Executive Summary

Emakola is a multi-vertical commerce platform for West Africa, launching in Ghana. It combines two product surfaces into one platform:

1. **Multi-tenant ecommerce** for product merchants — Shopify-style storefronts with mobile-money checkout (already shipped, hardening in flight).
2. **Services marketplace** for verified artisans — a Jiji-style discovery surface where buyers find verified plumbers, electricians, makeup artists, tutors, mechanics, and more — with WhatsApp/call lead tracking, in-platform booking, MoMo escrow-style deposits, and a paid-boost revenue model.

The platform's strategic position: **"Jiji + WhatsApp business + verified artisans + MoMo escrow + simple advertising tools, all in one place."** The differentiator versus Jiji is **trust** (verification, transaction-gated reviews, escrow-style funds release, fraud detection) and versus Shopify is **localization** (mobile money, WhatsApp, low-bandwidth UX, Ghana-specific verification).

The MVP timeline is approximately **three months** across five phases, ending with end-to-end paid bookings between verified artisans and buyers.

---

## 2. Vision & Strategic Positioning

### 2.1 Vision

> Make it as safe and simple to hire a verified plumber in East Legon, or buy from a registered store in Kumasi, as it is to send MoMo to a friend.

### 2.2 Strategic positioning

|                          | Jiji          | Shopify       | WhatsApp Business | **Emakola**   |
|--------------------------|---------------|---------------|-------------------|---------------|
| Cross-seller discovery   | Yes           | No            | No                | **Yes**       |
| Verified sellers         | Weak          | N/A           | Self-claim        | **Strong (Ghana Card + phone)** |
| In-platform transactions | No            | Yes           | No                | **Yes (MoMo)** |
| Fraud prevention         | Weak          | N/A           | None              | **First-class** |
| Mobile money native      | Partial       | Via gateways  | No                | **Yes (Hubtel)** |
| Localised for Ghana      | Some          | Generic       | Some              | **Yes**       |

The product is not generic-Shopify-for-Africa or generic-Jiji-with-payments. It is **the trust layer** for buyers and sellers in West Africa, with payments and discovery as the primary surfaces.

### 2.3 Why now

- Mobile money penetration in Ghana is >60% of adults; MoMo is now the de facto payment rail.
- Hubtel (and now Paystack) provide reliable APIs over MTN MoMo, Telecel Cash, AirtelTigo Money.
- Jiji's reputation in Ghana is dominated by scam complaints — there is a clear opening for a trust-first competitor.
- WhatsApp is already where transactions happen informally; formalising this captures latent demand.

---

## 3. Problem Statement

### 3.1 Buyer-side problems
- **Trust deficit**: It is hard to know if an artisan or seller is real, skilled, and accountable. Existing platforms accept self-reported information.
- **Discovery friction**: Most artisans rely on word-of-mouth and WhatsApp groups. Finding a trusted plumber for an urgent repair often means asking 3 friends.
- **Payment risk**: Paying upfront via MoMo to a stranger has no protection. Paying after the job is done leaves the artisan exposed.
- **Communication fragmentation**: Transactions span SMS, WhatsApp, in-person, with no record. Disputes have no evidence trail.

### 3.2 Seller-side problems
- **Discoverability**: Artisans without strong social-media presence have no path to new customers beyond walk-by traffic and referrals.
- **Customer acquisition cost**: Boosting on Facebook or Instagram requires English copy, ad-account setup, and budget knowledge most artisans don't have.
- **No-show & non-payment risk**: Buyers cancel or refuse to pay, and the artisan has no leverage.
- **Lack of operational tools**: No calendar, no quote system, no receipt generator, no review collection.

### 3.3 Platform-side opportunity

- A trusted directory of verified artisans + a payment rail + lead tracking creates two revenue streams (transaction fees and paid boost).
- The product side (existing) and services side (new) reinforce each other: a buyer who trusts the platform for a haircut booking will trust it for a clothing purchase.

---

## 4. Goals & Non-Goals

### 4.1 Goals (MVP, 3 months)

| Goal | Measure |
|---|---|
| Verified artisans can be found and contacted by buyers | ≥ 200 verified artisans live by month 3; ≥ 1,000 leads tracked |
| Buyers feel safe transacting | ≥ 70% of paid bookings reach `:completed` without dispute; ≥ 4.0 average review |
| The platform earns revenue | Listing-boost revenue ≥ GH₵5,000 / month by month 3; first paid booking commission live in Phase 4 |
| Fraud is contained | < 1% of bookings flagged as fraud; banned-identifier registry actively blocking re-registration |
| Existing merchants are not disrupted | Existing product checkout flow regression-free across phases |

### 4.2 Non-goals (MVP)

- WhatsApp Business API integration (Meta verification per merchant takes 2-4 weeks; we use deep-links for now)
- Full escrow with held-balance accounting (we use a logical "pending until buyer confirms or 72h elapses" rule instead)
- Full dispute-resolution workflow (placeholder UI + manual admin moderation only)
- AI ad creator, social posting helper, QR codes, calendar UI, repeat booking, diaspora flow
- Twi / Ga / Ewe localization (English only at MVP)
- Native mobile app (mobile web first)
- Nigeria expansion (Ghana only at MVP)
- Pay-per-lead pricing model (start with subscription/boost; revisit post-MVP)
- Insurance, financing, or credit products

---

## 5. Target Users (Personas)

### 5.1 Kwame — the artisan (primary new audience)
- Plumber, 32, based in Madina. Has a Ghana Card and an MTN MoMo account.
- Uses WhatsApp daily; has tried Jiji but stopped because of scam reports.
- Owns an Android phone (~3 years old, 32 GB storage, 2 GB RAM). Uses MTN data, often metered.
- Wants: more customers, less time chasing payment, a way to look credible to new clients.
- Pain: no professional online presence; customers haggle every time; some don't pay after the job.
- Success looks like: 3-5 verified leads per week, a trust score he can show clients, money in his MoMo wallet within 72 hours of completing a job.

### 5.2 Ama — the buyer (primary new audience)
- 28, marketing assistant in East Legon, owns a smartphone.
- Comfortable with MoMo, WhatsApp, Instagram. Skeptical of Jiji.
- Needs: a plumber today, a makeup artist for a wedding next month, occasional one-off services.
- Pain: doesn't trust strangers from the internet, asks friends for recommendations, has been scammed once.
- Success looks like: searches "plumber East Legon" → sees verified results → WhatsApps one → confirms availability → pays a small deposit via MoMo → gets the job done → leaves a review.

### 5.3 Adjoa — the existing product merchant (existing audience)
- Runs a hair-care brand on Emakola's storefront product since 2025-12.
- Already onboarded; uses Hubtel checkout; receives WhatsApp order notifications.
- Wants: more orders. Open to also offering a "salon booking" service alongside her products.
- Pain: knows her customers personally and worries the marketplace pivot might dilute her brand.
- Success looks like: her storefront still works, she can opt-in to "also offer services" without disrupting her catalog.

### 5.4 Yaw — the platform admin (Emakola team)
- Reviews verifications, monitors fraud signals, resolves disputes.
- Needs: a moderation queue, an audit trail, a way to ban scammers fast.
- Success looks like: every flagged seller gets reviewed within 24h; banned identifiers prevent re-registration; the trust score reflects reality.

### 5.5 Personas explicitly out of MVP scope
- **Diaspora user** — Ghanaians abroad booking services in Ghana for family. Strong future market but adds KYC complexity (international payments, FX). Phase 5+.
- **Trade-association sellers** — group accounts (e.g., the Madina plumbers' association). Adds seat-management; defer.

---

## 6. User Journeys (MVP)

### 6.1 Artisan onboarding
1. Lands on emakola.com → "Become a verified artisan" CTA.
2. Registers (email + password OR magic-link). Receives phone OTP via Hubtel SMS.
3. Onboarding wizard:
   - **Step 0**: "What do you sell?" → selects "Services" (or "Both").
   - Step 1: Store/profile basics (name, currency, location, WhatsApp number).
   - Step 2: Service category(ies) selection.
   - Step 3: Upload Ghana Card → KYC tier becomes `:ghana_card_verified` after manual review (target: 24h SLA).
   - Step 4: Add first service listing (title, description, price range, area served, photos).
   - Step 5: Theme + share link.
4. Profile is now live in marketplace search; can be found, called, and WhatsApped.

### 6.2 Buyer discovery → contact
1. Buyer lands on emakola.com (root domain — the unified marketplace surface).
2. Searches "plumber in East Legon" or browses category "Home Repairs".
3. Sees ranked list of artisans. Verified artisans rank above unverified; trust badges are visible at a glance.
4. Clicks an artisan → public profile shows services, rates, reviews, response time, verification badges.
5. Taps "WhatsApp" or "Call" → click is logged as a `Lead` → buyer is redirected to `wa.me/...?text=` or to the dialer.
6. (Out of platform) buyer and artisan agree on the job over WhatsApp.

### 6.3 Booking + payment + review (Phase 3 + Phase 4)
1. Buyer returns to the artisan's profile and clicks "Book this service".
2. Submits booking request (date, address, notes).
3. Artisan receives notification (in-app + Hubtel SMS), sends a quote.
4. Buyer accepts → MoMo deposit paid (Hubtel). Funds held in `:pending` state.
5. Job completed → artisan marks `:completed`.
6. Buyer either confirms (funds released) OR has 72h to dispute. If neither, `BookingFundsReleaseWorker` releases automatically.
7. Buyer leaves a review (gated on `:completed` booking).
8. `TrustScoreWorker` recomputes artisan score.

### 6.4 Existing-merchant addition of services
1. Adjoa logs into her admin dashboard.
2. Sees a new banner: "You can now offer services alongside your products."
3. Clicks → onboarding-fork mini-wizard (skip product steps, do verification + service-category selection).
4. Her storefront `/s/adjoa-hair` now has a "Services" tab; she also appears in the unified marketplace under "Beauty".

---

## 7. Functional Requirements

Each requirement is tagged: **[MVP]** = required for launch, **[Post-MVP]** = deferred. MVP requirements are further mapped to the phase that delivers them (P0/P1/P2/P2.5/P3/P4).

### 7.1 Account & Identity

| ID | Requirement | Priority | Phase |
|----|-------------|----------|-------|
| ACC-1 | Buyers and sellers have separate but related accounts (existing `Customer` and `Merchant` actor types). | [MVP] | Existing |
| ACC-2 | Email + password and email magic-link auth (existing). | [MVP] | Existing |
| ACC-3 | Phone OTP verification on first login for new artisan accounts. Hashed OTP at rest, TTL ≤ 10min, max 5 attempts, rate-limited resends. | [MVP] | P1 |
| ACC-4 | Banned-identifier registry (hashed Ghana Card, hashed phone, hashed device-fp, IP) blocks re-registration. | [MVP] | P0 |
| ACC-5 | Account deletion / GDPR-style data export. | [Post-MVP] | — |

### 7.2 Seller Profile & Verification

| ID | Requirement | Priority | Phase |
|----|-------------|----------|-------|
| VER-1 | Sellers have a public profile page showing name, photo/logo, location, services or products, prices, reviews, contact buttons, verification badges, trust score. | [MVP] | P1+P2 |
| VER-2 | KYC tiers: `:phone_only`, `:ghana_card_verified`, `:business_verified`. Tier visible on profile and in search. | [MVP] | P1 |
| VER-3 | Ghana Card upload + manual admin verification. Image stored encrypted (KMS or libsodium), separate S3 bucket from product images, audit-logged reads. Card number hashed. | [MVP] | P1 |
| VER-4 | Business registration upload (optional, unlocks `:business_verified` tier and removes paid-booking caps). | [MVP] | P1 |
| VER-5 | Trade certificate upload (optional, displays as additional badge). | [Post-MVP] | — |
| VER-6 | Verification badges are derived from `Verification` records, not stored separately. | [MVP] | P1 |
| VER-7 | Trust score computed by `TrustScoreWorker`; includes positive (verifications, completed jobs, reviews) and **negative** (cancellations, disputes, complaints, scanner hits) signals. Formula documented in worker `@moduledoc`. | [MVP] | P3 |

### 7.3 Listings (Products & Services)

| ID | Requirement | Priority | Phase |
|----|-------------|----------|-------|
| LST-1 | Sellers can list **products** with photos, prices, quantity, delivery options, payment options (existing). | [MVP] | Existing |
| LST-2 | Sellers can list **services** with title, description, price range (or "quote on request"), area served, availability, photos. | [MVP] | P1 |
| LST-3 | Listing description scanned for phone numbers, MoMo references, and external links. Hits trigger an inline warning to the seller and an `AuditLog` entry. Auto-stripping is **not** done. | [MVP] | P1 |
| LST-4 | Listings carry a status (`:draft`, `:active`, `:archived`) and only `:active` listings appear in search. | [MVP] | P1 |
| LST-5 | A unified `Marketplace.Listing` Postgres view (`UNION ALL` of products + services) backs all marketplace search. | [MVP] | P2 |

### 7.4 Discovery (Search, Marketplace, Categories, Location)

| ID | Requirement | Priority | Phase |
|----|-------------|----------|-------|
| DIS-1 | Unified marketplace surface at root domain (`emakola.com`) coexists with per-store storefronts at `/s/:slug`. | [MVP] | P2 |
| DIS-2 | Marketplace home page shows categories, featured artisans, trust-forward CTAs. | [MVP] | P2 |
| DIS-3 | Search by free-text + city/region + category. Postgres FTS with tsvector + GIN index. | [MVP] | P2 |
| DIS-4 | Search ranking is a configurable weighted sum: text relevance + recency + trust score + boost weight + distance. Weights live in runtime config, not hardcoded. | [MVP] | P2 |
| DIS-5 | Search down-weights `:phone_only` sellers and up-weights verified tiers. | [MVP] | P2 |
| DIS-6 | Public artisan profile page accessible by direct link (`/seller/:slug`) and shareable as the artisan's "mini-website." | [MVP] | P2 |
| DIS-7 | Per-store storefront search (existing) continues to work. | [MVP] | Existing |
| DIS-8 | Location-based "near me" using lat/lng + radius. | [Post-MVP] | — |
| DIS-9 | Emergency-services flag ("plumber available now"). | [Post-MVP] | — |
| DIS-10 | SEO landing pages ("Best plumbers in Accra"). | [Post-MVP] | — |

### 7.5 Communication (lead tracking, in-app chat)

| ID | Requirement | Priority | Phase |
|----|-------------|----------|-------|
| COM-1 | "WhatsApp" and "Call" buttons on every listing route through `/lead/:listing_id?action=...` to log a `Lead` and 302-redirect to `https://wa.me/...?text=` or `tel:`. | [MVP] | P2 |
| COM-2 | Lead-redirect endpoint rate-limited (60/hour/IP) to prevent seller-phone scraping. | [MVP] | P2 |
| COM-3 | In-app chat for buyers and sellers on a booking. Outgoing messages run through `Messaging.Scanner`; off-platform-payment hits show a warning banner and write `AuditLog`. | [MVP] | P3 |
| COM-4 | WhatsApp Business API: official templates, conversation tracking, two-way notifications. | [Post-MVP] | — |

### 7.6 Transactions (Booking, Quote, Payment, Refund, Dispute)

| ID | Requirement | Priority | Phase |
|----|-------------|----------|-------|
| TXN-1 | Buyer can submit a booking request with date, address, notes. | [MVP] | P3 |
| TXN-2 | Booking state machine: `:requested → :quoted → :accepted → :in_progress → :completed → :reviewed | :cancelled`. | [MVP] | P3 |
| TXN-3 | Seller can send a quote on a booking; buyer accepts or counters (counter is text-only at MVP). | [MVP] | P3 |
| TXN-4 | Buyer pays a deposit (or full amount) via Hubtel MoMo on accepted booking. | [MVP] | P4 |
| TXN-5 | KYC-tier gate: payment endpoints reject any booking whose seller is not at least `:ghana_card_verified`. Enforced in the Ash action, not in LiveView. | [MVP] | P4 |
| TXN-6 | Funds held in logical `:pending` state until buyer confirms completion OR 72h elapses post-`:completed` with no dispute. `BookingFundsReleaseWorker` enforces the timeout rule. | [MVP] | P4 |
| TXN-7 | Buyer can file a dispute on a `:completed` booking within 72h → freezes auto-release → admin moderation queue. Resolution is manual at MVP. | [MVP] | P4 |
| TXN-8 | Refund operational path: either manual-refund Oban queue + admin LiveView (Hubtel) or native Paystack refund. Decision in Phase 3 retro. | [MVP] | P4 |
| TXN-9 | Receipts: every successful payment auto-generates a buyer + seller receipt via existing email pipeline. | [MVP] | P4 |
| TXN-10 | Hubtel webhook hardening: idempotency keyed on `gateway_reference`, never re-process. | [MVP] | P4 |
| TXN-11 | Velocity check: 10x typical booking volume in 24h flags `fraud_signals` and pauses payouts. | [MVP] | P4 |
| TXN-12 | Full escrow with held-balance accounting (separate platform-held wallet, automated settlement). | [Post-MVP] | — |
| TXN-13 | Invoices for business buyers. | [Post-MVP] | — |

### 7.7 Reviews & Trust

| ID | Requirement | Priority | Phase |
|----|-------------|----------|-------|
| REV-1 | `Catalog.Review` already exists; eligibility gated on delivered order. Untouched at MVP. | [MVP] | Existing |
| REV-2 | `Bookings.BookingReview` separate resource; eligibility gated on `:completed` booking. Identity constraint: one review per `booking_id`. | [MVP] | P3 |
| REV-3 | Storefront unifies review display via UNION query alongside `Catalog.Review`. | [MVP] | P3 |
| REV-4 | Reviews require a completed transaction. Audit-logged. | [MVP] | P3 |
| REV-5 | Trust score recomputed by `TrustScoreWorker` on review/booking-completion events. | [MVP] | P3 |

### 7.8 Advertising & Boost

| ID | Requirement | Priority | Phase |
|----|-------------|----------|-------|
| ADV-1 | Sellers can pay to boost a listing for a time window (e.g., GH₵50 for 7 days). | [MVP] | P2.5 |
| ADV-2 | Boost weight added to search ranking within active window. | [MVP] | P2.5 |
| ADV-3 | Simple admin LiveView: "Spend GH₵X to reach more customers this week." | [MVP] | P2.5 |
| ADV-4 | Pay-per-lead model. | [Post-MVP] | — |
| ADV-5 | Ad performance dashboard for sellers (views, calls, WhatsApps, bookings). | [MVP] | P4 |
| ADV-6 | AI ad creator (English/Twi/Ga/Pidgin captions). | [Post-MVP] | — |
| ADV-7 | Social-media cross-posting (Facebook, Instagram, TikTok, WhatsApp Status, Google Business Profile). | [Post-MVP] | — |
| ADV-8 | Per-seller QR code. | [Post-MVP] | — |

### 7.9 Notifications

| ID | Requirement | Priority | Phase |
|----|-------------|----------|-------|
| NOT-1 | Hubtel SMS provider wired (currently behaviour stub). Used for OTP, booking notifications, payment confirmations. | [MVP] | P0/P1 |
| NOT-2 | WhatsApp deep-link (`wa.me/...?text=`) for buyer-seller contact. | [MVP] | P2 |
| NOT-3 | Email notifications for booking lifecycle (existing pipeline reused). | [MVP] | P3 |
| NOT-4 | Rate limits on notification dispatch to prevent spam abuse. | [MVP] | P0 |
| NOT-5 | WhatsApp Business API (templates, two-way). | [Post-MVP] | — |
| NOT-6 | In-app push notifications. | [Post-MVP] | — |

### 7.10 Admin & Moderation

| ID | Requirement | Priority | Phase |
|----|-------------|----------|-------|
| ADM-1 | Existing admin dashboard (orders, products, customers, themes, settings) preserved without regression. | [MVP] | Existing |
| ADM-2 | Verification review queue (pending Ghana Card uploads). 24h SLA target. | [MVP] | P1 |
| ADM-3 | Moderation queue surfacing flagged sellers (high cancellation rate, complaints, scanner hits, fraud signals). | [MVP] | P3 |
| ADM-4 | Ban a seller and write to `BannedIdentifier` registry (hashed identifiers). | [MVP] | P3 |
| ADM-5 | Dispute review queue (manual resolution). | [MVP] | P4 |
| ADM-6 | Category management for both products and services. | [MVP] | P1 |
| ADM-7 | Content moderation queue (listings, photos, reviews) with auto-flag on scanner hits. | [MVP] | P1 |
| ADM-8 | Platform-level analytics (active stores, leads, GMV, fraud rate, dispute rate). | [MVP] | P4 |
| ADM-9 | Per-seller analytics (already covered by ADV-5). | [MVP] | P4 |

---

## 8. Non-Functional Requirements

### 8.1 Fraud-Prevention (first-class, non-negotiable)

Fraud-prevention is a non-negotiable invariant alongside tenant isolation and money-as-pesewas. The full operational principles live in `CLAUDE.md`. The PRD-level requirements below cross-reference those principles.

| ID | Requirement |
|----|-------------|
| FRA-1 | Every user-input boundary (listing text, review text, profile bio, message body) treated as attack surface. Validation, sanitization, and pattern scanning at write time. |
| FRA-2 | Off-platform-payment scanner active on all in-app messaging (booking chat, review text). Hits warn the user and write `AuditLog`. |
| FRA-3 | `BannedIdentifier` registry checked at every account-creation and verification-creation action. |
| FRA-4 | Ghana Card numbers, phone numbers, OTPs stored hashed. Plaintext never logged. |
| FRA-5 | Money flow enforced by KYC tier in Ash policies, not LiveView. |
| FRA-6 | Funds release rule: buyer confirmation OR 72h timeout, never seller-controlled. |
| FRA-7 | Audit trail mandatory on every state change in `Booking`, `Payment`, `Verification`, `Lead`, `Review`, `BannedIdentifier`. |
| FRA-8 | Anomaly detection (`AnomalyScanWorker`) populates `SellerProfile.fraud_signals` hourly. |
| FRA-9 | Rate limiting (`Hammer`) at every public entry point. Defaults documented in CLAUDE.md. |
| FRA-10 | Trust score includes negative signals; high-volume seller with 3 complaints scores lower than low-volume seller with zero. |
| FRA-11 | No client-side trust enforcement — server-side authorisation on every action. |

### 8.2 Performance (low-bandwidth focus)

| Metric | Target |
|---|---|
| Marketplace home page Time-to-Interactive on a Moto G7 over 3G | ≤ 4s |
| Search response time (P95) | ≤ 600ms |
| Storefront product page LCP | ≤ 2.5s |
| Image transport | WebP/AVIF, lazy-load below the fold, srcset for responsive loads |
| JS payload | ≤ 100kb gzipped on critical path |
| Server-side rendering via LiveView; minimal client JS |

### 8.3 Security

- TLS everywhere; HSTS enabled.
- CSP — migrate from `'unsafe-inline'` `style-src` to nonced styles (existing TODO).
- Webhook signature verification (Paystack HMAC SHA512 already; Hubtel IP allowlist + HMAC if available).
- Sobelow scan clean each phase.
- Sensitive data encryption-at-rest for Ghana Card images.
- Atom conversion via `Emakola.SafeAtom` only; no `String.to_atom/1` on user input.

### 8.4 Multi-tenancy & data isolation

- Ash attribute-based multitenancy on `store_id` for every tenant-scoped resource.
- Cross-tenant read isolation enforced (recently hardened — see TODO.md residuals for the last 6 test failures).
- Marketplace search reads from a dedicated view that intentionally crosses tenants but is restricted to `:active` listings only.

### 8.5 Privacy & data handling

- Ghana Card images stored in a dedicated S3 bucket/prefix with strict ACL, KMS or libsodium encryption-at-rest, and audit-logged reads.
- Phone numbers and Ghana Card numbers stored hashed; raw values never logged.
- OTPs hashed at rest; never logged; deleted after TTL or successful use.
- User-initiated account deletion is a Post-MVP requirement.

### 8.6 Localization & accessibility

- MVP: English (en-GH) only.
- Currency: GHS (default), NGN ready for Nigeria expansion (deferred).
- Money format: integer minor units (pesewas / kobo); display formatting only in the presentation layer.
- Accessibility: target WCAG 2.1 AA on critical paths (sign-up, search, booking, payment). Audit at end of P2 and P4.
- Twi / Ga / Ewe localization is Post-MVP.

### 8.7 Reliability

- Phoenix release on Fly.io (existing).
- Oban for background jobs with idempotent workers.
- Webhook idempotency keyed on `gateway_reference` (TXN-10).
- Health check endpoint queries DB (existing).
- Target uptime: 99.5% during MVP.

### 8.8 Compliance

- Ghana Data Protection Act compliance for personal data (Ghana Card, phone, address).
- Mobile-money compliance through Hubtel (we are not a licensed financial institution; we operate on top of a licensed partner).
- Receipts stored for both buyer and seller; retention period documented.

---

## 9. Technical Architecture (Summary)

> Full stack details in `CLAUDE.md`. This section is for stakeholders/PMs.

- **Language**: Elixir 1.18+ / Erlang OTP 27+
- **Web**: Phoenix 1.8+ with LiveView (server-rendered, low JS payload)
- **Domain**: Ash 3.x (resources, domains, multitenancy, policies, AshAuthentication)
- **Database**: PostgreSQL 15+ with `tsvector` FTS and a `searchable_listings` UNION-ALL view
- **Background jobs**: Oban (idempotent workers; scheduled jobs for funds-release, anomaly-scan, trust-score)
- **Payments**: Hubtel (MoMo via `paymentChannel`), Paystack (cards + bank). Refund operational path TBD per Phase 3 retro.
- **SMS**: Hubtel SMS (real provider replacing stub in P0/P1)
- **WhatsApp**: deep-link only at MVP; Business API deferred
- **Storage**: S3-compatible. Two buckets/prefixes: product images (existing) and ID documents (new, encrypted).
- **Rate limiting**: Hammer (ETS or Redis backend)
- **Styling**: TailwindCSS v4 with named tokens; mobile-first
- **Observability**: existing logger + AuditLog; consider Telemetry → Grafana post-MVP

### Key new domains introduced for the marketplace expansion
- `Emakola.Services` — `Service`, `ServiceCategory`, `ServiceArea`, `Availability`
- `Emakola.Verification` — `Verification` (kind ∈ [:phone, :ghana_card, :business_reg]); badges derived from records
- `Emakola.Marketplace` — `Listing` (read-only view), `Lead`, `Boost`, `SellerProfile` (1-1 with Store), `BannedIdentifier`
- `Emakola.Bookings` — `Booking`, `Quote`, `BookingReview`
- `Emakola.Messaging` — `Scanner` for off-platform-payment detection

### Architectural decisions made (with reasoning, for context)
- **No polymorphic Listing**. `Catalog.Product` and `Services.Service` stay separate resources with different lifecycles. Unification happens via a Postgres view, not a generic schema. Reason: Spree/Saleor went generic-product and accumulated 60+ NULL-half-the-time fields.
- **`BookingReview` separate from `Catalog.Review`**. Reason: `Catalog.Review`'s identity constraint on `(customer, product)` and `eligible?/3` Ecto join over Orders+LineItem make polymorphism painfully retrofittable.
- **`Trust` is not a domain**. `trust_score` lives on `Marketplace.SellerProfile`; computed by an Oban worker.
- **Lead lives in `Marketplace`, not `Bookings`**. Most leads never become bookings; coupling them corrupts the funnel metric.

---

## 10. Phasing & Timeline

> Full plan: `~/.claude/plans/think-of-the-project-quizzical-boot.md`. Tasks tracked in [TODO.md](./TODO.md).

| Phase | Duration | Outcome |
|---|---|---|
| **P0 — Foundations** | ~1.5 wks | Seller-type branching, FTS infra, document-upload pipeline, fraud infra (rate limits, BannedIdentifier, AuditLog generic helper) |
| **P1 — Services + Verification + Branched Onboarding** | ~3-4 wks | Verified artisan can list services on their store. Phone OTP live. Ghana Card upload + manual review. |
| **P2 — Marketplace Surface + Lead Tracking** | ~2-3 wks | Buyers find artisans cross-store via root-domain search; WhatsApp/call leads tracked. |
| **P2.5 — Boost** | ~3-5 days | Sellers pay to promote listings; first revenue line. |
| **P3 — Bookings (free) + Reviews + SellerProfile** | ~2 wks | Full transactional spine without payment risk. Trust score live. |
| **P4 — MoMo Payment + Analytics** | ~2-3 wks | End-to-end paid bookings. KYC-gated. Dispute placeholder live. |
| Total | ~3 months | MVP shipped. |

Dependencies: P4 depends on P3 (verification gates payment). P2.5 can ship between P2 and P3. P1 and P2 can overlap toward the end of P1.

---

## 11. Success Metrics

### 11.1 Product KPIs (tracked weekly from P2 onwards)

| Metric | Target by month 3 |
|---|---|
| Verified artisans live | ≥ 200 |
| Active product merchants (existing) | preserved (no regression) |
| Marketplace search sessions / week | ≥ 2,000 |
| Leads tracked / week | ≥ 250 |
| Lead → booking conversion | ≥ 8% |
| Bookings reaching `:completed` without dispute | ≥ 70% |
| Average review rating | ≥ 4.0 / 5.0 |
| Repeat-buyer rate (book a 2nd time within 30 days) | ≥ 15% |

### 11.2 Trust & fraud KPIs

| Metric | Target |
|---|---|
| Bookings flagged as fraud | < 1% |
| Banned identifiers preventing re-registration | tracked, growing monotonically |
| Off-platform-payment scanner hits per 1k messages | tracked, declining trend after warnings rolled out |
| Verification SLA (Ghana Card review turnaround) | ≤ 24h P95 |
| Dispute resolution SLA | ≤ 72h P95 |

### 11.3 Revenue KPIs

| Metric | Target by month 3 |
|---|---|
| Listing-boost revenue / month | ≥ GH₵5,000 |
| Paid-booking commission revenue / month | ≥ GH₵2,000 (Phase 4 only) |
| % of artisans who try boost at least once | ≥ 20% |

### 11.4 Engineering KPIs

| Metric | Target |
|---|---|
| Test coverage on new code | ≥ 90% |
| Sobelow scan | 0 critical/high findings |
| P95 marketplace search response | ≤ 600ms |
| LiveView memory per session (idle) | ≤ 100kb |

---

## 12. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Fraud overruns the marketplace before trust signals mature** | High | Existential | Fraud-prevention principles are non-negotiable from P0; rate limits, scanner, banned-identifier registry, KYC gating all live before Phase 4. Strict moderation SLA. |
| **Hubtel refunds remain `:not_supported`** | High | Medium | Decide in Phase 3 retro: build manual-refund Oban queue OR route booking deposits through Paystack. Both are operationally acceptable. |
| **WhatsApp Business API takes 4 weeks per merchant** | Confirmed | Medium | MVP uses deep-link only. Real Business API deferred to Post-MVP; start Meta business verification for Emakola itself in parallel with Phase 1. |
| **Ghana Card verification SLA slips beyond 24h** | Medium | High (kills funnel) | Manual review at MVP; staff up via VA before P1 launch; automate where possible Post-MVP. |
| **Existing product merchants feel disrupted by marketplace pivot** | Medium | Medium | Keep per-store storefronts at `/s/:slug` untouched. Marketplace is opt-in per store. Adjoa-style merchants can stay product-only. |
| **Cross-store search ranking quality is bad at launch** | High | Medium | Externalize ranking weights to runtime config so iteration is cheap. Plan a 4-week tuning sprint after Phase 2. |
| **Hubtel webhook IP changes break payments** | Low | High | Idempotency on `gateway_reference`; alert on signature/IP failure; fall back to polling. |
| **Trust-score formula is unfair to new sellers (cold-start)** | Medium | Medium | Document formula publicly; include "new seller" badge so buyers can opt-in to taking a chance; revisit after 30 days of data. |
| **Long-running marketplace branch accumulates merge conflicts** | High | Medium | Per CLAUDE.md workflow lessons: rebase daily; land in stacked sub-PRs every 2-3 days. |
| **Ghana Data Protection Act compliance gaps** | Medium | High | KMS encryption for ID images, audit-logged reads, account deletion path on roadmap. Engage compliance counsel before paid bookings go live. |

---

## 13. Dependencies & Integrations

| Provider | Purpose | Status | Notes |
|---|---|---|---|
| Hubtel | MoMo payments + SMS | Live (payments), stub (SMS) | Real SMS provider wired in P0/P1. Refund support TBD. |
| Paystack | Card + bank payments | Live | Webhook HMAC SHA512 verified. Possible fallback for booking deposits if Hubtel refund path is too painful. |
| Meta WhatsApp Business API | WhatsApp templates + two-way | Deferred | Phase Post-MVP. Verification per-merchant takes 2-4 weeks. |
| AWS S3 (or DigitalOcean Spaces) | File storage | Live (product images) | Add separate ID-document bucket with KMS in P0. |
| Hammer | Rate limiting | TBD | Add in P0. ETS backend at MVP; consider Redis if multi-node. |
| Fly.io | Hosting | Live | Existing deployment. |
| Hubtel SMS / Twilio | SMS gateway (OTP + notifications) | Stub | Real provider in P0/P1. |
| Ghana Data Protection Commission | Compliance counsel | TBD | Engage before P4. |

---

## 14. Open Questions (Decisions Needed)

| # | Question | Owner | Decision needed by |
|---|---|---|---|
| 1 | Route booking deposits through Hubtel (build manual-refund Oban) or Paystack (native refunds)? | Engineering + Founder | End of Phase 3 |
| 2 | Should we begin Meta Business verification for Emakola itself in parallel with Phase 1 so WhatsApp Business API is ready Post-MVP? | Founder | Start of Phase 1 |
| 3 | Search ranking: hand-tune weights initially, or invest in CTR instrumentation to learn weights? | Engineering | End of Phase 2 |
| 4 | Manual Ghana Card review by Emakola staff or outsource to a verification partner (e.g., Smile Identity)? | Founder | Start of Phase 1 |
| 5 | Pricing for listing boost: flat (GH₵50/week) or tiered? | Founder | End of Phase 2 |
| 6 | Commission rate on paid bookings: percentage, flat, or hybrid? | Founder | End of Phase 3 |
| 7 | Dispute SLA target — 72h good enough or should it be tighter? | Founder + Ops | Start of Phase 4 |
| 8 | Should `:phone_only` sellers be allowed to receive *unpaid* bookings, or blocked entirely until Ghana Card verified? | Founder | End of Phase 1 |

---

## 15. Glossary

| Term | Definition |
|---|---|
| **Artisan** | Seller offering services (plumber, electrician, makeup artist, tutor, etc.). Modeled as a Store with `seller_type: :services` or `:both`. |
| **Boost** | Paid promotion of a listing within search ranking for a time window. |
| **Booking** | A request from a buyer to an artisan for a specific service, with a state machine from `:requested` to `:reviewed`. |
| **KYC tier** | Verification level controlling what a seller can do: `:phone_only`, `:ghana_card_verified`, `:business_verified`. |
| **Lead** | A click on a "WhatsApp" or "Call" button, logged before redirect. Top-of-funnel signal. |
| **Listing** | Read-only Postgres view + Ash resource that unifies products and services for marketplace search. |
| **MoMo** | Mobile money. Refers collectively to MTN MoMo, Telecel Cash, AirtelTigo Money. |
| **Pesewas** | Ghana cedi minor unit; 1 GHS = 100 pesewas. All money stored as integer pesewas. |
| **SellerProfile** | One-to-one with Store; owns `trust_score`, `fraud_signals`, `verification_status`, `boost_balance`. Introduced in Phase 3. |
| **Store** | Multi-tenancy anchor. Existing concept; extended with `seller_type` to support services. |
| **Trust score** | Derived numeric reputation, computed by `TrustScoreWorker`; includes positive and negative signals. |

---

## 16. Appendix A — Full Feature Inventory (50 features, mapped to MVP)

The original strategic vision listed 50 features. The mapping below shows which are MVP, which are Phase-2-or-later, and which are deferred entirely.

| # | Feature | Status |
|---|---|---|
| 1 | User Account | MVP (existing) |
| 2 | Seller / Service Provider Profile | MVP (P1+P2) |
| 3 | Verification System | MVP (P1) |
| 4 | Service Listings | MVP (P1) |
| 5 | Product Listings | MVP (existing) |
| 6 | Search | MVP (P2) |
| 7 | Location-Based Results | Partial MVP (city/region in P2); lat/lng radius Post-MVP |
| 8 | Request A Service ("post a job") | Post-MVP |
| 9 | Quotes / Price Estimates | MVP (P3) |
| 10 | Booking System | MVP (P3) |
| 11 | Calendar For Sellers | Post-MVP |
| 12 | WhatsApp / Call Button (with lead tracking) | MVP (P2 deep-link) |
| 13 | In-App Chat | MVP (P3, on bookings only) |
| 14 | MoMo Payment | MVP (P4 via Hubtel) |
| 15 | Escrow Payment | MVP-lite (P4: 72h hold rule); full escrow Post-MVP |
| 16 | Deposit Payment | MVP (P4) |
| 17 | Receipts And Invoices | MVP receipts (P4); business invoices Post-MVP |
| 18 | Ratings And Reviews | MVP (P3, gated on completed booking) |
| 19 | Seller Trust Score | MVP (P3) |
| 20 | Complaint And Dispute System | MVP placeholder (P4); full workflow Post-MVP |
| 21 | Refund System | MVP (P4) |
| 22 | Emergency Service Option | Post-MVP |
| 23 | Advertising / Boosting | MVP (P2.5) |
| 24 | Pay-Per-Lead Advertising | Post-MVP |
| 25 | Ad Performance Dashboard | MVP (P4 seller analytics) |
| 26 | AI Ad Creator | Post-MVP |
| 27 | Social Media Posting Help | Post-MVP |
| 28 | Seller Storefront Link | MVP (existing per-store storefronts; new public profile in P2) |
| 29 | QR Code For Sellers | Post-MVP |
| 30 | Customer Favorites | MVP (existing wishlist for products); favorites for sellers Post-MVP |
| 31 | Repeat Booking | Post-MVP |
| 32 | Notifications (in-app, SMS, email, WhatsApp) | MVP via SMS+email+WA deep-link (P0-P4); WA Business API Post-MVP |
| 33 | Admin Dashboard | MVP (existing + extensions in P1+P3+P4) |
| 34 | Category Management | MVP (P1) |
| 35 | Content Moderation | MVP (P1+P3 scanner-driven queue) |
| 36 | Fraud Detection | MVP (P0-P4, threaded throughout) |
| 37 | Customer Support | MVP (manual: email + WhatsApp); ticketing Post-MVP |
| 38 | Seller Training | Post-MVP |
| 39 | Creative Services | Post-MVP |
| 40 | Business Verification Badge | MVP (P1, `:business_verified` tier) |
| 41 | Delivery / Dispatch Integration | Post-MVP |
| 42 | Diaspora Booking | Post-MVP |
| 43 | Local Language Support | Post-MVP |
| 44 | Lightweight Mobile App | Post-MVP (mobile-first web at MVP) |
| 45 | Mobile Website | MVP (existing + extended) |
| 46 | SEO Pages | Post-MVP |
| 47 | Analytics For Platform Owners | MVP (P4) |
| 48 | Subscription Plans | Post-MVP (boost only at MVP) |
| 49 | Commission On Completed Jobs | MVP (P4) |
| 50 | Partnerships | Ongoing (Hubtel + Paystack done; rest case-by-case) |

---

## 17. Document History

| Version | Date | Author | Notes |
|---|---|---|---|
| 1.0 | 2026-04-27 | Kojo + AI | Initial PRD consolidating the marketplace expansion plan, fraud-prevention principles, and 50-feature mapping. Replaces ad-hoc planning notes. |
