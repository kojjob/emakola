# Emakola Design Guide

> Based on Google Stitch project: https://stitch.withgoogle.com/projects/9610015930188110254
> We use Stitch layouts/UX patterns but maintain our own Emakola color theme.

---

## Color Theme

### Dark Mode (Admin / Auth Pages)

| Token | Hex | Usage |
|-------|-----|-------|
| Background | `#0c1526` | Page background, body |
| Secondary BG | `#1a2744` | Gradients, panels |
| Sidebar | `#0C1F17` | Admin sidebar |
| Accent Gold | `#d4a843` | Highlights, badges, step numbers |
| Primary Blue | `#2563eb` | Links, focus rings, buttons |
| Emerald Active | `#10B981` | Active nav items, success |
| Text Light | `#f1f5f9` | Primary text on dark |
| Text Muted | `#8896ab` | Secondary/placeholder text |
| WhatsApp Green | `#25D366` | WhatsApp CTA buttons |

### Light Mode (Storefront)

| Token | Hex | Usage |
|-------|-----|-------|
| Background | `#ffffff` / `#f7f8fa` | Page background |
| Dark Text | `#0F172A` | Primary text |
| Secondary Text | `#475569` | Descriptions, metadata |
| Amber Accent | `#B45309` | Category badges, active nav |
| Amber Light BG | `#FEF3C7` | Badge backgrounds, highlights |
| Dark CTA Button | `#1C1917` | "Add to Cart" buttons |
| Category Indicator | `#B45309` to `#F59E0B` | Gradient indicators |

### Typography

- **UI Text**: Inter (weights: 300-700)
- **Numbers/Code**: JetBrains Mono (weights: 400-600)
- **Headings**: Manrope (weights: 600-800)

---

## Screen List (25 Pages)

### Merchant Admin (7 screens)

1. **Admin Dashboard** -- KPIs (GH₵), revenue charts, order snapshots
2. **Product Inventory** -- Grid management of items
3. **Product Editor** -- Forms for creating/editing products
4. **Order List** -- Tracking sales with MoMo/Telecel status
5. **Order Detail** -- Fulfillment and customer data
6. **Customer Directory** -- CRM for the merchant
7. **Settings** -- Store config (WhatsApp, Domain, Payments)

### Customer Storefront (10 screens)

1. **Storefront Home (Desktop)** -- Full-width hero, featured products
2. **Storefront Home (Mobile)** -- Instagram-native style, story categories
3. **Shop Categories (Mobile)** -- Category browsing
4. **Product Detail (Mobile)** -- High-intent layout with MoMo branding
5. **Premium Product Detail (Mobile)** -- Enhanced with artisan stories, heritage sections
6. **Cart Summary (Mobile)** -- Shopping bag summary
7. **Checkout (Mobile)** -- Payment-first flow (MTN/Telecel)
8. **Thank You (Mobile)** -- Post-purchase confirmation
9. **High-Fidelity Storefront** -- Polished storefront version
10. **High-Fidelity Landing Page** -- Marketing-grade landing

### Marketing & Auth (4 screens)

1. **Marketing Landing Page** -- Conversion-focused landing
2. **Multipurpose Landing Page** -- Generic landing template
3. **Authentication (Signup/Login)** -- Split-screen auth
4. **Merchant Onboarding** -- Setup flow

### Logistics (2 screens)

1. **Rider Dispatch** -- Dispatching orders to motorbike riders
2. **Delivery Tracking (Mobile)** -- Customer-facing live tracking

---

## Design Principles

1. **Visual Dominance**: Large, high-res imagery -- artisan craft front and center
2. **Social Proof & Scarcity**: "Limited Edition", "Verified Artisan" badges for trust and urgency
3. **Storytelling**: "Artisan's Signature" section -- human touch, master weaver behind the product
4. **Engagement-Focused UI**: Primary "Add to Cart" + "Buy via WhatsApp" CTAs, high-contrast
5. **Heritage & Care**: "Material & Care" and "Cultural Heritage" sections for product depth
6. **Logistics Transparency**: Clear "Shipping & Returns" with clean iconography
7. **Curated Pairings**: "Complete the Look" cross-sell section
8. **Platform Disappears**: Merchant brand is the star, platform UI is invisible
9. **Mobile-First**: Most storefront screens designed for mobile (West African market)
10. **WhatsApp-First**: WhatsApp buying CTA alongside standard cart

---

## Stitch Reference Colors (DO NOT USE -- reference only)

These are from the Stitch project's generated palette. We override them with our theme above.

- Primary Green: `#059669`
- Secondary Emerald: `#064E3B`
- Tertiary Gold: `#CA8A04`
- Neutral: `#727974`
