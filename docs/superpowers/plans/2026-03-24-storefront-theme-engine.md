# Storefront Theme Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a storefront theme system where merchants pick from 3 themes (Atelier, Market, Vibrant) and customize colors, hero content, and section visibility via a `theme_config` JSON column on the Store resource.

**Architecture:** A `ThemeBehaviour` pattern where each theme is a module implementing render callbacks. `ThemeResolver` merges merchant overrides with theme defaults. CSS variables inject colors into templates. Existing storefront LiveViews dispatch to theme-specific render functions. Shared pages (cart, checkout) use CSS variables for theming.

**Tech Stack:** Elixir/Phoenix LiveView, Ash 3.x resources, TailwindCSS with CSS custom properties, PostgreSQL jsonb

**Spec:** `docs/superpowers/specs/2026-03-24-storefront-theme-engine-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `priv/repo/migrations/*_add_theme_config_to_stores.exs` | Add theme_config column |
| Create | `lib/emakola/stores/theme_config.ex` | Validation module for theme_config JSON |
| Create | `lib/emakola/themes/theme_behaviour.ex` | Behaviour definition |
| Create | `lib/emakola/themes/theme_resolver.ex` | Merge defaults + overrides |
| Create | `lib/emakola/themes/atelier.ex` | Atelier theme (defaults + render dispatch) |
| Create | `lib/emakola/themes/atelier/home.ex` | Atelier home page components |
| Create | `lib/emakola/themes/atelier/product_list.ex` | Atelier product list components |
| Create | `lib/emakola/themes/atelier/product_detail.ex` | Atelier product detail components |
| Create | `lib/emakola/themes/atelier/shared.ex` | Atelier shared components (nav, cards, footer) |
| Create | `lib/emakola/themes/market.ex` | Market theme (refactored from existing) |
| Create | `lib/emakola/themes/market/home.ex` | Market home page components |
| Create | `lib/emakola/themes/market/product_list.ex` | Market product list components |
| Create | `lib/emakola/themes/market/product_detail.ex` | Market product detail components |
| Create | `lib/emakola/themes/market/shared.ex` | Market shared components |
| Create | `lib/emakola/themes/vibrant.ex` | Vibrant theme (defaults + render dispatch) |
| Create | `lib/emakola/themes/vibrant/home.ex` | Vibrant home page components |
| Create | `lib/emakola/themes/vibrant/product_list.ex` | Vibrant product list components |
| Create | `lib/emakola/themes/vibrant/product_detail.ex` | Vibrant product detail components |
| Create | `lib/emakola/themes/vibrant/shared.ex` | Vibrant shared components |
| Modify | `lib/emakola/accounts/resources/store.ex` | Add theme_config attribute |
| Modify | `lib/emakola_web/components/layouts/storefront.html.heex` | CSS variable injection + font loading |
| Modify | `lib/emakola_web/live/storefront/store_live.ex` | Dispatch to theme render |
| Modify | `lib/emakola_web/live/storefront/product_list_live.ex` | Dispatch to theme render |
| Modify | `lib/emakola_web/live/storefront/product_detail_live.ex` | Dispatch to theme render |
| Create | `test/emakola/themes/theme_resolver_test.exs` | ThemeResolver tests |
| Create | `test/emakola/stores/theme_config_test.exs` | ThemeConfig validation tests |
| Create | `test/emakola_web/live/storefront/theme_rendering_test.exs` | Integration tests for theme rendering |

---

## Task 1: Migration and Store Resource

**Files:**
- Create: `priv/repo/migrations/*_add_theme_config_to_stores.exs`
- Modify: `lib/emakola/accounts/resources/store.ex`

- [ ] **Step 1: Generate migration**

```bash
mix ecto.gen.migration add_theme_config_to_stores
```

- [ ] **Step 2: Write migration**

```elixir
defmodule Emakola.Repo.Migrations.AddThemeConfigToStores do
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :theme_config, :map, default: %{}
    end
  end
end
```

- [ ] **Step 3: Add theme_config to Store resource**

In `lib/emakola/accounts/resources/store.ex`, add inside the `attributes do` block:

```elixir
attribute :theme_config, :map, default: %{}, public?: true
```

And add `:theme_config` to the `update_settings` action's accept list.

- [ ] **Step 4: Run migration**

```bash
mix ecto.migrate
```

- [ ] **Step 5: Commit**

```bash
git add priv/repo/migrations/ lib/emakola/accounts/resources/store.ex
git commit -m "feat(stores): add theme_config column to stores table"
```

---

## Task 2: ThemeConfig Validation Module

**Files:**
- Create: `lib/emakola/stores/theme_config.ex`
- Create: `test/emakola/stores/theme_config_test.exs`

- [ ] **Step 1: Write failing tests**

```elixir
defmodule Emakola.Stores.ThemeConfigTest do
  use ExUnit.Case, async: true

  alias Emakola.Stores.ThemeConfig

  describe "validate/1" do
    test "accepts valid config with all fields" do
      config = %{
        "theme" => "atelier",
        "colors" => %{"primary" => "#CA8A04", "accent" => "#1C1917", "background" => "#FAFAF9"},
        "hero" => %{"title" => "My Store", "subtitle" => "Welcome", "cta_text" => "Shop", "cta_url" => "/products"},
        "sections" => %{"hero" => true, "categories" => true, "featured_products" => true, "brand_story" => false, "instagram" => false, "newsletter" => true}
      }
      assert {:ok, validated} = ThemeConfig.validate(config)
      assert validated["theme"] == "atelier"
    end

    test "accepts empty config" do
      assert {:ok, %{}} = ThemeConfig.validate(%{})
    end

    test "accepts partial config" do
      assert {:ok, _} = ThemeConfig.validate(%{"theme" => "market"})
    end

    test "rejects invalid theme name" do
      assert {:error, _} = ThemeConfig.validate(%{"theme" => "nonexistent"})
    end

    test "rejects invalid hex color" do
      config = %{"colors" => %{"primary" => "not-a-color"}}
      assert {:error, _} = ThemeConfig.validate(config)
    end

    test "accepts valid hex colors in various formats" do
      config = %{"colors" => %{"primary" => "#fff", "accent" => "#1C1917", "background" => "#FAFAF9"}}
      assert {:ok, _} = ThemeConfig.validate(config)
    end

    test "rejects invalid section values" do
      config = %{"sections" => %{"hero" => "yes"}}
      assert {:error, _} = ThemeConfig.validate(config)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/emakola/stores/theme_config_test.exs
```

- [ ] **Step 3: Implement ThemeConfig**

```elixir
defmodule Emakola.Stores.ThemeConfig do
  @moduledoc """
  Validates theme_config JSON stored on the Store resource.
  """

  @valid_themes ~w(atelier market vibrant)
  @valid_sections ~w(hero categories featured_products brand_story instagram newsletter)
  @hex_regex ~r/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/

  def validate(config) when config == %{}, do: {:ok, %{}}

  def validate(config) when is_map(config) do
    with :ok <- validate_theme(config),
         :ok <- validate_colors(config),
         :ok <- validate_sections(config) do
      {:ok, config}
    end
  end

  def validate(_), do: {:error, "theme_config must be a map"}

  defp validate_theme(%{"theme" => theme}) when theme in @valid_themes, do: :ok
  defp validate_theme(%{"theme" => _}), do: {:error, "theme must be one of: #{Enum.join(@valid_themes, ", ")}"}
  defp validate_theme(_), do: :ok

  defp validate_colors(%{"colors" => colors}) when is_map(colors) do
    invalid =
      colors
      |> Enum.filter(fn {_k, v} -> is_binary(v) and not Regex.match?(@hex_regex, v) end)

    case invalid do
      [] -> :ok
      [{key, val} | _] -> {:error, "invalid hex color for #{key}: #{val}"}
    end
  end
  defp validate_colors(_), do: :ok

  defp validate_sections(%{"sections" => sections}) when is_map(sections) do
    invalid =
      sections
      |> Enum.filter(fn {k, v} -> k in @valid_sections and not is_boolean(v) end)

    case invalid do
      [] -> :ok
      [{key, val} | _] -> {:error, "section #{key} must be boolean, got: #{inspect(val)}"}
    end
  end
  defp validate_sections(_), do: :ok
end
```

- [ ] **Step 4: Run tests**

```bash
mix test test/emakola/stores/theme_config_test.exs
```

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/stores/theme_config.ex test/emakola/stores/theme_config_test.exs
git commit -m "feat(stores): add ThemeConfig validation module with tests"
```

---

## Task 3: ThemeBehaviour and ThemeResolver

**Files:**
- Create: `lib/emakola/themes/theme_behaviour.ex`
- Create: `lib/emakola/themes/theme_resolver.ex`
- Create: `test/emakola/themes/theme_resolver_test.exs`

- [ ] **Step 1: Write failing tests for ThemeResolver**

```elixir
defmodule Emakola.Themes.ThemeResolverTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.ThemeResolver

  describe "resolve/1" do
    test "returns market defaults for empty config" do
      result = ThemeResolver.resolve(%{})
      assert result.theme == "market"
      assert result.colors.primary == "#2563EB"
      assert result.fonts.heading == "Inter"
    end

    test "returns atelier defaults when theme is atelier" do
      result = ThemeResolver.resolve(%{"theme" => "atelier"})
      assert result.theme == "atelier"
      assert result.colors.primary == "#CA8A04"
      assert result.fonts.heading == "Cormorant"
    end

    test "returns vibrant defaults when theme is vibrant" do
      result = ThemeResolver.resolve(%{"theme" => "vibrant"})
      assert result.theme == "vibrant"
      assert result.colors.primary == "#DC2626"
      assert result.fonts.heading == "Playfair Display"
    end

    test "merges color overrides on top of defaults" do
      result = ThemeResolver.resolve(%{"theme" => "atelier", "colors" => %{"primary" => "#FF0000"}})
      assert result.colors.primary == "#FF0000"
      assert result.colors.accent == "#1C1917"  # default kept
    end

    test "merges hero overrides" do
      result = ThemeResolver.resolve(%{"theme" => "market", "hero" => %{"title" => "My Shop"}})
      assert result.hero.title == "My Shop"
      assert result.hero.cta_text != nil  # default kept
    end

    test "merges section overrides" do
      result = ThemeResolver.resolve(%{"theme" => "atelier", "sections" => %{"instagram" => false}})
      assert result.sections.instagram == false
      assert result.sections.hero == true  # default kept
    end

    test "falls back to market for unknown theme" do
      result = ThemeResolver.resolve(%{"theme" => "nonexistent"})
      assert result.theme == "market"
    end
  end

  describe "theme_module/1" do
    test "returns correct module for each theme" do
      assert ThemeResolver.theme_module("atelier") == Emakola.Themes.Atelier
      assert ThemeResolver.theme_module("market") == Emakola.Themes.Market
      assert ThemeResolver.theme_module("vibrant") == Emakola.Themes.Vibrant
    end

    test "defaults to Market for unknown" do
      assert ThemeResolver.theme_module("unknown") == Emakola.Themes.Market
    end
  end
end
```

- [ ] **Step 2: Implement ThemeBehaviour**

```elixir
defmodule Emakola.Themes.ThemeBehaviour do
  @moduledoc """
  Behaviour that all storefront themes must implement.
  """

  @callback id() :: String.t()
  @callback name() :: String.t()
  @callback defaults() :: map()
  @callback fonts() :: [String.t()]
  @callback render_home(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_product_list(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_product_detail(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
end
```

- [ ] **Step 3: Implement ThemeResolver**

```elixir
defmodule Emakola.Themes.ThemeResolver do
  @moduledoc """
  Merges merchant theme_config overrides with theme defaults.
  Returns a fully-resolved theme config struct with atom keys.
  """

  @theme_modules %{
    "atelier" => Emakola.Themes.Atelier,
    "market" => Emakola.Themes.Market,
    "vibrant" => Emakola.Themes.Vibrant
  }

  def resolve(config) when is_map(config) do
    theme_id = get_theme_id(config)
    mod = theme_module(theme_id)
    defaults = mod.defaults()

    %{
      theme: theme_id,
      theme_module: mod,
      colors: merge_map(defaults.colors, get_in_config(config, "colors")),
      fonts: defaults.fonts,
      hero: merge_map(defaults.hero, get_in_config(config, "hero")),
      sections: merge_map(defaults.sections, get_in_config(config, "sections"))
    }
  end

  def resolve(_), do: resolve(%{})

  def theme_module(theme_id) do
    Map.get(@theme_modules, theme_id, Emakola.Themes.Market)
  end

  defp get_theme_id(config) do
    theme = Map.get(config, "theme", "market")
    if Map.has_key?(@theme_modules, theme), do: theme, else: "market"
  end

  defp get_in_config(config, key) do
    case Map.get(config, key) do
      val when is_map(val) -> atomize_keys(val)
      _ -> %{}
    end
  end

  defp merge_map(defaults, overrides) do
    Map.merge(defaults, overrides)
  end

  defp atomize_keys(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    ArgumentError -> Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
```

- [ ] **Step 4: Create stub theme modules** (so resolver tests pass)

Create minimal stub modules for all 3 themes with just `id/0`, `name/0`, `defaults/0`, and `fonts/0`. The render callbacks will be placeholder functions that raise "not implemented yet".

**Atelier stub** (`lib/emakola/themes/atelier.ex`):
```elixir
defmodule Emakola.Themes.Atelier do
  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def id, do: "atelier"

  @impl true
  def name, do: "Atelier"

  @impl true
  def fonts, do: [
    "https://fonts.googleapis.com/css2?family=Cormorant:ital,wght@0,400;0,500;0,600;0,700;1,400&family=Montserrat:wght@300;400;500;600;700&display=swap"
  ]

  @impl true
  def defaults do
    %{
      colors: %{primary: "#CA8A04", accent: "#1C1917", background: "#FAFAF9"},
      fonts: %{heading: "Cormorant", body: "Montserrat"},
      hero: %{image_url: "", title: "The New Essential", subtitle: "New Collection", cta_text: "Shop Collection", cta_url: "/products"},
      sections: %{hero: true, categories: true, featured_products: true, brand_story: true, instagram: true, newsletter: true}
    }
  end

  @impl true
  def render_home(assigns), do: Emakola.Themes.Atelier.Home.render(assigns)

  @impl true
  def render_product_list(assigns), do: Emakola.Themes.Atelier.ProductList.render(assigns)

  @impl true
  def render_product_detail(assigns), do: Emakola.Themes.Atelier.ProductDetail.render(assigns)
end
```

**Market stub** (`lib/emakola/themes/market.ex`):
```elixir
defmodule Emakola.Themes.Market do
  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def id, do: "market"

  @impl true
  def name, do: "Market"

  @impl true
  def fonts, do: [
    "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap"
  ]

  @impl true
  def defaults do
    %{
      colors: %{primary: "#2563EB", accent: "#0F172A", background: "#FFFFFF"},
      fonts: %{heading: "Inter", body: "Inter"},
      hero: %{image_url: "", title: "Welcome to Our Store", subtitle: "Shop the latest", cta_text: "Shop Now", cta_url: "/products"},
      sections: %{hero: true, categories: true, featured_products: true, brand_story: true, instagram: false, newsletter: true}
    }
  end

  @impl true
  def render_home(assigns), do: Emakola.Themes.Market.Home.render(assigns)

  @impl true
  def render_product_list(assigns), do: Emakola.Themes.Market.ProductList.render(assigns)

  @impl true
  def render_product_detail(assigns), do: Emakola.Themes.Market.ProductDetail.render(assigns)
end
```

**Vibrant stub** (`lib/emakola/themes/vibrant.ex`):
```elixir
defmodule Emakola.Themes.Vibrant do
  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def id, do: "vibrant"

  @impl true
  def name, do: "Vibrant"

  @impl true
  def fonts, do: [
    "https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,500;0,600;0,700;1,400&family=DM+Sans:wght@300;400;500;600;700&display=swap"
  ]

  @impl true
  def defaults do
    %{
      colors: %{primary: "#DC2626", accent: "#7C2D12", background: "#FFFBEB"},
      fonts: %{heading: "Playfair Display", body: "DM Sans"},
      hero: %{image_url: "", title: "Discover Unique Finds", subtitle: "Handcrafted with Love", cta_text: "Explore Now", cta_url: "/products"},
      sections: %{hero: true, categories: true, featured_products: true, brand_story: true, instagram: true, newsletter: true}
    }
  end

  @impl true
  def render_home(assigns), do: Emakola.Themes.Vibrant.Home.render(assigns)

  @impl true
  def render_product_list(assigns), do: Emakola.Themes.Vibrant.ProductList.render(assigns)

  @impl true
  def render_product_detail(assigns), do: Emakola.Themes.Vibrant.ProductDetail.render(assigns)
end
```

- [ ] **Step 5: Run tests**

```bash
mix test test/emakola/themes/theme_resolver_test.exs
```

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/themes/ test/emakola/themes/
git commit -m "feat(themes): add ThemeBehaviour, ThemeResolver, and 3 theme stubs"
```

---

## Task 4: Storefront Layout + LiveView Integration

**Files:**
- Modify: `lib/emakola_web/components/layouts/storefront.html.heex`
- Modify: `lib/emakola_web/live/storefront/store_live.ex`
- Modify: `lib/emakola_web/live/storefront/product_list_live.ex`
- Modify: `lib/emakola_web/live/storefront/product_detail_live.ex`

- [ ] **Step 1: Update storefront layout for CSS variables and font loading**

In `storefront.html.heex`, add at the top of `<div>`:

```heex
<style>
  :root {
    --theme-primary: <%= @theme.colors.primary %>;
    --theme-accent: <%= @theme.colors.accent %>;
    --theme-bg: <%= @theme.colors.background %>;
  }
  body { font-family: '<%= @theme.fonts.body %>', system-ui, sans-serif; }
  .font-theme-heading { font-family: '<%= @theme.fonts.heading %>', serif; }
</style>
<%= for font_url <- @theme_fonts do %>
  <link href={font_url} rel="stylesheet" />
<% end %>
```

The layout needs `@theme` and `@theme_fonts` assigns. These come from the LiveView's `mount/3` which sets them on the socket.

- [ ] **Step 2: Create a shared helper for theme resolution in storefront LiveViews**

Add a helper function used by all storefront LiveViews. Add to a new module or inline in each:

In each storefront LiveView's `mount/3`, after resolving the store, add:

```elixir
theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{})
theme_module = theme.theme_module

socket =
  socket
  |> assign(:theme, theme)
  |> assign(:theme_module, theme_module)
  |> assign(:theme_fonts, theme_module.fonts())
```

- [ ] **Step 3: Update StoreLive to dispatch to theme render**

In `store_live.ex`, change `render/1` to dispatch:

```elixir
def render(assigns) do
  assigns.theme_module.render_home(assigns)
end
```

- [ ] **Step 4: Update ProductListLive to dispatch**

Same pattern in `product_list_live.ex`:

```elixir
def render(assigns) do
  assigns.theme_module.render_product_list(assigns)
end
```

- [ ] **Step 5: Update ProductDetailLive to dispatch**

Same pattern in `product_detail_live.ex`:

```elixir
def render(assigns) do
  assigns.theme_module.render_product_detail(assigns)
end
```

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/components/layouts/storefront.html.heex lib/emakola_web/live/storefront/
git commit -m "feat(storefront): integrate theme resolver into layout and LiveViews"
```

---

## Task 5: Market Theme (Refactor Existing)

**Files:**
- Create: `lib/emakola/themes/market/home.ex`
- Create: `lib/emakola/themes/market/product_list.ex`
- Create: `lib/emakola/themes/market/product_detail.ex`
- Create: `lib/emakola/themes/market/shared.ex`

This task extracts the EXISTING storefront render functions from the current LiveView files into the Market theme module. This is a refactor — the visual output should be identical.

- [ ] **Step 1: Extract StoreLive render into Market.Home**

Read `store_live.ex` render/1 function. Copy the entire HEEx template into `Market.Home.render/1` as a function component. Replace hardcoded colors with CSS variable references where appropriate.

- [ ] **Step 2: Extract ProductListLive render into Market.ProductList**

Same extraction from `product_list_live.ex`.

- [ ] **Step 3: Extract ProductDetailLive render into Market.ProductDetail**

Same extraction from `product_detail_live.ex`.

- [ ] **Step 4: Create Market.Shared for common components**

Extract shared components (product_card, category_circles, nav elements) from `storefront_components.ex` that are Market-theme specific.

- [ ] **Step 5: Test that existing storefront still renders correctly**

```bash
mix test test/emakola_web/live/storefront/
```

All existing storefront tests must pass — this is a refactor.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/themes/market/
git commit -m "refactor(themes): extract existing storefront into Market theme"
```

---

## Task 6: Atelier Theme (From Prototype)

**Files:**
- Create: `lib/emakola/themes/atelier/home.ex`
- Create: `lib/emakola/themes/atelier/product_list.ex`
- Create: `lib/emakola/themes/atelier/product_detail.ex`
- Create: `lib/emakola/themes/atelier/shared.ex`

Implement the Atelier theme based on the `design/prototypes/store.html` prototype. The prototype has:
- Full-screen editorial hero with gradient overlay
- Asymmetric masonry category grid
- Product cards with 5:6 aspect ratio, hover hearts, star ratings, New/Sale badges
- Brand story split section
- Instagram/lookbook 6-column grid
- Newsletter signup with subscriber count
- Premium dark footer with payment icons

- [ ] **Step 1: Create Atelier.Shared** — product card, category card, nav components adapted from prototype using CSS variables

- [ ] **Step 2: Create Atelier.Home** — full home page with all sections (hero, categories, featured products, brand story, instagram, newsletter), each gated by `@theme.sections`

- [ ] **Step 3: Create Atelier.ProductList** — shop page with filter sidebar, search, product grid

- [ ] **Step 4: Create Atelier.ProductDetail** — PDP with image gallery, variant selectors, add to cart

- [ ] **Step 5: Test Atelier theme renders**

Create `test/emakola_web/live/storefront/theme_rendering_test.exs`:

```elixir
defmodule EmakolaWeb.Storefront.ThemeRenderingTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  # Create a store with atelier theme
  # Navigate to /s/:slug/
  # Assert key Atelier elements render (serif font class, gold color, editorial hero)
end
```

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/themes/atelier/ test/
git commit -m "feat(themes): implement Atelier premium fashion theme"
```

---

## Task 7: Vibrant Theme

**Files:**
- Create: `lib/emakola/themes/vibrant/home.ex`
- Create: `lib/emakola/themes/vibrant/product_list.ex`
- Create: `lib/emakola/themes/vibrant/product_detail.ex`
- Create: `lib/emakola/themes/vibrant/shared.ex`

The Vibrant theme is bold, colorful, West African-inspired:
- Bold split hero with pattern/texture elements
- Circle "story" category bubbles (like the current storefront)
- Large rounded product cards with shadows
- Colorful accent sections
- Warm ivory background

- [ ] **Step 1-4: Create all 4 Vibrant component files** following the same pattern as Atelier

- [ ] **Step 5: Test Vibrant theme renders**

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/themes/vibrant/ test/
git commit -m "feat(themes): implement Vibrant bold colorful theme"
```

---

## Task 8: Final Integration and Verification

- [ ] **Step 1: Run full test suite**

```bash
mix test
```

Ensure no regressions in existing tests.

- [ ] **Step 2: Run format and credo**

```bash
mix format
mix credo --strict
```

- [ ] **Step 3: Manual verification**

Start dev server and test each theme:
1. Set a store's `theme_config` to `%{"theme" => "market"}` — verify existing look
2. Set to `%{"theme" => "atelier"}` — verify editorial look
3. Set to `%{"theme" => "vibrant"}` — verify bold look
4. Set to `%{"theme" => "atelier", "colors" => %{"primary" => "#FF0000"}}` — verify color override works

- [ ] **Step 4: Commit any fixes**

```bash
git commit -m "fix(themes): final integration cleanup"
```
