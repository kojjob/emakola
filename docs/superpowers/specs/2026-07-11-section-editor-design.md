# Theme-Native Section Editor — Design

**Date:** 2026-07-11 · **Status:** approved in brainstorm, pending spec review
**Owner item:** TODO.md "White-label Phase 2 — Section editor (Shopify-style)"

## Context

The white-label design system's remaining phase is a homepage section editor.
Exploration found the platform already ships a complete **page-builder block
system** (10 block types, registry, `Block` behaviour, renderer, a 1,026-line
editor with drag handles) and a working **home override**: a published page at
slug `"home"` replaces the theme home, otherwise the theme's fixed
`render_home` renders (zero-risk fallback in `store_live.ex`).

That path makes a merchant abandon their theme's crafted look. The decision
(2026-07-11) is Shopify's real model instead: **the theme's own home sections
become the editable units**, so customizing never leaves the theme's design
language.

## Decisions (from brainstorm)

| Question | Decision |
|---|---|
| Vision | **Theme-native sections** (not generic-blocks polish, not hybrid-as-vision) |
| Rollout | **All 12+ themes sectionized up front** (contract proven on 2 reference themes, remainder fanned out to parallel agents) |
| Capabilities | **Full theming v1**: reorder + show/hide + per-section settings + per-section color/spacing overrides + custom sections |
| Custom sections | Add extra instances of any theme section **and** insert any existing page-builder block into the home flow (via one adapter — reuses the 10-block library) |
| Persistence | **Per-theme layouts**: each theme keeps its saved layout; switching themes and back preserves customizations |
| Editor UX | **Real-time preview**: one LiveView renders the actual theme sections with draft state in-process — no iframe, no postMessage |

## Architecture

### 1. Section contract

```elixir
defmodule Emakola.Themes.Section do
  @callback key() :: String.t()            # stable identity, e.g. "atelier/story_categories"
  @callback label() :: String.t()          # editor display name
  @callback settings_schema() :: [setting] # see Settings below
  @callback render(assigns) :: Phoenix.LiveView.Rendered.t()
  # assigns: store, products, categories, settings (defaults deep-merged), tokens
end
```

- Sections live in `lib/emakola/themes/<theme>/sections/*.ex`.
- Each theme module gains `sections/0` → ordered list of section modules
  (its default layout). The theme's `render_home` becomes "render my
  sections in default order" — an untouched store renders **byte-identically**
  to today (regression-tested per theme).
- A **registry** (`Emakola.Themes.Sections`) maps `key -> module` across all
  themes plus the block bridge, mirroring `Emakola.PageBuilder`'s registry
  pattern.

### 2. Block bridge (custom sections)

`Emakola.Themes.Sections.BlockSection` adapts any registered page-builder
block as a section: key `"block/<block_type>"`, label from the block,
settings schema derived from the block's `default_content/0`, render
delegating to `PageBuilder.render_block/2`. One adapter, ten new insertable
sections, no duplication.

### 3. Settings

A setting is `%{key, type, label, default}` with types:
`:string`, `:text`, `:image_url`, `:category` (picker, stores the id),
`:link`, `:boolean`, `:integer`. Schemas stay deliberately small per section
(heading, subheading, source category/collection, image, CTA label+href).
Values are sanitized at save: no raw HTML anywhere; URLs must be http(s);
category ids validated against the store's categories.

### 4. Storage

Inside the existing `store.theme_config` map (no migration):

```
theme_config["home_sections"] = %{
  "v" => 1,
  <theme_name> => [
    %{"id" => uuid, "type" => section_key, "enabled" => bool,
      "settings" => %{...}, "style" => %{"bg" => css_color | nil,
      "text" => css_color | nil, "padding" => "none|sm|md|lg" | nil}}
  ]
}
```

Per-theme keys give risk-free theme experimentation. Unknown `type` keys at
render time are skipped with a log (a removed section never crashes a
storefront). Missing settings keys fall back to schema defaults
(the page-builder's "loose schema" convention).

### 5. Rendering

`Emakola.Themes.SectionRenderer.home(store, theme_module, assigns)`:

1. layout = saved layout for active theme || theme defaults (from `sections/0`)
2. for each enabled entry: resolve module via registry → merge settings over
   schema defaults → render inside the **style wrapper**
3. Style wrapper (v1 "full theming", universal across all themes): a div
   applying validated background/text color (via the existing
   `EmakolaWeb.Helpers.CssColor.safe_css_color`) and a vertical padding scale.
   No per-section CSS work; sections inherit color.

Storefront precedence in `store_live.ex` (unchanged shape):
**page-builder "home" page override → section layout → theme fixed home.**
The fixed-home branch remains as safety fallback even after full rollout.

### 6. Editor

New LiveView `/admin/design/sections` (linked from the Design tab):

- **Left panel:** section rows — drag to reorder via the `SectionSortable`
  JS hook (hand-rolled HTML5 drag-and-drop, **no new JS dependency**,
  pushing one `reorder` event with the full id order on drop; keyboard
  fallback via per-row up/down buttons for accessibility), enable/disable
  toggle, expand for settings form +
  style controls (two color inputs + padding select), remove (custom
  instances only — a theme's default sections can be hidden, not deleted),
  and an "Add section" picker listing the active theme's section types and
  the ten bridged blocks.
- **Right panel:** real-time preview — renders
  `SectionRenderer.home(store, theme, draft_assigns)` directly in the same
  LiveView, wrapped in the store's DesignTokens CSS vars and a storefront-
  width container. Updates on every draft change (same process, no iframe).
  Storefront-only JS hooks (scroll effects) simply don't animate in preview —
  acceptable.
- **Draft/publish:** draft lives in socket assigns; **Publish** writes
  `theme_config`; an unsaved-changes guard warns on navigation. "Reset to
  theme defaults" clears the active theme's saved layout (with confirm).
- Authorization: store resolved from session assigns; merchant actor passed
  to a `Emakola.Themes.HomeSections` context (get/put layout) that enforces
  store membership; params never trusted for tenancy.

### 7. Rollout plan (amended 2026-07-11 after the new-themes decision)

1. **Core PR** — contract, registry, block bridge, `SectionRenderer`,
   `HomeSections` context, storefront wiring, **starter + Atelier**
   decomposed as references, per-theme equivalence tests. (Starter and
   Atelier are safe keeps: the default and the showcase.)
2. **Editor PR** — the LiveView, `SectionSortable` hook, settings/style
   forms, real-time preview, publish/reset, LiveView tests.
3. **Seven new themes** (five locked 2026-07-11; Pace and Ntoma added same
   day) — **born sectionized**, built by seven parallel agents after the
   core PR so `sections/0` exists from birth:

   | Theme | Vertical | Direction |
   |---|---|---|
   | Sika | Jewelry & accessories | Quiet-luxury minimal: monochrome + one metallic accent, oversized serif display, full-bleed photography |
   | Fie | Home & décor | Belo.fur reference (locked 2026-07-11, Dribbble shot 26409577): modernist catalog — white gallery ground in a blush frame, huge grotesk display, numbered category index with hairline rules, pale-grey product panels, black pill CTAs |
   | Chale | Streetwear & urban youth | Concrete palette (locked 2026-07-11): crimson accents on light concrete grey, black type; oversized nav, marquee strips, drop stock counters |
   | Dede | Food vendors & chop bars | Mobile-order-first menu layout, sticky quick-buy, prominent WhatsApp ordering |
   | Depot | Wholesalers & B2B (Earn suppliers) | Dense quick-order tables, volume-tier pricing, heavy filtering, minimal chrome |
   | Pace | Activewear & techwear | Kinetic athletic catalog (locked to Kojo's Dribbble video ref, userupload/43016702): ice-blue ground, rounded canvas, dark-gradient photo cards with overlaid caps type, ghost marquee behind cards, letter-reveal headlines; motion CSS-driven and low-bandwidth-safe |
   | Ntoma | Fashion & apparel retail | Warm mainstream fashion (locked to Kojo's Frolax ref, Dribbble shot 26410257 by Bilash Roy): terracotta + amber palette, oversized serif display, trust-badge strip, asymmetric category tiles, full-bleed gold featured band with giant wordmark, editorial lifestyle banners; hero photography celebrates West African print |

   **Production-grade bar** for each: native `home` (as sections),
   `product_list`, `product_detail`, and shared chrome (nav/footer/cart
   entry); design-tokens support; mobile-first low-bandwidth discipline;
   WhatsApp CTAs where the vertical calls for them; a storefront test
   suite matching the strongest existing theme's coverage; DefaultRenderers
   remain acceptable for secondary pages (About/Contact/FAQ/Policies) per
   platform convention.
4. **Existing-theme cull, then survivor fan-out** — Kojo picks which of the
   ~10 remaining existing themes to keep; ONLY survivors get decomposed
   (parallel agents, one per theme) against the hard rule: *default layout
   renders the same sections in the same order; the theme's existing
   storefront tests pass unchanged; add the equivalence test.* Dropped
   themes are removed rather than sectionized.

### 8. Testing

- **Contract:** every section renders with schema defaults (registry-driven
  generative test: for each registered section, render with empty settings).
- **Renderer:** order respected, disabled skipped, unknown type skipped+logged,
  settings merged over defaults, style wrapper applies sanitized values.
- **Equivalence per theme:** default layout ≡ pre-decomposition home
  (section presence/order asserted; existing storefront theme tests unchanged).
- **Editor LV:** reorder persists order, toggle, settings save + sanitization
  rejects bad URLs/colors, add block-section, publish writes theme_config,
  reset restores defaults, cross-store access forbidden.
- **Storefront integration:** customized layout renders on `/s/:slug`;
  page-builder home override still wins; store with no layout unchanged.

### 9. Out of scope (v1)

- Real-time preview device-size toggles (desktop-width only).
- Per-section custom CSS or arbitrary style properties beyond bg/text/padding.
- Section-level scheduling/AB testing.
- Sectionizing non-home pages (product/list pages keep theme renderers).
- Editing generic-block *content* inside this editor beyond its settings
  schema (the full page-builder editor remains for block-heavy homes).
