# Design Studio — Make It True

**Date:** 2026-07-25
**Status:** Audit complete; first fix landed (`d76689c6`), remainder needs a
product decision from Kojo.

## 1. The problem

`EmakolaWeb.Admin.DesignLive` renders its live preview through
`Emakola.Themes.DesignTokens`. The storefront renders independently. Nothing
ties them together, so a control can move the preview and change nothing on
the real shop.

A merchant sets "4 columns, bordered cards, centered navbar", watches the
preview change, saves successfully, opens their storefront — and it is
identical. That is worse than a missing feature: a missing feature is honest.
This one shows the change, confirms the save, and silently discards it, and
it is invisible to testing because the preview agrees with the merchant.

## 2. Verified state of all ten controls

Measured by call-site grep across `lib/`, not inferred.

| Control | Mechanism | Effect |
|---|---|---|
| `heading_font` | `--dt-heading-font`, global `!important` on `h1..h6`, **83** theme references | ✅ every theme |
| `body_font` | `--dt-body-font`, global rule on text elements | ✅ every theme |
| `typography_scale` | **fixed 2026-07-25** — `:root { font-size }` | ✅ every theme |
| `button_style` | `.dt-btn` CSS rule + Atelier's `button_classes/1` | ⚠️ Atelier only |
| `footer_style` | `footer_style/1` in `atelier/footer.ex` | ⚠️ Atelier only |
| `card_style` | none | ❌ dead |
| `navbar_layout` | none | ❌ dead |
| `product_grid_columns` | none | ❌ dead |
| `hero_layout` | none | ❌ dead |
| `product_card_style` | none | ❌ dead |

**`.dt-btn` has zero consumers.** `storefront.html.heex` defines
`.dt-btn { border-radius: var(--dt-btn-radius) !important }` and not one of
the 21 themes puts that class on anything. The hook was built and never
applied — which is why `button_style` moves the preview and only Atelier's
storefront.

## 3. What was fixed, and why only that one

`typography_scale` was the only dead control fixable without touching all 21
themes. `heading_size/1` and `body_size/1` returned Tailwind classes no theme
applies. A root font-size does the same job globally, because every theme
sizes type *and* spacing in rem — and proportional scaling is what the control
means: its options carry density icons (`density_small`/`medium`/`large`), so
"Compact" asks for a tighter page, not merely smaller headings.

Guarded: emitted only when the merchant leaves the default, and
`root_font_size/1` pattern-matches to hardcoded values with a `nil`
fall-through, so a merchant-writable `theme_config` string cannot reach the
`<style>` block. `design_tokens_reach_storefront_test.exs` covers both, plus
an injection attempt.

## 4. The remaining five, and why they are a product decision

`card_style`, `navbar_layout`, `product_grid_columns`, `hero_layout` and
`product_card_style` are **structural**. They cannot be expressed as a global
CSS variable the way fonts and density can — each needs per-theme markup:

- `card_style` / `product_grid_columns` could be done with class hooks
  (`.dt-card`, `.dt-product-grid`) applied in all 21 themes. Mechanical, ~21
  edits each, visually verifiable.
- `navbar_layout`, `hero_layout`, `product_card_style` need genuine
  alternate layouts per theme. That is 21 × 3 variants — a project, not a
  task, and arguably fights each theme's identity: a merchant who chose
  Atelier for its editorial hero probably should not be able to swap it for
  a split hero.

**Three options, and the decision is Kojo's:**

1. **Wire the two tractable ones** (`card_style`, `product_grid_columns`) via
   class hooks; **cut** the three structural ones from the UI.
2. **Cut all five.** Smallest, immediately honest, loses nothing that
   currently works.
3. **Build all five per theme.** Largest by far; questionable value.

Recommendation: option 1. Note that `.dt-btn` should be applied across the 21
themes at the same time, which makes `button_style` real as a side effect.

## 5. Independent of the above: stop the preview from being able to lie

The durable fix is architectural. Replace `DesignLive`'s hand-built preview
with an **iframe of the real storefront**, rendered with the unsaved tokens
applied. The preview then cannot drift, because it *is* the storefront — and
any control that does nothing becomes visibly obvious to the merchant and to
us, instead of being hidden behind a second implementation that happens to
agree.

This is worth doing regardless of which option in §4 is chosen, and it is what
would have prevented the whole class of defect.

## 6. Also open (not started)

- **Information architecture.** Three pages, 3,233 lines, overlapping jobs:
  `/admin/theme` (theme picker, colours, hero image, section toggles),
  `/admin/design` (components, typography, preview),
  `/admin/design/sections` (home section editor). Hero *image* lives in
  Theme; hero *layout* in Design Studio. Colours — the thing merchants most
  want — are absent from the Studio entirely.
- **Features**, once the above is true: device preview toggle (this market is
  overwhelmingly mobile and the preview is desktop-shaped), colour editing
  with WCAG contrast warnings, draft vs. publish, curated presets, a wider
  Google Fonts list than today's three headings and two body faces.
