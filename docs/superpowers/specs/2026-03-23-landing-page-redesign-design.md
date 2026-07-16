# Landing Page Redesign — Design Spec

**Date:** 2026-03-23
**Status:** Approved
**File:** `lib/emakola_web/live/landing_live.ex` (complete rewrite)

---

## Context

The current landing page is a generic SaaS boilerplate ("Ship Your SaaS In Days, Not Months") with no connection to Emakola's actual product: a multi-tenant ecommerce platform for West African merchants and shoppers. This redesign replaces it entirely.

## Audience

Dual-audience: **merchants** (primary, revenue-driving) and **shoppers** (secondary).

## Visual Direction

- **Style:** Clean & trustworthy. Bank-level confidence.
- **Color palette:** Deep Navy & Gold
  - Primary dark: `#0c1526`
  - Secondary dark: `#1a2744`
  - Accent blue: `#2563eb`
  - Gold accent: `#d4a843`
  - Light background: `#f7f8fa`
  - Light border: `#e8eaed`
  - Muted text (dark): `#8896ab`
  - Muted text (light): `#5f6b7a`
- **No emojis.** Use high-fidelity images and quality icons.
- **Icons:** Material Symbols Outlined (the existing landing page icon system). Do not mix with Heroicons on this page.
- **Typography:** Keep existing Manrope (headings), Inter (body), JetBrains Mono (code).
- **CSS Scope:** The Deep Navy & Gold palette is **landing-page-scoped only**. Do NOT modify the existing app-wide design token system (`--fp-primary`, `--color-primary`, etc.) in `app.css` — those power the admin dashboard and all other pages. Instead, define landing-page colors using Tailwind arbitrary values (e.g., `bg-[#0c1526]`) or a small set of scoped CSS custom properties in the `landing_live.ex` template's `<style>` block. The existing "Indigo Slate Protocol" tokens remain untouched.

## Layout: 8 Sections

### 1. Navigation (Sticky)

- Glass effect on scroll (keep existing `ScrollGlass` hook)
- Dark background (`#0c1526`)
- **Left:** Emakola logo
- **Center:** Features, Pricing, How It Works (anchor links)
- **Right:** Login (text link), Get Started (blue CTA button)
- Mobile: hamburger menu — full-screen overlay with dark navy background, slide-down animation, same nav links + CTAs stacked vertically. Close button top-right.
- **No ThemeToggle button** on the landing page nav. The landing page has a fixed dark+light split aesthetic; theme toggle is only relevant for the app (dashboard, admin). Remove the `ThemeToggle` hook from this page.

### 2. Hero (Split Screen)

Full-viewport-height split into two halves. Content within each half is constrained to `max-w-3xl` (centered within the half) for readability, but the background colors are full-bleed edge-to-edge.

**Left half — Merchants (dark navy background `#0c1526`):**
- Label: "FOR MERCHANTS" (gold `#d4a843`, uppercase, tracked)
- Headline: "Launch Your Online Store in Ghana"
- Subtext: "Accept MTN MoMo, Telecel Cash, and card payments. Notify customers on WhatsApp. Manage everything from one dashboard."
- Primary CTA: "Start Selling" (blue `#2563eb` button)
- Secondary CTA: "Watch Demo" (ghost button) — links to `#features` section (scrolls down). Can be updated to a video modal later.
- Payment provider badges below: MTN MoMo, Telecel Cash, Paystack, Hubtel (small bordered cards with names/logos)

**Right half — Shoppers (light background `#f7f8fa`):**
- Label: "FOR SHOPPERS" (blue `#2563eb`, uppercase, tracked)
- Headline: "Shop Trusted Local Businesses"
- Subtext: "Pay with mobile money. Get order updates on WhatsApp. Support local merchants."
- Primary CTA: "Browse Stores" (dark navy `#0c1526` button)
- Mini product cards below: 2-3 sample products with colored placeholder divs (no external images needed — use `bg-[#e2e8f0]` rectangles as image stand-ins), product names, and GHS prices

**Responsive behavior:** On mobile, stack vertically — merchant section on top, shopper section below.

### 3. Trust Bar

- Light background (`#f0f1f4`)
- Centered row: "Trusted by 500+ merchants across Ghana"
- Payment partner logos: MTN MoMo, Telecel Cash, AirtelTigo Money, Paystack, Hubtel
- Use actual brand logos or clean text representations with brand colors

### 4. How It Works

Two sub-sections stacked vertically with a visual separator (horizontal line or spacing — no tabs, no JS interaction needed). Merchants section first, then shoppers.

**For Merchants (3 steps):**
1. Create Your Store — "Sign up and customize your storefront in minutes"
2. Add Products — "Upload products, set prices in GHS, manage inventory"
3. Start Selling — "Share your store link. Accept mobile money. Grow your business."

**For Shoppers (3 steps):**
1. Browse Stores — "Discover local businesses and products"
2. Pay with MoMo — "Checkout securely with MTN MoMo, Telecel Cash, or card"
3. Track Your Order — "Get real-time updates on WhatsApp"

Each step: numbered circle icon + heading + one-line description. Scroll-reveal animation (keep existing `ScrollReveal` hook).

### 5. Features Grid (Bento Layout)

6 feature cards in a 3-column grid (2 large spanning 2 columns + 4 standard single-column):

**Grid layout:**
- Row 1: `[Mobile Money Payments (2-col)] [WhatsApp Notifications (1-col)]`
- Row 2: `[Merchant Dashboard (1-col)] [Multi-Store Management (2-col)]`
- Row 3: `[Inventory Tracking (1-col)] [Shipping & Delivery (1-col)]`

| Feature | Size | Description |
|---------|------|-------------|
| Mobile Money Payments | Large (2-col) | "Accept MTN MoMo, Telecel Cash, and AirtelTigo Money. Automatic payment confirmation and reconciliation." |
| WhatsApp Notifications | Standard | "Order confirmations, shipping updates, and delivery alerts sent directly to your customers on WhatsApp." |
| Merchant Dashboard | Standard | "Track sales, orders, inventory, and customer analytics from a single dashboard." |
| Multi-Store Management | Large (2-col) | "Run multiple stores from one account. Each store gets its own storefront, products, and settings." |
| Inventory Tracking | Standard | "Real-time stock levels. Low-stock alerts. Never oversell again." |
| Shipping & Delivery | Standard | "Set delivery zones, shipping rates, and fulfillment methods for local and nationwide delivery." |

Each card: Material Symbols icon, heading, description, subtle navy border (`border-[#1a2744]`), hover lift effect (`hover:-translate-y-1 transition-transform`). Background: `#f7f8fa`.

### 6. Pricing

4-tier hybrid model displayed as cards in a row.

| Tier | Monthly Fee | Transaction Fee | Key Features |
|------|-------------|-----------------|--------------|
| Starter | Free | 3.5% per sale | 1 store, 25 products, basic dashboard, email support |
| Growth | GHS 29/mo | 2.0% per sale | 1 store, 250 products, WhatsApp notifications, priority support |
| Pro (highlighted) | GHS 79/mo | 1.2% per sale | 3 stores, unlimited products, custom domain, analytics, phone support |
| Enterprise | Custom | Custom | Unlimited stores, dedicated account manager, SLA, API access |

- Pro tier visually highlighted with gold border and "Most Popular" badge
- Each card: tier name, price, transaction fee, feature list, CTA button
- CTA buttons: Starter/Growth/Pro link to `/auth/register`, Enterprise links to a `mailto:sales@emakola.com`
- "All plans include: SSL, mobile money payments, basic analytics"

### 7. Testimonials

3 testimonial cards in a horizontal row (stack on mobile).

Each card:
- 5-star rating (gold `#d4a843` filled stars as SVG icons)
- Quote text (2-3 sentences)
- Merchant name, business name, location (e.g., "Ama Mensah, Ama's Fashion, Accra")
- Profile image placeholder (circular colored div with initials, e.g., `bg-[#1a2744]` with white text "AM")

Use placeholder testimonial content that sounds authentic to Ghanaian merchants.

### 8. Final CTA + Footer

**CTA Section:**
- Dark navy background with subtle gradient
- Headline: "Ready to Grow Your Business?"
- Subtext: "Join 500+ merchants selling online across Ghana"
- Dual CTAs: "Start Selling" (blue) and "Browse Stores" (ghost/outline)

**Footer:**
- 4-column layout:
  - Product: Features, Pricing, Demo, API
  - Resources: Help Center, Blog, Developer Docs, Status
  - Company: About, Careers, Press, Contact
  - Legal: Privacy Policy, Terms of Service, Cookie Policy
- Bottom bar: copyright with dynamic year, social links (GitHub, Twitter/X, LinkedIn as SVG icons)

## Existing Infrastructure to Keep

- `ScrollGlass` hook (glass nav on scroll). Scrolled state on dark nav: add `backdrop-blur-md` + subtle bottom border (`border-b border-[#1a2744]`) + slight background opacity change (`bg-[#0c1526]/95`). No color change, just a depth cue.
- `ScrollReveal` hook (scroll-triggered animations)
- SEO meta tags in mount — update to reflect Emakola's actual product
- `og_image` — needs a new OG image for Emakola branding. For now, keep the existing image path but update alt text. Create a new OG image as a follow-up task.

**Do NOT keep on this page:**
- `ThemeToggle` hook — removed from landing page (see Nav section above). The landing page has fixed dark+light split styling.

**Footer approach:** Create a new `landing_footer` component (or inline the footer in `landing_live.ex`) rather than modifying `public_footer` in `core_components.ex`. The existing `public_footer` is used by other pages and has different styling/links. The landing footer has its own dark navy background and Emakola-specific link structure.

## Existing Infrastructure to Remove

- All generic SaaS boilerplate content
- Generic pricing tiers (Free/$29/$79/$199 with Stripe references)
- Tech stack bar (Phoenix, Elixir, Ash mentions — not relevant to end users)
- Developer experience section ("Three commands. Ship it.")
- AI Agent Orchestration feature references

## SEO Updates

- `page_title`: "Emakola — Online Stores for Ghana | Accept Mobile Money"
- `meta_description`: "Launch your online store in Ghana. Accept MTN MoMo, Telecel Cash, and card payments. WhatsApp order notifications. Join 500+ merchants on Emakola."
- `og_title`: "Emakola — Sell Online in Ghana"
- `og_description`: "The easiest way to create an online store in West Africa. Mobile money payments, WhatsApp notifications, and more."

## Responsive Behavior

- **Desktop (1024px+):** Full split-screen hero, side-by-side sections
- **Tablet (768px-1023px):** Split hero stacks, 2-column grids become single
- **Mobile (< 768px):** Single column throughout, merchant content first, hamburger nav
- Mobile-first CSS approach (most users are on mobile in target market)

## Out of Scope

- Actual marketplace/store browsing functionality. The "Browse Stores" CTA links to `/auth/register` with a query param `?role=shopper` for now. Can be updated to a real browse page later.
- Dark/light theme toggle for the landing page (removed — fixed dark+light split aesthetic)
- Internationalization (English only for now)
- Animation beyond scroll-reveal (no complex JS animations)

## Accessibility Notes

- Gold text `#d4a843` on dark navy `#0c1526` meets WCAG AA for large text (labels, headings) but may not for small body text. Use gold only for labels and decorative accents, never for small body copy. Body text on dark backgrounds uses `#f1f5f9` (white-ish) or `#8896ab` (muted, large text only).
- All icon-only buttons (hamburger menu, close button, social links) must have `aria-label` attributes.
- CTA buttons must have sufficient focus-visible styles: `focus-visible:ring-2 focus-visible:ring-[#2563eb] focus-visible:ring-offset-2`.
