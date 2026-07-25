# Akwaaba Variant Picker (P0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore variant selection on the Akwaaba theme, and close the hole in
the guard test that let its absence pass CI.

**Architecture:** Akwaaba's `product_detail.ex` reads `@selected_variant` for
price, sale price and purchasability, but renders no option picker, so
`@selected_variant` is frozen at its mount-time default. `add_to_cart` reads
that same assign — so on a product with variants, only the default variant is
purchasable and no other can ever be chosen. The existing
`EmakolaWeb.Storefront.VariantPickerTest` loops over every theme but wraps its
assertions in `if html =~ ~s(phx-click="select_option")`, so a theme with no
picker at all skips every assertion and passes. Close the test hole first
(red), then add the picker (green).

**Tech Stack:** Elixir 1.20, Phoenix LiveView, ExUnit, TailwindCSS.

## Global Constraints

- Branch off `main`: `fix/akwaaba-variant-picker`. This ships on its own, ahead
  of the Heirloom and parity work.
- Option buttons MUST send `phx-value-option_type_id` and
  `phx-value-option_value_id`. NEVER `phx-value-value` — the browser overwrites
  that attribute with the element's own `.value`, which is `""` on a `<button>`.
  Guarded by `EmakolaWeb.PhxValueCollisionTest`.
- Storefront LiveViews have no catch-all `handle_event/3`; a mistyped event name
  crashes the page. The event name is exactly `select_option`.
- Match Akwaaba's existing visual language: `rounded-full` controls, `zinc`
  borders, `--akwaaba-ink` / `--akwaaba-sun` / `--akwaaba-display` CSS tokens,
  `min-h-[44px]` touch targets, `motion-safe:` transitions.
- Money is formatted only via `Currency.format_price/2`. Do not touch price
  rendering in this task.
- Pre-commit: `mix test`, `mix format --check-formatted`, `mix credo --strict`.

---

### Task 1: Close the hole in the variant-picker guard test

**Files:**
- Modify: `test/emakola_web/live/storefront/variant_picker_test.exs:47-68`

**Interfaces:**
- Consumes: `Emakola.Themes.ThemeResolver.theme_ids/0`, `Emakola.Factory`
  helpers `create_store!/1`, `create_product!/2`, `create_option_type!/3`,
  `create_option_value!/3`, `create_variant!/3` (all already used in this file).
- Produces: a test that fails for any theme rendering no picker.

- [ ] **Step 1: Make the assertion unconditional**

The seeded product always has one option type with two values, so every theme
must render a picker. Replace the `if html =~ ... do ... end` wrapper with a
direct assertion. Change the test body to:

```elixir
      test "#{theme}", %{conn: conn} do
        ctx = seed(@theme)

        {:ok, view, html} = live(conn, "/s/#{ctx.store.slug}/products/#{ctx.product.slug}")

        # No `if` guard. A theme that renders no picker at all is the bug this
        # test exists to catch — Akwaaba shipped without one and passed CI for
        # months because the assertions used to be conditional on the picker
        # already being present.
        assert html =~ ~s(phx-click="select_option"),
               "the #{@theme} product page renders no variant picker, so a " <>
                 "shopper cannot choose a size or colour and add_to_cart can " <>
                 "only ever add the default variant"

        assert has_element?(
                 view,
                 ~s([phx-click="select_option"][phx-value-option_type_id="#{ctx.option_type.id}"][phx-value-option_value_id="#{ctx.large.id}"])
               ),
               "the #{@theme} variant picker does not send option_type_id + the value's id"

        # Would raise FunctionClauseError and kill the page before the fix.
        selected =
          render_click(view, "select_option", %{
            "option_type_id" => ctx.option_type.id,
            "option_value_id" => ctx.large.id
          })

        assert selected =~ "Large"
      end
```

- [ ] **Step 2: Run the test to verify it fails for akwaaba only**

Run: `mix test test/emakola_web/live/storefront/variant_picker_test.exs`

Expected: FAIL. Exactly one failure, `test akwaaba`, with the message
"the akwaaba product page renders no variant picker…". Every other theme
passes. If more than one theme fails, stop — the parity plan covers the rest
and this branch must stay a single-theme fix.

- [ ] **Step 3: Commit the failing test**

```bash
git add test/emakola_web/live/storefront/variant_picker_test.exs
git commit -m "test(web): require every theme to render a variant picker

The assertions were wrapped in `if html =~ select_option`, so a theme
that rendered no picker skipped them and passed. That is how akwaaba
shipped a product page on which no variant can be chosen."
```

---

### Task 2: Render the option picker on Akwaaba

**Files:**
- Modify: `lib/emakola/themes/akwaaba/product_detail.ex` — insert between the
  description paragraph (ends line 101) and the quantity/add-to-cart row
  (opens line 103)
- Modify: `lib/emakola/themes/akwaaba/product_detail.ex:6` (moduledoc)
- Test: `test/emakola_web/live/storefront/variant_picker_test.exs` (from Task 1)

**Interfaces:**
- Consumes: assigns `@option_types` (list of option types, each with `.id`,
  `.name`, `.option_values`), `@selected_options` (map of
  `option_type_id => option_value_id`), both assigned by
  `EmakolaWeb.Storefront.ProductDetailLive`.
- Produces: no new public functions. Markup only.

- [ ] **Step 1: Insert the picker markup**

Insert immediately after the description `<p>` closing tag on line 101 and
before the `<div class="mt-8 flex flex-wrap items-center gap-4">` on line 103:

```heex
            <div :if={@option_types != []} class="mt-8 space-y-5">
              <div :for={option_type <- @option_types}>
                <p class="text-xs font-bold uppercase tracking-[0.18em] text-zinc-500">
                  {option_type.name}
                </p>
                <div class="mt-3 flex flex-wrap gap-2">
                  <button
                    :for={option_value <- option_type.option_values || []}
                    type="button"
                    phx-click="select_option"
                    phx-value-option_type_id={option_type.id}
                    phx-value-option_value_id={option_value.id}
                    aria-pressed={
                      to_string(Map.get(@selected_options, option_type.id) == option_value.id)
                    }
                    class={[
                      "min-h-[44px] rounded-full border px-5 text-sm font-semibold motion-safe:transition-colors",
                      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)]",
                      if(Map.get(@selected_options, option_type.id) == option_value.id,
                        do: "border-[color:var(--akwaaba-ink)] bg-[color:var(--akwaaba-ink)] text-white",
                        else:
                          "border-zinc-200 bg-white text-[color:var(--akwaaba-ink)] hover:border-[color:var(--akwaaba-sun)]"
                      )
                    ]}
                  >
                    {option_value.value}
                  </button>
                </div>
              </div>
            </div>
```

Note `phx-value-option_type_id` and `phx-value-option_value_id` — never
`phx-value-value`.

- [ ] **Step 2: Run the guard test to verify it passes**

Run: `mix test test/emakola_web/live/storefront/variant_picker_test.exs`

Expected: PASS, all themes.

- [ ] **Step 3: Run the collision guard and the theme's own suite**

Run: `mix test test/emakola_web/phx_value_collision_test.exs test/emakola/themes/akwaaba_test.exs`

Expected: PASS. The collision test asserts no theme emits `phx-value-value`.

- [ ] **Step 4: Correct the moduledoc**

Line 6 already claims the theme handles `select_option`. It now actually does,
so the line becomes true — no edit needed to its text. Verify by reading lines
1-10 that the claim matches the markup, and if the list omits any event the
file now emits, correct it.

- [ ] **Step 5: Full verification**

```bash
mix format
mix test
mix credo --strict
```

Expected: `mix test` reports 0 failures. Read the `Result:` line — the exit
code of a piped `mix test` is not trustworthy.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/themes/akwaaba/product_detail.ex
git commit -m "fix(web): render the variant picker on akwaaba product pages

Akwaaba read @selected_variant for price, sale price and purchasability
but rendered no option picker, so the assign stayed at its mount-time
default. add_to_cart reads the same assign, so on a product with
variants only the default was purchasable and no other could be chosen."
```

---

## Self-Review

**Spec coverage:** §9 P0 (akwaaba variant picker) — Task 2. The test-hole root
cause, which §9 did not name because it was found after the spec was written —
Task 1.

**Placeholder scan:** No TBD/TODO. Both code steps carry complete, pasteable
markup. Step 4 of Task 2 is a verification step, not a placeholder — it has a
concrete pass condition.

**Type consistency:** `option_type.id`, `option_type.name`,
`option_type.option_values`, `option_value.id`, `option_value.value` and
`@selected_options` keyed by option-type id all match the shapes used in
`lib/emakola/themes/home_living/product_detail.ex:124-140` and the handler head
at `lib/emakola_web/live/storefront/product_detail_live.ex:112`.

**Out of scope for this branch:** every other theme's gaps (parity plan), and
the Heirloom theme.
