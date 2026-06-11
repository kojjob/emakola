# Landing Page Redesign — Shopify-Inspired, Merchant-First

**Date:** 2026-06-11
**Status:** Approved design, pending implementation plan
**Mockup reference:** `.superpowers/brainstorm/35989-1781173236/content/design-preview-v4.html` (gitignored, session artifact)

## Goal

Replace the current dual-audience landing page (`EmakolaWeb.LandingLive`) with a
merchant-first, story-driven page modeled on Shopify's homepage: one aspirational
narrative, real photography for emotional impact, comprehensive feature coverage,
strong SEO/AI-SEO, and a single conversion goal — merchant signup.

## Decisions (made interactively with mockups)

1. **Merchant-first.** The page speaks to one audience: merchants. Shoppers get a
   "Browse stores" link in the nav and final CTA — no shopper hero.
2. **Dark & gold visual identity.** Keep navy `#0c1526` / gold `#d4a843` brand,
   refined. Light sections (`#f7f8fa`) alternate for rhythm.
3. **Story-driven architecture (Shopify mirror).** No pricing section on the
   landing page.
4. **Pricing moves to a new `/pricing` page** reusing the existing 4-plan grid.
5. **Image-led.** High-fidelity photography carries the page (curated Unsplash
   photos, downloaded and optimized — not hotlinked).
6. **Women-forward imagery.** More women than men (7 women / 2 men across the
   page), reflecting Ghanaian market commerce.
7. **Tall image cards.** Store wall images ~170px, feature-story photos ~240px,
   growth-arc portraits ~180px (desktop).
8. **Fully responsive, mobile-first** — explicit per-section behavior below.
9. **Complete feature coverage** — a features grid presents the full platform,
   including dropshipping, sourced from the actual codebase (no invented features).
10. **SEO and AI-SEO are first-class** — structured data, semantic HTML, an FAQ
    section, and quotable plain-language copy (see SEO section).

## Page Structure (top to bottom)

### 1. Nav (sticky, ScrollGlass hook retained)
Links: How it works (`#how-it-works`), Features (`#features`), FAQ (`#faq`),
Pricing (`/pricing`), Browse stores (`/stores`), Login (`/auth/login`), Get
Started (`/auth/register`). Mobile: hamburger + full-screen overlay (existing
`mobile_menu_open` assign and `toggle_mobile_menu` event retained).

### 2. Hero — full-bleed photo
- Background: market woman carrying goods on her head while on her phone, with
  navy gradient overlay (`rgba(12,21,38,.62) → #0c1526`).
- Eyebrow: `FOR GHANA'S MERCHANTS`
- H1: "Be the next" + **rotating gold word**: "big name in Accra" → "household
  brand" → "MoMo success story" → "market leader".
- Subcopy: "Dream big and sell fast on Emakola. Mobile money payments, WhatsApp
  updates, and a storefront built for Ghana."
- CTA: gold "Start selling — free" → `/auth/register`; microcopy "No credit card
  needed".
- Rotation is **pure CSS keyframes** (no JS hook; survives LiveView DOM diffing).
  Custom CSS lives in `@layer components` in `app.css` per project rule.
  Honor `prefers-reduced-motion: reduce` by disabling the animation (first word
  stays visible).

### 3. Store wall — "Stores built on Emakola"
Four CSS-composed store cards (header with colored dot + store name, tall photo,
price chip), staggered vertical offsets on desktop:
- Mansa Fresh — fruit vendor photo — "Fruit Basket · GHS 75"
- Adwoa Spices — spice seller photo — "Spice Mix Set · GHS 55"
- Efua's Kitchen — egg seller photo — "Fresh Eggs · GHS 40"
- Kojo the Tailor — tailor at sewing machine — "Custom Kaftan · GHS 320"

These are illustrative example stores (same convention as the current page's
testimonial names), not real merchant data. No backend query.

### 4. Feature stories (light section)
Three alternating photo + floating-UI-card rows:
1. **"Get paid in seconds"** — smiling woman photo; floating card: "Payment
   received / + GHS 85.00 · MoMo / ✓ In your wallet". Copy: "MTN MoMo, Vodafone
   Cash, AirtelTigo, and cards. The money lands before the customer hangs up."
2. **"Customers kept in the loop"** — group-around-laptop photo; floating
   WhatsApp bubble: "Order #1042 confirmed! Hi Akosua — your order ships today."
   Copy: "Order confirmations and delivery updates sent on WhatsApp and SMS — no
   extra work for you."
3. **"A storefront that loads fast everywhere"** — bustling market photo;
   floating chip: "🔒 amas-fashion.emakola.com / Loads in 1.2s on 3G". Copy:
   "Built for real Ghanaian networks — light pages, lazy images, works on any
   phone."

### 5. Features grid — "Everything you need to sell" (`#features`)
Nine compact cards (icon + title + one-liner), all backed by real platform
capabilities:

| Feature | One-liner | Backed by |
|---|---|---|
| **Dropshipping & suppliers** | Sell products you don't stock — suppliers fulfill, Emakola tracks costs and settlements | `Emakola.Suppliers`, supplier ledger, dropship fulfillment |
| **Storefront themes** | 14 professional themes, from fashion to pharmacy — switch anytime | `Emakola.Themes` (akoma, atelier, beauty, bold, …) |
| **Digital products** | Sell downloads — files delivered automatically after payment | `Catalog.DigitalFile`, account downloads |
| **Inventory tracking** | Know your stock levels across locations, always | `Emakola.Inventory` |
| **Shipping & delivery** | Zones, rates, and live order tracking across Ghana | `Emakola.Shipping`, `Emakola.Fulfillment`, `/track` |
| **Coupons & discounts** | Run promotions that bring customers back | `Emakola.Marketing.Coupon` |
| **Analytics & reports** | See sales, customers, and trends — export PDF reports | `Emakola.Analytics`, `pdf_report` |
| **Blog & recipes** | Built-in content marketing — publish posts and recipes on your store | `Emakola.Content` (posts, recipes) |
| **Multi-store** | Run several stores from one account and dashboard | `Emakola.Stores` |

Product reviews, customer accounts, wishlists, and the page builder are mentioned
in FAQ/SEO copy but do not get grid cards (nine is the cap — the grid must stay
scannable).

### 6. Growth arc — "From first sale to household name" (`#how-it-works`)
Three portrait cards, START → GROW → SCALE:
- **START** (woman): "From her phone in Makola Market" — Ama listed 12 products
  on a Sunday; first MoMo payment by Wednesday.
- **GROW** (man): "Three stores, one dashboard" — Kwame runs electronics,
  accessories, and repairs from one account.
- **SCALE** (woman, gold-ring card): "Selling across all 16 regions" — Efua's
  Kitchen ships nationwide with delivery zones and order tracking.

### 7. Stats band (darkest navy `#0a1120`)
- **500+** merchants on Emakola (existing claim, carried over)
- **3** mobile money networks
- **Seconds** from checkout to payout

### 8. Launch in 3 steps — "Launch before lunch"
Subcopy: "Most merchants go live in under an hour."
01 Add your first product · 02 Share your store link · 03 Get paid with MoMo.

### 9. FAQ (`#faq`) — also feeds FAQPage structured data
Six questions, accordion on mobile, two-column on desktop. Answers are 2-3
plain-language sentences written to be quotable by search/AI engines:
1. **What is Emakola?** — Emakola is an ecommerce platform for West African
   merchants. You create an online store, accept mobile money payments, and
   manage orders from one dashboard.
2. **How much does Emakola cost?** — Free to start (3.5% per sale), paid plans
   from GHS 29/month with lower rates. Link to `/pricing`.
3. **Can I accept MTN MoMo and Vodafone Cash?** — Yes. MTN MoMo, Vodafone Cash,
   AirtelTigo, and card payments via Paystack and Hubtel.
4. **What is dropshipping on Emakola?** — Sell products your suppliers hold;
   when an order comes in, the supplier fulfills it and Emakola tracks supplier
   costs and settlements automatically.
5. **Can I sell digital products?** — Yes. Upload files; customers get automatic
   download access after payment.
6. **Do customers get order updates?** — Yes, automatically on WhatsApp and SMS:
   confirmations, shipping, and delivery updates.

Accordion uses `<details>/<summary>` (native, no JS, LiveView-safe).

### 10. Final CTA — "Ready when you are"
Market photo (woman in green dress) under navy overlay. Gold "Start selling —
free" + ghost "Browse stores".

### 11. Footer
Reuse existing `landing_footer` component unchanged.

## SEO and AI-SEO

**Structured data (JSON-LD, rendered in `<head>` or page body):**
- `Organization` — name, logo, URL, sameAs (social links from footer).
- `WebSite` — name + URL.
- `SoftwareApplication` — Emakola as a web application, with `offers` (free
  tier + GHS 29/79 plans, `priceCurrency: "GHS"`) and `applicationCategory:
  "BusinessApplication"`.
- `FAQPage` — the six FAQ entries verbatim.
- `/pricing` gets its own `Product`/`Offer` markup for the plans.

**On-page semantics:**
- Exactly one `<h1>` (hero); every section has an `<h2>`; landmarks
  (`<nav>`, `<main>`, `<footer>`); descriptive `alt` on every photo
  ("Market woman in Accra taking an order on her phone", not "hero image").
- Title: "Emakola — Start Selling Online in Ghana | Mobile Money & Dropshipping".
- Meta description mentioning: online store Ghana, MTN MoMo, dropshipping,
  WhatsApp notifications (≤160 chars).
- Canonical URL on `/` and `/pricing`; OG + Twitter card assigns kept.
- Verify `/` and `/pricing` are emitted by the existing `SitemapController`
  (add `/pricing` if missing).

**AI-SEO (answer-engine optimization):**
- FAQ answers and section copy written as self-contained factual statements
  ("Emakola is…", "Emakola supports…") that LLM crawlers can quote directly.
- Stable, descriptive heading text (no pun-only headings without a factual
  subheading nearby).
- All marketing claims on the page must be true of the product (features grid is
  sourced from the codebase, claims table above).

**Performance signals (Core Web Vitals):**
- Hero image preloaded; all below-the-fold images `loading="lazy"`;
  explicit `width`/`height` (or aspect classes) on images to avoid CLS.

## Responsive Behavior (mobile-first)

| Section | Mobile (default) | Desktop (`lg:`) |
|---|---|---|
| Nav | Hamburger + overlay menu | Inline links + CTAs |
| Hero | `text-4xl` headline, photo `bg-cover` with overlay | `text-6xl`, same photo |
| Store wall | Horizontal scroll-snap row (`overflow-x-auto snap-x`), cards `w-64 shrink-0` | 4-column grid with staggered `lg:mt-*` offsets |
| Feature stories | Stacked: photo above text, full width | Alternating 2-column rows (`lg:flex-row` / `lg:flex-row-reverse`) |
| Features grid | 1 column | 3-column grid (`sm:grid-cols-2 lg:grid-cols-3`) |
| Growth arc | Vertical stack | 3-column grid |
| Stats band | 3 columns that wrap to stacked on very small screens (`grid-cols-1 sm:grid-cols-3`) | 3 columns |
| 3 steps | Vertical stack | 3-column grid |
| FAQ | Single-column accordion | Two-column accordion |
| Final CTA | Stacked buttons | Inline buttons |

Floating UI cards on feature-story photos use absolute positioning *inside* the
photo bounds on mobile (no negative offsets that cause horizontal overflow);
negative offsets (`lg:-bottom-3.5 lg:-left-3.5`) apply at `lg:` only.

## Image Manifest

Download from Unsplash (free commercial use, no attribution required), compress,
and commit to `priv/static/images/landing/`. Target ≤ 150 KB per card image,
≤ 300 KB for hero/CTA.

| File | Unsplash photo ID | Slot | Width |
|---|---|---|---|
| `hero-market-woman.jpg` | `1641422162969-3a3d177124d5` | Hero background | 1600px |
| `store-fruit.jpg` | `1773858441336-7a8652acbaf1` | Mansa Fresh | 600px |
| `store-spices.jpg` | `1778079247396-9c0e01c83c8b` | Adwoa Spices | 600px |
| `store-eggs.jpg` | `1762945274836-4c2cbb75e20e` | Efua's Kitchen | 600px |
| `store-tailor.jpg` | `1687422809069-0fa3546b8471` | Kojo the Tailor | 600px |
| `story-momo.jpg` | `1573497019418-b400bb3ab074` | Get paid story | 800px |
| `story-whatsapp.jpg` | `1655720357872-ce227e4164ba` | WhatsApp story | 800px |
| `story-storefront.jpg` | `1773858438654-08abe8814620` | Storefront story | 800px |
| `growth-start.jpg` | `1573497160825-0d94a2724d40` | START card | 600px |
| `growth-grow.jpg` | `1614023342667-6f060e9d1e04` | GROW card | 600px |
| `growth-scale.jpg` | `1563132337-f159f484226c` | SCALE card | 600px |
| `cta-market.jpg` | `1773858440557-cdb7fa2275bb` | Final CTA background | 1600px |

Loading discipline: hero image preloaded (`<link rel="preload">` or eager `img`);
all below-the-fold images `loading="lazy"`. Overlays are CSS gradients so one
image serves all breakpoints.

Old landing images that become unreferenced after the rewrite (`hero-merchant`,
`hero-shopper`, `step-*`, `feature-*`, `product-*`, `testimonial-*`) are deleted
**only after** a grep confirms nothing else references them.

## Technical Shape

- **`EmakolaWeb.LandingLive`** — rewritten in place. Same `/` route,
  `layout: false`, SEO assigns kept with merchant-first copy. `mobile_menu_open`
  assign, `toggle_mobile_menu` event, `ScrollReveal` and `ScrollGlass` hooks all
  retained. JSON-LD rendered via a private function component returning a
  `<script type="application/ld+json">` tag (content built with `Jason.encode!`
  from a map — no string interpolation).
- **`EmakolaWeb.PricingLive`** — new LiveView at `/pricing` in the public
  browser scope, `layout: false`. Pricing grid markup moves over from the
  current landing page unchanged (4 plans: Starter Free/3.5%, Growth GHS 29/2.0%,
  Pro GHS 79/1.2% highlighted, Enterprise custom). Own SEO assigns + Offer
  JSON-LD.
- **`EmakolaWeb.LandingComponents`** — extract the nav into a shared
  `landing_nav` function component (used by Landing and Pricing);
  `landing_footer` already lives here.
- **Custom CSS** — rotating-word keyframes in `app.css` inside
  `@layer components`, with `prefers-reduced-motion` guard. Everything else is
  Tailwind utilities.
- **FAQ accordion** — native `<details>/<summary>`, no JS.
- **No new JS hooks. No new dependencies. No schema/data changes.**

## Error Handling

Static marketing page — no user input beyond the menu toggle and no data
loading. Nothing beyond LiveView defaults.

## Testing (TDD)

1. **Rewrite `test/emakola_web/live/landing_live_test.exs` first** to pin the new
   structure (red), then implement until green:
   - Hero: eyebrow, "Be the next", all four rotating words present in markup,
     single registration CTA, no shopper hero.
   - Nav: links to `/pricing`, `/stores`, `/auth/login`, `/auth/register`;
     ScrollGlass hook present.
   - Store wall: 4 store names + GHS prices; images referenced.
   - Feature stories: 3 headlines + floating-card copy.
   - Features grid: all 9 feature titles render, including "Dropshipping".
   - Growth arc: START/GROW/SCALE + merchant names.
   - Stats band: "500+", "3", payout copy.
   - 3 steps + final CTA copy.
   - FAQ: 6 questions render inside `<details>` elements.
   - JSON-LD: page contains `application/ld+json` scripts for Organization,
     SoftwareApplication, and FAQPage (assert key substrings).
   - **No pricing section on `/`** (refute plan names like "Starter" pricing grid).
   - SEO meta tags updated; footer renders.
2. **New `test/emakola_web/live/pricing_live_test.exs`**:
   - Renders 4 plans with GHS amounts and per-sale rates.
   - Pro plan highlighted ("Most Popular").
   - Nav and footer render; SEO title set; Offer JSON-LD present.
   - Registration CTAs point to `/auth/register`.
3. `mix test`, `mix format --check-formatted`, `mix credo --strict` all clean
   before each commit.

## Out of Scope

- Real merchant data in the store wall (illustrative content, like today).
- Billing/plan enforcement behind the pricing page.
- Translations (gettext) — English only, matching the current page.
- Storefront, dashboard, and supplier pages.
- llms.txt / robots.txt changes (can be a follow-up if desired).
