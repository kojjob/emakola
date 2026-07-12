# Market theme — elevation + sectionization

**Status:** approved (Kojo, 2026-07-12 — "sectionize market first", "make them beautiful modern and aesthetic")

## Why Market first

Production census (11 stores): **9 are on Market** — 5 explicit, 4 unset falling through to `@default_theme`. Roughly 82% of live storefronts render this theme, and most of those merchants never picked a theme at all. Market is the single highest-leverage visual surface on the platform.

## The constraints that shape the design

1. **Merchants own the palette and fonts.** `DesignTokens` exposes a merchant-chosen primary colour and a heading font (`serif` → Cormorant, `display` → Playfair, `sans` → inherit). The theme must look intentional under *any* of those choices. This is why Market is currently bland — it was built neutral to survive them.
2. **The cards are shared.** `EmakolaWeb.StorefrontComponents` (`product_card/1`, `featured_product_card/1`, `about_section/1`) is imported by Atelier, Pharmacy, Spotlight, Electronics, Heritage, Home Living and more. **Do not restyle it** — that would silently redesign eight other themes. Market gets its own components module.
3. **Low bandwidth, cheap Android, mobile-first.** Photos arrive late or not at all.
4. **Market must flatter every category** — food, fashion, beauty, electronics. No vertical-specific styling.

## Direction: "Stall" — price-forward, photo-light, warm

### Colour

Market today is 100% Tailwind **slate** (`#0F172A`, `#E2E8F0`, `#94A3B8`, `#475569`, `#F1F5F9`, `#CBD5E1`, `#F8FAFC`) — a cold blue-grey ramp that renders food and fabric grey and lifeless. Replace with the warm **stone** ramp:

| Role | Hex | Tailwind |
|---|---|---|
| Ink | `#1C1917` | `stone-900` |
| Ash | `#57534E` | `stone-600` |
| Clay | `#A8A29E` | `stone-400` |
| Sand | `#E7E5E4` | `stone-200` |
| Chalk | `#FAFAF9` | `stone-50` |
| Paper | `#FFFFFF` | `white` |

Warm neutrals flatter skin tones, produce, and cloth — the actual inventory of these merchants. Tailwind-native; no custom CSS.

**The merchant's `--color-primary` is the only accent, and appears in exactly three places:** the price chip, the active/hover category ring, and the primary CTA. This restraint is what lets the theme survive any hue the merchant picks.

### Type

Respect `DesignTokens` for heading/body families — do not hardcode a typeface. Add one new role: **price is typography, not metadata.** Prices are set large, in the heading family, with `tabular-nums` and tight tracking.

### Signature: the price chip

A high-contrast, image-free price element — tabular numerals, tight tracking, a small notched/folded corner — sitting at the lower-left of the product image. It recurs on every product card, the featured hero, and the detail page.

Grounded in the subject: in a market, price is the first question and it is *shouted* (chalkboards, hand-lettered tags). It also renders instantly with zero image bytes, which is the point below.

### The aesthetic risk: the slow-network state IS the design

Product cards must look **finished before the photograph loads**. The image slot is a warm tinted panel carrying the product's initial in large display type, with the price chip already legible; the real photo fades in over it when it arrives.

For a shopper on 2G this is the common state, not the degraded one — so it gets to be designed. A branded, shoppable grid beats a field of grey boxes.

Keep `optimized_image/1` (lazy-loading, width/height set — no layout shift).

## Sections

Market's home becomes four registered sections. `home.ex` keeps only chrome (`theme_styles`, `SectionRenderer.home/1`, footer), matching the Starter/Atelier pattern.

| key | label | notes |
|---|---|---|
| `market/category_strip` | Categories | Story-style circles. **Keep this DNA** — these merchants come from Instagram and WhatsApp; the circles are true to their origin. Warm rings; active state uses primary. |
| `market/featured` | Featured product | One large "stall front" card: photo, oversized price chip, name, CTA. |
| `market/product_grid` | Product grid | "Shop All" — 2 / 3 / 4 col. Cards carry the placeholder-first treatment, price chip, and add-to-cart. |
| `market/about` | About | Store story. |

**Byte-identical defaults are deliberately WAIVED for Market** — this is an intentional visual elevation, approved by Kojo, not a regression. Every other theme keeps the rule. Update Market's existing storefront tests deliberately; preserve content landmarks (category names, product titles, "Shop All", store description) so coverage stays meaningful.

Note this also resolves a structural problem: today three of the four sections are trapped inside one shared padded `<div>` while the category strip sits outside it, which a flat section list cannot reproduce. In the new layout each section is a top-level sibling owning its own horizontal padding.

No newsletter section — out of scope, and not asked for.

## Hard gates (inherited from the section-editor core)

- Every `settings_schema/0` entry **MUST declare `default:`** — `coerce_value/2` pattern-matches on it.
- **No `phx-click` / `phx-submit` in section markup without a handler in `lib/`.** `add_to_cart` is handled by `StoreLive` (payload `%{"product-id" => id}`); `subscribe_newsletter` is now handled platform-wide by `EmakolaWeb.Hooks.NewsletterSubscription`. Anything else you introduce needs a handler, or it crashes the live storefront *and* the editor preview.
- Register `Emakola.Themes.Market` in `Sections.@sectionized_themes`, or its merchants cannot reach the editor.
- Accessibility floor: visible keyboard focus, `prefers-reduced-motion` respected, alt text, `aria-label` on the category nav.
