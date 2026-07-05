# Storefront Theme Tokens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shared storefront components follow the merchant's theme via a CSS-variable contract; hardcoded hex is eliminated (token utilities or standard palette classes) behind a guardrail test.

**Architecture:** Bridge the existing `--theme-primary/accent/bg` runtime injection into the `--color-store-*` token family in `@theme` (with static fallbacks + `color-mix()` tints under `@supports`), harden the injection with a `safe_css_color/2` boundary, sweep the two component files, scope per-card vars on marketplace cards, pin it all with a source-scanning consistency test.

**Tech Stack:** Phoenix LiveView, Tailwind v4 (`@theme`, var-arbitrary utilities `from-(--x)`, `stroke-(--x)`), ExUnit.

**Spec:** `docs/superpowers/specs/2026-06-10-storefront-theme-tokens-design.md`
**Branch:** `design/storefront-theme-tokens` (off main)
**Gates per commit:** `mix test --seed 0` green · `mix format --check-formatted` · `MIX_ENV=test mix compile --warnings-as-errors` · `mix credo --strict` on changed files.

---

### Task 1: Token bridge + safe color boundary

**Files:**
- Modify: `assets/css/app.css` (the `--color-store-*` tokens in `@theme`; add a `@supports` tint block after `@theme`)
- Modify: `lib/emakola_web/components/layouts/storefront.html.heex` (~lines 63–79 injection)
- Create: `lib/emakola_web/helpers/css_color.ex` (`EmakolaWeb.Helpers.CssColor.safe_css_color/2`)
- Test: `test/emakola_web/helpers/css_color_test.exs`, plus a layout-injection assertion in an existing storefront LiveView test

Steps (TDD):
- [ ] Failing tests for `safe_css_color/2`: valid `"#B45309"`/`"#fff"`/8-digit hex pass through; `nil`, `"red;background:url(//evil)"`, `"</style><script>"`, `"url(x)"` → return the default argument.
- [ ] Implement: `def safe_css_color(value, default)` — `is_binary(value) and value =~ ~r/^#[0-9a-fA-F]{3,8}$/` → value, else default.
- [ ] `app.css`: re-point tokens (keep names/utilities working):
  `--color-store-accent: var(--theme-primary, #B45309);` · `--color-store-accent-light: var(--theme-accent-soft, #FEF3C7);` (keep `-light` as alias of the new `-soft` value) · `--color-cta-dark: var(--theme-accent, #1C1917);` · add `--color-store-bg: var(--theme-bg, #FAFAF9);`, `--color-store-accent-bright: #F59E0B;`, `--color-store-accent-soft: #FEF3C7;`. After the `@theme` block add:
  ```css
  @supports (color: color-mix(in srgb, red, white)) {
    :root {
      --color-store-accent-bright: color-mix(in srgb, var(--color-store-accent), white 35%);
      --color-store-accent-soft: color-mix(in srgb, var(--color-store-accent), white 85%);
    }
  }
  ```
  Check for pre-existing manual `.bg-store-accent`-style classes duplicating `@theme`-generated utilities — if both exist, keep behavior, remove exact duplicates only.
- [ ] Layout injection: wrap every interpolated color with `safe_css_color(..., default)`; assert in a storefront LiveView test that a store with `theme_config` primary `#123456` renders `--theme-primary: #123456` and a malicious value renders the default.
- [ ] Gates → commit `feat(themes): bridge store tokens to theme vars + safe CSS color boundary`.

### Task 2: `storefront_components.ex` sweep

**Files:** Modify `lib/emakola_web/components/storefront_components.ex`; update its tests if class assertions break (never delete).

- [ ] Inventory: `grep -nE '\-\[#|stroke="#|fill="#' lib/emakola_web/components/storefront_components.ex`
- [ ] Theme-followers → tokens: `#B45309`→`store-accent` utilities, `#F59E0B`→`(--color-store-accent-bright)` forms, `#FEF3C7`→`store-accent-light`/`(--color-store-accent-soft)`, `#1C1917`→`cta-dark`, `#FAFAF9`→`store-bg`. Gradient stops use `from-(--color-store-accent) to-(--color-store-accent-bright)`. SVG divider strokes/fills (`stroke="#B45309"` etc.) → `class="stroke-(--color-store-accent)"` (drop the presentation attr; Tailwind v4 CSS wins).
- [ ] Fixed chrome → standard palette classes per the inventory mapping (slate/stone exact matches); WhatsApp → existing `bg-whatsapp` token (+ add a `--color-whatsapp-dark: #1FAF55` token for the hovers); other social brands (facebook `#1877F2`, tiktok `#1F1F1F`, x `#0F1419`, instagram gradient ends) → named brand tokens added beside the payment brands in `@theme`.
- [ ] Gates + visual spot-check (`/s/tiny-stitches` + `/s/kente-kingdom` on :4002 render unchanged) → commit `refactor(themes): storefront components consume theme tokens, drop hardcoded hex`.

### Task 3: `stores_components.ex` sweep + per-card vars

**Files:** Modify `lib/emakola_web/components/stores_components.ex` (+ its tests as needed).

- [ ] The 4 inline-gradient call sites: card root gains `style={"--theme-primary: #{safe_css_color(theme_primary(@store), "#B45309")}; --theme-accent: #{safe_css_color(theme_accent(@store), "#1C1917")}"}`; the inner gradient/accent markup switches to `(--color-store-accent)`/`(--color-cta-dark)` forms. Behavior: identical tints, now via the shared contract.
- [ ] Fixed chrome → palette classes. Ghana-map art hexes (`#7A1F1F`, `#d4a843`, map fills) stay literal — they're pictorial.
- [ ] Gates + `/stores` visual check (per-store card tints intact) → commit `refactor(themes): marketplace cards on scoped theme vars`.

### Task 4: Guardrail + finish

**Files:** Create `test/emakola_web/storefront_design_consistency_test.exs`.

- [ ] Source-scanning test (mirror `AdminDesignConsistencyTest`): for the two component files, forbid `-[#` color classes and raw `#hex` inside `style=` strings, EXCEPT an explicit `@allowlist` (Ghana-map literals, listed individually with a comment). Plus: assert `storefront.html.heex` source contains `--theme-primary` (contract root) and `safe_css_color`.
- [ ] Full gates; push; PR `feat(themes): storefront components follow merchant theme (design-system sub-project 2)` with spec link + test plan; watch CI.

## Self-review
- Spec coverage: bridge (T1), tints (T1), security boundary (T1, consumed in T3), follower sweep (T2), chrome sweep (T2/T3), per-card vars (T3), allowlist + guardrail (T4). Out-of-scope respected (no theme modules).
- The `-light`→`-soft` aliasing keeps existing `bg-store-accent-light` call sites working while new code uses `-soft`.
