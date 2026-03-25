# Storefront Theme Engine — Design Spec

**Date:** 2026-03-24
**Status:** Approved
**Scope:** Sub-project 1 of 3 (Theme Engine + Atelier theme)

---

## Context

Emakola's storefront currently has hardcoded styling with zero merchant customization. Merchants need to choose how their store looks and customize colors, hero images, and which sections appear. This is the foundation for a Shopify-style theme system.

## Goals

- Merchants can pick a theme (Atelier, Market, Vibrant) and customize colors, hero content, and section visibility
- Theme rendering is fast (microseconds, not milliseconds) — no per-request database queries after initial load
- Adding new themes requires only implementing a behaviour module — no framework changes
- All existing storefront functionality (cart, checkout, payments, tracking) continues working unchanged

## Audience

Ghanaian merchants — many with low technical literacy. Defaults must look great out of the box. Customization is optional.

---

## Data Model

### Store Resource Change

Add a `theme_config` map/jsonb column to the existing `stores` table via migration.

```elixir
attribute :theme_config, :map, default: %{}, public?: true
```

### ThemeConfig Validation

An embedded module `Emakola.Stores.ThemeConfig` validates the JSON structure:

```
%{
  theme: "atelier" | "market" | "vibrant",    # Required, default "market"
  colors: %{
    primary: "#hex",      # CTAs, prices, active states
    accent: "#hex",       # Secondary buttons, nav, badges
    background: "#hex"    # Page background
  },
  hero: %{
    image_url: string,    # Hero background image URL
    title: string,        # Hero headline
    subtitle: string,     # Hero subheadline / season label
    cta_text: string,     # CTA button text
    cta_url: string       # CTA button link (relative path)
  },
  sections: %{
    hero: boolean,              # Full-screen hero
    categories: boolean,        # Category grid
    featured_products: boolean, # Curated products section
    brand_story: boolean,       # Store about / brand story
    instagram: boolean,         # Instagram/lookbook grid
    newsletter: boolean         # Newsletter signup
  }
}
```

All fields optional. Theme defaults fill gaps.

### Migration

```
add :theme_config, :map, default: %{}
```

Single column, no new tables.

---

## Theme Defaults

| Setting | Atelier | Market | Vibrant |
|---------|---------|--------|---------|
| Primary color | `#CA8A04` (gold) | `#2563EB` (blue) | `#DC2626` (red) |
| Accent color | `#1C1917` (charcoal) | `#0F172A` (navy) | `#7C2D12` (burnt orange) |
| Background | `#FAFAF9` (cream) | `#FFFFFF` (white) | `#FFFBEB` (warm ivory) |
| Heading font | Cormorant (serif) | Inter (sans) | Playfair Display (serif) |
| Body font | Montserrat (sans) | Inter (sans) | DM Sans (sans) |
| Hero style | Full-bleed editorial | Clean banner + search | Bold split with texture |
| Product cards | Minimal, 5:6, hover heart | Practical, badges, quick-add | Large, rounded, shadow |
| Categories | Masonry grid + overlays | Simple grid + labels | Circle story bubbles |
| Sections enabled | All | All except Instagram | All |

---

## Rendering Architecture

### Request Flow

```
Request → Router → StoreLive.mount/3
  → StoreResolver.resolve(slug) → store (with theme_config from cache)
  → ThemeResolver.merge(store.theme_config) → full config (defaults + overrides)
  → assign(socket, :theme, merged_config)
  → render/1 → dispatches to theme module based on theme.theme
```

### Key Modules

#### 1. `Emakola.Themes.ThemeBehaviour`

Behaviour that all themes implement:

```elixir
@callback id() :: String.t()
@callback name() :: String.t()
@callback defaults() :: map()
@callback fonts() :: [String.t()]  # Google Fonts URLs
@callback render_home(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
@callback render_product_list(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
@callback render_product_detail(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
```

#### 2. `Emakola.Themes.ThemeResolver`

```elixir
def merge(theme_config) do
  theme_id = Map.get(theme_config, "theme", "market")
  theme_module = theme_module_for(theme_id)
  defaults = theme_module.defaults()
  DeepMerge.deep_merge(defaults, theme_config)
end

def theme_module_for("atelier"), do: Emakola.Themes.Atelier
def theme_module_for("market"), do: Emakola.Themes.Market
def theme_module_for("vibrant"), do: Emakola.Themes.Vibrant
def theme_module_for(_), do: Emakola.Themes.Market
```

#### 3. Theme Modules

- `Emakola.Themes.Atelier` — premium editorial (from store.html prototype)
- `Emakola.Themes.Market` — clean practical
- `Emakola.Themes.Vibrant` — bold colorful

Each module implements `ThemeBehaviour` and contains its own render functions using Phoenix function components.

#### 4. CSS Variable Injection

In the storefront layout, inject theme colors as CSS custom properties:

```heex
<style>
  :root {
    --theme-primary: <%= @theme.colors.primary %>;
    --theme-accent: <%= @theme.colors.accent %>;
    --theme-bg: <%= @theme.colors.background %>;
  }
</style>
```

Components use: `text-[var(--theme-primary)]`, `bg-[var(--theme-accent)]`, etc.

---

## Shared vs Theme-Specific Pages

### Theme-specific (each theme renders differently):
- **Home** (`StoreLive`) — hero, categories, featured products, brand story, instagram, newsletter
- **Product List** (`ProductListLive`) — grid style, filter layout, card design
- **Product Detail** (`ProductDetailLive`) — gallery style, layout, variant selectors

### Shared (one design, themed colors):
- **Cart** (`CartLive`)
- **Checkout** (`CheckoutLive`)
- **Order Confirmation** (`OrderConfirmationLive`)
- **Account** (`AccountLive`)
- **Wishlist** (`WishlistLive`)
- **Tracking** (`TrackingLive`)
- **Category** (`CategoryLive`) — uses product list theme component

Shared pages use CSS variables for colors but keep a single layout across all themes.

---

## Storefront Layout Changes

Update `storefront.html.heex`:

1. Inject CSS variables from `@theme.colors`
2. Load theme-specific Google Fonts from `@theme_module.fonts()`
3. Keep existing: WhatsApp FAB, payment badges footer, flash messages
4. Nav component reads theme colors via CSS variables

---

## Store Resource Changes

Add to `store.ex`:
- `attribute :theme_config, :map, default: %{}`
- Add `theme_config` to `update_settings` action accept list
- No new relationships or resources needed

---

## Caching

Use existing `Emakola.Cache.StoreCache` — store objects (including `theme_config`) are already cached. Theme resolution (`ThemeResolver.merge`) runs on the cached data. No additional caching layer needed.

---

## Implementation Scope (Sub-project 1)

This spec covers:
1. Migration to add `theme_config` column
2. `ThemeConfig` validation module
3. `ThemeBehaviour` behaviour
4. `ThemeResolver` merge logic
5. CSS variable injection in storefront layout
6. **Atelier theme** — full implementation (home, product list, product detail) based on the `store.html` prototype
7. **Market theme** — the current storefront design extracted into the theme system (refactor, not rebuild)
8. **Vibrant theme** — new bold/colorful design
9. Updated storefront LiveViews to dispatch to theme modules
10. Tests for theme resolution, config validation, and rendering

This spec does NOT cover:
- Theme Customizer admin UI (Sub-project 3)
- Theme preview/publish workflow
- Custom CSS injection
- Section reordering

---

## Testing Requirements

- Unit tests for `ThemeResolver.merge/1` — defaults, partial overrides, full overrides, invalid theme ID
- Unit tests for `ThemeConfig` validation — valid configs, invalid hex colors, invalid theme names
- Integration tests for each theme's home page rendering — verify key content appears
- Existing storefront tests must continue passing (cart, checkout, etc.)

---

## File Structure

```
lib/emakola/
  stores/
    theme_config.ex          # Embedded validation module
  themes/
    theme_behaviour.ex       # Behaviour definition
    theme_resolver.ex        # Merge logic
    atelier.ex               # Atelier theme module
    atelier/
      home.ex                # Home page components
      product_list.ex        # Product list components
      product_detail.ex      # Product detail components
      shared.ex              # Shared components (nav, footer, product card)
    market.ex                # Market theme module
    market/
      home.ex
      product_list.ex
      product_detail.ex
      shared.ex
    vibrant.ex               # Vibrant theme module
    vibrant/
      home.ex
      product_list.ex
      product_detail.ex
      shared.ex

test/emakola/
  themes/
    theme_resolver_test.exs
    theme_config_test.exs
  themes/atelier/
    home_test.exs
  themes/market/
    home_test.exs
  themes/vibrant/
    home_test.exs
```
