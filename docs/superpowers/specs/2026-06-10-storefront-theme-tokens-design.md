# Storefront Theme Tokens — Design System Sub-project 2

**Date:** 2026-06-10 · **Status:** Approved · **Predecessor:** admin design system (PR #111)
**Scope:** `storefront_components.ex`, `stores_components.ex`, the storefront layout var injection, `app.css`. NOT the 14 theme modules (sub-project 3). NOT admin.

## Problem

Shared storefront components hardcode ~47 arbitrary-hex color classes (62 occurrences) and
4 inline-style gradients. They ignore the merchant's `theme_config` entirely — a store
that picks a blue theme still gets amber accents on product cards, category circles,
coupon banners, dividers. Inventory (2026-06-10) classified the values:

- **Theme-followers (5 values):** `#B45309` (accent, 10×), `#F59E0B` (bright accent, 8×),
  `#FEF3C7` (soft accent, 4×), `#1C1917` (dark CTA, 4×), `#FAFAF9` (bg, 2×).
- **Fixed chrome (~40 values):** almost all exact Tailwind palette matches
  (`#E2E8F0`=slate-200, `#475569`=slate-600, `#0F172A`=slate-900…) plus social-brand
  constants (WhatsApp/Facebook/TikTok/X/Instagram) and the Ghana-map art.
- **Already half-built:** the storefront layout (`storefront.html.heex` ~lines 63–79)
  already injects `--theme-primary/--theme-accent/--theme-bg` from the resolved `@theme`;
  themes with custom `theme_styles/1` (Atelier) re-declare those SAME var names later.
  `app.css` already has static `--color-store-accent/-light` and `--color-cta-dark`.
  Components consume NONE of it.

## Decisions

1. **Bridge, don't replace, the injection.** Keep `--theme-primary/accent/bg` as the
   runtime injection names (themes' override blocks keep working untouched). In `app.css`
   `@theme`, re-point the existing static tokens through them with fallbacks:
   ```css
   --color-store-accent: var(--theme-primary, #B45309);
   --color-cta-dark: var(--theme-accent, #1C1917);
   --color-store-bg: var(--theme-bg, #FAFAF9);          /* new token */
   ```
   Non-storefront pages (no `--theme-*` set) fall back to today's exact colors — zero
   visual change outside themed storefronts.
2. **Derived tints via `color-mix()` with progressive enhancement.** New tokens
   `--color-store-accent-bright` (≈ #F59E0B) and `--color-store-accent-soft` (≈ #FEF3C7,
   replaces/aliases `-light`): declare the static hex first, then override inside
   `@supports (color: color-mix(in srgb, red, white))` with
   `color-mix(in srgb, var(--color-store-accent), white 35%/85%)`. Old 3G-era browsers
   keep amber; modern browsers get theme-following tints automatically. No new theme
   schema keys.
3. **Consumption syntax:** Tailwind v4 utilities from the `@theme` tokens
   (`text-store-accent`, `bg-store-bg`, …) for plain uses; var-arbitrary forms for the
   rest: gradient stops `from-(--color-store-accent)`, SVG `stroke-(--color-store-accent)`
   / `fill-(--color-store-accent)`, rings `ring-(--color-store-accent)`.
4. **Fixed chrome → standard palette classes** (`border-slate-200` etc.); social brands →
   the existing brand tokens (`bg-whatsapp`) or literal brand hex WITH a named token added
   where reused (facebook, tiktok, x, instagram).
5. **Marketplace per-card theming** (`stores_components.ex`, used on `/stores` which has
   NO page-level theme): the 4 inline-gradient call sites set vars on the card element —
   `style={"--theme-primary: #{theme_primary(@store)}; --theme-accent: #{theme_accent(@store)}"}`
   — and the gradient/accent markup inside consumes `(--color-store-accent)` etc., which
   resolve through the locally-scoped `--theme-*`. Same contract, element-scoped.
6. **CSS-injection boundary (security):** theme colors are merchant-controlled input
   flowing into `<style>`/`style=` contexts. Every value interpolated into CSS MUST pass
   a strict hex validation (`~r/^#[0-9a-fA-F]{3,8}$/`) or fall back to the default —
   enforced in one place (a `safe_css_color/2` helper used by the layout injection AND
   the per-card var sites), with tests for malicious values
   (`"red;background:url(//evil)"`, `"</style><script>"` → fall back to default).
7. **Ghana-map art + any genuinely pictorial hex:** exempt by explicit allowlist.
7. **Guardrail:** new `StorefrontDesignConsistencyTest` (source-scanning, like the admin
   one): the two component files must contain no `-[#` arbitrary-hex color classes and no
   raw hex in `style=` outside the allowlist; plus an assertion that the storefront layout
   still injects `--theme-primary` (the contract's root).

## Verification

- Full suite green; format/credo/warnings-as-errors clean.
- Layout-injection test: rendered storefront layout for a store whose theme_config sets a
  custom primary contains that hex in the `--theme-primary` declaration.
- Manual: `/s/tiny-stitches` (default theme) renders identically; change a store's theme
  primary in theme_config → shared components follow it; `/stores` marketplace cards keep
  per-store tints; admin unaffected.
