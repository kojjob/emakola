# Default Renderer Extraction Pattern

**Established:** 2026-04-26 with `Emakola.Themes.DefaultRenderers.Cart`

This document codifies the pattern for moving a storefront LiveView's
inline `render_default/1` body into a sibling `DefaultRenderers.X`
module. Use it for the remaining 10 pages listed at the end.

---

## The seam

Every storefront LiveView already dispatches through
`Emakola.Themes.ThemeRenderer.theme_render/2`. The shape today:

```elixir
def render(assigns) do
  case Emakola.Themes.ThemeRenderer.theme_render(assigns, :cart) do
    {:ok, rendered} -> rendered                # theme overrode :render_cart
    :default -> render_default(assigns)        # 200-1300 lines of HEEx inline
  end
end

defp render_default(assigns) do
  ~H"""
  ...500 lines of cart markup...
  """
end
```

The inline `render_default/1` is the duplication. Six themes will
NEVER override `:render_cart` (they only customize home/product
pages), but each one inherits `cart_live.ex`'s 500-line inline cart
template by default. When the cart UI changes, the LV file changes —
fine — but the template stays coupled to the LV's mount + event
handlers, so any "extract this for the new theme" work has to copy
the entire body.

---

## The extraction

Move `render_default/1`'s body to `Emakola.Themes.DefaultRenderers.X`
where `X` is the page name (`Cart`, `Checkout`, `BlogList`, etc.).
Keep private helpers that ONLY render (function components like
`quantity_stepper/1`) in the new module too. Keep mount/event/data
helpers (`reload_cart`, `assign_totals`, etc.) in the LV.

### Steps

1. **Create the module** at `lib/emakola/themes/default_renderers/<page>.ex`:
   ```elixir
   defmodule Emakola.Themes.DefaultRenderers.<Page> do
     @moduledoc """
     Default render for the storefront <page> page.
     ...
     """

     use Phoenix.Component

     # Mirror the LV's render-side imports/aliases:
     import EmakolaWeb.StorefrontComponents
     alias EmakolaWeb.Helpers.Currency
     # (drop business-logic imports the template doesn't reference)

     def render(assigns) do
       ~H"""
       ...moved markup...
       """
     end

     # Move private function components used by render/1 here too.
     defp some_component(assigns) do
       ~H"""..."""
     end
   end
   ```

2. **Update the LV** to delegate:
   ```elixir
   def render(assigns) do
     case Emakola.Themes.ThemeRenderer.theme_render(assigns, :cart) do
       {:ok, rendered} -> rendered
       :default -> Emakola.Themes.DefaultRenderers.<Page>.render(assigns)
     end
   end
   ```

3. **Delete** the original `defp render_default/1` and any private
   function components that moved with it.

4. **Run tests** for the LV (`mix test
   test/emakola_web/live/storefront/<page>_live_test.exs`) to confirm
   markup output unchanged.

### What NOT to move

- `mount/3`, `handle_event/3`, `handle_info/2` — stay in the LV.
- Data helpers like `reload_cart/1`, `assign_totals/2`, `cart_count/1`
  — stay in the LV (they update socket state).
- LV-specific imports (`alias Emakola.Cart.CartStore`) — stay.

---

## What "Shared wrapper" turned out NOT to be

The original 2026-03-28 plan suggested a `DefaultRenderers.Shared`
wrapper that would inject navbar + footer + CSS variables around every
default-rendered page. After the proof-of-pattern Cart extraction, it
became clear this is unnecessary:

- The **storefront live layout** (`lib/emakola_web/components/layouts/storefront.html.heex`)
  already provides fallback navbar, footer, WhatsApp FAB, search
  overlay, flash messages — but ONLY when `@theme_module` is unset.
- When `@theme_module` IS set (e.g. Atelier), the layout strips its
  fallbacks and the theme renders nav+footer itself.
- For `:default`-rendered pages, `@theme_module` is non-nil but the
  *page* falls back. The layout currently treats this as "theme-owned"
  and hides its fallbacks — which means default pages render without
  nav/footer.

**Follow-up needed:** the layout's `:if={!assigns[:theme_module]}` guards
on the fallback nav/footer should change to also show the fallback
when the *theme module exists but doesn't implement the page* — i.e.
when `theme_render/2` returns `:default`. Add a `@page_default` boolean
assigned by the LV based on the dispatch result, or check
`function_exported?` ahead of layout render.

This is a small layout edit, not a new wrapper component. Fix as part
of the second `DefaultRenderers` extraction so the pattern carries
through.

---

## Checklist for remaining 10 pages

| Page | LV file | Inline `render_default/1` size | Notes |
|---|---|---|---|
| Cart | `cart_live.ex` | ✅ done — 451 lines extracted | Pattern proof |
| Checkout | `checkout_live.ex` | ~1300+ lines | Largest. Has its own form state, payment poll. |
| BlogList | `blog_list_live.ex` | ~150 lines | Easy |
| BlogPost | `blog_post_live.ex` | ~200 lines | Includes recipe-link rendering |
| RecipeList | `recipe_list_live.ex` | ~150 lines | Easy |
| RecipeDetail | `recipe_live.ex` | ~250 lines | |
| OrderConfirmation | `order_confirmation_live.ex` | ~400 lines | Tracks payment status |
| Tracking | `tracking_live.ex` | ~300 lines | Map-style status |
| Category | `category_live.ex` | ~200 lines | |
| Wishlist | `wishlist_live.ex` | ~250 lines | Customer-auth-gated |
| Account | `account_live.ex` | ~500 lines | Tabbed (orders, addresses, wishlist) |

**Recommended order**: simplest first to validate the pattern at
scale (BlogList → RecipeList → BlogPost → RecipeDetail → Category →
Wishlist → Tracking → OrderConfirmation → Account → Checkout). Save
Checkout for last — it has the most state-coupled markup.

---

## Why this pattern over LiveComponent / function-component-with-attrs

Three options were considered:

1. **Sibling module with `def render(assigns)` taking `assigns` directly** ← chosen
2. Function component with explicit `attr` declarations
3. `Phoenix.LiveComponent`

Option 1 wins because:

- The render function already takes `assigns` — no signature change,
  no mount/event splitting required.
- Themes that *do* override implement the same shape:
  `Atelier.Cart.render_cart(assigns) -> Phoenix.LiveView.Rendered.t()`.
  Default renderers having the identical shape means the dispatch
  table in `ThemeRenderer` doesn't need a special case.
- LiveComponents are heavy (own state, lifecycle) and not warranted
  for a stateless markup move.
- Explicit `attr` declarations would require enumerating ~20 assigns
  per page and updating them every time the LV adds a new one. The
  `assigns` map is the LV's contract; no reason to relitigate it at
  the boundary.

---

## Testing strategy

The LV's existing test file is the regression check. The render is
markup-only, so a simple "page renders without errors and contains
expected text" test catches breakage. We did NOT write a separate
test file for `DefaultRenderers.Cart` — exercising it through the LV
test is sufficient.

If a future page needs more focused testing (e.g., conditional
sections, error states), add `test/emakola/themes/default_renderers/<page>_test.exs`
using `Phoenix.LiveViewTest.render_component/2`.

---

## Inventory of who calls who, post-Cart-migration

```
EmakolaWeb.Storefront.CartLive
  └── render/1
        ├── theme_render(assigns, :cart) → :default
        └── Emakola.Themes.DefaultRenderers.Cart.render(assigns)
              ├── inline markup
              └── quantity_stepper/1 (private)

Emakola.Themes.Atelier (if it had render_cart):
  └── theme_render(assigns, :cart) → {:ok, rendered}
        └── Atelier.Cart.render_cart(assigns) — never reaches DefaultRenderers
```

The seam is clean: themes either own the page (override) or fall back
to the default renderer. No three-way negotiation.
