# The seven new themes — build contract

Read this in full before writing any code. It is the same contract for all seven themes; your dispatch adds only your theme's design direction.

## Why these exist

Makola is a multi-tenant e-commerce platform for West Africa, launching in Ghana. The merchants are largely Instagram/WhatsApp social sellers. Their customers shop on **cheap Android phones over metered data**. Themes are how a small merchant's store looks credible in ten seconds.

These seven are built *after* the section editor, so they are born sectionized rather than retrofitted.

## The theme contract

Your theme module `lib/emakola/themes/<id>.ex` must expose:

| Function | Returns |
|---|---|
| `id/0` | the theme id string, e.g. `"sika"` |
| `name/0` | display name, e.g. `"Sika"` |
| `defaults/0` | the theme's default config — **copy the shape from `lib/emakola/themes/starter.ex` exactly**, including `colors` and the typography keys |
| `fonts/0` | list of Google Fonts stylesheet URLs (`display=swap`), or `[]` for system fonts. The onboarding picker loads these to preview your theme in its real typeface. |
| `sections/0` | ordered list of your home-page section modules |
| `renderer/1` | `:home` / `:product_list` / `:product_detail` → your page modules |

Files on disk (mirror `lib/emakola/themes/starter/`):

```
lib/emakola/themes/<id>.ex
lib/emakola/themes/<id>/home.ex           # chrome only: theme_styles, nav, SectionRenderer.home, footer
lib/emakola/themes/<id>/product_list.ex
lib/emakola/themes/<id>/product_detail.ex
lib/emakola/themes/<id>/shared.ex         # theme_styles, YOUR nav, YOUR footer, cards
lib/emakola/themes/<id>/sections/*.ex     # one module per home section
```

**Read `lib/emakola/themes/market/` first.** It is the most recently elevated theme and the closest model for everything below — its nav, its footer, its sections, its cards, its empty states.

## 🔴 Hard gates — each of these is a bug we shipped and had to fix

These are not style advice. Every one is a real production incident from this codebase.

**1. Your theme MUST render its own nav, with a cart link, on all three pages.**
The storefront layout renders a fallback header only via `<header :if={!assigns[:theme_module]}>` — it assumes every theme brings its own nav. Market shipped without one, so customers on **82% of live stores** could add to cart and never reach checkout. Vibrant had the same bug.

The cart link must be reachable **on desktop** — the shared `bottom_nav/1` is `sm:hidden` (mobile only), so a cart link *only* in a mobile bar still strands every desktop shopper. `test/emakola_web/live/storefront/theme_nav_audit_test.exs` audits this automatically for every registered theme, across home / product list / product detail. It will catch you.

**2. No `phx-click` / `phx-submit` without a real handler in `lib/`.**
Allowed today: `add_to_cart` (`StoreLive`, payload `%{"product-id" => id}`), `search_overlay` / `close_search` (`StoreLive`), `subscribe_newsletter` (handled platform-wide by `EmakolaWeb.Hooks.NewsletterSubscription`). Also `filter_category`, `load_more`, `select_image`, `select_option`, `increment_quantity`, `decrement_quantity` on the list/detail pages — **verify each against the LiveView that renders your page before using it.**
Inventing a binding with no handler crashes the **live public storefront** AND the section editor's preview. The newsletter form did exactly this on five themes.

**3. Every `settings_schema/0` entry MUST declare `default:`.**
The section editor's `coerce_value/2` pattern-matches on it. A missing `default:` crashes the editor.

**4. Sections must tolerate empty data.** `@products == []` and `@categories == []` are the *normal* state during onboarding. A brand-new store must render an intentional empty state, never a blank page.

**5. Do NOT modify `EmakolaWeb.StorefrontComponents` or any other theme.** Eight themes import those shared components; restyling them silently redesigns everyone else. Your theme owns its own chrome, its own cards, its own footer. You may *reuse* `optimized_image/1` (lazy loading, width/height set — no layout shift).

**6. Do NOT touch the four registration files.** `theme_resolver.ex`, `sections.ex`, `onboarding_live.ex`, `admin/theme_live.ex` are edited centrally after the fan-out — seven agents editing them in parallel would conflict. Just build your theme; registration is handled for you.

## Craft floor

- **TailwindCSS only.** No custom CSS. Mobile-first — most of these merchants and their customers are on phones.
- **Low bandwidth is the design constraint, not an afterthought.** Photos arrive late or never. Market's answer — cards that look finished *before* the image loads, with the product initial and price already legible — is a good model. Don't ship grey skeleton boxes.
- **Respect `DesignTokens`.** The merchant picks their own primary colour and heading font. Your design must survive any hue they choose — deploy the accent with restraint, and never hardcode a brand colour where a token belongs.
- **Money is integer minor units** (pesewas). Never floats. Format only at the presentation layer.
- **Accessibility floor:** a `<header>`/`banner` landmark, `<main>`, `<footer>`/`contentinfo`; one `<h1>` per page; visible keyboard focus; `prefers-reduced-motion` respected; alt text; `aria-label` on icon-only controls.
- **Ghana specifics:** payments are MTN MoMo, Telecel Cash, AirtelTigo Money, and card via Paystack/Hubtel. WhatsApp is a primary sales channel, not a footnote. Currency is GHS (₵).

## TDD is mandatory

Red → Green → Refactor. At minimum, per theme: each section renders its landmark; the theme exposes its sections in order; home / product list / product detail all render; a cart link is present outside the mobile-only bar on all three pages; empty products and empty categories don't crash; the price renders formatted from minor units.

**No vacuous assertions.** An assertion that would pass against an empty render or a no-op implementation is a defect, not coverage. (Real example from this codebase: a test asserted `html =~ "Hero"` to prove a section wasn't deleted — but a static picker elsewhere on the page always rendered the word "Hero", so it passed even when the section *was* deleted.)

## Gates — all clean before you commit

`mix format --check-formatted` · `mix compile --warnings-as-errors` · `mix credo --strict` · `mix test`

**`mix test | tail` exits 0 EVEN WHEN TESTS FAIL** — parse the `Result:` line, never the exit code.
