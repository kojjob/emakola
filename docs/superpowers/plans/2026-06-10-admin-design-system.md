# Admin Design System v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One source of truth for admin styling — semantic tokens (emerald primary), canonical `admin_button`/`admin_card` components, an 8-page consistency sweep, and a regression-proof consistency test.

**Architecture:** Migrate the 6 files using legacy "Stitch" `--fp-*` utilities to literal classes first (no visual surprises), then delete Stitch and define clean semantic tokens in Tailwind v4 `@theme`. Build canonical components on those tokens (TDD), then sweep 8 admin page-units one commit each, guarded by a source-scanning consistency test (same pattern as `DefaultRendererConsistencyTest`).

**Tech Stack:** Phoenix 1.8 / LiveView, Tailwind v4 (CSS-first `@theme` config in `assets/css/app.css`), ExUnit.

**Spec:** `docs/superpowers/specs/2026-06-10-admin-design-system-design.md`
**Branch:** `design/admin-design-system` (already created off main)

**Gates for EVERY commit:** `mix test` green · `mix format --check-formatted` · `mix credo --strict` on changed files · no compile warnings (`MIX_ENV=test mix compile --warnings-as-errors`).

---

## Stitch-class → literal-class conversion table (used by Tasks 1a–1c)

Current light-mode values shown; map every occurrence per this table. The same utility maps differently in docs (preserve indigo look) vs everywhere else (brand cutover to emerald is desired).

| Stitch utility (light value) | docs_live.ex | All other files |
|---|---|---|
| `bg-primary` (#4648d4) | `bg-indigo-600` | `bg-emerald-600` |
| `text-primary` | `text-indigo-600` | `text-emerald-600` |
| `ring-primary` / `border-primary` | `ring-indigo-600` / `border-indigo-600` | `ring-emerald-600` / `border-emerald-600` |
| `bg-primary-container` (#6063ee) | `bg-indigo-500` | `bg-emerald-500` |
| `text-on-primary` (#fff) | `text-white` | `text-white` |
| `text-on-surface` (#191c1e) | `text-slate-900` | `text-slate-900` |
| `text-on-surface-variant` (#464554) | `text-slate-500` | `text-slate-500` |
| `text-on-background` | `text-slate-900` | `text-slate-900` |
| `bg-background` / `bg-surface` (#f7f9fb) | `bg-slate-50` | `bg-slate-50` |
| `bg-surface-container-lowest` (#fff) | `bg-white` | `bg-white` |
| `bg-surface-container-low` (#f2f4f6) | `bg-slate-100` | `bg-slate-100` |
| `bg-surface-container` (#eceef0) | `bg-slate-100` | `bg-slate-100` |
| `bg-surface-container-high(est)` | `bg-slate-200` | `bg-slate-200` |
| `bg-surface-variant` (#e0e3e5) | `bg-slate-200` | `bg-slate-200` |
| `border-outline` (#767586) | `border-slate-400` | `border-slate-400` |
| `border-outline-variant` (#c7c4d7) | `border-slate-300` | `border-slate-300` |
| `bg-error`/`text-error` (#ba1a1a) | `bg-red-600`/`text-red-600` | same |
| `bg-error-container` (#ffdad6) | `bg-red-100` | `bg-red-100` |
| `text-on-error` | `text-white` | `text-white` |
| `secondary`/`tertiary` family (ambers) | nearest `amber-600/700` per hex | same |
| `dark:*` variants of the above | drop the `dark:` variant entirely | drop entirely |

Anything not listed: map to the visually nearest slate/emerald/amber/red literal using the hex values in `app.css` lines 159–203 as reference.

---

### Task 1a: Migrate docs_live off Stitch utilities (preserve indigo look)

**Files:**
- Modify: `lib/emakola_web/live/docs/docs_live.ex` (62 occurrences)

- [ ] **Step 1: Inventory occurrences**

Run: `grep -nE "(bg|text|border|ring)-(primary|surface|on-surface|on-primary|on-background|outline|error|secondary|tertiary)[a-z-]*" lib/emakola_web/live/docs/docs_live.ex | wc -l`
Expected: ~62. Keep the numbered list open while editing.

- [ ] **Step 2: Replace per conversion table (docs column)**

Mechanical Edit calls — e.g. `text-on-surface-variant` → `text-slate-500` (31×, use replace_all), `text-primary` → `text-indigo-600` (10×), `text-on-surface` → `text-slate-900` (9×), `bg-primary` → `bg-indigo-600` (6×), `bg-surface-container` → `bg-slate-100` (4×), `ring-primary` → `ring-indigo-600`, `bg-surface-container-high` → `bg-slate-200`.
⚠️ Replace longer names FIRST (`text-on-surface-variant` before `text-on-surface`; `bg-surface-container-high` before `bg-surface-container`) so substring replacement can't corrupt them.

- [ ] **Step 3: Verify zero Stitch classes remain in the file**

Run: `grep -cE "(bg|text|border|ring)-(primary|surface|on-|outline)" lib/emakola_web/live/docs/docs_live.ex`
Expected: 0 (note: `text-indigo-600` etc. don't match this pattern).

- [ ] **Step 4: Gates + commit**

Run: `mix test test/emakola_web/live/docs --seed 0 2>/dev/null || mix test --seed 0` then `mix format && mix format --check-formatted`
```bash
git add lib/emakola_web/live/docs/docs_live.ex
git commit -m "refactor(docs): replace Stitch utility classes with literal indigo/slate"
```

### Task 1b: Migrate core_components, layouts, skeleton off Stitch utilities

**Files:**
- Modify: `lib/emakola_web/components/core_components.ex` (33+ Stitch + bare `bg-primary` uses)
- Modify: `lib/emakola_web/components/layouts.ex` (2 + bare uses)
- Modify: `lib/emakola_web/components/skeleton.ex` (11 uses)

- [ ] **Step 1: Inventory per file** (same grep as Task 1a Step 1, per file)

- [ ] **Step 2: Replace per conversion table ("other files" column — emerald cutover)**

Same longest-first mechanic. `bg-primary`→`bg-emerald-600`, `text-on-primary`→`text-white`, `hover:bg-primary-container`→`hover:bg-emerald-500`, surfaces→slate per table. This intentionally recolors the core `button`/inputs from indigo to brand emerald (auth pages inherit the fix).

- [ ] **Step 3: Verify zero remaining** — run the Task 1a Step 3 grep against each of the 3 files; expect 0.

- [ ] **Step 4: Gates + commit**

Run: `mix test --seed 0` (full — core_components is used everywhere). Expected: 0 failures; if a test asserts an old class string, update that assertion in the same commit.
```bash
git add lib/emakola_web/components/core_components.ex lib/emakola_web/components/layouts.ex lib/emakola_web/components/skeleton.ex
git commit -m "refactor(web): core components on literal emerald/slate, off Stitch tokens"
```

### Task 1c: Migrate admin product pages off Stitch utilities

**Files:**
- Modify: `lib/emakola_web/live/admin/product_live/index.ex` (26 uses)
- Modify: `lib/emakola_web/live/admin/product_live/form.ex` (15 uses)

- [ ] **Step 1–3:** Same inventory → replace ("other files" column) → zero-check as Task 1b.
- [ ] **Step 4: Gates + commit**

Run: `mix test test/emakola_web/live/admin --seed 0 && mix test --seed 0`
```bash
git add lib/emakola_web/live/admin/product_live/
git commit -m "refactor(admin): product pages on literal emerald/slate, off Stitch tokens"
```

### Task 2: Delete Stitch, define semantic tokens

**Files:**
- Modify: `assets/css/app.css`

- [ ] **Step 1: Confirm zero Stitch-utility consumers remain**

Run: `grep -rE "(bg|text|border|ring)-(on-surface|on-primary|on-background|surface-container|surface-variant|surface-tint|surface-dim|surface-bright|outline|inverse-|primary-fixed|primary-container|on-error|error-container|on-secondary|secondary-fixed|tertiary)" lib/ --include="*.ex" --include="*.heex" | wc -l`
Expected: 0. If not 0 → finish Tasks 1a–1c first.

- [ ] **Step 2: Delete the Stitch blocks in `app.css`**

Delete entirely:
- the `:root { --fp-... }` dark block (lines ~114–157)
- the `html:not(.dark) { --fp-... }` light block (lines ~160–203)
- every `--color-*: var(--fp-*)` line inside `@theme` (lines ~235–276)
- the unused chart block (`--fp-chart-*`, both `:root` and `html:not(.dark)`, lines ~297–305)

KEEP: the `@layer components` editorial utilities; the Emakola brand tokens (`--color-emakola-*`, `--color-store-accent*`, `--color-cta-dark`, payment colors); the font tokens.

- [ ] **Step 3: Add the semantic token set inside `@theme`** (above the brand tokens)

```css
  /* ── Emakola semantic tokens (Design System v1) ── */
  /* Actions */
  --color-primary: #059669;        /* emerald-600 — every primary action */
  --color-primary-hover: #047857;  /* emerald-700 */
  --color-primary-soft: #ECFDF5;   /* emerald-50 — soft bg, selected states */
  /* Accent (demoted: financial highlights, ratings only) */
  --color-accent-gold: #CA8A04;
  /* Neutrals */
  --color-surface: #FFFFFF;
  --color-surface-subtle: #F8FAFC; /* slate-50 */
  --color-border: #E2E8F0;         /* slate-200 */
  --color-text: #0F172A;           /* slate-900 */
  --color-text-muted: #64748B;     /* slate-500 */
  /* Status */
  --color-success: #059669;  --color-success-soft: #ECFDF5;
  --color-warning: #D97706;  --color-warning-soft: #FEF3C7;
  --color-danger:  #DC2626;  --color-danger-soft:  #FEE2E2;
  --color-info:    #2563EB;  --color-info-soft:    #EFF6FF;
  /* Shape */
  --radius-control: 0.75rem;  /* buttons, inputs */
  --radius-card: 1rem;        /* cards, modals */
```

- [ ] **Step 4: Fix the direct `var(--fp-*)` consumers in app.css**

```css
/* ── Body base ── */
body {
  background-color: var(--color-surface-subtle);
  color: var(--color-text);
}

/* ── Selection ── */
::selection {
  background-color: rgb(5 150 105 / 0.2);
  color: var(--color-primary-hover);
}
```

- [ ] **Step 5: Verify no `--fp-` references remain anywhere**

Run: `grep -rn "fp-" assets/css/ lib/ --include="*.css" --include="*.ex" --include="*.heex" | grep -v "_build" | wc -l`
Expected: 0.

- [ ] **Step 6: Rebuild assets + full gates**

Run: `mix assets.build && mix test --seed 0`
Expected: compile + suite green. Manually load `/dashboard` and `/docs` (`mix phx.server`) — pages render with white/slate surfaces, emerald (or indigo on docs) accents, nothing unstyled/transparent.

- [ ] **Step 7: Commit**

```bash
git add assets/css/app.css
git commit -m "feat(design): replace Stitch system with Emakola semantic tokens"
```

### Task 3: `admin_button` component (TDD)

**Files:**
- Test: `test/emakola_web/components/admin_components_test.exs` (create if absent)
- Modify: `lib/emakola_web/components/admin_components.ex`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule EmakolaWeb.AdminComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias EmakolaWeb.AdminComponents

  describe "admin_button/1" do
    test "primary md renders token classes and content" do
      html =
        render_component(&AdminComponents.admin_button/1, %{
          inner_block: inner("Save changes")
        })

      assert html =~ "bg-primary"
      assert html =~ "hover:bg-primary-hover"
      assert html =~ "rounded-control"
      assert html =~ "px-4 py-2.5"
      assert html =~ "Save changes"
      assert html =~ ~s(type="button")
    end

    test "secondary variant renders bordered white button" do
      html =
        render_component(&AdminComponents.admin_button/1, %{
          variant: :secondary,
          inner_block: inner("Cancel")
        })

      assert html =~ "bg-surface"
      assert html =~ "border-border"
      refute html =~ "bg-primary"
    end

    test "danger variant renders danger tokens" do
      html =
        render_component(&AdminComponents.admin_button/1, %{
          variant: :danger,
          inner_block: inner("Delete")
        })

      assert html =~ "bg-danger"
    end

    test "sm size renders compact padding" do
      html =
        render_component(&AdminComponents.admin_button/1, %{
          size: :sm,
          inner_block: inner("Edit")
        })

      assert html =~ "px-3 py-1.5"
    end

    test "passes through global attrs (phx-click, disabled, type)" do
      html =
        render_component(&AdminComponents.admin_button/1, %{
          type: "submit",
          "phx-click": "save",
          disabled: true,
          inner_block: inner("Go")
        })

      assert html =~ ~s(type="submit")
      assert html =~ ~s(phx-click="save")
      assert html =~ "disabled"
    end
  end

  defp inner(text) do
    [%{inner_block: fn _, _ -> text end, __slot__: :inner_block}]
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/components/admin_components_test.exs`
Expected: FAIL — `admin_button/1 is undefined`.

- [ ] **Step 3: Implement in `admin_components.ex`**

```elixir
  @doc """
  Canonical admin button. The ONLY way to render a button in swept admin pages.

      <.admin_button phx-click="save">Save changes</.admin_button>
      <.admin_button variant={:secondary} size={:sm}>Cancel</.admin_button>
  """
  attr :variant, :atom, default: :primary, values: [:primary, :secondary, :danger]
  attr :size, :atom, default: :md, values: [:md, :sm]
  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def admin_button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center gap-2 font-semibold transition-colors",
        "rounded-control disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer",
        button_size(@size),
        button_variant(@variant),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_size(:md), do: "px-4 py-2.5 text-sm"
  defp button_size(:sm), do: "px-3 py-1.5 text-xs"

  defp button_variant(:primary), do: "bg-primary hover:bg-primary-hover text-white"

  defp button_variant(:secondary),
    do: "bg-surface hover:bg-surface-subtle text-text border border-border"

  defp button_variant(:danger), do: "bg-danger hover:bg-red-700 text-white"
```

- [ ] **Step 4: Run tests** — `mix test test/emakola_web/components/admin_components_test.exs` → PASS (5 tests).

- [ ] **Step 5: Gates + commit**

```bash
git add lib/emakola_web/components/admin_components.ex test/emakola_web/components/admin_components_test.exs
git commit -m "feat(design): canonical admin_button component (TDD)"
```

### Task 4: `admin_card` component (TDD)

**Files:**
- Test: `test/emakola_web/components/admin_components_test.exs`
- Modify: `lib/emakola_web/components/admin_components.ex`

- [ ] **Step 1: Add failing tests**

```elixir
  describe "admin_card/1" do
    test "renders the canonical container with content" do
      html =
        render_component(&AdminComponents.admin_card/1, %{
          inner_block: inner("Card body")
        })

      assert html =~ "bg-surface"
      assert html =~ "rounded-card"
      assert html =~ "border-border"
      assert html =~ "shadow-sm"
      assert html =~ "p-6"
      assert html =~ "Card body"
    end

    test "padding: :none drops the default padding" do
      html =
        render_component(&AdminComponents.admin_card/1, %{
          padding: :none,
          inner_block: inner("Table here")
        })

      refute html =~ "p-6"
    end
  end
```

- [ ] **Step 2: Run** → FAIL (`admin_card/1 undefined`).

- [ ] **Step 3: Implement**

```elixir
  @doc """
  Canonical admin card container.

      <.admin_card>…</.admin_card>
      <.admin_card padding={:none}>full-bleed table</.admin_card>
  """
  attr :padding, :atom, default: :default, values: [:default, :none]
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def admin_card(assigns) do
    ~H"""
    <div
      class={[
        "bg-surface rounded-card border border-border shadow-sm",
        @padding == :default && "p-6",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
```

- [ ] **Step 4: Run** → PASS. **Step 5: Commit**

```bash
git add lib/emakola_web/components/admin_components.ex test/emakola_web/components/admin_components_test.exs
git commit -m "feat(design): canonical admin_card component (TDD)"
```

### Task 5: Repaint `admin_page_header` + `status_pill` onto tokens

**Files:**
- Modify: `lib/emakola_web/components/admin_components.ex`

- [ ] **Step 1: Inventory raw colors in the module**

Run: `grep -nE "emakola-gold|emerald-[0-9]|slate-[0-9]|#[0-9A-Fa-f]{3,6}" lib/emakola_web/components/admin_components.ex`

- [ ] **Step 2: Replace** — the `bg-emakola-gold` CTA in `admin_page_header` becomes an `<.admin_button>` call (primary, md). All other raw colors map: `emerald-600`→`primary`, `emerald-700`→`primary-hover`, `emerald-50`→`primary-soft`, `slate-900`→`text`, `slate-500`→`text-muted`, `slate-200`→`border`, `slate-50`→`surface-subtle`, `white`→`surface`, amber/red/blue status colors → `warning/danger/info(-soft)` tokens. `rounded-xl`→`rounded-control`, `rounded-2xl`→`rounded-card`. Status pills keep `rounded-full`.

- [ ] **Step 3: Verify zero raw colors**

Run: `grep -cE "emakola-gold|emerald-[0-9]|slate-[0-9]|#[0-9A-Fa-f]{6}" lib/emakola_web/components/admin_components.ex`
Expected: 0.

- [ ] **Step 4: Full gates** (`mix test --seed 0` — header is used across the admin) **+ commit**

```bash
git add lib/emakola_web/components/admin_components.ex
git commit -m "refactor(design): admin_components on semantic tokens; gold CTA -> emerald"
```

### Task 6: Consistency-test guardrail

**Files:**
- Create: `test/emakola_web/admin_design_consistency_test.exs`

- [ ] **Step 1: Write the test (passes immediately — `@swept` starts empty)**

```elixir
defmodule EmakolaWeb.AdminDesignConsistencyTest do
  @moduledoc """
  Pins the admin design system. Swept pages must use canonical components
  (admin_button/admin_card/status_pill) instead of hand-rolled markup.
  Pages join @swept as they are converted; the list only grows.
  """
  use ExUnit.Case, async: true

  @admin_dir "lib/emakola_web/live"

  # Page files converted to the design system (paths relative to @admin_dir)
  @swept ~w()

  # Raw classes forbidden in swept files — use the canonical components/tokens.
  @forbidden ~w(bg-emerald-600 bg-emerald-700 bg-emakola-gold rounded-2xl rounded-xl)

  test "swept admin pages contain no hand-rolled design classes" do
    for rel <- @swept do
      source = File.read!(Path.join(@admin_dir, rel))

      for cls <- @forbidden do
        refute source =~ cls,
               "#{rel} contains raw `#{cls}` — use admin_button/admin_card/" <>
                 "status_pill or semantic tokens (see docs/superpowers/specs/" <>
                 "2026-06-10-admin-design-system-design.md)"
      end
    end
  end

  test "the Stitch token system stays dead" do
    hits =
      Path.wildcard("lib/**/*.{ex,heex}")
      |> Enum.filter(fn f ->
        File.read!(f) =~ ~r/(bg|text|border|ring)-(on-surface|surface-container)/
      end)

    assert hits == [], "Stitch-derived classes reappeared in: #{inspect(hits)}"
  end
end
```

- [ ] **Step 2: Run** → PASS (2 tests). **Step 3: Commit**

```bash
git add test/emakola_web/admin_design_consistency_test.exs
git commit -m "test(design): admin design-system consistency guardrail"
```

### Tasks 7–14: Page sweep (one task per page-unit, identical recipe)

| Task | Page-unit | Files (Modify) | `@swept` entries to add |
|---|---|---|---|
| 7 | Dashboard | `lib/emakola_web/live/dashboard_live.ex` | `dashboard_live.ex` |
| 8 | Products index | `lib/emakola_web/live/admin/product_live/index.ex` | `admin/product_live/index.ex` |
| 9 | Orders | `lib/emakola_web/live/admin/order_live/index.ex`, `.../show.ex` | both |
| 10 | Inventory | `lib/emakola_web/live/admin/inventory_live.ex` | `admin/inventory_live.ex` |
| 11 | Suppliers | `lib/emakola_web/live/admin/supplier_live/index.ex`, `.../show.ex` | both |
| 12 | Settings | `lib/emakola_web/live/admin/settings_live.ex` | `admin/settings_live.ex` |
| 13 | Theme | `lib/emakola_web/live/admin/theme_live.ex` | `admin/theme_live.ex` |
| 14 | Coupons | `lib/emakola_web/live/admin/coupon_live.ex` | `admin/coupon_live.ex` |

**Recipe for each task (all steps required, in order):**

- [ ] **Step 1: Inventory the page's offenders**

Run (substitute FILE):
`grep -nE "bg-emerald-[0-9]+|bg-emakola-gold|rounded-(xl|2xl|lg)|<button" FILE | head -60`

- [ ] **Step 2: Convert buttons** — every hand-rolled `<button class="…bg-emerald-600…">Label</button>` (or gold) becomes:

```heex
<.admin_button phx-click="the_existing_event" phx-value-id={@the_existing_value}>
  Label
</.admin_button>
```

Preserve ALL existing `phx-*`/`type`/`form`/`disabled` attrs verbatim; pick `variant={:secondary}` for white/bordered buttons, `variant={:danger}` for red destructive ones, `size={:sm}` where current padding is `px-3 py-1.5` or smaller. Do NOT rename events or change layout.

- [ ] **Step 3: Convert cards** — `<div class="bg-white rounded-2xl border border-slate-200 shadow-sm p-6">` (and close variants) become `<.admin_card>`; variants wrapping full-bleed tables use `<.admin_card padding={:none}>` with the table's own padding preserved.

- [ ] **Step 4: Convert badges & empty states** — inline status spans (rounded-full + status colors) become `<.status_pill>` with the page's existing status atom; hand-rolled "no records" divs become `<.empty_state>` (keep the page's copy). On Task 14 specifically: delete `coupon_live`'s private badge helper (~lines 705–756) after replacing its call sites.

- [ ] **Step 5: Remaining raw colors in the page** — map per Task 5 Step 2's token table (`slate-500`→`text-muted` etc.). Any `rounded-xl/2xl` left after Steps 2–3 → `rounded-control`/`rounded-card`.

- [ ] **Step 6: Add the page to `@swept`** in `test/emakola_web/admin_design_consistency_test.exs`.

- [ ] **Step 7: Gates**

Run: `mix test test/emakola_web/admin_design_consistency_test.exs && mix test --seed 0 && mix format --check-formatted`
Expected: consistency test green WITH the new entry; full suite green (update any test that asserted replaced class strings — assert on the new canonical markup, never delete the test).

- [ ] **Step 8: Visual check** — `mix phx.server`, load the page at 375px and desktop; buttons/cards/pills look uniform; touch targets ≥ previous size.

- [ ] **Step 9: Commit (one per page-unit)**

```bash
git add <files> test/emakola_web/admin_design_consistency_test.exs
git commit -m "refactor(admin): <page> on design-system components"
```

### Task 15: Final verification + PR

- [ ] **Step 1: Repo-wide gates**

```bash
mix test --seed 0                     # 0 failures
mix format --check-formatted
mix credo --strict
grep -rn "fp-\|surface-container\|on-surface" lib/ assets/css/ | wc -l   # 0
grep -rn "bg-emakola-gold" lib/emakola_web/live/ lib/emakola_web/components/admin_components.ex | wc -l  # 0
```

- [ ] **Step 2: Visual sweep** — all 8 pages + `/docs` + `/auth/login` at mobile + desktop.

- [ ] **Step 3: Push + PR**

```bash
git push -u origin design/admin-design-system
gh pr create --base main --title "feat(design): admin design system v1 — semantic tokens + canonical components" \
  --body "Spec: docs/superpowers/specs/2026-06-10-admin-design-system-design.md. Tokens (emerald primary, Stitch deleted), admin_button/admin_card, 8-page sweep, consistency guardrail."
```

Watch CI to green.

---

## Self-review notes

- Spec coverage: tokens (T2), Stitch migration+deletion (T1a–c, T2), admin_button (T3), admin_card (T4), repaint header/pill (T5), coupon badge absorption (T14 Step 4), guardrail (T6), 8-page sweep (T7–14), out-of-scope respected (no storefront/theme/dark-mode tasks).
- The audit's "34 Stitch uses" was an undercount; reality is ~150 across 6 files — hence Tasks 1a–1c before token cutover (no silent recolors, every commit green).
- `--rounded-control/card` utilities come from Tailwind v4's `--radius-*` namespace; verified naming against v4 conventions.
- `inner/1` helper in tests builds a minimal slot; `render_component/2` accepts function components with slots in LiveViewTest.
