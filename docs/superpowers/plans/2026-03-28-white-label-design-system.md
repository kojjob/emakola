# White-Label Design System — Implementation Plan

## Context

Emakola has 6 storefront themes (Market, Atelier, Fresh, Bold, Starter, Vibrant) covering 3 core pages each (~10,000 lines). But 10+ pages are unstyled, there's no section editor, and merchants can't customize component shapes or typography. The goal is to upgrade to a Shopify-level design system where merchants mix and match component variants to create unique stores without code.

**Three layers, each shippable independently:**
1. Full page coverage (all pages theme-aware)
2. Section editor (drag-and-drop home page builder)
3. Component variant system (buttons, cards, grids, typography)

---

## Phase 1: Full Page Coverage

**Goal:** Every storefront page renders through the theme pipeline with fallback to default renderers. Existing themes unchanged.

### Architecture

```
LiveView.render/1
  → ThemeRenderer.render(theme_module, :cart, assigns)
    → if function_exported?(theme_module, :render_cart, 1)
        → theme_module.render_cart(assigns)    # theme-specific
      else
        → DefaultRenderers.Cart.render(assigns)  # shared fallback
```

### Files to Create

| File | Purpose |
|------|---------|
| `lib/emakola/themes/theme_renderer.ex` | Dispatcher with `function_exported?` fallback |
| `lib/emakola/themes/default_renderers/shared.ex` | Wrapper: navbar + CSS vars + content + footer |
| `lib/emakola/themes/default_renderers/cart.ex` | Extract from cart_live.ex render |
| `lib/emakola/themes/default_renderers/checkout.ex` | Extract from checkout_live.ex render |
| `lib/emakola/themes/default_renderers/blog_list.ex` | Extract from blog_list_live.ex render |
| `lib/emakola/themes/default_renderers/blog_post.ex` | Extract from blog_post_live.ex render |
| `lib/emakola/themes/default_renderers/recipe_list.ex` | Extract from recipe_list_live.ex |
| `lib/emakola/themes/default_renderers/recipe_detail.ex` | Extract from recipe_live.ex |
| `lib/emakola/themes/default_renderers/order_confirmation.ex` | Extract |
| `lib/emakola/themes/default_renderers/tracking.ex` | Extract |
| `lib/emakola/themes/default_renderers/category.ex` | Extract |
| `lib/emakola/themes/default_renderers/wishlist.ex` | Extract |
| `lib/emakola/themes/default_renderers/account.ex` | Extract |
| `test/emakola/themes/theme_renderer_test.exs` | Dispatcher + fallback tests |

### Files to Modify

| File | Change |
|------|--------|
| `lib/emakola/themes/theme_behaviour.ex` | Add `@optional_callbacks` for 13 new pages |
| `lib/emakola_web/hooks/resolve_store.ex` | Ensure ALL storefront pages get `@theme_module` assigned |
| 13 storefront LiveViews | Replace inline `render/1` with `ThemeRenderer.render(...)` call |

### Key Decision
The `DefaultRenderers.Shared` wrapper component renders the storefront layout's default navbar + footer, injecting the store's theme colors as CSS custom properties. This means every page automatically inherits the merchant's color scheme even without a theme-specific renderer.

### Tasks: ~15-18

---

## Phase 2: Section Editor

**Goal:** Merchants reorder, add, remove, and configure home page sections via drag-and-drop.

### Data Model

New key in `Store.theme_config`:
```json
{
  "home_sections": [
    {"id": "abc", "type": "hero", "position": 0, "visible": true, "settings": {"layout": "full-bleed", "title": "..."}},
    {"id": "def", "type": "featured_products", "position": 1, "visible": true, "settings": {"columns": 4}},
    {"id": "ghi", "type": "testimonials", "position": 2, "visible": true, "settings": {"style": "carousel"}}
  ]
}
```

No database migration needed — `theme_config` is already a `:map` (JSONB). `ThemeResolver` populates defaults from theme's existing section config when absent.

### Section Type Registry (15+ blocks)

| Type | Description |
|------|-------------|
| `hero` | Banner with image/carousel, title, CTA |
| `featured_products` | Product grid (configurable columns) |
| `categories` | Category circles/cards |
| `testimonials` | Customer quotes (card or carousel) |
| `faq` | Accordion Q&A |
| `banner` | Full-width announcement/promo |
| `video` | Embedded YouTube/Vimeo |
| `countdown` | Sale countdown timer |
| `gallery` | Image grid/masonry |
| `newsletter` | Email signup form |
| `trust` | Payment/shipping badges |
| `brand_story` | About/mission section |
| `text_block` | Rich text content |
| `divider` | Visual separator |
| `custom_html` | Raw HTML (advanced) |

### Files to Create

| File | Purpose |
|------|---------|
| `lib/emakola/themes/sections/registry.ex` | Section type definitions + defaults + schemas |
| `lib/emakola/themes/sections/section_renderer.ex` | Dispatches section type → HEEx component |
| `lib/emakola/themes/sections/renderers.ex` | One function component per section type |
| `lib/emakola_web/live/admin/section_editor_live.ex` | Drag-and-drop section list admin UI |
| `lib/emakola_web/live/admin/section_settings_form.ex` | Dynamic per-section settings panel |
| `assets/js/hooks/section_sortable.js` | JS hook for drag-and-drop (SortableJS) |
| `test/emakola/themes/sections/registry_test.exs` | Registry tests |
| `test/emakola/themes/sections/section_renderer_test.exs` | Renderer tests |
| `test/emakola_web/live/admin/section_editor_live_test.exs` | Admin UI tests |

### Files to Modify

| File | Change |
|------|--------|
| `lib/emakola/themes/theme_resolver.ex` | Populate `home_sections` defaults from theme config |
| `lib/emakola/themes/theme_renderer.ex` | Section-aware home rendering when `home_sections` exists |
| `lib/emakola_web/router.ex` | Add `/admin/section-editor` route |
| `lib/emakola_web/components/layouts/app.html.heex` | Add sidebar link |
| `assets/js/app.js` | Register `SectionSortable` hook |

### How Home Rendering Changes

```
If store has home_sections:
  Iterate sections array → render each via SectionRenderer

If store has NO home_sections:
  Fall back to existing theme_module.render_home(assigns)
  (backwards compatible, zero changes for existing stores)
```

### Tasks: ~20-25

---

## Phase 3: Component Variant System

**Goal:** 10 design dimensions merchants can customize. Components across all pages respond to these tokens.

### Design Tokens

Stored in `theme_config.design_tokens`:

| Token | Variants | Default |
|-------|----------|---------|
| `button_style` | `rounded`, `square`, `pill` | `rounded` |
| `card_style` | `minimal`, `shadow`, `bordered` | `shadow` |
| `navbar_layout` | `centered`, `left`, `hamburger` | `left` |
| `product_grid_columns` | `2`, `3`, `4` | `3` |
| `hero_layout` | `full-bleed`, `split`, `video` | `full-bleed` |
| `footer_style` | `minimal`, `columns`, `mega` | `columns` |
| `product_card_style` | `card`, `list`, `magazine` | `card` |
| `typography_scale` | `compact`, `default`, `spacious` | `default` |
| `heading_font` | `serif`, `sans`, `display` | `sans` |
| `body_font` | `sans`, `serif` | `sans` |

### Implementation: Pure Function Class Maps

```elixir
# lib/emakola/themes/design_tokens.ex
def button_classes("pill"), do: "rounded-full px-6 py-2.5"
def button_classes("square"), do: "rounded-none px-5 py-2.5"
def button_classes(_), do: "rounded-lg px-5 py-2.5"
```

No runtime overhead — pattern matching is compile-time optimized. Tailwind safelist ensures classes aren't purged.

### Files to Create

| File | Purpose |
|------|---------|
| `lib/emakola/themes/design_tokens.ex` | Token → Tailwind class mapping (all 10 dimensions) |
| `lib/emakola/themes/font_loader.ex` | Font family token → Google Fonts URL |
| `lib/emakola/themes/design_tokens/style_injector.ex` | CSS custom property injection component |
| `test/emakola/themes/design_tokens_test.exs` | Class resolution tests |
| `test/emakola/themes/font_loader_test.exs` | Font URL tests |

### Files to Modify

| File | Change |
|------|--------|
| `lib/emakola/themes/theme_resolver.ex` | Populate `design_tokens` defaults |
| `lib/emakola_web/live/admin/theme_live.ex` | Add "Design" step with variant pickers |
| `lib/emakola/themes/default_renderers/*.ex` | Use `DesignTokens.button_classes(...)` etc. |
| `tailwind.config.js` | Add safelist for all variant classes |

### Admin UI: Design Tab

Visual picker for each dimension — shows 3-4 preview swatches/mockups. Merchant taps to select. Live preview updates immediately.

### Tasks: ~15-18

---

## Migration Path

- **No database migration.** `theme_config` is already JSONB. New keys are simply absent for existing stores.
- **ThemeResolver handles absence.** Missing `home_sections` → generates defaults from theme's section booleans. Missing `design_tokens` → returns sensible defaults.
- **Existing themes unchanged.** `function_exported?` fallback means the 6 themes keep their custom renderers. Only pages they DON'T implement fall to DefaultRenderers.

## Risk: Tailwind Purging

Design token classes are constructed at runtime. Tailwind's purge may strip them. **Fix:** Add explicit safelist in `tailwind.config.js` for all variant class fragments (~50 entries).

---

## Summary

| Phase | What Ships | Tasks | Independently Shippable |
|-------|-----------|-------|------------------------|
| 1 | All 13+ pages theme-aware | 15-18 | Yes |
| 2 | Drag-and-drop section editor | 20-25 | Yes (requires Phase 1) |
| 3 | 10 component variant dimensions | 15-18 | Yes (requires Phase 1) |
| **Total** | **White-label design system** | **50-61** | |

## Verification

- Run `mix test` after each phase — all existing tests must pass
- Visual QA: navigate between themed store pages and blog/cart/checkout — navbar and footer consistent
- Test section editor: reorder sections, add/remove, save, reload — sections persist
- Test design tokens: change button style to "pill", verify all buttons across all pages update
- Test backwards compatibility: existing store with no `home_sections`/`design_tokens` renders identically to before
