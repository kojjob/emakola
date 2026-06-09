# Spotlight Theme — Design Spec

**Date:** 2026-06-09
**Status:** Awaiting approval
**Reference:** https://coctails-gapsy.webflow.io/ ("LIVELY" single-product DTC beverage site)
**Goal:** A new storefront theme **Spotlight** for **single-product stores** — an immersive, photography-forward, long-form landing experience for one hero product, adapted for Emakola (GHS, WhatsApp ordering, real product/variant/review data). A **lighter** interpretation of the dark LIVELY reference: warm off-white backgrounds, big bold display type, one vibrant configurable brand accent, pill CTAs, scroll-reveal motion.

> **Name:** Spotlight. Module `Emakola.Themes.Spotlight`, key `"spotlight"`. **Confirmed.**

---

## 1. Design language (lighter take on LIVELY)

| Token | Value | Use |
|---|---|---|
| `background` | `#FBF9F5` | warm off-white page bg |
| `surface` | `#FFFFFF` | cards |
| `text` | `#16130F` | headings/body (warm near-black) |
| `text_secondary` | `#6B675F` | muted copy |
| `border` | `#ECE7DE` | hairlines |
| `primary` | `#7C3AED` | **accent/CTA** — vibrant violet (merchant-configurable) |
| `primary_dark` | `#6D28D9` | CTA hover |
| `accent_soft` | `#EDE7FB` | section tints, floating blobs behind product |

- **Type:** heading **Archivo** (700–900, big bold display, à la "IN EVERY JAR"); body **Inter**. Loaded via `fonts/0`.
- **Shape:** **pill** CTAs (`rounded-full`); generous spacing; max width 1200–1280px; large rounded product imagery with soft accent blobs behind.
- **Motion:** reuse the existing `ScrollReveal` JS hook (already wired in `app.js`) via `phx-hook="ScrollReveal"` on section wrappers for fade/slide-in on scroll. No new JS.
- Fully **palette-driven** so any single-product brand (drinks, cosmetics, snacks, supplements) can recolour via theme config.

---

## 2. Architecture decision — where the interactive experience lives

Emakola splits data loading: the **home** LiveView (`StoreLive`) assigns `:products` (list), `:categories`, `:cart_count`; the **product** LiveView (`ProductDetailLive`) assigns the full `product` + `variants` + `option_types` + `selected_variant` + `selected_options` + `reviews` + `review_form_*` and handles all the interactive events (`select_option`, `select_image`, `increment/decrement_quantity`, `add_to_cart`, `submit_review`, `share-product`).

**Therefore:**
- **`render_product_detail` (Spotlight.ProductDetail) is the CENTERPIECE** — the full immersive single-product page with the real, interactive buy flow. This is the "match or beat LIVELY" page. It has every assign and event it needs with **no changes to `ProductDetailLive`**.
- **`render_home` (Spotlight.Home)** is an immersive **marketing landing** that showcases the store's hero product (first of `@products`) — big hero, benefits, ingredients, testimonials, statement, newsletter — and **funnels** to the product page: its primary CTAs (“Choose the taste”, “Shop now”) link to `/s/<slug>/products/<hero_product.slug>`. (No `StoreLive` changes; it only reads `@products`.)
- **`render_product_list` (Spotlight.ProductList)** — a simple Spotlight-styled grid (for stores that list a few products). Reads `@products`.

This delivers the single-product-website feel (home → the one product page, which is the rich interactive experience) while staying within each LiveView's existing data contract. **No shared infrastructure changes.**

> **Decision to confirm:** the home funnels to the product page rather than embedding the live buy flow inline. (Embedding the live variant-select/add-to-cart on the home would require modifying `StoreLive` to load the hero product's variants/options/reviews — shared infra, out of scope for v1.)

---

## 3. Content sourcing (data-driven, not static)

Spotlight reads editorial content from the **resolved `@theme`** (merchant-editable via `theme_config`, deep-merged by `ThemeResolver`) wherever a resolver key exists, and from the product for transactional data:

| Section | Source |
|---|---|
| Hero headline / tagline / overline / CTA / badge | `@theme.hero` (+ new keys in `defaults().hero`) |
| Benefits (4 icon features — "Explore pure balance") | `@theme.trust.items` (already resolved & editable) |
| Statement quote + CTA | `@theme.closing_cta` (resolved & editable) |
| Testimonials (avatar + quote cards) | `@theme.testimonials` (resolved & editable) |
| Newsletter | `@theme.newsletter` (resolved & editable) |
| **Ingredients** ("N active ingredients") | `Emakola.Themes.Spotlight.ingredients/0` — content lives in the theme module (see note) |
| Hero product image / title / price | the product (`selected_variant.price` / `product.min_price`, `product.images`) |
| **"Choose the taste"** selector | the product's `option_types` / variants (real `select_option`) |
| Star rating + reviews | `product.avg_rating`, `product.review_count`, `ReviewComponents.review_section` |

> **Ingredients note:** `ThemeResolver.resolve/2` only deep-merges a fixed set of top-level keys, so a brand-new `ingredients` key in `theme_config` would not reach the template. For v1, ingredients content is a **theme-default** returned by a module function `Spotlight.ingredients/0` (rendered, looks complete, but not yet admin-editable). Making it merchant-editable later is a small additive change to `ThemeResolver` — explicitly deferred. The same applies to any hero overline/badge fields not already in the resolved `hero` map: read them from `Spotlight.defaults().hero` via a helper if the resolver doesn't carry them. (Implementation note: prefer keys the resolver already carries; only fall back to `defaults()` for genuinely new fields.)

---

## 4. The centerpiece — `Spotlight.ProductDetail` (single-product page)

Pure `Phoenix.Component`. Declares the standard product_detail attrs (store, theme, product, related_products, categories, cart_count, selected_variant, option_types, selected_options, quantity, current_image_index) and reads optional review/upload assigns via **Access** (`assigns[:reviews]`, etc.) so the shared `product_detail_variants_test.exs` (which omits them) never raises — the same proven pattern Akoma uses.

Sections (top → bottom), each wrapped for `ScrollReveal`:

1. **Sticky nav** (`Spotlight.Shared.nav`) — wordmark, anchor links (Product / Benefits / Ingredients / Reviews), cart link with count.
2. **Hero** — warm bg with soft accent blobs; overline (e.g. "Relaxation"), huge Archivo display headline (`product.title` or `hero.title`), tagline, **price** (`Currency.format_price`), primary pill CTA "Add to cart" (`phx-click="add_to_cart"`) + secondary "Order on WhatsApp" (`wa.me`), "100% Organic"-style badge; large product image (`current_image` + thumbnails via `select_image`) floated with accent blob. Star rating → `#reviews`.
3. **Benefits** ("Explore pure balance") — 4 icon cards from `@theme.trust.items` (`material-symbols` icons).
4. **Statement** — centered big quote from `@theme.closing_cta` + pill CTA scrolling to the buy section.
5. **Ingredients** ("N active ingredients for your balance") — grid from `Spotlight.ingredients/0` (name + description).
6. **Choose the taste / Buy** — the **variant/option selector** (pills, real `select_option` contract: `phx-value-option_type_id`/`phx-value-value`, selected via `Map.get(@selected_options, option_type.id) == option_value.id`), qty stepper, stock status, **Add to cart** + **WhatsApp**. (This is the transactional anchor the statement/hero CTAs scroll to.)
7. **Testimonials** — avatar + quote cards from `@theme.testimonials` with a star row.
8. **Reviews** (`#reviews`) — `ReviewComponents.review_section` gated by `:if={assigns[:reviews] != nil}`, passing review_* assigns via Access (Akoma pattern).
9. **Footer** (`Spotlight.Shared.footer`).

**Cart:** "Add to cart" uses the existing `add_to_cart` event and updates the nav cart count; a lightweight "added → View cart" affordance links to `/s/<slug>/cart`. A full LIVELY-style slide-out cart **drawer** is **out of scope** for v1 (would need cart-contents data not assigned on the product page).

---

## 5. `Spotlight.Home` (marketing funnel)

Reads `@products` (and `@cart_count`). Derives `hero_product = List.first(@products)` (guard for empty). Sections: hero (hero_product image/title/price + "Choose the taste" CTA → `/s/<slug>/products/<hero_product.slug>`), benefits (`@theme.trust`), ingredients (`Spotlight.ingredients/0`), testimonials (`@theme.testimonials`), statement (`@theme.closing_cta`), newsletter (`@theme.newsletter`), footer. All optional sections gated by `section_enabled?(@theme, key)` (the per-theme private helper pattern used by Heritage/Fresh/Akoma). Empty-products state: a tasteful "Coming soon" hero.

---

## 6. `Spotlight.ProductList`

Spotlight-styled responsive grid of `Spotlight.Shared.product_card` over `@products`, with nav + footer and an empty state. (Most Spotlight stores have one product, but the page must be valid and pleasant.)

---

## 7. Module / file plan

- Create `lib/emakola/themes/spotlight.ex` — behaviour, `defaults/0` (palette + hero + trust(4) + testimonials + closing_cta + newsletter + sections + css_variables), `fonts/0`, `ingredients/0`, delegates.
- Create `lib/emakola/themes/spotlight/shared.ex` — `theme_styles/1` (CSS vars + `.spot-*` classes + ScrollReveal-friendly base styles), `nav/1`, `footer/1`, `product_card/1`, image + WhatsApp helpers, `section_enabled?/2`.
- Create `lib/emakola/themes/spotlight/product_detail.ex` — the centerpiece (§4).
- Create `lib/emakola/themes/spotlight/home.ex` — §5.
- Create `lib/emakola/themes/spotlight/product_list.ex` — §6.
- Modify `lib/emakola/themes/theme_resolver.ex` — register `"spotlight"`.
- Modify `lib/emakola_web/live/admin/theme_live.ex` — add picker entry (`@theme_metadata`).
- Modify `test/emakola/themes/product_detail_variants_test.exs` — add `{Emakola.Themes.Spotlight, "spotlight"}`.
- Create `test/emakola/themes/spotlight_test.exs` — resolver/contract + render tests for all three pages + the option-selector contract + Decimal-rating safety.

**Reuse:** `StorefrontComponents.optimized_image`, `ReviewComponents.review_section`, `Currency.format_price`, the `ScrollReveal` hook.

---

## 8. Testing plan (TDD)

Modeled on `spotlight_test.exs` ≈ the Akoma test suite:
1. Resolver resolves `"spotlight"` with the light palette + accent.
2. Behaviour contract (name/css_variables/render_* exported); css_variables keys.
3. ProductDetail render: title, price, option pills (correct `select_option` contract), Add-to-cart, WhatsApp link, benefits, ingredients, testimonials, reviews section; renders without raising when review assigns absent (variants-test shape) and with them present; handles `%Decimal{}` `avg_rating`.
4. Home render: hero product title + a CTA linking to the product page; section toggle (disable newsletter → hidden).
5. ProductList render: grid of products + empty state.
6. Add `{Emakola.Themes.Spotlight, "spotlight"}` to the all-themes variants test.

≥90% coverage on new modules; all pure-template render assertions.

---

## 9. Out of scope (v1)
- Subscription / "monthly plan" purchases (Emakola has no recurring billing) — one-time purchase + quantity + WhatsApp only.
- Full slide-out cart drawer with line items (cart contents aren't assigned on product/home pages).
- Admin-editable `ingredients` (theme-default for now; resolver extension deferred).
- No changes to `StoreLive` / `ProductDetailLive` / any Ash resource.

---

## 10. Resolved decisions
1. **New separate theme** "Spotlight"; Akoma untouched.
2. **Lighter take** — warm off-white + vibrant configurable accent (default violet `#7C3AED`), big Archivo display, pill CTAs, scroll-reveal motion.
3. **Centerpiece = `render_product_detail`**; home funnels to it; product_list is a simple branded grid.
4. **One-time purchase** + qty + WhatsApp; no subscriptions; no full cart drawer (v1).
