# Akoma Theme — Design Spec

**Date:** 2026-06-09
**Status:** Awaiting approval
**Goal:** Add a new storefront theme, **Akoma**, whose centerpiece is a beautiful, modern single-item (product detail) page modeled on Shopify's *Be Yours* theme, adapted for Emakola (GHS pricing, WhatsApp ordering, mobile-first / low-bandwidth). The theme is a full, registerable, selectable theme with home, product list, and product detail pages.

> **Name note:** "Akoma" (an Adinkra symbol — the heart; patience, goodwill) is a placeholder identity. Trivially renameable before implementation — say the word.

---

## 1. Design direction (validated visually)

Clean, modern, minimal, sans-serif, whitespace-led — the *Be Yours* aesthetic. The PDP is a two-column layout: a large sticky media gallery on the left, product details on the right, with collapsible info accordions, an inline reviews section, a "Pair it with" complementary row, and a sticky add-to-cart bar.

### Palette — **Forest**
Neutral off-white base + near-black text + a deep-green accent. Primary CTAs stay near-black for a premium minimal feel (à la Be Yours); the forest green is the accent on prices, links, swatch/selection outlines, in-stock indicators, and small highlights.

| Token | Value | Use |
|---|---|---|
| `primary` | `#1A1A1A` | CTA buttons, headings, brand wordmark |
| `accent` | `#2F5D50` | prices, links, selected option outline, in-stock dot, badges |
| `accent_dark` | `#264B41` | accent hover |
| `background` | `#F8F9F7` | page background |
| `surface` | `#FFFFFF` | cards, gallery, sticky bars |
| `text` | `#1A1A1A` | body text |
| `text_secondary` | `#6B7280` | muted/meta text |
| `border` | `#E8EAE7` | hairlines, dividers, accordions |
| `sale` | `#B91C1C` on `#FDE2E2` | sale/save badge |
| `success` | `#16A34A` | "Only N left" / "In stock" |
| `whatsapp` | `#25D366` / `#128C3A` | WhatsApp order button |

### Typography
- **Heading:** Manrope (600/700/800) — geometric, modern.
- **Body:** Inter (400/500/600).
- Loaded via the theme's `fonts/0` Google Fonts URL (both already used elsewhere in the app).

### Design tokens / shape
- Button & input radius: 6px (clean, slightly soft — not pill, not sharp).
- Generous spacing; max content width 1280px.

---

## 2. Key tradeoff to confirm — option selectors

`Emakola.Catalog.OptionValue` stores only `value` (string) + `position`; **there is no color/hex attribute**, and no existing theme renders true color swatches. Therefore:

- **Decision (default):** Render **all** option types (Size, Color, Material, …) as **pill buttons**. Selected = forest outline/fill; unavailable/out-of-stock = struck-through & disabled. Universal, clean, matches Be Yours' size-pill treatment.
- The circular color swatches shown in the mockup were illustrative.
- **Optional enhancement (not in default scope):** a small name→hex heuristic (e.g. "Black", "Sand", "Forest" → swatch circles) for option types named "Colour/Color". Fragile and partial; only worth it if you want it. *Flag for user.*

---

## 3. Architecture & file plan

Follows the existing theme pattern exactly (see `Emakola.Themes.Heritage`).

**New files:**
- `lib/emakola/themes/akoma.ex` — main module. `@behaviour Emakola.Themes.ThemeBehaviour`. Implements `id/0`, `name/0`, `fonts/0`, `defaults/0`, `css_variables/0`, `renderer/1`, and `defdelegate render_home/1`, `render_product_list/1`, `render_product_detail/1` to sub-modules.
- `lib/emakola/themes/akoma/shared.ex` — `theme_styles/1` (injects `:root` CSS vars + theme classes), `akoma_nav/1`, `akoma_footer/1`, and helpers (`current_image/2`, price/compare-at helpers, accordion markup).
- `lib/emakola/themes/akoma/product_detail.ex` — **the centerpiece** (see §4).
- `lib/emakola/themes/akoma/home.ex` — homepage (see §5).
- `lib/emakola/themes/akoma/product_list.ex` — collection/shop grid (see §6).

**Modified files:**
- `lib/emakola/themes/theme_resolver.ex` — add `"akoma" => Emakola.Themes.Akoma` to `@theme_modules`.
- Any other theme registry/catalog (e.g. the admin theme picker list). *Implementation step: grep for the full theme list — `"heritage"`/`Heritage` across `lib/` — and register Akoma everywhere it's enumerated so it's selectable in admin.*

**No changes to `ProductDetailLive`, `ProductListLive`, `StoreLive`, or any Ash resource.** The theme is pure presentation; all data-loading and events already exist.

---

## 4. Product detail page (centerpiece) — `Akoma.ProductDetail`

Pure `Phoenix.Component` template. Declares the same `attr`s as other themes' product_detail modules (`store, theme, product, related_products, categories, cart_count, selected_variant, option_types, selected_options, quantity, current_image_index, reviews`, plus review-form assigns).

**Every interactive element maps to an existing `ProductDetailLive` event — no new LiveView code:**

| UI element | Existing event / mechanism |
|---|---|
| Thumbnail click / prev / next | `select_image`, `prev_image`, `next_image` (`current_image_index`) |
| Option pill select | `select_option` (`selected_options` → `selected_variant`) |
| Quantity − / + | `decrement_quantity` / `increment_quantity` |
| Add to cart | `add_to_cart` |
| Star rating in review form | `set_review_rating` |
| Submit review | `submit_review` |
| Share | `share-product` |
| Accordions | `Phoenix.LiveView.JS.toggle` (client-only; no CSS-checkbox per CLAUDE.md) |
| WhatsApp order | plain `<a href="https://wa.me/{store.whatsapp_number}?text=…">` (no event) |
| Sticky mobile bar | CSS `fixed bottom-0 lg:hidden` (no JS) |

**Layout (desktop, two-column under a breadcrumb):**

1. **Breadcrumb** — Marketplace / Collection / Title.
2. **Gallery (left, ~55%)** — vertical thumbnail rail + large main image (`aspect-[3/4]`), SALE badge when `compare_at_price` present. Uses `optimized_image` + `Shared.current_image/2`.
3. **Info column (right, sticky `lg:sticky lg:top-24`):**
   - Store name (uppercase, muted).
   - Title (Manrope, ~26px).
   - Rating + review count → links to `#reviews` (reuse `ReviewComponents.star_display` / `review_summary`).
   - Price block: `Currency.format_price(selected_variant.price, store.currency)`; compare-at strikethrough + "Save X%" badge when applicable.
   - Short description (truncated `product.description`).
   - Option selectors (pills, §2), with selected value shown in each label.
   - Quantity stepper + stock status (`selected_variant.stock_quantity`: "Only N left" / "In stock" / "Out of stock" → disables CTA).
   - **Add to cart** (near-black, full-width) + **Order on WhatsApp** (secondary, green outline).
   - Accordions: **Description** (open), **Delivery & returns**, **Materials & care** (JS.toggle).
   - Trust row: secure checkout · MoMo/Paystack · local delivery (reuse `trust_badges_strip` or inline).
   - Share strip (reuse `share_strip`).
4. **Sticky add-to-cart bar** — mobile: fixed bottom (thumbnail + price + Add). Desktop: handled by the sticky info column.
5. **"Pair it with"** — `related_products` rendered with `Shared` product cards / `StorefrontComponents.product_card`.
6. **Reviews (`#reviews`)** — summary with rating-distribution bars + list (reuse `ReviewComponents.review_section`) + the existing review form (rating, title, body, photo upload) gated by `can_review` / `already_reviewed`.

**Mobile:** single column — full-bleed swipeable gallery → title/price → pills → accordions → reviews; sticky Add-to-cart bar pinned to the bottom of the viewport.

---

## 5. Home page — `Akoma.Home`

Clean, whitespace-led, same type/colour system. Sections driven by `theme.sections` flags and `theme.hero` / `theme.trust` / `theme.newsletter` config (same shape as Heritage):
- Hero: large image + headline + single CTA (minimal, no carousel by default).
- Featured products grid (reuse `product_card` / `featured_product_card`).
- Category circles (reuse `category_circles`).
- Trust badges strip.
- Newsletter band.
- `Shared.akoma_nav` + `Shared.akoma_footer`.

Not over-built — these reuse `StorefrontComponents` and theme config; the PDP is where the detail goes.

---

## 6. Product list — `Akoma.ProductList`

Clean responsive grid of `product_card`s on the off-white base, minimal sort control, optional category filter pills, `akoma_nav` + `akoma_footer`. Matches PDP styling.

---

## 7. Reuse vs. new

**Reuse (no changes):** `StorefrontComponents` (`optimized_image`, `product_card`, `featured_product_card`, `share_strip`, `wishlist_heart`, `category_circles`, `trust_badges_strip`), `ReviewComponents` (`star_display`, `review_summary`, `review_section`), `EmakolaWeb.Helpers.Currency.format_price/2`.

**New (theme-local):** Akoma nav/footer, gallery layout, pill option selectors, JS accordions, sticky mobile bar, the `defaults/0` token map + `theme_styles/1`.

---

## 8. Testing plan (TDD — write first)

Modeled on `test/emakola/themes/theme_renderer_test.exs`, `product_detail_variants_test.exs`, `theme_resolver_test.exs`.

1. **Resolver:** `ThemeResolver.resolve(%{"theme" => "akoma"})` → `theme_id: "akoma"`, `theme_name: "Akoma"`, Forest colours present.
2. **Behaviour contract:** `Akoma` exports `name/0`, `css_variables/0`, `render_home/1`, `render_product_list/1`, `render_product_detail/1`; `css_variables` has `--theme-primary`/`--theme-accent`/`--theme-bg`. (The existing `default_renderer_consistency_test` / `theme_renderer_test` also enforce all-theme consistency once registered.)
3. **PDP render (LiveView):** mount `/s/:slug/products/:product_slug` with a store on the Akoma theme → asserts title, formatted price, option pills, **Add to cart**, **Order on WhatsApp** (correct `wa.me` link), stock status, accordions, and `#reviews` all render; out-of-stock variant disables the CTA.
4. **Home & list render:** smoke tests that both mount and render featured products / grid without error.
5. **Variant selection:** reuse the `product_detail_variants` pattern — selecting an option updates the displayed price/variant.

Target ≥90% coverage on new modules (per project rule). All pure-template, so tests are render assertions.

---

## 9. Out of scope / assumptions

- No changes to checkout, cart, account, blog, recipe pages — Akoma inherits `DefaultRenderers` for unimplemented optional callbacks (and may `defdelegate render_about` like Heritage does, optional).
- No new Ash attributes or migrations.
- Color **swatches** deferred (see §2); pills ship by default.
- Admin theme-customizer overrides work automatically via the standard `defaults/0` + `ThemeResolver` deep-merge.
- "Pair it with" uses the existing `related_products` (6 random active products); a curated complementary-products feature is out of scope.

---

## 10. Open questions for the user

1. **Theme name** — keep "Akoma", or pick another?
2. **Color swatches** — pills-for-everything (default), or add the name→hex heuristic for colour options?
3. **Scope reminder** — "Full theme" confirmed: PDP (full detail) + Home + Product list, all in this style.
