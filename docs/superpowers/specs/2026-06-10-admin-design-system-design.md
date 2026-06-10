# Emakola Design System v1 — Foundation + Admin Consistency

**Date:** 2026-06-10
**Status:** Approved design, pending implementation plan
**Scope:** Sub-project 1 of 3 (this spec). Later: storefront tokenization (62 hardcoded
hex values in storefront components), theme-system completion (DesignTokens/FontLoader
across all themes). Those are explicitly out of scope here.

## Problem

The merchant admin grew fast and shows it. Evidence from the audit (2026-06-10):

- **Primary CTA color is split**: most pages use `bg-emerald-600`, but
  `admin_components.admin_page_header` renders its CTA in `bg-emakola-gold` — the
  Products page button is gold while Suppliers is emerald.
- **Shape is inconsistent**: `rounded-xl` on ~56 controls vs `rounded-lg` on ~23,
  with ad-hoc padding (`px-3 py-1.5` / `px-4 py-2` / `px-5 py-2.5`) page to page.
- **Tokens are fragmented**: a legacy "Stitch" `--fp-*` variable system (FounderPad
  era, dark/light wiring) has only ~34 uses, against ~1,204 hardcoded `slate-*`
  classes. Two token vocabularies plus raw utilities — no source of truth.
- **Components are duplicated**: buttons, status badges, and empty states each have
  several competing implementations (e.g. `coupon_live` re-rolls `status_pill` inline).

## Decisions (locked with product owner, 2026-06-10)

| Decision | Choice |
|---|---|
| Primary action color | **Emerald `#059669`** (per BRAND.md); hover `#047857`; soft `#ECFDF5` |
| Gold `#CA8A04` | Demoted to accent: financial highlights, ratings — never primary CTAs |
| Shape & density | **Soft & roomy**: `rounded-xl` controls, `rounded-2xl` cards, generous padding (mobile-first touch targets) |
| Token strategy | **Clean semantic tokens** in Tailwind v4 `@theme`; delete the Stitch `--fp-*` system after migrating its ~34 uses |
| Sweep scope | **Canonical components + 8 top pages**; remaining pages convert opportunistically |
| Typography | Unchanged: Manrope (headings), Inter (body), JetBrains Mono (mono) |
| Dark mode | Not built now; semantic tokens keep it possible later |

## 1. Token layer (`assets/css/app.css`)

Define in `@theme` (Tailwind v4 CSS-first config), replacing the Stitch block:

```css
/* Actions */
--color-primary: #059669;        /* emerald-600 — every primary action */
--color-primary-hover: #047857;  /* emerald-700 */
--color-primary-soft: #ECFDF5;   /* emerald-50 — soft backgrounds, selected states */

/* Accent (demoted) */
--color-accent-gold: #CA8A04;    /* financial highlights, star ratings only */

/* Neutrals (mapped to slate) */
--color-surface: #FFFFFF;
--color-surface-subtle: #F8FAFC; /* slate-50 — page bg, table header bg */
--color-border: #E2E8F0;         /* slate-200 */
--color-text: #0F172A;           /* slate-900 */
--color-text-muted: #64748B;     /* slate-500 */

/* Status */
--color-success: #059669;  --color-success-soft: #ECFDF5;
--color-warning: #D97706;  --color-warning-soft: #FEF3C7;
--color-danger:  #DC2626;  --color-danger-soft:  #FEE2E2;
--color-info:    #2563EB;  --color-info-soft:    #EFF6FF;

/* Shape */
--radius-control: 0.75rem;  /* rounded-xl — buttons, inputs, selects */
--radius-card: 1rem;        /* rounded-2xl — cards, modals, panels */
```

Rules:
- Tailwind v4 generates utilities from these (`bg-primary`, `text-text-muted`,
  `rounded-control`, …). New/swept admin code uses semantic utilities; raw
  `emerald-*`/`slate-*` utilities are allowed only outside swept surfaces.
- The Stitch `--fp-*` variables, their `html:not(.dark)` overrides, and the `@theme`
  mappings derived from them are **deleted**. Their ~34 call-sites migrate to the new
  tokens in the same change (grep-able: `bg-surface-container`, `text-on-surface*`, etc.).
- Existing brand tokens that remain useful (`--color-emakola-emerald` sidebar ink,
  payment brand colors, `--color-store-accent` for storefront) are kept untouched.
- Custom rules stay inside `@layer components` (existing project rule — unlayered CSS
  outranks utilities in Tailwind v4).

## 2. Canonical components (extend `lib/emakola_web/components/admin_components.ex`)

No new module — `admin_components.ex` is already the admin's home. Add/normalize:

| Component | Contract | Notes |
|---|---|---|
| `admin_button` | `variant: :primary \| :secondary \| :danger`, `size: :md \| :sm`, standard btn attrs + inner block | THE only way to render an admin button. `:primary` = `bg-primary hover:bg-primary-hover text-white`; `:secondary` = white + border; `:danger` = `bg-danger`. md = `px-4 py-2.5 text-sm font-semibold rounded-control`; sm = `px-3 py-1.5` |
| `admin_card` | slot-based container | `bg-surface rounded-card border border-border shadow-sm` + standard padding; replaces the hand-rolled `bg-white rounded-2xl …` divs |
| `status_pill` | keep existing API | Absorb `coupon_live`'s inline duplicate; stays `rounded-full` |
| `admin_page_header` | keep existing API | CTA repainted gold → `admin_button :primary` |
| `empty_state` | keep existing API | Adopted on swept pages instead of hand-rolled centered divs |

All components use semantic tokens only — zero raw `emerald-*`/`slate-*`/hex inside
`admin_components.ex` when done.

## 3. Page sweep (8 pages)

Mechanical conversion — markup only, no layout redesign, no behavior change:

1. `dashboard_live.ex`
2. `admin/product_live/index.ex`
3. `admin/order_live/index.ex` + `show.ex` (counted as one page-unit)
4. `admin/inventory_live.ex`
5. `admin/supplier_live/index.ex` + `show.ex` (one page-unit)
6. `admin/settings_live.ex`
7. `admin/theme_live.ex`
8. `admin/coupon_live.ex`

Per page: hand-rolled buttons → `admin_button`; card divs → `admin_card`; inline
badges → `status_pill`; empty divs → `empty_state`; remaining raw colors in swept
markup → semantic utilities. Each page is one commit, independently revertible.

## 4. Guardrail — consistency test

`test/emakola_web/admin_design_consistency_test.exs`, same source-scanning pattern as
the proven `DefaultRendererConsistencyTest`:

- Maintains a `@swept` list of admin LiveView files.
- Asserts swept files contain no raw button markup (`bg-emerald-600`,
  `bg-emakola-gold`, `bg-primary` on a literal element with padding classes) — they
  must call `admin_button`.
- Asserts swept files contain no `--fp-*`-derived classes (`bg-surface-container`,
  `text-on-surface`) anywhere in the repo after migration.
- New pages join `@swept` as they're converted; the list only grows.

## 5. Testing & verification

- TDD on components: render tests for `admin_button` (variants/sizes/disabled) and
  `admin_card` before implementation.
- Existing LiveView tests stay green — the sweep is markup-only; any test asserting a
  specific class string is updated deliberately in the same commit as its page.
- Full gate per page-commit: `mix test`, `mix format --check-formatted`,
  `mix credo --strict`.
- Visual pass: manual review of the 8 pages at mobile width (375px) and desktop —
  most Ghanaian merchants are on phones; touch targets must not shrink.
- `grep -c "fp-\|surface-container\|on-surface"` returns 0 in `lib/` when done.

## Build order

1. Tokens (app.css): add semantic set, migrate 34 Stitch uses, delete Stitch block → suite green.
2. Components: `admin_button` + `admin_card` (TDD), repaint `admin_page_header`/`status_pill` → suite green.
3. Consistency test scaffold with empty `@swept` list.
4. Pages 1–8, one commit each, adding each to `@swept` as it lands.

## Out of scope

- Storefront component tokenization (sub-project 2)
- Theme-system DesignTokens/FontLoader completion (sub-project 3)
- Dark mode implementation
- Any layout/UX redesign of admin pages (this is consistency, not redesign)
- The remaining ~17 admin pages (convert opportunistically; guardrail list grows with them)
