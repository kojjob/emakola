# Section Editor Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The theme-native section infrastructure — contract, registry, block bridge, renderer, layout context — with Starter and Atelier decomposed as byte-identical references. (Editor UI, six new themes, and the survivor fan-out are separate follow-up plans.)

**Architecture:** Each theme's home decomposes into `Emakola.Themes.Section` modules; the theme's `render_home` renders its sections through `SectionRenderer`, which resolves a per-theme saved layout from `store.theme_config["home_sections"]` (falling back to the theme's `sections/0` defaults — byte-identical for untouched stores). `store_live.ex` is NOT modified: the existing precedence (page-builder "home" override → theme `render_home`) is preserved because customization lives inside `render_home` itself.

**Tech Stack:** Elixir/Phoenix 1.8, LiveView 1.1 function components, Ash 3 (Store resource `theme_config` map — no migration), existing `Emakola.PageBuilder` block library.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-11-section-editor-design.md` — read it first.
- Byte-identical defaults: a store with no saved layout must render exactly today's home. The per-theme equivalence tests are the gate.
- No migration: layouts live in `store.theme_config["home_sections"]` (`"v" => 1`, keyed by theme name).
- Sanitize everything written to layouts: types must resolve in the registry; colors via `EmakolaWeb.Helpers.CssColor.safe_css_color/2`; padding in `~w(none sm md lg)`; URLs http(s)-only; no raw HTML settings.
- Unknown section types at render time are skipped with `Logger.warning` — never crash a storefront.
- All gates before each commit: `mix format` (changed files), `mix compile` zero new warnings, `mix credo --strict` clean, listed tests green. Read the test run's `Result:` line — never trust exit codes through pipes.
- Branch: `feature/theme-sections-core` (already exists, carries the spec).

---

### Task 1: Section behaviour + registry

**Files:**
- Create: `lib/emakola/themes/section.ex`
- Create: `lib/emakola/themes/sections.ex`
- Test: `test/emakola/themes/sections_registry_test.exs`

**Interfaces:**
- Produces: `Emakola.Themes.Section` behaviour (`key/0`, `label/0`, `settings_schema/0`, `render/1`); `Emakola.Themes.Sections.resolve(key) :: {:ok, {module, meta :: map()}} | :error`; `Emakola.Themes.Sections.sectionized_themes() :: [module]`.
- Consumes: `Emakola.PageBuilder.block_module_for/1` (existing), each block module's `type/0` and `label/0`-equivalents (read `lib/emakola/page_builder/block.ex` for the exact callback names before writing the bridge in Task 2 — the registry only needs `block_module_for/1` here).

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Emakola.Themes.SectionsRegistryTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.Sections

  test "resolves a theme section key to its module" do
    # Starter's hero is registered in Task 5; until then the registry is
    # empty of theme sections, so we assert the contract via the block
    # bridge and the error path.
    assert :error = Sections.resolve("nope/never")
  end

  test "resolves block keys through the bridge with block metadata" do
    assert {:ok, {Emakola.Themes.Sections.BlockSection, meta}} =
             Sections.resolve("block/hero_banner")

    assert meta.block_type == "hero_banner"
    assert is_atom(meta.block_module)
  end

  test "every registered theme section module implements the contract" do
    for theme <- Sections.sectionized_themes(),
        section <- theme.sections() do
      behaviours =
        section.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Emakola.Themes.Section in behaviours,
             "#{inspect(section)} must implement Emakola.Themes.Section"

      assert is_binary(section.key())
      assert is_binary(section.label())
      assert is_list(section.settings_schema())
    end
  end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/emakola/themes/sections_registry_test.exs`
Expected: FAIL — `Emakola.Themes.Sections` is undefined.

- [ ] **Step 3: Write the behaviour and registry**

```elixir
# lib/emakola/themes/section.ex
defmodule Emakola.Themes.Section do
  @moduledoc """
  Contract for a theme-native home section (spec:
  docs/superpowers/specs/2026-07-11-section-editor-design.md).

  `render/1` receives the storefront assigns (`:store`, `:products`,
  `:categories`, plus whatever the theme's home already passes) merged
  with `:settings` (schema defaults overridden by the merchant's saved
  values) and `:section_meta` (registry metadata — used by the block
  bridge, empty for theme sections).

  A setting is `%{key: String.t(), type: atom, label: String.t(),
  default: term}` with type in `:string | :text | :image_url |
  :category | :link | :boolean | :integer`.
  """

  @callback key() :: String.t()
  @callback label() :: String.t()
  @callback settings_schema() :: [map()]
  @callback render(map()) :: Phoenix.LiveView.Rendered.t()
end
```

```elixir
# lib/emakola/themes/sections.ex
defmodule Emakola.Themes.Sections do
  @moduledoc """
  Registry mapping section keys to modules across all sectionized themes,
  plus the `"block/<type>"` bridge into the page-builder library.
  Mirrors `Emakola.PageBuilder`'s registry pattern.
  """

  # Fan-out appends here, one module per decomposed theme.
  @sectionized_themes []

  def sectionized_themes, do: @sectionized_themes

  def resolve("block/" <> block_type) do
    case Emakola.PageBuilder.block_module_for(block_type) do
      nil ->
        :error

      block_module ->
        {:ok,
         {Emakola.Themes.Sections.BlockSection,
          %{block_type: block_type, block_module: block_module}}}
    end
  end

  def resolve(key) when is_binary(key) do
    case Map.fetch(theme_section_index(), key) do
      {:ok, module} -> {:ok, {module, %{}}}
      :error -> :error
    end
  end

  defp theme_section_index do
    for theme <- @sectionized_themes,
        section <- theme.sections(),
        into: %{} do
      {section.key(), section}
    end
  end
end
```

Note: if `Emakola.PageBuilder.block_module_for/1` has a different arity/name, adapt the call — but do NOT change PageBuilder.

- [ ] **Step 4: Create a stub BlockSection so the module reference compiles** (full implementation is Task 2)

```elixir
# lib/emakola/themes/sections/block_section.ex
defmodule Emakola.Themes.Sections.BlockSection do
  @moduledoc false
  @behaviour Emakola.Themes.Section

  @impl true
  def key, do: "block/*"
  @impl true
  def label, do: "Builder block"
  @impl true
  def settings_schema, do: []
  @impl true
  def render(assigns), do: raise("implemented in Task 2: #{inspect(assigns[:section_meta])}")
end
```

- [ ] **Step 5: Run tests, expect PASS** — `mix test test/emakola/themes/sections_registry_test.exs`

- [ ] **Step 6: Gates + commit**

```bash
mix format lib/emakola/themes/section.ex lib/emakola/themes/sections.ex lib/emakola/themes/sections/block_section.ex test/emakola/themes/sections_registry_test.exs
git add -A && git commit -m "feat(web): section contract and registry with block-bridge resolution"
```

---

### Task 2: Block bridge render

**Files:**
- Modify: `lib/emakola/themes/sections/block_section.ex`
- Test: `test/emakola/themes/block_section_test.exs`

**Interfaces:**
- Consumes: `Emakola.PageBuilder.render_block/2` and block `default_content/0` — READ `lib/emakola/page_builder.ex` and `lib/emakola/page_builder/blocks/hero_banner.ex` first for the exact block-map shape `render_block/2` expects (`%{"type" => ..., "content" => ...}` or similar) and mirror it exactly.
- Produces: `BlockSection.render/1` — renders any block given `assigns.section_meta.block_type` + `assigns.settings` as the block content overrides.

- [ ] **Step 1: Failing test**

```elixir
defmodule Emakola.Themes.BlockSectionTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Sections

  test "renders a bridged block with its default content" do
    {:ok, {module, meta}} = Sections.resolve("block/text_section")

    html =
      %{
        store: %{id: Ash.UUID.generate(), name: "Test Store"},
        products: [],
        categories: [],
        settings: %{},
        section_meta: meta,
        __changed__: nil
      }
      |> module.render()
      |> rendered_to_string()

    assert is_binary(html) and html != ""
  end

  test "merchant settings override the block's default content" do
    {:ok, {module, meta}} = Sections.resolve("block/text_section")

    html =
      %{
        store: %{id: Ash.UUID.generate(), name: "Test Store"},
        products: [],
        categories: [],
        settings: %{"heading" => "Akwaaba Deals"},
        section_meta: meta,
        __changed__: nil
      }
      |> module.render()
      |> rendered_to_string()

    assert html =~ "Akwaaba Deals"
  end
```

(If `text_section`'s content schema doesn't have a `heading` key, read its `default_content/0` and use a real key — the assertion intent is: settings override defaults.)

- [ ] **Step 2: Run, expect FAIL** (the Task-1 stub raises).

- [ ] **Step 3: Implement**

```elixir
defmodule Emakola.Themes.Sections.BlockSection do
  @moduledoc """
  Bridges any registered page-builder block into the section system:
  key "block/<type>", settings = the block's content map. One adapter,
  the whole block library becomes insertable custom sections.
  """

  @behaviour Emakola.Themes.Section

  @impl true
  def key, do: "block/*"

  @impl true
  def label, do: "Builder block"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    %{block_type: block_type, block_module: block_module} = assigns.section_meta
    content = Map.merge(block_module.default_content(), assigns.settings || %{})

    Emakola.PageBuilder.render_block(
      %{"type" => block_type, "content" => content},
      %{
        __changed__: nil,
        store: assigns.store,
        products: assigns[:products] || [],
        categories: assigns[:categories] || []
      }
    )
  end
end
```

Adapt the `render_block/2` argument shapes to what `lib/emakola/page_builder.ex` actually expects (read it) — keep THIS module the only place that knows the block-map shape.

- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Gates + commit** — `git commit -m "feat(web): block bridge renders builder blocks as sections"`

---

### Task 3: HomeSections layout context

**Files:**
- Create: `lib/emakola/themes/home_sections.ex`
- Test: `test/emakola/themes/home_sections_test.exs`

**Interfaces:**
- Produces:
  - `default_layout(theme_module) :: [entry]` — entry: `%{"id" => key, "type" => key, "enabled" => true, "settings" => %{}, "style" => %{}}` (default entries use the section key as a stable id)
  - `saved_layout(store, theme_name) :: [entry] | nil`
  - `effective_layout(store, theme_module) :: [entry]` — saved || defaults
  - `put_layout(actor, store, theme_name, entries) :: {:ok, updated_store} | {:error, term}` — sanitizes + store-membership check
  - `clear_layout(actor, store, theme_name) :: {:ok, store} | {:error, term}`
- Consumes: `Emakola.Themes.Sections.resolve/1` (type validation); `EmakolaWeb.Helpers.CssColor.safe_css_color/2`; Store `:update` action accepts `:theme_config` (verified); membership pattern copied from `Emakola.Inventory.ensure_store_access/2`.

- [ ] **Step 1: Failing tests**

```elixir
defmodule Emakola.Themes.HomeSectionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Themes.HomeSections

  defmodule FakeSection do
    @behaviour Emakola.Themes.Section
    def key, do: "fake/hero"
    def label, do: "Fake hero"
    def settings_schema, do: [%{key: "heading", type: :string, label: "Heading", default: ""}]
    def render(assigns), do: Phoenix.Component.sigil_H(~S|<div>fake</div>|, assigns)
  end

  defmodule FakeTheme do
    def sections, do: [Emakola.Themes.HomeSectionsTest.FakeSection]
  end

  setup do
    {merchant, store} = create_merchant_with_store!()
    %{merchant: merchant, store: store}
  end

  test "default_layout builds enabled entries with the key as id" do
    assert [entry] = HomeSections.default_layout(FakeTheme)
    assert entry["id"] == "fake/hero"
    assert entry["type"] == "fake/hero"
    assert entry["enabled"] == true
  end

  test "effective_layout falls back to defaults when nothing is saved", %{store: store} do
    assert HomeSections.effective_layout(store, FakeTheme) ==
             HomeSections.default_layout(FakeTheme)
  end

  test "put_layout persists per-theme and effective_layout returns it", %{
    merchant: merchant,
    store: store
  } do
    entries = [
      %{
        "id" => "fake/hero",
        "type" => "block/text_section",
        "enabled" => false,
        "settings" => %{"heading" => "Hi"},
        "style" => %{"bg" => "#FFF7ED", "padding" => "md"}
      }
    ]

    assert {:ok, updated} = HomeSections.put_layout(merchant, store, "starter", entries)
    assert [saved] = HomeSections.saved_layout(updated, "starter")
    assert saved["enabled"] == false
    assert saved["style"]["bg"] == "#FFF7ED"

    # Other themes are untouched.
    assert HomeSections.saved_layout(updated, "atelier") == nil
  end

  test "put_layout sanitizes: bad type, bad color, bad padding, bad url", %{
    merchant: merchant,
    store: store
  } do
    entries = [
      %{"id" => "x", "type" => "not/registered", "enabled" => true},
      %{
        "id" => "y",
        "type" => "block/text_section",
        "enabled" => true,
        "settings" => %{"heading" => "ok", "image" => "javascript:alert(1)"},
        "style" => %{"bg" => "url(javascript:x)", "padding" => "huge"}
      }
    ]

    assert {:ok, updated} = HomeSections.put_layout(merchant, store, "starter", entries)
    assert [only] = HomeSections.saved_layout(updated, "starter")
    assert only["id"] == "y"
    assert only["style"] == %{}
    refute Map.has_key?(only["settings"], "image")
  end

  test "cross-store actors are forbidden", %{store: store} do
    {stranger, _} = create_merchant_with_store!()
    assert {:error, :forbidden} = HomeSections.put_layout(stranger, store, "starter", [])
  end
end
```

- [ ] **Step 2: Run, expect FAIL** — module undefined.

- [ ] **Step 3: Implement**

```elixir
defmodule Emakola.Themes.HomeSections do
  @moduledoc """
  Per-theme home-section layouts inside `store.theme_config["home_sections"]`
  (`%{"v" => 1, <theme_name> => [entry]}`). No migration; unknown keys are
  sanitized away on write and skipped on read.
  """

  require Ash.Query

  @paddings ~w(none sm md lg)
  @config_key "home_sections"

  def default_layout(theme_module) do
    for section <- theme_module.sections() do
      %{
        "id" => section.key(),
        "type" => section.key(),
        "enabled" => true,
        "settings" => %{},
        "style" => %{}
      }
    end
  end

  def saved_layout(store, theme_name) do
    case get_in(store.theme_config || %{}, [@config_key, theme_name]) do
      entries when is_list(entries) -> entries
      _missing -> nil
    end
  end

  def effective_layout(store, theme_module) do
    saved_layout(store, theme_module.name()) || default_layout(theme_module)
  end

  def put_layout(actor, store, theme_name, entries) when is_list(entries) do
    with :ok <- ensure_store_access(actor, store.id) do
      sanitized = entries |> Enum.map(&sanitize_entry/1) |> Enum.reject(&is_nil/1)

      existing = store.theme_config || %{}
      section_map = Map.get(existing, @config_key, %{"v" => 1})

      config =
        Map.put(existing, @config_key, Map.put(section_map, theme_name, sanitized))

      update_theme_config(store, config)
    end
  end

  def clear_layout(actor, store, theme_name) do
    with :ok <- ensure_store_access(actor, store.id) do
      existing = store.theme_config || %{}
      section_map = existing |> Map.get(@config_key, %{}) |> Map.delete(theme_name)
      update_theme_config(store, Map.put(existing, @config_key, section_map))
    end
  end

  # ── sanitization ────────────────────────────────────────────────

  defp sanitize_entry(%{} = entry) do
    type = entry["type"] || entry[:type]

    case Emakola.Themes.Sections.resolve(type || "") do
      :error ->
        nil

      {:ok, _resolved} ->
        %{
          "id" => to_string(entry["id"] || entry[:id] || type),
          "type" => type,
          "enabled" => (entry["enabled"] || entry[:enabled]) == true,
          "settings" => sanitize_settings(entry["settings"] || entry[:settings] || %{}),
          "style" => sanitize_style(entry["style"] || entry[:style] || %{})
        }
    end
  end

  defp sanitize_entry(_other), do: nil

  defp sanitize_settings(%{} = settings) do
    for {key, value} <- settings,
        is_binary(key),
        sane_setting_value?(value),
        into: %{} do
      {key, value}
    end
  end

  defp sanitize_settings(_other), do: %{}

  # Strings that look like URLs must be http(s); everything textual is
  # rendered escaped by HEEx anyway — the URL rule blocks javascript: hrefs.
  defp sane_setting_value?(value) when is_boolean(value) or is_integer(value), do: true

  defp sane_setting_value?(value) when is_binary(value) do
    scheme = value |> String.trim() |> String.downcase()

    not String.contains?(scheme, ":") or
      String.starts_with?(scheme, "http://") or
      String.starts_with?(scheme, "https://")
  end

  defp sane_setting_value?(_other), do: false

  defp sanitize_style(%{} = style) do
    bg = EmakolaWeb.Helpers.CssColor.safe_css_color(style["bg"] || "", nil)
    text = EmakolaWeb.Helpers.CssColor.safe_css_color(style["text"] || "", nil)
    padding = if style["padding"] in @paddings, do: style["padding"]

    [{"bg", bg}, {"text", text}, {"padding", padding}]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp sanitize_style(_other), do: %{}

  defp update_theme_config(store, config) do
    store
    |> Ash.Changeset.for_update(:update, %{theme_config: config})
    |> Ash.update(authorize?: false)
  end

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> case do
      [_] -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_store_access(_actor, _store_id), do: {:error, :forbidden}
end
```

Check `safe_css_color/2`'s exact contract first (`lib/emakola_web/helpers/css_color.ex`): if it returns the default for invalid input, passing `nil` as default gives the reject-on-invalid behavior used above. If the theme root module's `name/0` returns a display name rather than the config key (check `starter.ex`), use the config key the ThemeResolver uses — grep `theme_config["theme"]` to confirm the canonical name string, and use THAT everywhere as `theme_name`.

- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Gates + commit** — `git commit -m "feat(web): per-theme home-section layout storage with sanitization"`

---

### Task 4: SectionRenderer

**Files:**
- Create: `lib/emakola/themes/section_renderer.ex`
- Test: `test/emakola/themes/section_renderer_test.exs`

**Interfaces:**
- Produces: `SectionRenderer.home/1` — a function component: assigns require `:store`, `:theme_module`, and carry the storefront pass-throughs (`:products`, `:categories`, anything else the theme home uses). Renders `HomeSections.effective_layout/2` order.
- Consumes: `HomeSections.effective_layout/2`, `Sections.resolve/1`, section `render/1` + `settings_schema/0`.

- [ ] **Step 1: Failing tests** (use two fake sections defined in the test, registered via a FakeTheme; drive layouts through `put_layout` from Task 3)

```elixir
defmodule Emakola.Themes.SectionRendererTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{HomeSections, SectionRenderer}

  defmodule AlphaSection do
    @behaviour Emakola.Themes.Section
    def key, do: "faketheme/alpha"
    def label, do: "Alpha"

    def settings_schema,
      do: [%{key: "heading", type: :string, label: "Heading", default: "Alpha default"}]

    def render(assigns) do
      Phoenix.Component.sigil_H(~S|<section data-sec="alpha">{@settings["heading"]}</section>|, assigns)
    end
  end

  defmodule BetaSection do
    @behaviour Emakola.Themes.Section
    def key, do: "faketheme/beta"
    def label, do: "Beta"
    def settings_schema, do: []

    def render(assigns) do
      Phoenix.Component.sigil_H(~S|<section data-sec="beta">B</section>|, assigns)
    end
  end

  defmodule FakeTheme do
    def name, do: "faketheme"
    def sections, do: [AlphaSection, BetaSection]
  end

  setup do
    {merchant, store} = create_merchant_with_store!()
    %{merchant: merchant, store: store}
  end

  defp render_home(store) do
    %{store: store, theme_module: FakeTheme, products: [], categories: [], __changed__: nil}
    |> SectionRenderer.home()
    |> rendered_to_string()
  end

  test "renders defaults in order with schema-default settings", %{store: store} do
    html = render_home(store)
    assert html =~ ~r/alpha.*beta/s
    assert html =~ "Alpha default"
  end

  test "saved layout controls order, enabled, settings, and style wrapper", %{
    merchant: merchant,
    store: store
  } do
    {:ok, store} =
      HomeSections.put_layout(merchant, store, "faketheme", [
        %{"id" => "faketheme/beta", "type" => "faketheme/beta", "enabled" => true},
        %{
          "id" => "faketheme/alpha",
          "type" => "faketheme/alpha",
          "enabled" => true,
          "settings" => %{"heading" => "Custom heading"},
          "style" => %{"bg" => "#B45309", "padding" => "lg"}
        }
      ])

    html = render_home(store)
    assert html =~ ~r/beta.*alpha/s
    assert html =~ "Custom heading"
    assert html =~ "background-color: #B45309"
    assert html =~ "data-section-padding=\"lg\""
  end

  test "disabled sections are skipped", %{merchant: merchant, store: store} do
    {:ok, store} =
      HomeSections.put_layout(merchant, store, "faketheme", [
        %{"id" => "faketheme/alpha", "type" => "faketheme/alpha", "enabled" => false},
        %{"id" => "faketheme/beta", "type" => "faketheme/beta", "enabled" => true}
      ])

    html = render_home(store)
    refute html =~ "alpha"
    assert html =~ "beta"
  end

  test "an unresolvable saved type is skipped without crashing", %{
    merchant: merchant,
    store: store
  } do
    {:ok, store} =
      HomeSections.put_layout(merchant, store, "faketheme", [
        %{"id" => "faketheme/beta", "type" => "faketheme/beta", "enabled" => true}
      ])

    # Simulate a section removed from a later release: corrupt the saved type.
    config = store.theme_config
    entries = [%{"id" => "gone", "type" => "faketheme/removed", "enabled" => true}] ++
                get_in(config, ["home_sections", "faketheme"])
    store = %{store | theme_config: put_in(config, ["home_sections", "faketheme"], entries)}

    html = render_home(store)
    assert html =~ "beta"
  end
end
```

Note: `resolve/1` in the registry only knows `@sectionized_themes`. To let the fake theme resolve, extend `Sections.resolve/1` in THIS task with a test seam: an application env override `Application.get_env(:emakola, :extra_sectionized_themes, [])` consulted alongside `@sectionized_themes` — set it in this test's `setup_all` (and delete_env on exit). Keep the seam documented as test-only. (`put_layout` sanitization also resolves types, so the seam must be in place before Task 3's fake-type tests too — if Task 3's test used `block/text_section` types only, it needs no seam; keep it that way.)

- [ ] **Step 2: Run, expect FAIL** — SectionRenderer undefined.

- [ ] **Step 3: Implement**

```elixir
defmodule Emakola.Themes.SectionRenderer do
  @moduledoc """
  Renders a store's effective home-section layout: saved layout for the
  active theme when present, else the theme's `sections/0` defaults —
  making untouched stores byte-identical to the pre-section themes.

  Each enabled entry renders inside the universal style wrapper
  (validated background/text color + a padding scale) — v1 "full
  theming" with zero per-section CSS work.
  """

  use Phoenix.Component

  require Logger

  alias Emakola.Themes.{HomeSections, Sections}

  @padding_classes %{
    "none" => "py-0",
    "sm" => "py-4 sm:py-6",
    "md" => "py-8 sm:py-12",
    "lg" => "py-14 sm:py-20"
  }

  def home(assigns) do
    entries =
      HomeSections.effective_layout(assigns.store, assigns.theme_module)
      |> Enum.filter(& &1["enabled"])
      |> Enum.flat_map(fn entry ->
        case Sections.resolve(entry["type"]) do
          {:ok, {module, meta}} ->
            [{entry, module, meta}]

          :error ->
            Logger.warning(
              "[sections] unknown section type #{inspect(entry["type"])} skipped " <>
                "(store=#{assigns.store.id})"
            )

            []
        end
      end)

    assigns = assign(assigns, :resolved_entries, entries)

    ~H"""
    <div
      :for={{entry, module, meta} <- @resolved_entries}
      class={padding_class(entry["style"])}
      style={wrapper_style(entry["style"])}
      data-section-id={entry["id"]}
      data-section-padding={entry["style"]["padding"]}
    >
      {render_section(module, meta, entry, assigns)}
    </div>
    """
  end

  defp render_section(module, meta, entry, assigns) do
    settings = Map.merge(schema_defaults(module), entry["settings"] || %{})

    assigns
    |> Map.drop([:resolved_entries])
    |> Map.put(:settings, settings)
    |> Map.put(:section_meta, meta)
    |> module.render()
  end

  defp schema_defaults(module) do
    for setting <- module.settings_schema(), into: %{} do
      {setting.key, setting.default}
    end
  end

  defp padding_class(%{"padding" => padding}), do: Map.get(@padding_classes, padding)
  defp padding_class(_style), do: nil

  defp wrapper_style(style) do
    [
      style["bg"] && "background-color: #{style["bg"]}",
      style["text"] && "color: #{style["text"]}"
    ]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      parts -> Enum.join(parts, "; ")
    end
  end
end
```

- [ ] **Step 4: Run, expect PASS.** Also rerun Tasks 1-3 tests.
- [ ] **Step 5: Gates + commit** — `git commit -m "feat(web): section renderer with layout resolution and style wrapper"`

---

### Task 5: Starter decomposition

**Files:**
- Create: `lib/emakola/themes/starter/sections/hero.ex`, `category_pills.ex`, `featured_products.ex`, `trust.ex`, `newsletter.ex`
- Modify: `lib/emakola/themes/starter/home.ex` (render → SectionRenderer; markup moves out), `lib/emakola/themes/starter.ex` (add `sections/0`), `lib/emakola/themes/sections.ex` (`@sectionized_themes [Emakola.Themes.Starter]`)
- Test: `test/emakola/themes/starter_sections_test.exs`

**Interfaces:**
- Consumes: `SectionRenderer.home/1`; the existing markup of `starter/home.ex` (`def render` at ~line 35; comment-marked blocks: Hero ~40-101, Category Pills ~102-127, Featured Products ~128-169, Trust ~170-269, Newsletter ~270-316; `section_enabled?/2` helper at ~318).
- Produces: five section modules keyed `"starter/hero"`, `"starter/category_pills"`, `"starter/featured_products"`, `"starter/trust"`, `"starter/newsletter"`; `Emakola.Themes.Starter.sections/0` in that order.

**Extraction recipe (byte-identical rule):**
1. Read `lib/emakola/themes/starter/home.ex` fully. For each comment-marked block, create a section module whose `render/1` body is the block's markup MOVED VERBATIM (same `~H`, same assigns usage). If a block uses `section_enabled?(@theme, "...")` keep that call — move `section_enabled?/2` into a shared helper module `Emakola.Themes.Starter.Sections.Helpers` and import it from each section that needs it (the legacy per-theme-config toggles remain a second gate underneath the new `enabled` flag; document that in the helper's moduledoc).
2. Settings schemas v1 (defaults MUST reproduce current output — use blank defaults and fall back to the existing expression when blank):

```elixir
# Pattern used inside a section render for a text override:
# heading = if @settings["heading"] not in [nil, ""], do: @settings["heading"], else: <existing expression>
```

   - hero: `heading`, `subheading`, `cta_label` (all `:string`, default `""`)
   - category_pills: `[]`
   - featured_products: `heading` (`:string`, default `""`)
   - trust: `[]`
   - newsletter: `heading` (`:string`, default `""`)
3. Section module skeleton (repeat per section, adjusting key/label/schema/markup):

```elixir
defmodule Emakola.Themes.Starter.Sections.Hero do
  @moduledoc "Starter home hero — extracted verbatim from starter/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "starter/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :string, label: "Subheading", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- moved verbatim from starter/home.ex Hero block --%>
    """
  end
end
```

4. `starter/home.ex` render becomes:

```elixir
def render(assigns) do
  ~H"""
  <Emakola.Themes.SectionRenderer.home
    store={@store}
    theme_module={Emakola.Themes.Starter}
    {assigns_passthrough(assigns)}
  />
  """
end
```

   If spreading full assigns is awkward, call `SectionRenderer.home(assigns_with_theme)` directly as a function instead of component syntax — the renderer takes a plain assigns map. Whichever form, ALL existing home assigns (store, products, categories, theme, etc.) must flow through unchanged, plus `theme_module`.
5. `starter.ex`: `def sections, do: [Sections.Hero, Sections.CategoryPills, Sections.FeaturedProducts, Sections.Trust, Sections.Newsletter]` (full module names).

- [ ] **Step 1: Write the equivalence + section tests FIRST** (they fail until the extraction lands)

```elixir
defmodule Emakola.Themes.StarterSectionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  test "sections/0 lists the five home sections in today's visual order" do
    keys = Enum.map(Emakola.Themes.Starter.sections(), & &1.key())

    assert keys == [
             "starter/hero",
             "starter/category_pills",
             "starter/featured_products",
             "starter/trust",
             "starter/newsletter"
           ]
  end

  test "default render carries each section's landmark content" do
    {_merchant, store} = create_merchant_with_store!()
    # Landmarks: pick one distinctive literal string per block from the
    # CURRENT starter/home.ex BEFORE extracting (e.g. the newsletter
    # heading text, a trust bullet), and assert all five appear in the
    # storefront home for a starter-theme store. Render via the existing
    # storefront test helper used by the theme tests (find the current
    # starter/theme storefront test and mirror its setup).
  end
end
```

Fill the landmark test concretely while reading home.ex in Step 2 — five literal strings, one per section, asserted present. The EXISTING starter storefront tests (grep `test/` for the starter theme's home assertions) must pass unchanged — they are the real equivalence gate; run them before and after.

- [ ] **Step 2: Run new tests, expect FAIL** (`sections/0` undefined). Also run the existing starter/storefront tests now to record the green baseline: `mix test test/emakola_web/live/storefront/` — note the `Result:` line.
- [ ] **Step 3: Extract** per the recipe above.
- [ ] **Step 4: Run** new tests + `mix test test/emakola_web/live/storefront/ test/emakola/themes/` — ALL green, including the untouched pre-existing storefront tests.
- [ ] **Step 5: Gates + commit** — `git commit -m "refactor(web): decompose the Starter home into registered sections"`

---

### Task 6: Atelier decomposition

**Files:**
- Create: `lib/emakola/themes/atelier/sections/{hero,category_circles,featured_products,new_arrivals,trust,delivery_zones,newsletter}.ex`
- Modify: `lib/emakola/themes/atelier/home.ex`, `lib/emakola/themes/atelier.ex` (add `sections/0`), `lib/emakola/themes/sections.ex` (append `Emakola.Themes.Atelier`)
- Test: `test/emakola/themes/atelier_sections_test.exs`

**Interfaces:** same shape as Task 5; keys `"atelier/hero"` … `"atelier/newsletter"`.

Atelier's home (848 lines) is ALREADY private function components per section (`hero_section/1` at ~105, category circles ~59, featured ~66, new arrivals ~73, trust ~80, delivery zones ~83, newsletter ~86 — read the render body at ~38-100 for the exact call list). The recipe is **promotion**: each private component's full body moves verbatim into a section module's `render/1`; private helpers used by exactly one section move with it; helpers shared by several stay in `atelier/shared.ex` (public) and get called module-qualified.

**Explicit exclusions (stay in home.ex, NOT sections):** the announcement/coupon bar (~line 43 — chrome tied to `@public_coupons`) renders BEFORE the SectionRenderer call; the footer (~89) renders AFTER it. Merchants reorder content sections, not chrome.

Settings schemas v1: hero (`heading`, `subheading`, `cta_label` — blank-default fallback pattern from Task 5), featured_products (`heading`), new_arrivals (`heading`), newsletter (`heading`), others `[]`.

- [ ] **Step 1: Tests first** — same shape as Task 5 (order test for the seven keys in today's render order; landmark literals per section chosen while reading home.ex). Record the existing Atelier storefront tests' green baseline.
- [ ] **Step 2: Run new tests, expect FAIL.**
- [ ] **Step 3: Promote** per the recipe; home.ex renders announcement bar → SectionRenderer.home → footer.
- [ ] **Step 4: Run** new + `test/emakola_web/live/storefront/ test/emakola/themes/` — all green, pre-existing Atelier tests unchanged.
- [ ] **Step 5: Gates + commit** — `git commit -m "refactor(web): decompose the Atelier home into registered sections"`

---

### Task 7: Storefront integration test + full gates

**Files:**
- Test: `test/emakola_web/live/storefront/home_sections_integration_test.exs`
- Modify: `TODO.md` (White-label Phase 2 entry — core shipped note, editor/new-themes/fan-out remaining)

- [ ] **Step 1: Write the integration tests** (these should pass already if Tasks 1-6 are correct — they are the end-to-end seal, not RED-first; note that in the commit message honestly)

```elixir
defmodule EmakolaWeb.HomeSectionsIntegrationTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest

  alias Emakola.Themes.HomeSections

  test "a saved starter layout reorders and hides sections on the live storefront", %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    # (Set the store's theme to starter if the factory default differs —
    # check the factory; adjust via the store update action.)

    defaults = HomeSections.default_layout(Emakola.Themes.Starter)

    reordered =
      defaults
      |> Enum.reject(&(&1["type"] == "starter/newsletter"))
      |> Enum.reverse()

    {:ok, _store} = HomeSections.put_layout(merchant, store, "starter", reordered)

    {:ok, _view, html} = live(conn, "/s/#{store.slug}")

    # Newsletter landmark absent; trust landmark appears BEFORE hero landmark.
    # (Reuse the landmark literals chosen in Task 5.)
    refute html =~ "<NEWSLETTER LANDMARK>"
    assert String.match?(html, ~r/<TRUST LANDMARK>.*<HERO LANDMARK>/s)
  end

  test "a store with no saved layout renders the unchanged default home", %{conn: conn} do
    {_merchant, store} = create_merchant_with_store!()
    {:ok, _view, html} = live(conn, "/s/#{store.slug}")
    assert html =~ "<HERO LANDMARK>"
    assert html =~ "<NEWSLETTER LANDMARK>"
  end

  test "the page-builder home override still wins over section layouts", %{conn: conn} do
    # Create + publish a Pages page at slug "home" (mirror the existing
    # page_live/store_live tests' setup for published pages), save a
    # section layout too, and assert the BLOCK content renders while the
    # theme hero landmark does not.
  end
end
```

Replace `<... LANDMARK>` with the Task-5 literals; complete the third test's setup from the existing `fetch_published_page` test patterns (grep `fetch_published_page` in test/).

- [ ] **Step 2: Run the file** — expect PASS; investigate any failure as a Task 1-6 bug, not a test to weaken.
- [ ] **Step 3: TODO.md** — update the "White-label Phase 2" entry: core infrastructure + two reference themes DONE 2026-07-11 (spec link), remaining = editor UI, six new themes, cull-gated fan-out.
- [ ] **Step 4: Full gates** — `mix format --check-formatted` · `mix credo --strict` · full `mix test` (read the `Result:` line).
- [ ] **Step 5: Commit** — `git commit -m "test(web): end-to-end home-section layout coverage and TODO update"`. Push branch; open the PR titled `feat(web): theme-native home sections — core (contract, renderer, Starter + Atelier)` with the spec linked and the equivalence guarantee stated.

---

## Self-review notes (already applied)

- Spec §1-§5 and §8 map to Tasks 1-7; §6 (editor) and §7 items 2-4 are explicitly out of this plan.
- The registry test seam (`:extra_sectionized_themes`) is the one deliberate test-only hook; documented inline.
- `theme_name` canonicalization (module `name/0` vs theme_config key) is flagged in Task 3 — the implementer MUST verify against `ThemeResolver` before writing `put_layout` calls anywhere.
- Task 7's integration tests are seal-tests (not RED-first) and the plan says so honestly.
