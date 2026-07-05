# Launch Steps Redesign — Photo Step Cards with Number Badges

**Date:** 2026-06-12
**Status:** Approved design (mockup approved in visual companion), pending plan
**Parent:** extends `2026-06-12-features-grid-redesign-design.md`; supersedes the
"Launch in 3 steps" section of the landing spec.
**Mockup:** `.superpowers/brainstorm/63294-1781220044/content/launch-steps.html`

## Goal

Give "Launch before lunch" the same photo-led, color-coded, animated card language as
the redesigned features grid, with sequence-specific touches so the 1→2→3 order reads
without words.

## Design

Same card anatomy as the features grid (photo `h-36` with `group-hover:scale-105`,
badge `-mt-6` overlapping the photo, title, one short line), with two differences:

1. **Number badges, not icons** — `w-12 h-12 rounded-xl` badges contain `01` / `02` /
   `03` (`font-headline font-extrabold`), colored sky-500 → violet-500 → emerald-500
   (green lands on "Get paid"). Same colored glow shadows.
2. **Animated arrow connectors** — gold `arrow_forward` Material icons
   (`aria-hidden="true"`) between cards on `md:`+ screens, nudging forward via a small
   looping keyframe (`@layer components`, disabled under `prefers-reduced-motion`).
   On mobile the cards stack; arrows rotate to point downward (`rotate-90`) and center
   between stacked cards.

## Content Matrix

| # | Title | Blurb | Badge | Photo |
|---|---|---|---|---|
| 01 | Add your first product | Snap it, price it, done | sky-500 | NEW `step-add-product.jpg` — merchant photographing/arranging her goods |
| 02 | Share your store link | WhatsApp it to your customers | violet-500 | NEW `step-share-link.jpg` — two people looking at / sharing a phone screen |
| 03 | Get paid with MoMo | Money straight to your wallet | emerald-500 | NEW `step-get-paid.jpg` — merchant receiving a mobile money payment on her phone |

Photos sourced from Unsplash at implementation time against those briefs (600×360,
q≈70, ≤100 KB, descriptive alt). Exact photo IDs are chosen during implementation
because the briefs are specific; the implementer verifies each image matches its brief
before committing.

## Animation

- Cards reuse the existing `.features-grid` stagger CSS. To keep the class honest it is
  **renamed `stagger-grid`** in the same change (CSS selectors + the features grid
  markup + this section's markup + the features test assertion).
- Arrow nudge: `@keyframes step-arrow-nudge { 0%,100% translateX(0); 50% translateX(5px) }`,
  1.6s loop, `prefers-reduced-motion: reduce` → `animation: none`.
- Card hover: identical to features grid (`hover:-translate-y-1.5 hover:shadow-xl`,
  photo zoom).

## Layout

Container `md:flex` row: card / arrow / card / arrow / card (`items-stretch`, arrows
`self-center shrink-0`). Mobile: column with arrows `rotate-90 self-center`.
Section keeps heading "Launch before lunch", subcopy "Most merchants go live in under
an hour.", and its white→`#f7f8fa` background as today.

## Testing (TDD)

Update the `launch steps` describe in `landing_live_test.exs` first:
- Keeps: "Launch before lunch", the three step titles.
- Adds: the three new blurbs, `step-add-product.jpg`/`step-share-link.jpg`/
  `step-get-paid.jpg` referenced, `stagger-grid` present, badge `bg-sky-500` present.
- Features test assertion updated `features-grid` → `stagger-grid`.

## Out of Scope

Everything else on the page; the final CTA; pricing page.
