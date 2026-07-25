# Heirloom Theme — Design

**Date:** 2026-07-25
**Status:** Approved
**Owner ask:** Convert a Dribbble reference —
[E-Commerce Website Design](https://dribbble.com/shots/27297400-E-Commerce-Website-Design)
by Shakuro UI/UX (the "Nestery" furniture store) — into a storefront theme
carrying real Emakola data.

Decisions locked with Kojo:

- **New theme**, not a rebuild of an existing one. Purely additive; no
  existing storefront changes.
- **Name: `heirloom`** (`Emakola.Themes.Heirloom`).
- **Team cards and stockist wall ship merchant-editable with `[]` defaults** —
  the design's layouts survive, the design's invented people and logos do not.

## 1. Design language

Colours sampled from the reference PNG, not eyeballed.

| Token | Value | Use |
|---|---|---|
| `--bg` | `#EFEFEF` | page canvas |
| `--tile` | `#E7E6E6` | product tile backgrounds |
| `--surface` | `#FFFFFF` | cards, floating panels |
| `--ink` | `#1B1208` | headings, body, dark pills |
| `--muted` | `#8C8781` | inactive tabs, secondary text |
| `--accent` | `#E8983F` | badges, active tab dot |
| `--deep` | `#000000` | wordmark band + footer |
| `--border` | `#DEDCD8` | hairlines |

**Typeface:** Outfit (Google Fonts, 100–800), one face throughout as in the
reference. The 100/200 weights carry the full-bleed wordmark; without them the
footer loses its whole character.

**Form:** `rounded-[28px]` on cards and images, `rounded-full` on pills,
`max-w-[1360px]` container, `py-24 sm:py-32` section rhythm.

## 2. Files

```
lib/emakola/themes/heirloom.ex                 # behaviour, defaults/0, delegates
lib/emakola/themes/heirloom/
  home.ex  product_list.ex  product_detail.ex  shared.ex
  sections/
    hero.ex  brand_story.ex  category_gallery.ex  our_story.ex
    team.ex  product_showcase.ex  clients.ex  faq.ex  newsletter.ex
```

Registration in **both** registries, or the storefront breaks:

- `ThemeResolver` — `"heirloom" => Emakola.Themes.Heirloom`
- `Sections.@sectionized_themes` — append `Emakola.Themes.Heirloom`

Heirloom's nav lives inside the hero section (same as Fashion, Beauty,
Electronics, HomeLiving), so a missing `Sections` entry costs the shop its
navigation entirely, not just one section. `SectionizedRegistrationTest`
holds this line.

## 3. Section mapping

Every section reads assigns already provided by
`EmakolaWeb.Storefront.StoreLive`: `:store`, `:theme`, `:products` (max 8,
variants loaded), `:categories`, `:testimonials`, `:page_content`.

| # | Section | Reference element | Real data source | Empty behaviour |
|---|---|---|---|---|
| 1 | `hero` | transparent nav, full-bleed photo, floating product card, room pills | `theme.hero.image_url`; card = first product, real name + `Money`-formatted price; pills = store categories | pills hidden under 2 categories; card hidden with no products |
| 2 | `brand_story` | scroll-reveal paragraph | `theme.brand_story.body`, neutral default | hidden when blank |
| 3 | `category_gallery` | overflowing cards, "12 GOODS / Kitchen" | real categories + real product counts | hidden with no categories |
| 4 | `our_story` | tab rail + overlapping images | `theme.our_story.tabs`, default `[]` | section vanishes |
| 5 | `team` | three member cards | `theme.team.items`, default `[]` | section vanishes |
| 6 | `product_showcase` | category tabs with counts + product row | real categories + products; variants drive sale/sold-out | hidden with no products |
| 7 | `clients` | testimonial bento + logo wall | testimonial via `Themes.Testimonial.list/1`; stockists via `theme.stockists.items`, default `[]` | each half hides independently |
| 8 | `faq` | two-column accordion | `ContentLoader.list(@page_content, :faq_items)` — the store's real FAQ | hidden when the store has no FAQ |
| 9 | `newsletter` | giant wordmark + dark footer | wordmark = actual store name | always renders |

### Empty-default keys are load-bearing

`theme.our_story.tabs`, `theme.team.items` and `theme.stockists.items` default
to `[]` but the keys **must exist** in `defaults/0`.
`ThemeResolver.deep_merge_atomize/2` drops any override whose key is absent
from the defaults, so deleting a key silently discards the content of every
merchant who filled it in. Same rule that guards `home_living`'s `sale_band`.

## 4. Deliberate departures from the reference

The reference is a visual mock and states things a real merchant has not.
These are the changes and their reasons:

- **"1 WEEK" badge → real sale / sold-out badge.** A hardcoded lead time is a
  delivery promise the merchant never made. Variants are already loaded on the
  home page, so the badge reflects genuine variant state instead.
- **"More than 200 clients from all over the world" → dropped.** No honest
  source exists for it.
- **`$999.59` / `$1299.00` → `Money` formatting.** Integer minor units, store
  currency (GHS default), formatted only in the presentation layer.
- **Named team members, Airbnb/WeWork/Ace Hotel logos, "three generations"
  brand story → merchant-supplied or absent.** These are precisely the
  fabricated-provenance pattern removed in PRs #321–328;
  `no_invented_provenance_test.exs`, `honest_testimonials_test.exs` and
  `honest_press_and_ugc_test.exs` run over every theme, including this one.

## 5. Responsive behaviour

The reference is desktop-only. Mobile is designed here, and this is a
mobile-first, low-bandwidth market:

- Hero stacks — headline, then product card, then CTAs. Nav collapses to the
  theme's existing mobile drawer pattern.
- Category gallery keeps horizontal scroll (native and cheap on mobile).
- Product showcase becomes a 2-up grid; category tabs scroll horizontally.
- FAQ collapses to a single column.
- Wordmark scales with `clamp()` so it bleeds edge-to-edge at every width.

The scroll-reveal paragraph uses CSS scroll-driven animation
(`animation-timeline: view()`), degrading to static full-opacity text where
unsupported. No JS, so nothing to break under LiveView DOM diffing — and no
CSS-checkbox state, per the project's LiveView guidance.

## 6. Inner pages

`product_list` is built in Heirloom's visual language at peer scope.

### 6a. Product detail — full capability

Kojo's ask: "do what a full PDP requires to function perfectly." An audit of
`ProductDetailLive` against all 20 existing themes found that **no theme wires
its full event set**, so "match a peer theme" is the wrong bar. Heirloom
implements every capability the LiveView actually supports.

`ProductDetailLive` exposes 12 events. Ownership splits cleanly:

**The theme must render these — all data is already in assigns:**

| Capability | Events / assigns | Themes doing it today |
|---|---|---|
| Image gallery | `select_image` (`index`), `prev_image`, `next_image`, `@current_image_index` | 20/20 partial — only Atelier has prev/next |
| Quantity stepper | `increment_quantity`, `decrement_quantity`, `@quantity` | 20/20 |
| Variant selection | `select_option`, `@option_types`, `@selected_options`, `@selected_variant` | 19/20 |
| Add to cart | `add_to_cart`, disabled on sold-out | 20/20 |
| Price / stock state | `@selected_variant` sale + compare-at, via `Money` | 20/20 |
| Related products | `@related_products` | 18/20 |
| Reviews | `ReviewComponents.review_section` — covers `set_review_rating`, `submit_review`, `validate_review`, `cancel_review_photo` incl. photo uploads, plus `@can_review` / `@already_reviewed` | 14/20 |
| Share | `StorefrontComponents.share_strip` — `share-product` with `platform` | 2/20 |
| **Delivery zones** | `@delivery_zones`, rendered through `Emakola.Themes.Delivery` | **0/20** |
| **Partner fulfillment** | `@partner_fulfillment` | **0/20** |

The last two are loaded on every product page and rendered by no theme at all.
Both are honest by construction — delivery info comes from the store's own
zones, not a theme default — so Heirloom renders them, and hides each when
its data is absent.

**Not the theme's job — do not build:**

- **Group buy.** `ProductDetailLive.render/1` renders the theme's output and
  then appends its own `group_buy` section (streams + `join_group_buy`).
  Every theme gets it free; a theme that rendered its own would double it.
  Its emerald-gradient styling will sit oddly against Heirloom's warm
  neutrals, but restyling it changes all 20 themes and is out of scope here.
- **SEO.** `json_ld`, `meta_description`, `og_image`, `page_title` are
  assigned by the LiveView and emitted by the layout.

### 6b. The variant-picker landmine

Option buttons **must** use:

```heex
phx-click="select_option"
phx-value-option_type_id={option_type.id}
phx-value-option_value_id={option_value.id}
```

Never `phx-value-value`. The browser overwrites that attribute with the
element's own `.value`, which is `""` on a `<button>` — it silently broke
variant selection on every theme at once. `EmakolaWeb.PhxValueCollisionTest`
guards it, and `product_detail_live.ex:108` carries the incident comment.

Storefront LiveViews have no catch-all `handle_event/3`, so a mistyped event
name crashes the page rather than no-opping. Event names are copied from the
handler heads, not from memory.

### 6c. Other pages

Optional callbacks (`about`, `contact`, `faq`, `policies`, cart, checkout,
blog, …) fall through to `DefaultRenderers`, as most themes do.

## 7. Testing

TDD per section. `test/emakola/themes/heirloom_sections_test.exs` mirrors
`home_living_sections_test.exs`:

- each section renders with representative data
- each section renders **nothing** in its empty state (the table above is the
  assertion list)
- prices render through `Money`, never as raw integers
- registration in both registries (covered by `SectionizedRegistrationTest`)
- the three provenance guards pick the theme up automatically

`test/emakola_web/live/storefront/heirloom_product_detail_test.exs` drives the
PDP through `ProductDetailLive` rather than rendering the theme module in
isolation — the only way to prove the wiring is real:

- each option-picker click changes `@selected_variant` (catches the
  `phx-value` collision, which no render-only test can see)
- gallery next/prev/select move `@current_image_index`
- quantity stepper bounds, add-to-cart, sold-out disabling
- review submission path renders via `review_section`
- delivery zones and partner fulfillment render when present, vanish when not

Success criteria: `mix test`, `mix format --check-formatted`, and
`mix credo --strict` all clean.

## 8. Out of scope

- A `heirloom-demo` seed store for click-through (dev DB only; can follow).
- Section-editor preview thumbnails.
- Any change to existing themes.
- Restyling the shared group-buy section (owned by `ProductDetailLive`,
  affects all 20 themes).
- Backporting delivery zones, partner fulfillment or `prev/next` gallery
  controls to the other 19 themes. The audit in §6a shows they're missing
  everywhere; worth a follow-up ticket, not this branch.
