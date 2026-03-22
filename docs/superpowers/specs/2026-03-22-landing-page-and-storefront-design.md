# Design Spec: Emakola Landing Page & Storefront

**Date:** 2026-03-22
**Status:** Approved
**Branch:** `feature/phase-1.6-1.7-admin`

---

## Overview

Build two premium frontend experiences for the Emakola West African ecommerce platform:

1. **Platform Landing Page** — Marketing page at `/` targeting merchants. Replaces FounderPad boilerplate in `landing_live.ex`. Warm African Premium style. 9 sections.
2. **Merchant Storefront** — Full customer-facing shopping experience across 6 LiveViews. Hybrid style (dark premium nav + warm amber + light product grid).

---

## Design Language

### Palette
| Token | Value | Usage |
|---|---|---|
| `--stone-900` | `#1C1917` | Dark nav backgrounds, hero sections, featured card |
| `--stone-800` | `#292524` | Secondary dark surfaces, trust bar |
| `--amber-700` | `#B45309` | Primary accent — CTAs, prices, active states |
| `--amber-500` | `#F59E0B` | Highlight accent — badges, stars, gradients |
| `--cream-50` | `#FAFAF9` | Light page background |
| `--surface` | `#FFFFFF` | Cards, product areas |
| `--text-primary` | `#1C1917` | Body headings |
| `--text-secondary` | `#475569` | Body text |
| `--text-muted` | `#78716C` | Labels, metadata |
| `--green-500` | `#22C55E` | Open status dot, success states |
| `--whatsapp` | `#25D366` | WhatsApp CTAs only |

### Typography
- **Display/Brand:** `Cormorant Garamond` serif — store names, hero headlines, featured product titles
- **UI:** `Inter` — all body text, labels, prices, buttons, forms
- **Scale:** 9px (labels) → 52px (hero h1)

### Motion
- **Scroll reveal:** `IntersectionObserver` via Phoenix LiveView `ScrollReveal` hook — `fadeInUp`, `fadeInLeft`, `fadeInRight` at 0.12 threshold
- **Hover states:** `translateY(-4px to -8px)` on cards, `scale(1.03–1.05)` on images, `translateX(4px)` on arrow icons
- **Floating cards:** CSS `@keyframes float` (6s ease-in-out infinite) on hero phone mockup
- **Background glows:** `@keyframes glow-pulse` (4–5s, opacity 0.2–0.35)
- **Micro-interactions:** Add to Bag → "Added!" + green background (1.6s), wishlist heart fill toggle, payment method radio selection, quantity counter increment/decrement

---

## Architecture

### Approach: Component-First + Parallel Agents

**Step 1 — Shared component module:**
Create `lib/emakola_web/components/storefront_components.ex` containing all shared storefront primitives as Phoenix function components:
- `store_nav/1` — dark stone nav with store avatar, name, status, search/wishlist/cart buttons
- `category_circles/1` — horizontal scroll story-style category rings with active gradient state
- `featured_product_card/1` — dark hero card with Cormorant title, amber tag, Add to Bag CTA
- `product_card/1` — 3:4 image, badge, hover heart, name + price
- `promo_banner/1` — dark gradient promotional banner with image
- `about_section/1` — store avatar, description, WhatsApp CTA, location
- `bottom_nav/1` — 4-item tab bar (Home, Search, Saved, Cart)
- `payment_method_option/1` — checkout payment row with radio
- `cart_item_row/1` — cart line item with quantity controls

**Step 2 — LiveView render rewrites (parallel):**
Each LiveView keeps its existing `mount/3` and data-loading functions unchanged. Only `render/1` and component functions are replaced.

---

## Page 1: Platform Landing Page (`landing_live.ex`)

### Structure
All 9 sections rendered in a single LiveView with no layout wrapper (`layout: false`).

| # | Section | Key elements |
|---|---|---|
| 1 | **Nav** | Glass nav, scrolled state via `ScrollGlass` JS hook, logo icon, links, "Start free" CTA |
| 2 | **Hero** | Two-column: left copy + right phone mockup. Badge dot, gradient h1 accent, stat grid, floating revenue + order-confirmed cards |
| 3 | **Trust Bar** | Payment provider logos with SVG icons |
| 4 | **Features** | 6-card grid with amber icon wrappers, hover lift |
| 5 | **How It Works** | 3-step dark section, amber numbered circles, connecting line |
| 6 | **Storefront Preview** | Dark section, left copy + right browser mockup showing a live store |
| 7 | **Payments** | Two-column: copy + 3×2 payment card grid |
| 8 | **Testimonials** | 3 testimonial cards with real Unsplash photos of Black/African people |
| 9 | **Pricing** | 3 plans (Free / GH₵ 49 / GH₵ 99), featured card in amber gradient |
| 10 | **Final CTA** | Full-width amber gradient, large headline with accent span |
| 11 | **Footer** | Logo, copyright "Made in Ghana", links |

### Animations
- Hero copy: `fadeInLeft` 0.8s on mount
- Hero phone: `float` 6s infinite, floating cards: `float-card` and `float-card-2`
- Sections: `ScrollReveal` hook applies `.visible` class triggering CSS transitions
- Nav: `ScrollGlass` hook toggles `.scrolled` class at 40px scroll depth (background + border + shadow)

### Key content
- Headline: "Sell Online. Get Paid with Mobile Money."
- Sub: "Launch your West African store in minutes. Accept MTN MoMo, Vodafone Cash, Paystack and Hubtel."
- Stats: 2,400+ stores · GH₵ 8M+ sales · 99.9% uptime
- Testimonials: Amara Asante (Osu), Kofi Mensah (Kumasi), Esi Boateng (East Legon)
- Pricing: Free forever / GH₵ 49/mo Growth (featured) / GH₵ 99/mo Pro

---

## Page 2: Storefront — Store Home (`store_live.ex`)

Complete rewrite of `render/1`. Business logic (`mount/3`, `load_featured_products/1`, `load_root_categories/1`) unchanged.

### Assigns
| Assign | Type | Initial value |
|---|---|---|
| `store` | `Store.t()` | Loaded from slug |
| `products` | `[Product.t()]` | `load_featured_products(store)` — max 8 |
| `categories` | `[Category.t()]` | `load_root_categories(store.id)` |
| `active_promotion` | `Promotion.t() \| nil` | `nil` (future feature, hidden when nil) |
| `cart_count` | `integer` | `0` |

### Layout
1. `<store_nav>` — dark stone, Cormorant store name, open status dot
2. `<category_circles>` — story rings with active amber gradient
3. `<promo_banner>` — rendered only when `@active_promotion != nil`; dark gradient with collection image
4. `<featured_product_card>` — dark hero card, `List.first(@products)`; hidden when products empty
5. Section heading "Shop All" + see-all link
6. 2-col `<product_card>` grid (2-col mobile → 3-col tablet → 4-col desktop)
7. `<about_section>` — store description + WhatsApp CTA
8. `<bottom_nav>`

---

## Page 3: Product Detail (`product_detail_live.ex`)

### Assigns
| Assign | Type | Initial value |
|---|---|---|
| `store` | `Store.t()` | Loaded from slug |
| `product` | `Product.t()` | Loaded from product slug |
| `selected_variant` | `Variant.t() \| nil` | First variant or `nil` |
| `images` | `[ProductImage.t()]` | `product.images` |
| `wishlisted` | `boolean` | `false` |
| `cart_count` | `integer` | `0` |

### Layout
1. Full-bleed product image (first image, 320px height mobile), swipe dots indicator, back + share overlay buttons
2. Cormorant product name, price row (price + original + savings badge)
3. Description
4. Size/colour variant selector — active state in amber
5. Wishlist + Add to Bag action row
6. WhatsApp order button (full width, green)
7. Delivery meta grid (4 items: delivery estimate, returns, payment, origin)
8. `<bottom_nav>`

### Interactions
- Variant selection: `phx-click="select_variant"` — updates `assigns.selected_variant`
- Add to Bag: `phx-click="add_to_cart"` — JS hook `AddToBag` shows "Added!" text for 1.6s
- Wishlist: `phx-click="toggle_wishlist"` — fills heart SVG, stores in `assigns.wishlist`

---

## Page 4: Product List (`product_list_live.ex`)

### Assigns
| Assign | Type | Initial value |
|---|---|---|
| `store` | `Store.t()` | Loaded from slug |
| `products` | `[Product.t()]` | `load_active_products(store.id, nil, nil)` |
| `categories` | `[Category.t()]` | Root categories |
| `selected_category` | `Category.t() \| nil` | `nil` |
| `search_query` | `string` | `""` |
| `page` | `integer` | `1` |
| `has_more` | `boolean` | `length(products) >= 12` |
| `cart_count` | `integer` | `0` |

### Layout
1. `<store_nav>`
2. Breadcrumb (Store → Category name if filtered)
3. Filter row: category pills (horizontal scroll), search input (debounced 300ms)
4. Product count label ("24 products")
5. 2-col grid → 3-col tablet → 4-col desktop `<product_card>`
6. "Load more" button (or infinite scroll via `phx-viewport-bottom`)
7. `<bottom_nav>`

---

## Page 5: Cart (`cart_live.ex`)

### Assigns
| Assign | Type | Initial value |
|---|---|---|
| `store` | `Store.t()` | Loaded from session/slug |
| `cart_items` | `[CartItem.t()]` | `[]` |
| `subtotal` | `integer` | `0` (minor units) |
| `delivery_fee` | `integer` | `3000` (GH₵ 30 in pesewas) |
| `total` | `integer` | `subtotal + delivery_fee` |

### Layout
1. Dark header "Your Bag" + item count badge
2. Cart item rows — image, name, variant, price, qty +/− controls (`phx-click`)
3. Empty state (if cart empty) — illustration + "Continue Shopping" button
4. Order summary (subtotal, delivery, total)
5. Checkout CTA button
6. `<bottom_nav>`

---

## Page 6: Category View (`category_live.ex`)

Mirrors `product_list_live.ex` with a category filter applied by default from the URL (`params["category_slug"]`). No separate category filter UI — the active category pill is pre-selected based on the slug.

### Layout
1. `<store_nav>`
2. Category header: category name (Cormorant headline), item count
3. 2-col product grid `<product_card>` scoped to the category
4. "Load more" button
5. `<bottom_nav>`

### Assigns
| Assign | Type | Initial value |
|---|---|---|
| `store` | `Store.t()` | Loaded from slug |
| `category` | `Category.t()` | Loaded from `category_slug` param |
| `products` | `[Product.t()]` | Category-scoped list |
| `page` | `integer` | `1` |
| `has_more` | `boolean` | `length(products) >= 12` |

---

## Page 7: Checkout (`checkout_live.ex`)

### Layout
1. Dark header with back button + "Checkout" title
2. 3-step progress (Bag ✓ → Delivery → Payment)
3. Step 2 — Delivery form: name, phone, address, city, region
4. Step 3 — Payment method selection (MTN MoMo, Vodafone Cash, AirtelTigo, Paystack/Card, Cash on Delivery)
5. Order summary sidebar (desktop) / collapsed (mobile)
6. "Place Order · GH₵ X" CTA

### LiveView steps
- `assigns.checkout_step` — `:delivery | :payment | :confirmation`
- `handle_event("next_step", ...)` — validates and advances step
- `handle_event("select_payment", ...)` — updates selected payment method
- Confirmation step shows order reference + WhatsApp notification confirmation

---

## Shared JavaScript Hooks (LiveView)

| Hook name | Purpose |
|---|---|
| `ScrollReveal` | Adds `.visible` to `.reveal` elements on intersection |
| `ScrollGlass` | Toggles `.scrolled` on nav at 40px scroll depth |
| `AddToBag` | Handles "Add to Bag" text swap + color feedback |

All hooks registered in `assets/js/hooks/index.js` and passed to `LiveSocket`.

---

## Images

- **People photos:** Black/African individuals — Unsplash photo IDs confirmed: `1531123897727-8f129e1688ce` (woman), `1504257432389-52343af06ae3` (man), `1488426862026-3ee34a7d66df` (woman), `1506863530036-1efedda3dd8e` (woman)
- **Product images:** African fashion (Kente, Ankara, Batik) — IDs: `1509631179647-0177331693ae`, `1553062407-98eeb64c6a62`, `1515886657613-9f3515b0c78f`, `1469334031218-e382a71b716b`, `1490481651871-ab68de25d43d`
- **Production:** Images will come from `product.images` (Ash loaded association) via `first_image/1` helper. Unsplash used only in prototypes/placeholders.

---

## Files to Create / Modify

### New files
- `lib/emakola_web/components/storefront_components.ex` — shared component module
- `assets/js/hooks/scroll_glass.js` — new (ScrollGlass hook)
- `assets/js/hooks/add_to_bag.js` — new (AddToBag hook)

### Modified files (hooks)
- `assets/js/hooks/scroll_reveal.js` — already exists; verify it works with `.reveal.up/.left/.right/.scale` classes and add if missing
- `assets/js/app.js` — **append** two new hook imports and register `ScrollGlass` and `AddToBag` alongside existing `{ThemeToggle, Analytics, ScrollReveal, AutoDismiss, ThemeSettings}`. Do NOT overwrite existing registrations.

### Modified files
- `lib/emakola_web/live/landing_live.ex` — full render/1 rewrite
- `lib/emakola_web/live/storefront/store_live.ex` — render/1 rewrite using new components
- `lib/emakola_web/live/storefront/product_detail_live.ex` — render/1 rewrite
- `lib/emakola_web/live/storefront/product_list_live.ex` — render/1 rewrite
- `lib/emakola_web/live/storefront/cart_live.ex` — render/1 rewrite
- `lib/emakola_web/live/storefront/checkout_live.ex` — render/1 rewrite
- `lib/emakola_web/live/storefront/category_live.ex` — render/1 rewrite

### Fonts (already in app.css or app.html.heex)
Add Google Fonts: `Inter` (300–900) and `Cormorant Garamond` (500, 600, italic 400)

---

## Testing

All existing tests must pass unchanged (no mount/data-loading logic changes).

New/updated tests required per TDD workflow (write assertions before implementation):

| File | Key assertions |
|---|---|
| `test/emakola_web/live/landing_live_test.exs` | Hero headline renders, "Start free" link present, 3 pricing plans visible, testimonial names present |
| `test/emakola_web/live/storefront/store_live_test.exs` | Existing 14 tests pass, store name renders in nav, category circles render, product grid renders |
| `test/emakola_web/live/storefront/product_detail_live_test.exs` | Product name renders, size variant buttons render, `select_variant` event updates selected state, `add_to_cart` event triggers, WhatsApp button has correct href |
| `test/emakola_web/live/storefront/product_list_live_test.exs` | Products grid renders, search input present, `search` event filters products, category pill click filters results |
| `test/emakola_web/live/storefront/cart_live_test.exs` | Cart items render, empty state renders when cart empty, total calculation correct, checkout button present |
| `test/emakola_web/live/storefront/checkout_live_test.exs` | Step 2 (delivery) renders form fields, `next_step` advances to payment, payment method options all present, `select_payment` updates selected method |
| `test/emakola_web/live/storefront/category_live_test.exs` | Category name renders in header, products scoped to category, load-more button present when `has_more: true` |

---

## Out of Scope

- Backend changes (Ash resources, Ecto migrations, domain logic)
- Authentication / merchant admin pages
- Payment processing integration (UI only, no gateway calls)
- Real WhatsApp API calls from storefront
- Category management LiveView (will use same component system but separate task)
