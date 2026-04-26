# White-Label Design System — Delta vs Original Plan

**Date:** 2026-04-26
**Original plan:** `docs/superpowers/plans/2026-03-28-white-label-design-system.md`

This document captures **what's done**, **what's partially done**,
and **what's left** against the 2026-03-28 plan.

---

## Phase 1: Full Page Coverage

### ✅ Done (more than the plan called for)

- **`Emakola.Themes.ThemeRenderer.theme_render/2`** exists at
  `lib/emakola/themes/theme_renderer.ex` — exactly the dispatcher
  shape the plan described, with `function_exported?` fallback.
- **`Emakola.Themes.ThemeBehaviour`** declares all 15 callbacks
  (3 required + 12 `@optional_callbacks`).
- **All 13 storefront LiveViews** call `ThemeRenderer.theme_render/2`:
  - `cart_live`, `checkout_live`, `blog_list_live`, `blog_post_live`,
    `recipe_list_live`, `recipe_live`, `order_confirmation_live`,
    `tracking_live`, `category_live`, `wishlist_live`, `account_live`,
    `product_detail_live`, `product_list_live`
- **6 themes are wired**: Market, Atelier, Fresh, Bold, Starter,
  Vibrant — each with `home`, `product_list`, `product_detail`
  page renderers (3 themes also have `about`).

### ❌ Not done

- **No `DefaultRenderers` modules**. The plan's directory
  `lib/emakola/themes/default_renderers/` doesn't exist. When a
  theme doesn't implement (e.g.) `:render_cart`, `theme_render/2`
  returns `:default` and the LiveView falls through to its own inline
  template — which works, but the LV's inline render is tightly coupled
  to the merchant's storefront layout and doesn't pick up
  theme-specific colours/fonts as cleanly as a `DefaultRenderers.Shared`
  wrapper would.
- **No `DefaultRenderers.Shared` wrapper** that provides the standard
  navbar + CSS-variable injection + footer for all default-rendered
  pages.

### What we'd need to actually finish Phase 1

Realistic shipping unit (~1 week):

1. Create `lib/emakola/themes/default_renderers/shared.ex` —
   navbar + footer + CSS var injection. Reuses
   `EmakolaWeb.StorefrontComponents` primitives.
2. Create 11 default renderer modules
   (`Cart`, `Checkout`, `BlogList`, `BlogPost`, `RecipeList`,
   `RecipeDetail`, `OrderConfirmation`, `Tracking`, `Category`,
   `Wishlist`, `Account`). Each extracts the LV's current inline
   template into a function component wrapped by `Shared`.
3. Update each LV's `:default` branch to call the corresponding
   `DefaultRenderers.X.render(assigns)` instead of inlining the markup.

Net effect: storefront LVs shrink from 700-1500 lines to ~150 (just
mount + handle_event + a 3-line render that delegates), and all 6
themes can override any page without re-implementing the 80% that's
identical.

---

## Phase 2: Section Editor

### ✅ Done

Nothing concrete — the plan was scoped here.

### ❌ Not done

- No section type registry
- No `home_sections` JSON in `theme_config`
- No drag-and-drop admin UI
- No SortableJS hook

### Recent unrelated work

A **Page Builder Phase 1** landed in commit `e8825bb` (page resource +
block behaviour + 5 starter blocks). That's a separate but conceptually
related effort — it gives merchants standalone "About / Landing /
Custom" pages. The home-section editor in the original plan is
different: it's about the storefront homepage's section composition.

We should **decide** before Phase 2: is the home-section editor
distinct from the page builder, or do we unify them into one
"sections inside any page" abstraction?

---

## Phase 3: Component Variant System

### ✅ Done

- **`Emakola.Themes.DesignTokens`** module exists at
  `lib/emakola/themes/design_tokens.ex`.
- **Atelier footer + navbar consume design tokens** —
  `DesignTokens.footer_style/1`, `heading_font_family/1`,
  `button_classes/1`.

### ⚠️ Partial

Only the Atelier theme's footer + navbar wire DesignTokens through.
The other themes' shared components (Market, Fresh, Bold, Starter,
Vibrant) hardcode their own classes.

### ❌ Not done

- **No `FontLoader`** for Google Fonts URL mapping.
- **No `design_tokens` map in `theme_config`** — merchants can't pick
  variants from the admin yet.
- **No Tailwind safelist** for variant class fragments. Tailwind v4
  CSS-based config doesn't have a `safelist` directive the way v3 did;
  the equivalent is `@source` directives, which already cover
  `lib/emakola/themes`. So this is auto-handled.
- **No Design tab in theme customizer.**

### What we'd need to actually finish Phase 3

1. Extend `DesignTokens` with all 10 dimensions the plan called out:
   button_style, card_style, navbar_layout, product_grid_columns,
   hero_layout, footer_style, product_card_style, typography_scale,
   heading_font, body_font.
2. Add `design_tokens` key to `theme_config`. Default merge happens
   at `ThemeResolver`.
3. Build `FontLoader` — single function:
   `font_url(:cormorant) -> "https://fonts.googleapis.com/css2?family=Cormorant..."`.
   Wire into the storefront layout `<head>`.
4. Refactor *all* theme shared components (not just Atelier) to use
   DesignTokens.
5. Build the Design tab in `lib/emakola_web/live/admin/theme_live.ex`
   — visual variant pickers with iframe previews.

Effort: ~2 weeks across the 6 themes.

---

## Recommended sequencing

**Highest leverage next:** finish Phase 1's `DefaultRenderers`. Reasons:

1. It collapses 7000+ lines of duplicated storefront LV markup.
2. Every other phase becomes easier when there's one canonical
   `Cart`/`Checkout`/etc. shape to override.
3. It's the closest to "fully shippable" — the dispatcher exists,
   themes can already opt in, we just need the fallback library.

**Phase 2 (section editor) decision needed first** — do we unify
with the page builder (e8825bb)?

**Phase 3 (variant system)** — defer until we have a second
merchant requesting customisation we can't already serve via theme
selection. The 6 existing themes already provide significant variety.

---

## Decision required

Three questions for the human reviewer:

1. **Do Phase 1 finish-the-job?** ~1 week of work, very high leverage.
2. **Phase 2 — unify with page builder or keep separate?** Affects
   the data model.
3. **Phase 3 — defer until requested?** Or do we need it for
   marketing/sales reasons?
