# Features Grid Redesign — Photo Cards with Color Badges

**Date:** 2026-06-12
**Status:** Approved design, pending implementation plan
**Parent spec:** `2026-06-11-landing-redesign-design.md` (this supersedes its "Features grid" section)
**Mockup reference:** `.superpowers/brainstorm/63294-1781220044/content/features-photo.html`, option A (gitignored session artifact)

## Goal

Replace the flat icon-card features grid ("Everything you need to sell") with photo-led,
color-coded, animated cards that communicate visually — many Emakola merchants read
little or no English, so each feature must be recognizable by picture and color alone.

## Decisions (made interactively with mockups)

1. **Photo-led** (chosen over icon discs, tinted cards, bold pictogram tiles, and
   full-bleed photo bento, all rejected): real photographs, consistent with the
   image-led hero/stories/store wall.
2. **One fixed color per feature**, same saturated palette as the low-literacy supplier
   pages (Tailwind `-500` family).
3. **Short plain titles** (one or two words) instead of compound titles.
4. **Subtle motion only**: staggered entrance, hover lift + photo zoom, colored badge
   glow. No looping animations.

## Card Anatomy

Each of the 9 cards (light `bg-[#f7f8fa]` card on the white section, `rounded-2xl`,
`overflow-hidden`):

1. **Photo** — `h-36 w-full object-cover` inside an `overflow-hidden` wrapper;
   `group-hover:scale-105` with `transition-transform duration-500`. `loading="lazy"`,
   explicit `width`/`height` (600×360), descriptive alt text.
2. **Icon badge** — `w-12 h-12 rounded-xl` in the feature color with white Material
   Symbol icon (`aria-hidden="true"`), pulled up over the photo edge (`-mt-6 relative
   ml-4`), colored glow (`shadow-lg shadow-<color>-500/40`).
3. **Title** — `text-base font-bold text-[#0c1526]`.
4. **Blurb** — one short line, `text-sm text-[#5f6b7a]`.

Card hover: `hover:-translate-y-1.5 hover:shadow-xl transition` on the card (`group`).

## Content Matrix

| # | Title | Blurb | Color | Icon | Photo |
|---|---|---|---|---|---|
| 1 | Dropshipping | Suppliers hold it, you sell it | violet-500 | warehouse | NEW `feature-dropship.jpg` — man pushing cart of boxes (Unsplash `1642756457381-930fdc1e2e2e`) |
| 2 | Themes | 14 beautiful looks for your store | rose-500 | palette | reuse `store-tailor.jpg` |
| 3 | Digital goods | Files delivered after payment | sky-500 | download | NEW `feature-digital.jpg` — woman at a laptop (Unsplash `1739300293504-234817eead52`) |
| 4 | Stock | Always know what is left | amber-500 | inventory_2 | NEW `feature-stock.jpg` — stacked yellow crates (Unsplash `1737219239970-4f2bea75b3d1`) |
| 5 | Delivery | Across all of Ghana | orange-500 | local_shipping | NEW `feature-delivery.jpg` — cargo motorcycle with goods (Unsplash `1762530179279-b9fbd4180b51`) |
| 6 | Discounts | Bring customers back | emerald-500 | percent | reuse `store-fruit.jpg` |
| 7 | Reports | See your sales clearly | indigo-500 | monitoring | NEW `feature-reports.jpg` — smiling woman using laptop (Unsplash `1615891081220-9116de3e1afd`) |
| 8 | Blog & recipes | Share posts and recipes | teal-500 | article | reuse `store-eggs.jpg` |
| 9 | Many stores | One account, one dashboard | pink-500 | storefront | reuse `cta-market.jpg` |

New images: download at 600×360 (`fit=crop`), q=70, target ≤100 KB each, into
`priv/static/images/landing/`.

Color classes are written as full literal Tailwind class strings in the data list
(e.g. `"bg-violet-500"`, `"shadow-violet-500/40"`) — never interpolated — so the
Tailwind scanner sees them.

## Animation

- **Entrance stagger:** cards keep `data-reveal` (existing ScrollReveal hook). A small
  `@layer components` rule scoped to the features grid adds incremental
  `transition-delay` per card (`#features [data-reveal]:nth-child(n)` steps of ~70ms,
  capped at 9).
- **Reduced motion:** the stagger rule and hover transforms sit inside the same
  `@media (prefers-reduced-motion: reduce)` discipline as the rotator — delays/transforms
  off, content always visible.
- Section heading/subcopy unchanged: "Everything you need to sell" / "The full toolkit,
  built for Ghana"; `id="features"` unchanged.

## Out of Scope

- All other landing sections, the pricing page, JSON-LD (feature names there are
  marketing-internal and unaffected), and the spec's "Backed by" claims table (the
  features still map to the same domain modules).

## Testing (TDD)

Update the existing `features grid` describe block in `landing_live_test.exs` FIRST:
- Asserts the 9 new short titles ("Dropshipping", "Themes", "Digital goods", "Stock",
  "Delivery", "Discounts", "Reports", "Blog &amp; recipes", "Many stores").
- Asserts the new image files are referenced (`feature-dropship.jpg`,
  `feature-delivery.jpg`, `feature-stock.jpg`, `feature-digital.jpg`,
  `feature-reports.jpg`).
- Keeps asserting "Everything you need to sell".
Then implement until green. Gate: landing + pricing scoped tests, `mix format`,
`mix credo --strict`. Work lands on the open PR #126 branch (`feature/landing-redesign`).
