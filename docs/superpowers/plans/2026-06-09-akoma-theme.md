# Akoma Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new storefront theme **Akoma** (Be Yours–inspired, Forest palette) with a polished product-detail page plus home and product-list pages, registered and selectable.

**Architecture:** Follow the existing theme pattern (`Emakola.Themes.Heritage`): a main module implementing `Emakola.Themes.ThemeBehaviour` that delegates each page to a sub-module, plus a `Shared` module for `theme_styles`/nav/footer/helpers. All data-loading and events already exist in `ProductDetailLive`/`ProductListLive`/`StoreLive`; the theme is pure presentation. Register in `ThemeResolver` (resolution) and `admin/theme_live.ex` (picker).

**Tech Stack:** Elixir, Phoenix LiveView, `Phoenix.Component` (HEEx), TailwindCSS, Ash. Reuses `EmakolaWeb.StorefrontComponents`, `EmakolaWeb.ReviewComponents`, `EmakolaWeb.Helpers.Currency`.

**Spec:** `docs/superpowers/specs/2026-06-09-akoma-theme-design.md`

---

## Critical implementation notes (read before starting)

1. **Optional assigns must use Access, not `@`.** `product_detail_variants_test.exs` calls `ProductDetail.render(assigns)` directly with a map that has **no** `reviews`/`can_review`/`uploads` keys, and attr-defaults are NOT applied on direct function calls. In `Akoma.ProductDetail`, reference review/upload assigns as `assigns[:reviews]`, `assigns[:can_review]`, `assigns[:uploads]` (return `nil` when absent) and wrap the reviews block in `:if={assigns[:reviews] != nil}`. Use `@product`, `@selected_variant`, etc. normally — those keys are always present.
2. **Option selection contract (mirror Heritage exactly):** button has `phx-click="select_option"`, `phx-value-option_type_id={option_type.id}`, `phx-value-value={option_value.id}`; selected when `Map.get(@selected_options, option_type.id) == option_value.id`. Iterate `option_type.option_values` (NOT `.values`).
3. **Two registries:** add Akoma to `theme_resolver.ex` `@theme_modules` AND `admin/theme_live.ex` `@themes`.
4. **All-themes test:** add `{Emakola.Themes.Akoma, "akoma"}` to the `@themes` list in `product_detail_variants_test.exs`.
5. **Currency:** `EmakolaWeb.Helpers.Currency.format_price(amount_minor_units, store.currency)`.
6. Run `mix format` before each commit. Branch already exists: `feature/akoma-theme`.

---

## File Structure

- Create `lib/emakola/themes/akoma.ex` — main module (behaviour, `defaults/0`, delegates).
- Create `lib/emakola/themes/akoma/shared.ex` — `theme_styles/1`, `akoma_nav/1`, `akoma_footer/1`, image helpers, `product_card/1`, WhatsApp helpers.
- Create `lib/emakola/themes/akoma/product_detail.ex` — the PDP (centerpiece).
- Create `lib/emakola/themes/akoma/home.ex` — homepage.
- Create `lib/emakola/themes/akoma/product_list.ex` — collection grid.
- Modify `lib/emakola/themes/theme_resolver.ex` — register `"akoma"`.
- Modify `lib/emakola_web/live/admin/theme_live.ex` — add picker entry.
- Modify `test/emakola/themes/product_detail_variants_test.exs` — add Akoma to `@themes`.
- Create `test/emakola/themes/akoma_test.exs` — resolver + render tests.

---

## Task 1: Theme module skeleton + registration

**Files:**
- Create: `lib/emakola/themes/akoma.ex`
- Create (stubs): `lib/emakola/themes/akoma/shared.ex`, `lib/emakola/themes/akoma/product_detail.ex`, `lib/emakola/themes/akoma/home.ex`, `lib/emakola/themes/akoma/product_list.ex`
- Modify: `lib/emakola/themes/theme_resolver.ex`, `lib/emakola_web/live/admin/theme_live.ex`
- Test: `test/emakola/themes/akoma_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/emakola/themes/akoma_test.exs`:

```elixir
defmodule Emakola.Themes.AkomaTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.ThemeResolver

  describe "registration & contract" do
    test "resolver resolves the akoma theme with Forest colours" do
      config = ThemeResolver.resolve(%{"theme" => "akoma"})
      assert config.theme_id == "akoma"
      assert config.theme_name == "Akoma"
      assert config.colors.primary == "#1A1A1A"
      assert config.colors.accent == "#2F5D50"
      assert config.colors.background == "#F8F9F7"
    end

    test "implements the required ThemeBehaviour callbacks" do
      Code.ensure_loaded!(Emakola.Themes.Akoma)
      assert Emakola.Themes.Akoma.name() == "Akoma"

      for {fun, arity} <- [
            render_home: 1,
            render_product_list: 1,
            render_product_detail: 1,
            css_variables: 0,
            name: 0
          ] do
        assert function_exported?(Emakola.Themes.Akoma, fun, arity),
               "missing #{fun}/#{arity}"
      end
    end

    test "css_variables exposes the theme custom properties" do
      vars = Emakola.Themes.Akoma.css_variables()
      assert vars["--theme-primary"] == "#1A1A1A"
      assert vars["--theme-accent"] == "#2F5D50"
      assert vars["--theme-bg"] == "#F8F9F7"
    end
  end
end
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `mix test test/emakola/themes/akoma_test.exs`
Expected: FAIL — `Emakola.Themes.Akoma` is undefined / module not available.

- [ ] **Step 3: Create the stub sub-modules so the main module compiles**

Create `lib/emakola/themes/akoma/shared.ex`:

```elixir
defmodule Emakola.Themes.Akoma.Shared do
  @moduledoc "Shared Akoma components: theme_styles, nav, footer, helpers."
  use Phoenix.Component

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root { --theme-primary:#1A1A1A; --theme-accent:#2F5D50; --theme-bg:#F8F9F7; }
    </style>
    """
  end
end
```

Create `lib/emakola/themes/akoma/product_detail.ex`:

```elixir
defmodule Emakola.Themes.Akoma.ProductDetail do
  @moduledoc "Akoma product detail page."
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="akoma-body"></div>
    """
  end
end
```

Create `lib/emakola/themes/akoma/home.ex`:

```elixir
defmodule Emakola.Themes.Akoma.Home do
  @moduledoc "Akoma home page."
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="akoma-body"></div>
    """
  end
end
```

Create `lib/emakola/themes/akoma/product_list.ex`:

```elixir
defmodule Emakola.Themes.Akoma.ProductList do
  @moduledoc "Akoma product list page."
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="akoma-body"></div>
    """
  end
end
```

- [ ] **Step 4: Create the main theme module**

Create `lib/emakola/themes/akoma.ex`:

```elixir
defmodule Emakola.Themes.Akoma do
  @moduledoc """
  Akoma theme — clean, modern, minimal (inspired by Shopify "Be Yours").
  Forest palette: off-white background, near-black text/CTAs, deep-green accent.
  Manrope headings + Inter body.

  Render modules:
  - `Emakola.Themes.Akoma.Home`
  - `Emakola.Themes.Akoma.ProductList`
  - `Emakola.Themes.Akoma.ProductDetail`
  - `Emakola.Themes.Akoma.Shared`
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  def id, do: "akoma"

  @impl true
  def name, do: "Akoma"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Manrope:wght@500;600;700;800&family=Inter:wght@400;500;600;700&display=swap"
    ]

  def defaults do
    %{
      id: :akoma,
      name: "Akoma",
      colors: %{
        primary: "#1A1A1A",
        accent: "#2F5D50",
        accent_dark: "#264B41",
        background: "#F8F9F7",
        text: "#1A1A1A",
        text_secondary: "#6B7280",
        border: "#E8EAE7",
        surface: "#FFFFFF"
      },
      fonts: %{heading: "Manrope", body: "Inter"},
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Considered goods,",
        subtitle: "made to last.",
        cta_text: "Shop the collection",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search products...", transparent: false},
      sections: %{
        hero: true,
        featured_in: false,
        featured_products: true,
        why_us: true,
        testimonials: false,
        faq: false,
        closing_cta: true,
        newsletter: true
      },
      trust: %{
        title: "Why shop with us",
        items: [
          %{icon: "verified_user", title: "Secure checkout", description: "MoMo, Paystack & cards — protected every step."},
          %{icon: "local_shipping", title: "Fast local delivery", description: "Next-day across Accra, nationwide in days."},
          %{icon: "autorenew", title: "Easy returns", description: "Not right? Return within 7 days, no fuss."}
        ]
      },
      newsletter: %{
        title: "Join the list",
        subtitle: "New arrivals and members-only drops, straight to your inbox.",
        button_text: "Subscribe"
      },
      closing_cta: %{
        title: "Find your next favourite thing",
        subtitle: "Thoughtfully made products, fairly priced.",
        button_text: "Browse all"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#1A1A1A",
        "--theme-accent" => "#2F5D50",
        "--theme-bg" => "#F8F9F7",
        "--theme-font-heading" => "'Manrope', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @impl true
  def css_variables, do: defaults().css_variables

  def renderer(:home), do: Emakola.Themes.Akoma.Home
  def renderer(:product_list), do: Emakola.Themes.Akoma.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Akoma.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Akoma.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Akoma.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Akoma.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Akoma.ProductDetail, as: :render
end
```

- [ ] **Step 5: Register in ThemeResolver**

Modify `lib/emakola/themes/theme_resolver.ex` — add the Akoma entry to `@theme_modules` (keep alphabetical-ish; place after `"atelier"`):

```elixir
  @theme_modules %{
    "akoma" => Emakola.Themes.Akoma,
    "atelier" => Emakola.Themes.Atelier,
    "beauty" => Emakola.Themes.Beauty,
    "bold" => Emakola.Themes.Bold,
    "electronics" => Emakola.Themes.Electronics,
    "fashion" => Emakola.Themes.Fashion,
    "fresh" => Emakola.Themes.Fresh,
    "heritage" => Emakola.Themes.Heritage,
    "home_living" => Emakola.Themes.HomeLiving,
    "market" => Emakola.Themes.Market,
    "pharmacy" => Emakola.Themes.Pharmacy,
    "starter" => Emakola.Themes.Starter,
    "vibrant" => Emakola.Themes.Vibrant
  }
```

- [ ] **Step 6: Register in the admin theme picker**

Modify `lib/emakola_web/live/admin/theme_live.ex` — add to the `@themes` module attribute list (the list beginning at line ~16), as the first entry:

```elixir
    %{id: "akoma", name: "Akoma", description: "Clean & modern (Be Yours)", icon: "deployed_code"},
    %{id: "market", name: "Market", description: "Simple & clean", icon: "storefront"},
```

- [ ] **Step 7: Run the test, verify it passes**

Run: `mix test test/emakola/themes/akoma_test.exs`
Expected: PASS (3 tests).

- [ ] **Step 8: Format & commit**

```bash
mix format
git add lib/emakola/themes/akoma.ex lib/emakola/themes/akoma/ lib/emakola/themes/theme_resolver.ex lib/emakola_web/live/admin/theme_live.ex test/emakola/themes/akoma_test.exs
git commit -m "feat(themes): scaffold + register Akoma theme"
```

---

## Task 2: Akoma.Shared — theme_styles, nav, footer, helpers, product_card

**Files:**
- Modify: `lib/emakola/themes/akoma/shared.ex`
- Test: `test/emakola/themes/akoma_test.exs`

- [ ] **Step 1: Add failing tests for Shared**

Append inside `Emakola.Themes.AkomaTest` (before the final `end`):

```elixir
  describe "Shared" do
    setup do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS", whatsapp_number: "+233201234567"}
      theme = ThemeResolver.resolve(%{"theme" => "akoma"})
      %{store: store, theme: theme}
    end

    defp html(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

    test "nav renders the store name and cart count", %{store: store} do
      out = html(Emakola.Themes.Akoma.Shared.akoma_nav(%{__changed__: nil, store: store, cart_count: 2}))
      assert out =~ "Demo Store"
      assert out =~ "/s/demo/cart"
      assert out =~ "2"
    end

    test "footer renders the store name", %{store: store} do
      out = html(Emakola.Themes.Akoma.Shared.akoma_footer(%{__changed__: nil, store: store}))
      assert out =~ "Demo Store"
    end

    test "product_card links to the product and shows price", %{store: store} do
      product = %{slug: "tee", title: "Cotton Tee", min_price: 12_000, images: [], featured_rank: nil}
      out = html(Emakola.Themes.Akoma.Shared.product_card(%{__changed__: nil, store: store, product: product}))
      assert out =~ "/s/demo/products/tee"
      assert out =~ "Cotton Tee"
      assert out =~ "GH₵ 120"
    end

    test "whatsapp_link builds a wa.me url with digits only", %{store: store} do
      assert Emakola.Themes.Akoma.Shared.whatsapp_link(store, "Cotton Tee") =~ "https://wa.me/233201234567"
    end
  end
```

- [ ] **Step 2: Run, verify it fails**

Run: `mix test test/emakola/themes/akoma_test.exs`
Expected: FAIL — `akoma_nav`/`akoma_footer`/`product_card`/`whatsapp_link` undefined.

- [ ] **Step 3: Implement Shared fully**

Replace the entire contents of `lib/emakola/themes/akoma/shared.ex`:

```elixir
defmodule Emakola.Themes.Akoma.Shared do
  @moduledoc """
  Shared components for the Akoma theme: theme_styles (CSS vars + base classes),
  akoma_nav (minimal sticky header), akoma_footer, image helpers, product_card,
  and WhatsApp ordering helpers.
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#1A1A1A" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#2F5D50" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#F8F9F7" %>;
      }
      .akoma-body { font-family: 'Inter', sans-serif; color: #1A1A1A; background: var(--theme-bg); }
      .akoma-heading { font-family: 'Manrope', 'Inter', sans-serif; letter-spacing: -0.015em; }
      .akoma-card { background: #FFFFFF; border: 1px solid #E8EAE7; border-radius: 8px; }
    </style>
    """
  end

  # ── Nav ──

  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def akoma_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-white/90 backdrop-blur border-b border-[#E8EAE7]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <nav class="hidden md:flex items-center gap-6 text-sm text-[#6B7280] flex-1">
            <a href={"/s/#{@store.slug}/products"} class="hover:text-[#1A1A1A]">Shop</a>
            <a href={"/s/#{@store.slug}/products"} class="hover:text-[#1A1A1A]">New</a>
            <a href={"/s/#{@store.slug}/about"} class="hover:text-[#1A1A1A]">About</a>
          </nav>
          <a href={"/s/#{@store.slug}"} class="akoma-heading text-lg sm:text-xl font-extrabold tracking-[0.15em] uppercase text-[#1A1A1A] flex-1 text-center">
            {@store.name}
          </a>
          <div class="flex items-center justify-end gap-3 flex-1">
            <a href={"/s/#{@store.slug}/account"} class="w-9 h-9 rounded-full hover:bg-[#F0F1EF] flex items-center justify-center" aria-label="Account">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 text-[#1A1A1A]" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="8" r="4" /><path d="M4 21a8 8 0 0 1 16 0" />
              </svg>
            </a>
            <a href={"/s/#{@store.slug}/cart"} class="relative w-9 h-9 rounded-full hover:bg-[#F0F1EF] flex items-center justify-center" aria-label={"Cart, #{@cart_count} items"}>
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 text-[#1A1A1A]" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z" /><path d="M3 6h18M16 10a4 4 0 0 1-8 0" />
              </svg>
              <span :if={@cart_count > 0} class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 rounded-full bg-[#2F5D50] text-white text-[10px] font-bold flex items-center justify-center">
                {@cart_count}
              </span>
            </a>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ── Footer ──

  attr :store, :map, required: true

  def akoma_footer(assigns) do
    ~H"""
    <footer class="bg-white border-t border-[#E8EAE7] mt-16">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-8">
          <div class="col-span-2">
            <div class="akoma-heading text-xl font-extrabold tracking-[0.12em] uppercase">{@store.name}</div>
            <p class="text-sm text-[#6B7280] leading-relaxed mt-3 max-w-sm">
              {@store.description || "Thoughtfully made products, fairly priced — delivered across Ghana."}
            </p>
          </div>
          <div>
            <h4 class="text-xs font-semibold uppercase tracking-wider text-[#1A1A1A] mb-3">Shop</h4>
            <ul class="space-y-2 text-sm text-[#6B7280]">
              <li><a href={"/s/#{@store.slug}/products"} class="hover:text-[#1A1A1A]">All products</a></li>
              <li><a href={"/s/#{@store.slug}/products"} class="hover:text-[#1A1A1A]">New arrivals</a></li>
            </ul>
          </div>
          <div>
            <h4 class="text-xs font-semibold uppercase tracking-wider text-[#1A1A1A] mb-3">Help</h4>
            <ul class="space-y-2 text-sm text-[#6B7280]">
              <li><a href={"/s/#{@store.slug}/about"} class="hover:text-[#1A1A1A]">About</a></li>
              <li><a href={"/s/#{@store.slug}/track"} class="hover:text-[#1A1A1A]">Track order</a></li>
            </ul>
          </div>
        </div>
        <div class="border-t border-[#E8EAE7] mt-10 pt-6 text-xs text-[#9CA3AF]">
          &copy; {DateTime.utc_now().year} {@store.name}. All rights reserved.
        </div>
      </div>
    </footer>
    """
  end

  # ── Image helpers ──

  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  def current_image(product, index) do
    case Enum.at(product.images, index) do
      %{medium_url: url} when is_binary(url) -> url
      %{url: url} when is_binary(url) -> url
      _ -> first_image(product)
    end
  end

  # ── WhatsApp ordering ──

  @doc "Digits-only phone or nil."
  def whatsapp_number(store) do
    case Map.get(store, :whatsapp_number) do
      n when is_binary(n) ->
        digits = String.replace(n, ~r/\D/, "")
        if digits == "", do: nil, else: digits

      _ ->
        nil
    end
  end

  @doc "wa.me link prefilled with the product title, or nil when the store has no number."
  def whatsapp_link(store, product_title) do
    case whatsapp_number(store) do
      nil -> nil
      digits -> "https://wa.me/#{digits}?text=#{URI.encode("Hi! I'd like to order: #{product_title}")}"
    end
  end

  # ── Product card ──

  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="akoma-card aspect-[3/4] overflow-hidden relative">
        <.optimized_image
          :if={first_image(@product)}
          src={first_image(@product)}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-500"
        />
        <div :if={!first_image(@product)} class="w-full h-full flex items-center justify-center bg-[#F0F1EF]">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-12 h-12 text-[#CBD5C7]" fill="currentColor" aria-hidden="true">
            <path d="M3.6 5.4a1 1 0 0 1 .9-.6h15a1 1 0 0 1 .9.6l1.6 3.6a1 1 0 0 1-.1.94 3.5 3.5 0 0 1-2.9 1.56V19a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7.5a3.5 3.5 0 0 1-2.9-1.56 1 1 0 0 1-.1-.94l1.6-3.6Zm5.4 8.6h6v4H9v-4Z" />
          </svg>
        </div>
      </div>
      <div class="pt-3">
        <h3 class="text-sm font-medium text-[#1A1A1A] line-clamp-1">{@product.title}</h3>
        <span class="text-sm font-semibold text-[#2F5D50] mt-1 block">
          {EmakolaWeb.Helpers.Currency.format_price(@product.min_price || 0, Map.get(@store, :currency, "GHS"))}
        </span>
      </div>
    </a>
    """
  end
end
```

- [ ] **Step 4: Run, verify it passes**

Run: `mix test test/emakola/themes/akoma_test.exs`
Expected: PASS (all tests incl. Shared).

- [ ] **Step 5: Format & commit**

```bash
mix format
git add lib/emakola/themes/akoma/shared.ex test/emakola/themes/akoma_test.exs
git commit -m "feat(themes): Akoma shared nav, footer, product_card, whatsapp helpers"
```

---

## Task 3: Akoma.ProductDetail — the centerpiece

**Files:**
- Modify: `lib/emakola/themes/akoma/product_detail.ex`
- Modify: `test/emakola/themes/product_detail_variants_test.exs` (add to `@themes`)
- Test: `test/emakola/themes/akoma_test.exs`

- [ ] **Step 1: Add Akoma to the all-themes variants test**

In `test/emakola/themes/product_detail_variants_test.exs`, add to the `@themes` list:

```elixir
  @themes [
    {Emakola.Themes.Akoma, "akoma"},
    {Emakola.Themes.Pharmacy, "pharmacy"},
    {Emakola.Themes.Beauty, "beauty"},
    {Emakola.Themes.HomeLiving, "home_living"},
    {Emakola.Themes.Electronics, "electronics"},
    {Emakola.Themes.Fashion, "fashion"},
    {Emakola.Themes.Heritage, "heritage"}
  ]
```

- [ ] **Step 2: Add a focused PDP render test**

Append inside `Emakola.Themes.AkomaTest` (before the final `end`):

```elixir
  describe "ProductDetail" do
    setup do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS", whatsapp_number: "+233201234567"}
      theme = ThemeResolver.resolve(%{"theme" => "akoma"})

      ot = %{id: "ot1", name: "Size", option_values: [
        %{id: "ov_s", value: "S"}, %{id: "ov_m", value: "M"}, %{id: "ov_l", value: "L"}
      ]}

      product = %{
        title: "Linen Overshirt", slug: "linen-overshirt", description: "Garment-dyed linen.",
        images: [], min_price: 42_000, avg_rating: 4.5, review_count: 12, share_count: 0
      }

      variant = %{price: 42_000, compare_at_price: 52_000, stock_quantity: 3}

      assigns = %{
        __changed__: nil, store: store, theme: theme, product: product,
        related_products: [], categories: [], cart_count: 0,
        selected_variant: variant, option_types: [ot],
        selected_options: %{"ot1" => "ov_m"}, quantity: 1, current_image_index: 0
      }

      %{assigns: assigns}
    end

    defp pdp_html(assigns), do: Emakola.Themes.Akoma.ProductDetail.render(assigns) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

    test "renders title, formatted price, and the two CTAs", %{assigns: a} do
      out = pdp_html(a)
      assert out =~ "Linen Overshirt"
      assert out =~ "GH₵ 420"
      assert out =~ "Add to cart"
      assert out =~ "WhatsApp"
      assert out =~ "https://wa.me/233201234567"
    end

    test "renders option pills with the select_option contract", %{assigns: a} do
      out = pdp_html(a)
      assert out =~ ~s(phx-click="select_option")
      assert out =~ ~s(phx-value-option_type_id="ot1")
      assert out =~ ~s(phx-value-value="ov_m")
      assert out =~ "S"
      assert out =~ "M"
      assert out =~ "L"
    end

    test "shows sale badge and compare-at price when on sale", %{assigns: a} do
      out = pdp_html(a)
      assert out =~ "GH₵ 520"
      assert out =~ "Save"
    end

    test "renders without raising when review assigns are absent (variants-test shape)", %{assigns: a} do
      # No reviews/can_review keys — must not raise.
      assert is_binary(pdp_html(a))
    end

    test "renders the reviews block when review assigns are present", %{assigns: a} do
      a = Map.merge(a, %{
        reviews: [], can_review: false, already_reviewed: false,
        review_form_rating: 0, review_form_title: "", review_form_body: "",
        review_submitting: false, uploads: nil
      })
      out = pdp_html(a)
      assert out =~ "review" or out =~ "Review"
    end
  end
```

- [ ] **Step 3: Run, verify it fails**

Run: `mix test test/emakola/themes/akoma_test.exs test/emakola/themes/product_detail_variants_test.exs`
Expected: FAIL — Akoma PDP is still the empty stub.

- [ ] **Step 4: Implement the PDP**

Replace the entire contents of `lib/emakola/themes/akoma/product_detail.ex`:

```elixir
defmodule Emakola.Themes.Akoma.ProductDetail do
  @moduledoc """
  Akoma product detail — Be Yours–style two-column: sticky gallery + details,
  pill option selectors, qty stepper, near-black Add to cart + WhatsApp order,
  JS accordions, sticky mobile bar, "Pair it with", and reviews.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias Emakola.Themes.Akoma.Shared

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :product, :map, required: true
  attr :related_products, :list, default: []
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0
  attr :selected_variant, :map, default: nil
  attr :option_types, :list, default: []
  attr :selected_options, :map, default: %{}
  attr :quantity, :integer, default: 1
  attr :current_image_index, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign(:price, price_for(assigns.product, assigns.selected_variant))
      |> assign(:compare_at, compare_at(assigns.selected_variant))
      |> assign(:currency, Map.get(assigns.store, :currency, "GHS"))
      |> assign(:wa_link, Shared.whatsapp_link(assigns.store, assigns.product.title))

    ~H"""
    <div class="akoma-body min-h-screen pb-24 lg:pb-0">
      <Shared.theme_styles theme={@theme} />
      <Shared.akoma_nav store={@store} cart_count={@cart_count} />

      <%!-- Breadcrumb --%>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-6">
        <nav class="flex items-center gap-2 text-xs text-[#9CA3AF]">
          <a href={"/s/#{@store.slug}"} class="hover:text-[#1A1A1A]">Home</a>
          <span>/</span>
          <a href={"/s/#{@store.slug}/products"} class="hover:text-[#1A1A1A]">Shop</a>
          <span>/</span>
          <span class="text-[#1A1A1A] truncate max-w-[180px]">{@product.title}</span>
        </nav>
      </div>

      <%!-- Main --%>
      <section class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-8 lg:py-12">
        <div class="grid lg:grid-cols-[1.1fr_1fr] gap-8 lg:gap-14">
          <%!-- Gallery --%>
          <div class="flex gap-3">
            <div :if={length(@product.images) > 1} class="hidden sm:flex flex-col gap-2 w-16 shrink-0">
              <button
                :for={{image, idx} <- Enum.with_index(@product.images)}
                type="button"
                phx-click="select_image"
                phx-value-index={idx}
                class={"akoma-card aspect-[3/4] overflow-hidden " <>
                  if(idx == @current_image_index, do: "ring-2 ring-[#1A1A1A]", else: "opacity-70 hover:opacity-100")}
              >
                <img src={Map.get(image, :thumbnail_url) || Map.get(image, :url)} alt={"#{@product.title} #{idx + 1}"} class="w-full h-full object-cover" />
              </button>
            </div>
            <div class="flex-1 akoma-card aspect-[3/4] overflow-hidden relative">
              <span :if={on_sale?(@price, @compare_at)} class="absolute top-3 left-3 z-10 bg-[#1A1A1A] text-white text-[10px] font-semibold tracking-wider px-2.5 py-1">SALE</span>
              <.optimized_image
                :if={Shared.current_image(@product, @current_image_index)}
                src={Shared.current_image(@product, @current_image_index)}
                alt={@product.title}
                class="w-full h-full object-cover"
              />
              <div :if={!Shared.current_image(@product, @current_image_index)} class="w-full h-full flex items-center justify-center bg-[#F0F1EF]">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-24 h-24 text-[#CBD5C7]" fill="currentColor" aria-hidden="true">
                  <path d="M3.6 5.4a1 1 0 0 1 .9-.6h15a1 1 0 0 1 .9.6l1.6 3.6a1 1 0 0 1-.1.94 3.5 3.5 0 0 1-2.9 1.56V19a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7.5a3.5 3.5 0 0 1-2.9-1.56 1 1 0 0 1-.1-.94l1.6-3.6Zm5.4 8.6h6v4H9v-4Z" />
                </svg>
              </div>
            </div>
          </div>

          <%!-- Info --%>
          <div class="lg:sticky lg:top-24 lg:self-start">
            <div class="text-[11px] uppercase tracking-[0.18em] text-[#9CA3AF]">{@store.name}</div>
            <h1 class="akoma-heading text-2xl sm:text-3xl font-bold text-[#1A1A1A] mt-2">{@product.title}</h1>

            <a :if={Map.get(@product, :review_count, 0) > 0} href="#akoma-reviews" class="inline-flex items-center gap-2 mt-2 text-xs text-[#6B7280]">
              <span class="text-[#1A1A1A] tracking-tight">{stars(@product)}</span>
              <span>{format_rating(@product)} · {@product.review_count} reviews</span>
            </a>

            <div class="flex items-baseline gap-3 mt-4">
              <span class="text-2xl font-bold text-[#1A1A1A]">{EmakolaWeb.Helpers.Currency.format_price(@price, @currency)}</span>
              <span :if={on_sale?(@price, @compare_at)} class="text-sm text-[#9CA3AF] line-through">
                {EmakolaWeb.Helpers.Currency.format_price(@compare_at, @currency)}
              </span>
              <span :if={on_sale?(@price, @compare_at)} class="text-[11px] font-semibold text-[#B91C1C] bg-[#FDE2E2] px-2 py-0.5 rounded">
                Save {discount_pct(@price, @compare_at)}%
              </span>
            </div>

            <p :if={@product.description} class="text-sm text-[#6B7280] leading-relaxed mt-4">{@product.description}</p>

            <%!-- Option pills --%>
            <div :if={@option_types != []} class="space-y-5 mt-6">
              <div :for={option_type <- @option_types}>
                <div class="text-xs text-[#1A1A1A] mb-2">
                  {option_type.name}:
                  <span class="text-[#6B7280]">{selected_label(option_type, @selected_options)}</span>
                </div>
                <div class="flex flex-wrap gap-2">
                  <button
                    :for={option_value <- option_type.option_values || []}
                    type="button"
                    phx-click="select_option"
                    phx-value-option_type_id={option_type.id}
                    phx-value-value={option_value.id}
                    class={"min-w-[44px] min-h-[44px] px-4 py-2 text-sm rounded-md border transition-colors " <>
                      if(Map.get(@selected_options, option_type.id) == option_value.id,
                        do: "border-[#2F5D50] bg-[#2F5D50] text-white font-medium",
                        else: "border-[#E8EAE7] bg-white text-[#1A1A1A] hover:border-[#2F5D50]")}
                  >
                    {option_value.value}
                  </button>
                </div>
              </div>
            </div>

            <%!-- Qty + stock --%>
            <div class="flex items-center gap-4 mt-6">
              <div class="flex items-center border border-[#E8EAE7] rounded-md">
                <button type="button" phx-click="decrement_quantity" class="w-10 h-10 flex items-center justify-center text-[#1A1A1A]" aria-label="Decrease">−</button>
                <span class="w-10 text-center text-sm font-medium">{@quantity}</span>
                <button type="button" phx-click="increment_quantity" class="w-10 h-10 flex items-center justify-center text-[#1A1A1A]" aria-label="Increase">+</button>
              </div>
              <span class="text-xs" style={"color: #{stock_color(@selected_variant)}"}>{stock_label(@selected_variant)}</span>
            </div>

            <%!-- CTAs --%>
            <button
              type="button"
              phx-click="add_to_cart"
              disabled={!in_stock?(@selected_variant)}
              class={"w-full mt-4 py-3.5 rounded-md text-sm font-semibold uppercase tracking-wider transition-colors " <>
                if(in_stock?(@selected_variant),
                  do: "bg-[#1A1A1A] text-white hover:bg-[#2F5D50]",
                  else: "bg-[#E8EAE7] text-[#9CA3AF] cursor-not-allowed")}
            >
              {if in_stock?(@selected_variant), do: "Add to cart", else: "Out of stock"}
            </button>

            <a
              :if={@wa_link}
              href={@wa_link}
              target="_blank"
              rel="noopener"
              class="w-full mt-3 py-3 rounded-md border border-[#25D366] text-[#128C3A] text-sm font-semibold flex items-center justify-center gap-2 hover:bg-[#25D366]/5"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-4 h-4" fill="currentColor" aria-hidden="true">
                <path d="M12 2a10 10 0 0 0-8.5 15.3L2 22l4.8-1.5A10 10 0 1 0 12 2Zm5.3 13.9c-.2.6-1.3 1.2-1.8 1.2-.5.1-1 .2-3.3-.7-2.8-1.1-4.5-3.9-4.7-4.1-.1-.2-1-1.4-1-2.6 0-1.3.6-1.9.9-2.1.2-.3.5-.3.7-.3h.5c.2 0 .4 0 .6.5l.8 1.9c.1.2.1.4 0 .5l-.4.5c-.2.2-.3.4-.1.7.2.3.8 1.3 1.7 2.1 1.2 1 2.1 1.4 2.4 1.5.2.1.4.1.6-.1l.7-.9c.2-.2.4-.2.6-.1l1.8.9c.2.1.4.2.5.3.1.2.1.6-.1 1.1Z" />
              </svg>
              Order on WhatsApp
            </a>

            <%!-- Accordions --%>
            <div class="mt-6 border-t border-[#E8EAE7]">
              <div class="border-b border-[#E8EAE7]">
                <button type="button" phx-click={JS.toggle(to: "#akoma-acc-desc")} class="w-full flex items-center justify-between py-3.5 text-sm text-[#1A1A1A]">
                  Description <span>+</span>
                </button>
                <div id="akoma-acc-desc" class="pb-4 text-sm text-[#6B7280] leading-relaxed">
                  {@product.description || "A well-made product, fairly priced."}
                </div>
              </div>
              <div class="border-b border-[#E8EAE7]">
                <button type="button" phx-click={JS.toggle(to: "#akoma-acc-ship")} class="w-full flex items-center justify-between py-3.5 text-sm text-[#1A1A1A]">
                  Delivery &amp; returns <span>+</span>
                </button>
                <div id="akoma-acc-ship" class="hidden pb-4 text-sm text-[#6B7280] leading-relaxed">
                  Next-day delivery across Accra, nationwide in 2–4 days. Easy returns within 7 days.
                </div>
              </div>
            </div>

            <%!-- Trust --%>
            <div class="flex flex-wrap gap-x-5 gap-y-2 mt-5 text-[11px] text-[#9CA3AF]">
              <span>🔒 Secure checkout</span>
              <span>📱 MoMo &amp; Paystack</span>
              <span>🚚 Local delivery</span>
            </div>
          </div>
        </div>
      </section>

      <%!-- Pair it with --%>
      <section :if={@related_products != []} class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 border-t border-[#E8EAE7]">
        <h2 class="akoma-heading text-lg font-bold text-[#1A1A1A] mb-6">Pair it with</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 sm:gap-6">
          <Shared.product_card :for={product <- Enum.take(@related_products, 4)} product={product} store={@store} />
        </div>
      </section>

      <%!-- Reviews (only when the LiveView provides review assigns) --%>
      <section :if={assigns[:reviews] != nil} id="akoma-reviews" class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 border-t border-[#E8EAE7]">
        <EmakolaWeb.ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={assigns[:reviews] || []}
          can_review={assigns[:can_review] || false}
          already_reviewed={assigns[:already_reviewed] || false}
          review_form_rating={assigns[:review_form_rating] || 0}
          review_form_title={assigns[:review_form_title] || ""}
          review_form_body={assigns[:review_form_body] || ""}
          review_submitting={assigns[:review_submitting] || false}
          avg_rating={Map.get(@product, :avg_rating)}
          review_count={Map.get(@product, :review_count, 0)}
          uploads={assigns[:uploads]}
        />
      </section>

      <%!-- Sticky mobile add-to-cart bar --%>
      <div class="fixed bottom-0 inset-x-0 z-40 lg:hidden bg-white border-t border-[#E8EAE7] px-4 py-3 flex items-center justify-between gap-3">
        <div class="min-w-0">
          <div class="text-xs font-medium text-[#1A1A1A] truncate">{@product.title}</div>
          <div class="text-sm font-bold text-[#2F5D50]">{EmakolaWeb.Helpers.Currency.format_price(@price, @currency)}</div>
        </div>
        <button
          type="button"
          phx-click="add_to_cart"
          disabled={!in_stock?(@selected_variant)}
          class={"shrink-0 px-6 py-3 rounded-md text-sm font-semibold uppercase tracking-wider " <>
            if(in_stock?(@selected_variant), do: "bg-[#1A1A1A] text-white", else: "bg-[#E8EAE7] text-[#9CA3AF]")}
        >
          {if in_stock?(@selected_variant), do: "Add", else: "Sold out"}
        </button>
      </div>

      <Shared.akoma_footer store={@store} />
    </div>
    """
  end

  # ── Helpers ──

  defp price_for(_product, %{price: price}) when is_integer(price), do: price
  defp price_for(product, _), do: Map.get(product, :min_price) || 0

  defp compare_at(%{compare_at_price: cap}) when is_integer(cap), do: cap
  defp compare_at(_), do: nil

  defp on_sale?(price, compare_at) when is_integer(compare_at), do: compare_at > price
  defp on_sale?(_, _), do: false

  defp discount_pct(price, compare_at) when is_integer(compare_at) and compare_at > 0 do
    round((compare_at - price) / compare_at * 100)
  end

  defp discount_pct(_, _), do: 0

  defp in_stock?(%{stock_quantity: q}) when is_integer(q), do: q > 0
  defp in_stock?(_), do: true

  defp stock_label(%{stock_quantity: q}) when is_integer(q) and q <= 0, do: "Out of stock"
  defp stock_label(%{stock_quantity: q}) when is_integer(q) and q <= 5, do: "Only #{q} left in stock"
  defp stock_label(_), do: "In stock"

  defp stock_color(%{stock_quantity: q}) when is_integer(q) and q <= 0, do: "#B91C1C"
  defp stock_color(_), do: "#16A34A"

  defp selected_label(option_type, selected_options) do
    selected_id = Map.get(selected_options, option_type.id)

    case Enum.find(option_type.option_values || [], &(&1.id == selected_id)) do
      %{value: v} -> v
      _ -> "Select"
    end
  end

  defp format_rating(product) do
    case Map.get(product, :avg_rating) do
      r when is_float(r) -> :erlang.float_to_binary(r, decimals: 1)
      r when is_integer(r) -> "#{r}.0"
      _ -> "—"
    end
  end

  defp stars(product) do
    n =
      case Map.get(product, :avg_rating) do
        r when is_number(r) -> round(r)
        _ -> 0
      end

    String.duplicate("★", n) <> String.duplicate("☆", 5 - n)
  end
end
```

- [ ] **Step 5: Run, verify it passes**

Run: `mix test test/emakola/themes/akoma_test.exs test/emakola/themes/product_detail_variants_test.exs`
Expected: PASS (Akoma PDP tests + all-themes variants test including Akoma).

- [ ] **Step 6: Format & commit**

```bash
mix format
git add lib/emakola/themes/akoma/product_detail.ex test/emakola/themes/akoma_test.exs test/emakola/themes/product_detail_variants_test.exs
git commit -m "feat(themes): Akoma product detail page (gallery, pills, WhatsApp, reviews)"
```

---

## Task 4: Akoma.Home

**Files:**
- Modify: `lib/emakola/themes/akoma/home.ex`
- Test: `test/emakola/themes/akoma_test.exs`

- [ ] **Step 1: Add a failing home render test**

Append inside `Emakola.Themes.AkomaTest`:

```elixir
  describe "Home" do
    test "renders hero and featured products" do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS"}
      theme = ThemeResolver.resolve(%{"theme" => "akoma"})
      product = %{slug: "tee", title: "Cotton Tee", min_price: 12_000, images: [], featured_rank: nil}

      assigns = %{
        __changed__: nil, store: store, theme: theme, cart_count: 0,
        featured_products: [product], categories: []
      }

      out = Emakola.Themes.Akoma.Home.render(assigns) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      assert out =~ "Demo Store"
      assert out =~ "Cotton Tee"
      assert out =~ "Shop the collection"
    end
  end
```

- [ ] **Step 2: Run, verify it fails**

Run: `mix test test/emakola/themes/akoma_test.exs`
Expected: FAIL — Home is the empty stub (no "Cotton Tee").

- [ ] **Step 3: Implement Home**

Replace the entire contents of `lib/emakola/themes/akoma/home.ex`:

```elixir
defmodule Emakola.Themes.Akoma.Home do
  @moduledoc "Akoma home page — minimal hero, featured grid, trust, newsletter."

  use Phoenix.Component

  alias Emakola.Themes.Akoma.Shared

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :featured_products, :list, default: []
  attr :categories, :list, default: []

  def render(assigns) do
    assigns = assign(assigns, :hero, get_in(assigns.theme, [:hero]) || %{})

    ~H"""
    <div class="akoma-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.akoma_nav store={@store} cart_count={@cart_count} />

      <%!-- Hero --%>
      <section class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24 text-center">
        <h1 class="akoma-heading text-4xl sm:text-6xl font-extrabold text-[#1A1A1A] leading-[1.05]">
          {Map.get(@hero, :title, "Considered goods,")}
          <span class="block text-[#2F5D50]">{Map.get(@hero, :subtitle, "made to last.")}</span>
        </h1>
        <a href={"/s/#{@store.slug}/products"} class="inline-block mt-8 px-8 py-3.5 rounded-md bg-[#1A1A1A] text-white text-sm font-semibold uppercase tracking-wider hover:bg-[#2F5D50] transition-colors">
          {Map.get(@hero, :cta_text, "Shop the collection")}
        </a>
      </section>

      <%!-- Featured --%>
      <section :if={@featured_products != []} class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10">
        <div class="flex items-baseline justify-between mb-6">
          <h2 class="akoma-heading text-xl font-bold text-[#1A1A1A]">Featured</h2>
          <a href={"/s/#{@store.slug}/products"} class="text-sm text-[#2F5D50] hover:underline">View all →</a>
        </div>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 sm:gap-6">
          <Shared.product_card :for={product <- Enum.take(@featured_products, 8)} product={product} store={@store} />
        </div>
      </section>

      <%!-- Trust --%>
      <section class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 border-t border-[#E8EAE7]">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-8 text-center">
          <div :for={item <- get_in(@theme, [:trust, :items]) || []}>
            <h3 class="akoma-heading text-base font-semibold text-[#1A1A1A]">{item.title}</h3>
            <p class="text-sm text-[#6B7280] mt-1">{item.description}</p>
          </div>
        </div>
      </section>

      <%!-- Newsletter --%>
      <section class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-14 text-center">
        <h2 class="akoma-heading text-2xl font-bold text-[#1A1A1A]">{get_in(@theme, [:newsletter, :title]) || "Join the list"}</h2>
        <p class="text-sm text-[#6B7280] mt-2">{get_in(@theme, [:newsletter, :subtitle])}</p>
        <form class="flex max-w-md mx-auto mt-6 gap-2">
          <input type="email" placeholder="you@email.com" class="flex-1 px-4 py-3 rounded-md border border-[#E8EAE7] text-sm focus:outline-none focus:border-[#2F5D50]" />
          <button type="button" class="px-6 py-3 rounded-md bg-[#1A1A1A] text-white text-sm font-semibold">{get_in(@theme, [:newsletter, :button_text]) || "Subscribe"}</button>
        </form>
      </section>

      <Shared.akoma_footer store={@store} />
    </div>
    """
  end
end
```

- [ ] **Step 4: Run, verify it passes**

Run: `mix test test/emakola/themes/akoma_test.exs`
Expected: PASS.

- [ ] **Step 5: Format & commit**

```bash
mix format
git add lib/emakola/themes/akoma/home.ex test/emakola/themes/akoma_test.exs
git commit -m "feat(themes): Akoma home page"
```

---

## Task 5: Akoma.ProductList

**Files:**
- Modify: `lib/emakola/themes/akoma/product_list.ex`
- Test: `test/emakola/themes/akoma_test.exs`

- [ ] **Step 1: Add a failing product-list render test**

Append inside `Emakola.Themes.AkomaTest`:

```elixir
  describe "ProductList" do
    test "renders a grid of products" do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS"}
      theme = ThemeResolver.resolve(%{"theme" => "akoma"})
      products = [
        %{slug: "tee", title: "Cotton Tee", min_price: 12_000, images: [], featured_rank: nil},
        %{slug: "cap", title: "Wool Cap", min_price: 9_500, images: [], featured_rank: nil}
      ]

      assigns = %{
        __changed__: nil, store: store, theme: theme, cart_count: 0,
        products: products, categories: []
      }

      out = Emakola.Themes.Akoma.ProductList.render(assigns) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      assert out =~ "Cotton Tee"
      assert out =~ "Wool Cap"
      assert out =~ "/s/demo/products/tee"
    end
  end
```

- [ ] **Step 2: Run, verify it fails**

Run: `mix test test/emakola/themes/akoma_test.exs`
Expected: FAIL — ProductList is the empty stub.

- [ ] **Step 3: Implement ProductList**

Replace the entire contents of `lib/emakola/themes/akoma/product_list.ex`:

```elixir
defmodule Emakola.Themes.Akoma.ProductList do
  @moduledoc "Akoma product list — clean responsive grid."

  use Phoenix.Component

  alias Emakola.Themes.Akoma.Shared

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :products, :list, default: []
  attr :categories, :list, default: []

  def render(assigns) do
    ~H"""
    <div class="akoma-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.akoma_nav store={@store} cart_count={@cart_count} />

      <section class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10">
        <div class="flex items-baseline justify-between mb-8">
          <h1 class="akoma-heading text-2xl font-bold text-[#1A1A1A]">All products</h1>
          <span class="text-sm text-[#9CA3AF]">{length(@products)} items</span>
        </div>

        <div :if={@products != []} class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6">
          <Shared.product_card :for={product <- @products} product={product} store={@store} />
        </div>

        <div :if={@products == []} class="text-center py-24 text-[#9CA3AF]">
          <p class="text-sm">No products yet. Check back soon.</p>
        </div>
      </section>

      <Shared.akoma_footer store={@store} />
    </div>
    """
  end
end
```

- [ ] **Step 4: Run, verify it passes**

Run: `mix test test/emakola/themes/akoma_test.exs`
Expected: PASS.

- [ ] **Step 5: Format & commit**

```bash
mix format
git add lib/emakola/themes/akoma/product_list.ex test/emakola/themes/akoma_test.exs
git commit -m "feat(themes): Akoma product list page"
```

---

## Task 6: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full theme test suite + consistency tests**

Run: `mix test test/emakola/themes/`
Expected: PASS — including `default_renderer_consistency_test.exs`, `theme_renderer_test.exs`, and the variants test (now covering Akoma).

- [ ] **Step 2: Confirm assets build (no esbuild break) and compile is clean**

Run: `mix compile --warnings-as-errors`
Expected: compiles with no warnings. Fix any unused alias/import warnings in the new modules.

- [ ] **Step 3: Format check + Credo**

Run: `mix format --check-formatted && mix credo --strict`
Expected: formatted; no new Credo issues. (Add `@moduledoc` if Credo flags any module — all new modules already have one.)

- [ ] **Step 4: Run the broader storefront test to catch integration regressions**

Run: `mix test test/emakola_web/live/storefront/`
Expected: PASS — no regressions in `ProductDetailLive`/`ProductListLive`/`StoreLive` (theme is additive).

- [ ] **Step 5: Manual smoke (optional but recommended)**

In `iex -S mix`, set a dev store to the Akoma theme and visit it:

```elixir
require Ash.Query
store = Emakola.Stores.Store |> Ash.Query.limit(1) |> Ash.read!(authorize?: false) |> hd()
store |> Ash.Changeset.for_update(:update_theme, %{theme_config: %{"theme" => "akoma"}}) |> Ash.update!(authorize?: false)
```

Then open `http://localhost:4000/s/<slug>/products/<product-slug>` and confirm the PDP renders, option pills select, Add to cart works, and the WhatsApp button links out. (If `:update_theme` isn't the action name, use the store's theme-update action — check `Emakola.Stores.Store` actions.)

- [ ] **Step 6: Final commit (if any formatting/warning fixes were made)**

```bash
mix format
git add -A
git commit -m "chore(themes): verification fixes for Akoma theme"
```

---

## Self-review notes

- **Spec coverage:** new theme + registration (Task 1) ✓; Forest palette tokens (Task 1 `defaults/0`) ✓; PDP gallery/pills/qty/CTAs/WhatsApp/accordions/sticky-bar/pair-it-with/reviews (Task 3) ✓; Home (Task 4) ✓; Product list (Task 5) ✓; reuse of StorefrontComponents/ReviewComponents/Currency ✓; TDD with render assertions + all-themes variants test ✓; pills-for-all-options (no swatch heuristic) ✓.
- **Optional-assign safety** encoded in Task 3 (`assigns[:reviews]` + `:if`), preventing a break in the shared variants test.
- **Option contract** matches Heritage exactly (`phx-value-value={option_value.id}`), so it passes the variants test's selected-id assertion.
- **Out of scope (inherited from DefaultRenderers):** cart, checkout, account, blog, recipes — unchanged.
