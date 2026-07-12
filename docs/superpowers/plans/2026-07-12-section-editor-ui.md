# Section Editor UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The merchant-facing section editor — `/admin/design/sections` LiveView with reorderable section rows, settings/style forms, add/remove, live in-process preview, and publish/reset — on top of the shipped section core (PR #296) and the URL-sanitization gate (PR #297).

**Architecture:** One LiveView (`EmakolaWeb.Admin.DesignSectionsLive`) holds the draft layout in socket assigns; every draft mutation re-renders the right-panel preview by calling `Emakola.Themes.SectionRenderer.home/1` in-process with `preview: true` (forced wrappers → `data-section-id` anchors). Publish funnels through `Emakola.Themes.HomeSections.put_layout/4` (tenancy + sanitization already enforced there); Reset through `clear_layout/3`. Reordering: hand-rolled `SectionSortable` HTML5 drag hook pushing one `reorder` event with the full id order; per-row up/down buttons are the keyboard/accessibility fallback and exist independently of the hook.

**Tech Stack:** Phoenix LiveView 1.1, existing `Emakola.Themes.*` core, TailwindCSS per the Makola Admin design language (stat tiles, rounded-2xl cards, premium polish — the UI-heavy tasks MUST load the `frontend-design:frontend-design` skill before writing markup).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-11-section-editor-design.md` §6 (editor), §8 (testing), §9 (out of scope) — read §6 verbatim first; it is binding.
- Draft lives in socket assigns; nothing persists until **Publish**. Unsaved-changes guard warns on navigate away.
- Tenancy: store comes from session assigns (`authenticate_conn` flow), merchant actor passed to `HomeSections.put_layout/clear_layout` — **params never trusted for tenancy** (spec-verbatim).
- Canonical theme key = `theme_module.id()`. `put_layout` returns `{:error, :unknown_theme}` for bad names and sanitizes entries (types must resolve; URL rules scoped to `:image_url`/`:link` schema types; padding `~w(none sm md lg)`; colors via `safe_css_color`).
- The "Add section" picker lists the active theme's `sections/0` types AND the bridged blocks — but **block/`<type>` entries must NOT offer list/map content fields** (FAQ items, testimonials) — scalar settings only (BlockSection moduledoc documents this).
- A theme's default sections can be **hidden, not deleted**; only custom-added instances get a remove control (spec-verbatim).
- Preview renders inside the store's DesignTokens CSS vars + storefront-width container (mirror `design_live.ex` / `storefront.html.heex` patterns).
- `SectionRenderer` default behavior is byte-frozen: `preview: true` is opt-in; without it, wrapper emission stays exactly as shipped (styled-only). The pre-existing renderer tests must pass unchanged.
- All gates before each commit: `mix format` (changed files), `mix compile --warnings-as-errors` clean for your files, `mix credo --strict` clean on your files, listed tests green — read the `Result:` line, never piped exit codes.
- Branch: `feature/section-editor-ui` (created off post-#297 main; carries this plan).

---

### Task 1: SectionRenderer preview mode (forced wrappers)

**Files:**
- Modify: `lib/emakola/themes/section_renderer.ex`
- Test: `test/emakola/themes/section_renderer_test.exs` (append tests only — existing tests unchanged)

**Interfaces:**
- Produces: `SectionRenderer.home/1` honors optional assign `:preview` (boolean, default absent/false). When truthy: EVERY resolved entry renders inside the wrapper div (with `data-section-id`), even unstyled ones; when absent: shipped styled-only behavior, byte-identical.
- Consumes: the shipped renderer (`styled?/1` gate at the wrapper decision).

- [ ] **Step 1: Failing tests** (append to the existing DataCase test file, mirroring its fakes/setup):

```elixir
  test "preview: true forces wrappers with data-section-id on unstyled defaults", %{store: store} do
    html =
      %{store: store, theme_module: FakeTheme, products: [], categories: [], preview: true, __changed__: nil}
      |> SectionRenderer.home()
      |> rendered_to_string()

    assert html =~ ~s(data-section-id="faketheme/alpha")
    assert html =~ ~s(data-section-id="faketheme/beta")
  end

  test "without preview, unstyled defaults still render bare", %{store: store} do
    html =
      %{store: store, theme_module: FakeTheme, products: [], categories: [], __changed__: nil}
      |> SectionRenderer.home()
      |> rendered_to_string()

    refute html =~ "data-section-id"
  end
```

- [ ] **Step 2: Run, expect FAIL** — `mix test test/emakola/themes/section_renderer_test.exs` (first test fails; second passes already — that is fine, it pins the frozen default).
- [ ] **Step 3: Implement** — in the wrapper decision, wrap when `assigns[:preview] || styled?(entry["style"])` (adjust to the module's actual private structure; cite the spec amendment in a one-line comment: preview mode forces anchors for the editor).
- [ ] **Step 4: Run, expect PASS** — whole file green (existing tests untouched).
- [ ] **Step 5: Gates + commit** — `git commit -m "feat(web): opt-in preview mode forces section wrappers for editor anchors"`

---

### Task 2: DesignSectionsLive — mount, rows, toggle, up/down reorder, publish/reset

**Files:**
- Create: `lib/emakola_web/live/admin/design_sections_live.ex`
- Modify: `lib/emakola_web/router.ex` (add `live "/admin/design/sections", Admin.DesignSectionsLive` beside the existing `/admin/design` route, same pipelines/session)
- Test: `test/emakola_web/live/admin/design_sections_live_test.exs`

**Interfaces:**
- Consumes: `HomeSections.effective_layout/2`, `put_layout/4`, `clear_layout/3`; `Sections.resolve/1`; `ThemeResolver` for the store's active theme module (grep `design_live.ex`/`store_live.ex` for the resolution call and mirror it); admin auth/session assigns exactly as the neighboring admin LiveViews (read one, e.g. `design_live.ex`, and mirror mount/session handling).
- Produces: the LiveView module + events `toggle_section` (`%{"id" => id}`), `move_section` (`%{"id" => id, "dir" => "up"|"down"}`), `publish` (no params), `reset_layout` (no params — wire the confirm in markup via `data-confirm`); draft assign `:draft` (list of entries, same map shape as `HomeSections` entries); `:dirty` boolean.

Draft mutations are pure list operations on `:draft` (reorder = swap adjacent; toggle = flip `"enabled"`); every event sets `dirty: true`. `publish` calls `put_layout(current_merchant, store, theme_module.id(), draft)`; on `{:ok, store}` reassign store + `dirty: false` + flash; on `{:error, :forbidden}`/`{:error, :unknown_theme}` flash error. `reset_layout` calls `clear_layout/3` then reloads draft from `default_layout/1`.

Mount: resolve store + theme module, `draft = HomeSections.effective_layout(store, theme_module)`, look up each entry's label via `Sections.resolve(entry["type"])` (unresolvable saved types: show the row with a "missing section" badge, disabled — never crash the editor).

- [ ] **Step 1: Failing LV tests** — mirror a neighboring admin LV test's setup (`create_merchant_with_store!` + `authenticate_conn`); store's theme must be a sectionized one (set `"starter"` via the store update action if the factory default differs — grep the Task-7 integration test from PR #296 for `set_starter_theme!` and reuse the technique):

```elixir
  test "lists the active theme's sections in order", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/design/sections")
    assert html =~ "Hero"
    assert String.match?(html, ~r/Hero.*Category Pills.*Featured Products.*Trust.*Newsletter/s)
  end

  test "toggle + publish persists a disabled section", %{conn: conn, merchant: merchant, store: store} do
    {:ok, view, _} = live(conn, "/admin/design/sections")
    view |> element(~s([phx-click="toggle_section"][phx-value-id="starter/newsletter"])) |> render_click()
    view |> element(~s(button[phx-click="publish"])) |> render_click()
    saved = Emakola.Themes.HomeSections.saved_layout(Ash.reload!(store), "starter")
    assert %{"enabled" => false} = Enum.find(saved, &(&1["id"] == "starter/newsletter"))
  end

  test "move down then publish persists the order", %{conn: conn, store: store} do
    {:ok, view, _} = live(conn, "/admin/design/sections")
    view |> element(~s([phx-click="move_section"][phx-value-id="starter/hero"][phx-value-dir="down"])) |> render_click()
    view |> element(~s(button[phx-click="publish"])) |> render_click()
    saved = Emakola.Themes.HomeSections.saved_layout(Ash.reload!(store), "starter")
    assert ["starter/category_pills", "starter/hero" | _] = Enum.map(saved, & &1["id"])
  end

  test "reset clears the saved layout", %{conn: conn, merchant: merchant, store: store} do
    {:ok, _} = Emakola.Themes.HomeSections.put_layout(merchant, store, "starter", [])
    {:ok, view, _} = live(conn, "/admin/design/sections")
    view |> element(~s(button[phx-click="reset_layout"])) |> render_click()
    assert Emakola.Themes.HomeSections.saved_layout(Ash.reload!(store), "starter") == nil
  end
```

(Adapt `Ash.reload!` to the codebase's actual re-fetch idiom — grep how other admin LV tests re-read the store after an action. If element selectors need adjusting to your markup, keep the EVENT names and value keys exactly as specified here.)

- [ ] **Step 2: Run, expect FAIL** (route + module missing).
- [ ] **Step 3: Implement** the LiveView + route. **Load the `frontend-design:frontend-design` skill before writing markup**; follow the Makola Admin design language (rounded-2xl cards, `admin_card`/`admin_button`/`status_badge` shared components where they fit). Left panel only in this task (rows: drag-handle placeholder icon, label, enabled toggle, up/down buttons, expand chevron placeholder); preview panel arrives in Task 3; settings forms in Task 4. Unsaved-changes guard: `phx-window-beforeunload` or the LV JS `data-confirm` pattern used elsewhere in the admin (grep for an existing unsaved-guard idiom; if none exists, a `@dirty`-gated `beforeunload` push_event hook is acceptable — keep it minimal).
- [ ] **Step 4: Run, expect PASS.** Also run the whole admin LV dir: `mix test test/emakola_web/live/admin/`.
- [ ] **Step 5: Gates + commit** — `git commit -m "feat(web): section editor LiveView — rows, toggle, keyboard reorder, publish/reset"`

---

### Task 3: Live preview panel

**Files:**
- Modify: `lib/emakola_web/live/admin/design_sections_live.ex`
- Test: `test/emakola_web/live/admin/design_sections_live_test.exs` (append)

**Interfaces:**
- Consumes: `SectionRenderer.home/1` with `preview: true` (Task 1); the storefront assigns the renderer needs (`:store`, `:products`, `:categories` — load a small product/category sample at mount exactly the way the storefront home mount does; grep `store_live.ex` for its home data loading and reuse the same context calls with a limit).
- Produces: a `render_preview/1` private component rendering the draft through the renderer inside the DesignTokens CSS-var wrapper + a storefront-width container.

Key mechanic: the preview must render the DRAFT (not the saved layout). `SectionRenderer.home/1` reads `HomeSections.effective_layout(store, theme_module)` internally — so pass a store struct whose `theme_config` carries the draft: `preview_store = %{store | theme_config: put_in(store.theme_config || %{}, ...draft under the active theme key...)}` (build the nested map explicitly; `put_in` on a missing key path needs the map seeded — mirror how `HomeSections.put_layout` builds it). This is the same struct-substitution technique the core's tests use.

- [ ] **Step 1: Failing tests:**

```elixir
  test "preview reflects the draft immediately (no publish)", %{conn: conn} do
    {:ok, view, html} = live(conn, "/admin/design/sections")
    assert html =~ ~s(data-section-id="starter/newsletter")
    view |> element(~s([phx-click="toggle_section"][phx-value-id="starter/newsletter"])) |> render_click()
    refute render(view) =~ ~s(data-section-id="starter/newsletter")
  end
```

- [ ] **Step 2: FAIL** (no preview markup yet).
- [ ] **Step 3: Implement** per the mechanic above. Storefront-only JS hooks won't animate in preview — acceptable per spec; do not import storefront JS.
- [ ] **Step 4: PASS** + admin dir green.
- [ ] **Step 5: Gates + commit** — `git commit -m "feat(web): in-process live preview renders the draft layout"`

---

### Task 4: Settings + style forms, add/remove sections

**Files:**
- Modify: `lib/emakola_web/live/admin/design_sections_live.ex`
- Test: append to the LV test file.

**Interfaces:**
- Consumes: each section's `settings_schema/0` via `Sections.resolve/1` (schema entries: `%{key, type, label, default}` with type in `:string | :text | :image_url | :category | :link | :boolean | :integer`); the bridged-block list — grep `Emakola.PageBuilder` for the public block-listing function (the page editor's picker uses it) and reuse; `BlockSection` settings for `block/<type>` entries come from the block's `default_content/0` **scalar** keys only (drop list/map-valued keys from the form — the platform constraint).
- Produces: events `update_settings` (`%{"id" => id, "settings" => params}` via form `phx-change`), `update_style` (`%{"id" => id, "style" => %{"bg" => _, "text" => _, "padding" => _}}`), `add_section` (`%{"type" => type}` — appends an entry with a unique id: `"#{type}-#{System.unique_integer([:positive])}"`), `remove_section` (`%{"id" => id}` — only rendered for custom instances, i.e. entries whose id ≠ its type key or whose type is `block/*`).

Form rendering is schema-driven: `:string`/`:text` → text input/textarea; `:image_url`/`:link` → url input; `:boolean` → checkbox; `:integer` → number input; `:category` → select of the store's categories. Style controls: two `<input type="color">` + padding select (`none/sm/md/lg`). Draft-side values go into the entry maps verbatim — **sanitization stays server-side in `put_layout` at publish**; after publish, reload the draft from the persisted layout so the merchant SEES what sanitization kept (e.g. a rejected `javascript:` URL comes back cleared — surface a flash noting dropped values when the persisted entries differ from the draft).

- [ ] **Step 1: Failing tests** (settings persist through publish; style persists; add block section appears in draft + preview; remove only for custom; javascript: URL in an `:image_url`-typed setting is dropped by publish and the reloaded draft shows it cleared):

```elixir
  test "add a bridged block section and publish", %{conn: conn, store: store} do
    {:ok, view, _} = live(conn, "/admin/design/sections")
    view |> element(~s([phx-click="add_section"][phx-value-type="block/text_section"])) |> render_click()
    view |> element(~s(button[phx-click="publish"])) |> render_click()
    saved = Emakola.Themes.HomeSections.saved_layout(Ash.reload!(store), "starter")
    assert Enum.any?(saved, &(&1["type"] == "block/text_section"))
  end

  test "default theme sections have no remove control", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/design/sections")
    refute html =~ ~s(phx-click="remove_section" phx-value-id="starter/hero")
  end
```

(Write the settings-form and sanitization-roundtrip tests concretely against your markup — keep event names/payload shapes exactly as specified above.)

- [ ] **Step 2: FAIL** → **Step 3: Implement** (frontend-design skill loaded; picker groups "Theme sections" vs "Content blocks") → **Step 4: PASS** + admin dir green.
- [ ] **Step 5: Gates + commit** — `git commit -m "feat(web): section settings, style controls, and add/remove in the editor"`

---

### Task 5: SectionSortable drag hook

**Files:**
- Create: `assets/js/hooks/section_sortable.js`
- Modify: `assets/js/app.js` (import + register in the hooks object, mirroring `theme_settings.js`'s registration), `lib/emakola_web/live/admin/design_sections_live.ex` (hook attrs + `reorder` event)
- Test: append LV test for the `reorder` event (the DOM drag itself is not unit-testable here; the event handler is).

**Interfaces:**
- Produces: hook `SectionSortable` — hand-rolled HTML5 drag-and-drop (draggable rows, dragstart/dragover/drop listeners, visual drop indicator class), pushing ONE `reorder` event with `%{"order" => [ids in new order]}` on drop. **No new JS dependency** (spec-verbatim).
- LV event `reorder`: reorders the draft to match the given id list (ids validated against the draft — unknown ids ignored, missing ids keep relative order; never crash), sets dirty.

- [ ] **Step 1: Failing LV test** for the event:

```elixir
  test "reorder event applies a full id order", %{conn: conn} do
    {:ok, view, _} = live(conn, "/admin/design/sections")
    order = ["starter/newsletter", "starter/trust", "starter/featured_products", "starter/category_pills", "starter/hero"]
    render_hook(view, "reorder", %{"order" => order})
    assert view |> render() |> then(&String.match?(&1, ~r/Newsletter.*Trust.*Featured Products.*Category Pills.*Hero/s))
  end
```

- [ ] **Step 2: FAIL** → **Step 3: Implement** hook + handler (defensive id validation per the interface) → **Step 4: PASS**; run `mix assets.build` (or the repo's asset alias — check mix.exs) to prove the JS compiles.
- [ ] **Step 5: Gates + commit** — `git commit -m "feat(web): hand-rolled drag-and-drop section reordering"`

---

### Task 6: Design-tab entry, integration seal, PR

**Files:**
- Modify: `lib/emakola_web/live/admin/design_live.ex` (a linked card/section "Homepage sections" → `/admin/design/sections`, matching that page's existing card idiom)
- Test: `test/emakola_web/live/storefront/` — append one integration test to the existing `home_sections_integration_test.exs`: editor-published layout renders on the live storefront (drive via `put_layout` + one editor publish round-trip), and TODO.md's "White-label Phase 2" entry updated (editor DONE; remaining = seven new themes, cull-gated fan-out).

- [ ] **Step 1: Integration test** (end-to-end seal, honest about not being RED-first): publish a reorder through the editor LV, then `live(conn, "/s/#{store.slug}")` asserts the landmark order changed (reuse the Task-5/7 landmarks from the core build: "Secure Payment" before "Your New Favorite Store").
- [ ] **Step 2: Design-tab link + TODO.md.**
- [ ] **Step 3: Full gates** — `mix format --check-formatted` · `mix credo --strict` · full `mix test` (`Result:` line).
- [ ] **Step 4: Commit** — `git commit -m "feat(web): section editor entry point, integration seal, TODO update"`. STOP — push/PR is the controller's step (final review first).

---

## Self-review notes

- Spec §6 coverage: rows/drag/keyboard fallback (T2+T5), toggle (T2), settings+style+remove-custom-only+add picker (T4), preview with tokens+storefront width (T3+T1), draft/publish/reset/unsaved guard (T2), tenancy (T2 via put_layout; cross-store test exists in core — editor test adds authenticated-scope by construction). §8 editor-test list mapped across T2-T6. §9 exclusions honored (no device toggles, no arbitrary CSS, no block-content editing beyond scalar settings).
- Type consistency: entry map shape (`"id"/"type"/"enabled"/"settings"/"style"`) matches `HomeSections` everywhere; event payload keys specified once and reused.
- Deliberate deviation from full-code rule: HEEx markup bodies are directive-specified (design language + component constraints) rather than verbatim — matching how the core plan handled large templates; all events, payloads, contracts, and tests are exact.
