# Spotlight Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A new single-product storefront theme **Spotlight** (lighter take on the LIVELY reference) — immersive product page as centerpiece, marketing-funnel home, simple product list.

**Architecture:** Same pattern as `Emakola.Themes.Heritage` (main module implements `ThemeBehaviour`, delegates each page to a sub-module, `Shared` holds styles/nav/footer/helpers). Centerpiece is `render_product_detail` (uses `ProductDetailLive`'s existing assigns + events). Home funnels to the product page. No changes to LiveViews or resources.

**Tech Stack:** Elixir, Phoenix LiveView (`Phoenix.Component`/HEEx), TailwindCSS, Ash. Reuses `EmakolaWeb.StorefrontComponents`, `EmakolaWeb.ReviewComponents`, `EmakolaWeb.Helpers.Currency`, the `ScrollReveal` JS hook.

**Spec:** `docs/superpowers/specs/2026-06-09-spotlight-theme-design.md`

---

## Critical implementation notes (read first)

1. **Optional review/upload assigns via Access, not `@`.** `product_detail_variants_test.exs` calls `ProductDetail.render(assigns)` with a map lacking `reviews`/`can_review`/`uploads`; attr-defaults are NOT applied on direct function calls. Use `assigns[:reviews]` etc. and gate the reviews block with `:if={assigns[:reviews] != nil}`.
2. **Option selector contract (exact):** `phx-click="select_option"`, `phx-value-option_type_id={option_type.id}`, `phx-value-value={option_value.id}`; selected when `Map.get(@selected_options, option_type.id) == option_value.id`; iterate `option_type.option_values`.
3. **Decimal-safe ratings:** `product.avg_rating` is a `%Decimal{}` at runtime (Ash aggregate). Rating helpers must match `%Decimal{}` BEFORE `is_float`/`is_number` (which are false for Decimal).
4. **Content sourcing:** read `hero`, `trust`, `testimonials`, `closing_cta`, `newsletter` from the resolved `@theme` (the resolver deep-merges them). Read ingredients from `Emakola.Themes.Spotlight.ingredients/0`.
5. **ScrollReveal:** before using it, READ `assets/js/hooks/scroll_reveal.js` to learn its contract. Apply `phx-hook="ScrollReveal"` + a unique `id` on section wrappers per that contract. **Content MUST be visible without JS** — do not leave sections permanently `opacity-0`; if the hook expects a pre-hidden state, follow its exact pattern, otherwise just attach the hook for enhancement.
6. Run `mix format` before each commit. Reference theme for conventions: `lib/emakola/themes/heritage/` (on main, available on this branch).
7. Branch: `feature/spotlight-theme`.

---

## File structure

- Create `lib/emakola/themes/spotlight.ex`
- Create `lib/emakola/themes/spotlight/shared.ex`
- Create `lib/emakola/themes/spotlight/product_detail.ex`
- Create `lib/emakola/themes/spotlight/home.ex`
- Create `lib/emakola/themes/spotlight/product_list.ex`
- Modify `lib/emakola/themes/theme_resolver.ex` (register)
- Modify `lib/emakola_web/live/admin/theme_live.ex` (`@theme_metadata` picker entry)
- Modify `test/emakola/themes/product_detail_variants_test.exs` (add Spotlight)
- Create `test/emakola/themes/spotlight_test.exs`

---

## Task 1: Scaffold + register Spotlight

**Files:** create `spotlight.ex` + 4 stub sub-modules; modify `theme_resolver.ex`, `admin/theme_live.ex`; create `test/emakola/themes/spotlight_test.exs`.

- [ ] **Step 1: Failing test** — create `test/emakola/themes/spotlight_test.exs`:

```elixir
defmodule Emakola.Themes.SpotlightTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.ThemeResolver

  describe "registration & contract" do
    test "resolver resolves spotlight with the light palette" do
      config = ThemeResolver.resolve(%{"theme" => "spotlight"})
      assert config.theme_id == "spotlight"
      assert config.theme_name == "Spotlight"
      assert config.colors.background == "#FBF9F5"
      assert config.colors.accent == "#7C3AED"
    end

    test "implements required ThemeBehaviour callbacks" do
      Code.ensure_loaded!(Emakola.Themes.Spotlight)
      assert Emakola.Themes.Spotlight.name() == "Spotlight"

      for {fun, arity} <- [render_home: 1, render_product_list: 1, render_product_detail: 1, css_variables: 0, name: 0] do
        assert function_exported?(Emakola.Themes.Spotlight, fun, arity), "missing #{fun}/#{arity}"
      end
    end

    test "css_variables exposes theme custom properties" do
      vars = Emakola.Themes.Spotlight.css_variables()
      assert vars["--theme-bg"] == "#FBF9F5"
      assert vars["--theme-accent"] == "#7C3AED"
    end

    test "ingredients/0 returns a non-empty list of name+description maps" do
      items = Emakola.Themes.Spotlight.ingredients()
      assert is_list(items) and length(items) >= 3
      assert Enum.all?(items, &(is_binary(&1.name) and is_binary(&1.description)))
    end
  end
end
```

- [ ] **Step 2: Run, verify FAIL** — `mix test test/emakola/themes/spotlight_test.exs` (Spotlight undefined).

- [ ] **Step 3: Create stub sub-modules**

`lib/emakola/themes/spotlight/shared.ex`:
```elixir
defmodule Emakola.Themes.Spotlight.Shared do
  @moduledoc "Shared Spotlight components."
  use Phoenix.Component

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>:root { --theme-bg:#FBF9F5; --theme-accent:#7C3AED; --theme-primary:#16130F; }</style>
    """
  end
end
```

`lib/emakola/themes/spotlight/product_detail.ex`, `home.ex`, `product_list.ex` — each:
```elixir
defmodule Emakola.Themes.Spotlight.ProductDetail do
  @moduledoc "Spotlight product detail page."
  use Phoenix.Component
  def render(assigns), do: ~H"""
  <div class="spot-body"></div>
  """
end
```
(Use the matching module name `Emakola.Themes.Spotlight.Home` and `Emakola.Themes.Spotlight.ProductList` for the other two, same body.)

- [ ] **Step 4: Create the main module** — `lib/emakola/themes/spotlight.ex`:

```elixir
defmodule Emakola.Themes.Spotlight do
  @moduledoc """
  Spotlight theme — for single-product stores. A lighter, immersive long-form
  landing experience for one hero product (inspired by the "LIVELY" reference):
  warm off-white background, big Archivo display type, one vibrant configurable
  accent, pill CTAs, scroll-reveal motion.

  Render modules: Spotlight.Home, Spotlight.ProductList, Spotlight.ProductDetail, Spotlight.Shared.
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  def id, do: "spotlight"

  @impl true
  def name, do: "Spotlight"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Archivo:wght@600;700;800;900&family=Inter:wght@400;500;600;700&display=swap"
    ]

  @doc "Ingredient/feature breakdown cards (theme-default content; not yet admin-editable)."
  def ingredients do
    [
      %{name: "Made simply", description: "Clean, honest components — nothing hidden, nothing unnecessary."},
      %{name: "Locally sourced", description: "Sourced and made in Ghana, supporting local supply chains."},
      %{name: "Everyday quality", description: "Built for daily use — dependable, consistent, and well-made."},
      %{name: "Fairly priced", description: "Honest pricing with no surprises at checkout."},
      %{name: "Made to last", description: "Considered design and materials that hold up over time."}
    ]
  end

  def defaults do
    %{
      id: :spotlight,
      name: "Spotlight",
      colors: %{
        primary: "#16130F",
        accent: "#7C3AED",
        accent_dark: "#6D28D9",
        accent_soft: "#EDE7FB",
        background: "#FBF9F5",
        surface: "#FFFFFF",
        text: "#16130F",
        text_secondary: "#6B675F",
        border: "#ECE7DE"
      },
      fonts: %{heading: "Archivo", body: "Inter"},
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        overline: "The one you reach for",
        title: "One product.",
        subtitle: "Done right.",
        tagline: "Clean, honest, and made to be part of your everyday rhythm.",
        cta_text: "Choose yours",
        cta_url: "/products",
        badge: "100% Made in Ghana"
      },
      nav: %{search_placeholder: "Search...", transparent: false},
      sections: %{
        hero: true,
        featured_in: false,
        featured_products: true,
        why_us: true,
        testimonials: true,
        faq: false,
        closing_cta: true,
        newsletter: true
      },
      trust: %{
        title: "What makes it different",
        items: [
          %{icon: "visibility", title: "Radical transparency", description: "Clear components, clearly listed — nothing hidden."},
          %{icon: "bolt", title: "Everyday quality", description: "Dependable and consistent, built for daily use."},
          %{icon: "favorite", title: "Made with care", description: "Crafted to a standard we'd be proud to use ourselves."},
          %{icon: "eco", title: "Honestly made", description: "Responsibly sourced and fairly priced — start to finish."}
        ]
      },
      testimonials: %{
        title: "Loved by everyday people",
        items: [
          %{name: "Ama D.", location: "Accra", quote: "Exactly what I was looking for. Simple, reliable, and it just works."},
          %{name: "Kofi B.", location: "Kumasi", quote: "Quality you can feel. I've reordered three times now."},
          %{name: "Esi M.", location: "Takoradi", quote: "Beautiful, honest product. The whole experience feels considered."}
        ]
      },
      newsletter: %{
        title: "Stay in the loop",
        subtitle: "New drops and members-only offers, straight to your inbox.",
        button_text: "Subscribe"
      },
      closing_cta: %{
        title: "One product, done properly.",
        subtitle: "If you only make one thing, make it count.",
        button_text: "Get yours"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#16130F",
        "--theme-accent" => "#7C3AED",
        "--theme-bg" => "#FBF9F5",
        "--theme-font-heading" => "'Archivo', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @impl true
  def css_variables, do: defaults().css_variables

  def renderer(:home), do: Emakola.Themes.Spotlight.Home
  def renderer(:product_list), do: Emakola.Themes.Spotlight.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Spotlight.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Spotlight.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Spotlight.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Spotlight.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Spotlight.ProductDetail, as: :render
end
```

- [ ] **Step 5: Register in ThemeResolver** — in `lib/emakola/themes/theme_resolver.ex`, add to `@theme_modules` (alphabetical, after `"pharmacy"`): `"spotlight" => Emakola.Themes.Spotlight,`. Read the map first to match formatting.

- [ ] **Step 6: Register in admin picker** — in `lib/emakola_web/live/admin/theme_live.ex`, add to the `@theme_metadata` list:
```elixir
    %{id: "spotlight", name: "Spotlight", description: "Single-product showcase", icon: "star"},
```

- [ ] **Step 7: Run, verify PASS** — `mix test test/emakola/themes/spotlight_test.exs` (4 tests).

- [ ] **Step 8: Format & commit**
```bash
mix format
git add lib/emakola/themes/spotlight.ex lib/emakola/themes/spotlight/ lib/emakola/themes/theme_resolver.ex lib/emakola_web/live/admin/theme_live.ex test/emakola/themes/spotlight_test.exs
git commit -m "feat(themes): scaffold + register Spotlight single-product theme"
```

---

## Task 2: Spotlight.Shared

**Files:** modify `lib/emakola/themes/spotlight/shared.ex`; test `spotlight_test.exs`.

- [ ] **Step 1: Failing tests** — append inside `Emakola.Themes.SpotlightTest`:

```elixir
  describe "Shared" do
    setup do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS", whatsapp_number: "+233201234567"}
      theme = ThemeResolver.resolve(%{"theme" => "spotlight"})
      %{store: store, theme: theme}
    end

    defp shtml(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

    test "nav renders store name + cart link/count", %{store: store} do
      out = shtml(Emakola.Themes.Spotlight.Shared.nav(%{__changed__: nil, store: store, cart_count: 3}))
      assert out =~ "Demo Store"
      assert out =~ "/s/demo/cart"
      assert out =~ "3"
    end

    test "footer renders store name", %{store: store} do
      out = shtml(Emakola.Themes.Spotlight.Shared.footer(%{__changed__: nil, store: store}))
      assert out =~ "Demo Store"
    end

    test "product_card links + price", %{store: store} do
      product = %{slug: "tee", title: "Cotton Tee", min_price: 12_000, images: []}
      out = shtml(Emakola.Themes.Spotlight.Shared.product_card(%{__changed__: nil, store: store, product: product}))
      assert out =~ "/s/demo/products/tee"
      assert out =~ "Cotton Tee"
      assert out =~ "GH₵ 120"
    end

    test "whatsapp_link encodes special chars (no raw &)", %{store: store} do
      link = Emakola.Themes.Spotlight.Shared.whatsapp_link(store, "Salt & Pepper")
      text = link |> String.split("?text=") |> List.last()
      refute String.contains?(text, "&")
    end

    test "section_enabled? respects toggles" do
      theme = ThemeResolver.resolve(%{"theme" => "spotlight", "sections" => %{"newsletter" => false}})
      refute Emakola.Themes.Spotlight.Shared.section_enabled?(theme, :newsletter)
      assert Emakola.Themes.Spotlight.Shared.section_enabled?(theme, :testimonials)
    end
  end
```

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Implement Shared** — replace `lib/emakola/themes/spotlight/shared.ex`:

```elixir
defmodule Emakola.Themes.Spotlight.Shared do
  @moduledoc """
  Shared Spotlight components: theme_styles (CSS vars + .spot-* classes),
  nav, footer, product_card, image + WhatsApp helpers, section_enabled?.
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#16130F" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#7C3AED" %>;
        --theme-accent-dark: <%= get_in(@theme, [:colors, :accent_dark]) || "#6D28D9" %>;
        --theme-accent-soft: <%= get_in(@theme, [:colors, :accent_soft]) || "#EDE7FB" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#FBF9F5" %>;
      }
      .spot-body { font-family: 'Inter', sans-serif; color: #16130F; background: var(--theme-bg); }
      .spot-display { font-family: 'Archivo', 'Inter', sans-serif; font-weight: 800; letter-spacing: -0.02em; line-height: 0.95; }
      .spot-heading { font-family: 'Archivo', 'Inter', sans-serif; font-weight: 700; letter-spacing: -0.01em; }
      .spot-cta { background: var(--theme-accent); color: #fff; }
      .spot-cta:hover { background: var(--theme-accent-dark); }
      .spot-blob { background: var(--theme-accent-soft); filter: blur(8px); }
    </style>
    """
  end

  # ── Nav ──
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-[#FBF9F5]/85 backdrop-blur border-b border-[#ECE7DE]">
      <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 flex items-center justify-between h-16">
        <a href={"/s/#{@store.slug}"} class="spot-heading text-lg font-extrabold tracking-tight">{@store.name}</a>
        <nav class="hidden md:flex items-center gap-7 text-sm text-[#6B675F]">
          <a href={"/s/#{@store.slug}/products"} class="hover:text-[#16130F]">Product</a>
          <a href="#benefits" class="hover:text-[#16130F]">Benefits</a>
          <a href="#ingredients" class="hover:text-[#16130F]">Ingredients</a>
          <a href="#reviews" class="hover:text-[#16130F]">Reviews</a>
        </nav>
        <a href={"/s/#{@store.slug}/cart"} class="relative inline-flex items-center gap-2 spot-cta rounded-full px-4 py-2 text-sm font-semibold" aria-label={"Cart, #{@cart_count} items"}>
          Cart
          <span class="inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 rounded-full bg-white/25 text-[11px] font-bold">{@cart_count}</span>
        </a>
      </div>
    </header>
    """
  end

  # ── Footer ──
  attr :store, :map, required: true

  def footer(assigns) do
    ~H"""
    <footer class="bg-white border-t border-[#ECE7DE] mt-20">
      <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-12 grid grid-cols-2 md:grid-cols-4 gap-8">
        <div class="col-span-2">
          <div class="spot-heading text-xl font-extrabold">{@store.name}</div>
          <p class="text-sm text-[#6B675F] mt-3 max-w-sm leading-relaxed">
            {@store.description || "One product, done properly — made in Ghana, delivered to your door."}
          </p>
        </div>
        <div>
          <h4 class="text-xs font-semibold uppercase tracking-wider mb-3">Shop</h4>
          <ul class="space-y-2 text-sm text-[#6B675F]">
            <li><a href={"/s/#{@store.slug}/products"} class="hover:text-[#16130F]">The product</a></li>
            <li><a href={"/s/#{@store.slug}/cart"} class="hover:text-[#16130F]">Cart</a></li>
          </ul>
        </div>
        <div>
          <h4 class="text-xs font-semibold uppercase tracking-wider mb-3">More</h4>
          <ul class="space-y-2 text-sm text-[#6B675F]">
            <li><a href={"/s/#{@store.slug}/about"} class="hover:text-[#16130F]">About</a></li>
            <li><a href={"/s/#{@store.slug}/track"} class="hover:text-[#16130F]">Track order</a></li>
          </ul>
        </div>
      </div>
      <div class="border-t border-[#ECE7DE]">
        <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-5 text-xs text-[#9b968c]">
          &copy; {DateTime.utc_now().year} {@store.name}. Made in Ghana.
        </div>
      </div>
    </footer>
    """
  end

  # ── Helpers ──
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

  def whatsapp_number(store) do
    case Map.get(store, :whatsapp_number) do
      n when is_binary(n) ->
        digits = String.replace(n, ~r/\D/, "")
        if digits == "", do: nil, else: digits

      _ ->
        nil
    end
  end

  def whatsapp_link(store, product_title) do
    case whatsapp_number(store) do
      nil -> nil
      digits -> "https://wa.me/#{digits}?text=#{URI.encode_www_form("Hi! I'd like to order: #{product_title}")}"
    end
  end

  @doc "Section toggle: nil/absent → enabled; explicit false → disabled."
  def section_enabled?(theme, key) do
    case get_in(theme, [:sections, key]) do
      false -> false
      _ -> true
    end
  end

  # ── Product card ──
  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="rounded-2xl overflow-hidden bg-white border border-[#ECE7DE] aspect-square relative">
        <.optimized_image
          :if={first_image(@product)}
          src={first_image(@product)}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-500"
        />
        <div :if={!first_image(@product)} class="w-full h-full flex items-center justify-center bg-[#F3EFE8]">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-12 h-12 text-[#d8d0c2]" fill="currentColor" aria-hidden="true">
            <path d="M3.6 5.4a1 1 0 0 1 .9-.6h15a1 1 0 0 1 .9.6l1.6 3.6a1 1 0 0 1-.1.94 3.5 3.5 0 0 1-2.9 1.56V19a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7.5a3.5 3.5 0 0 1-2.9-1.56 1 1 0 0 1-.1-.94l1.6-3.6Zm5.4 8.6h6v4H9v-4Z" />
          </svg>
        </div>
      </div>
      <div class="pt-3">
        <h3 class="spot-heading text-sm font-semibold line-clamp-1">{@product.title}</h3>
        <span class="text-sm font-bold text-[#7C3AED] mt-1 block">
          {EmakolaWeb.Helpers.Currency.format_price(@product.min_price || 0, Map.get(@store, :currency, "GHS"))}
        </span>
      </div>
    </a>
    """
  end
end
```

- [ ] **Step 4: Run, verify PASS** (`mix test test/emakola/themes/spotlight_test.exs`).
- [ ] **Step 5: Format & commit** — `git commit -m "feat(themes): Spotlight shared nav, footer, product_card, helpers"`.

---

## Task 3: Spotlight.ProductDetail (centerpiece)

**Files:** modify `product_detail.ex`; add Spotlight to `product_detail_variants_test.exs`; tests in `spotlight_test.exs`.

- [ ] **Step 1: Add to the all-themes variants test** — in `test/emakola/themes/product_detail_variants_test.exs`, add `{Emakola.Themes.Spotlight, "spotlight"}` as the first `@themes` entry (keep the rest).

- [ ] **Step 2: Focused PDP tests** — append inside `Emakola.Themes.SpotlightTest`:

```elixir
  describe "ProductDetail" do
    setup do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS", whatsapp_number: "+233201234567"}
      theme = ThemeResolver.resolve(%{"theme" => "spotlight"})
      ot = %{id: "ot1", name: "Taste", option_values: [%{id: "ov_b", value: "Blueberry"}, %{id: "ov_m", value: "Mint"}]}
      product = %{title: "Lively Drink", slug: "lively", description: "A sparkling drink.", images: [], min_price: 9900, avg_rating: 4.8, review_count: 18, share_count: 0}
      variant = %{price: 9900, compare_at_price: nil, stock_quantity: 12}
      assigns = %{__changed__: nil, store: store, theme: theme, product: product, related_products: [], categories: [], cart_count: 0, selected_variant: variant, option_types: [ot], selected_options: %{"ot1" => "ov_b"}, quantity: 1, current_image_index: 0}
      %{assigns: assigns}
    end

    defp spdp(assigns), do: Emakola.Themes.Spotlight.ProductDetail.render(assigns) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

    test "renders title, price, CTAs, taste pills, sections", %{assigns: a} do
      out = spdp(a)
      assert out =~ "Lively Drink"
      assert out =~ "GH₵ 99"
      assert out =~ "Add to cart"
      assert out =~ "https://wa.me/233201234567"
      assert out =~ ~s(phx-click="select_option")
      assert out =~ ~s(phx-value-value="ov_b")
      assert out =~ "Blueberry"
      assert out =~ "Mint"
    end

    test "renders ingredients and benefits content", %{assigns: a} do
      out = spdp(a)
      assert out =~ "Radical transparency"            # from theme.trust
      assert out =~ hd(Emakola.Themes.Spotlight.ingredients()).name
    end

    test "no raise when review assigns absent (variants-test shape)", %{assigns: a} do
      assert is_binary(spdp(a))
    end

    test "renders reviews block when review assigns present", %{assigns: a} do
      a = Map.merge(a, %{reviews: [], can_review: false, already_reviewed: false, review_form_rating: 0, review_form_title: "", review_form_body: "", review_submitting: false, uploads: nil})
      assert spdp(a) =~ "review" or spdp(a) =~ "Review"
    end

    test "handles Decimal avg_rating", %{assigns: a} do
      a = put_in(a.product.avg_rating, Decimal.new("4.8"))
      out = spdp(a)
      assert out =~ "4.8"
      assert out =~ "★"
    end
  end
```

- [ ] **Step 3: Run, verify FAIL.**

- [ ] **Step 4: Implement ProductDetail** — FIRST read `assets/js/hooks/scroll_reveal.js` to learn the hook contract (note 5). Then replace `lib/emakola/themes/spotlight/product_detail.ex` with the implementation below. The `phx-hook="ScrollReveal"` + `id` attributes on `<section>` wrappers are included; adjust ONLY if the hook requires a specific initial class — but keep all content visible without JS.

```elixir
defmodule Emakola.Themes.Spotlight.ProductDetail do
  @moduledoc """
  Spotlight single-product page (centerpiece): immersive hero, benefits,
  ingredients, taste/variant selector + buy, testimonials, reviews. Lighter
  take on the LIVELY reference. Pure presentation — all events/assigns come
  from ProductDetailLive.
  """

  use Phoenix.Component

  alias Emakola.Themes.Spotlight.Shared

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
      |> assign(:trust, get_in(assigns.theme, [:trust]) || %{})
      |> assign(:testimonials, get_in(assigns.theme, [:testimonials]) || %{})
      |> assign(:closing, get_in(assigns.theme, [:closing_cta]) || %{})
      |> assign(:ingredients, Emakola.Themes.Spotlight.ingredients())

    ~H"""
    <div class="spot-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.nav store={@store} cart_count={@cart_count} />

      <%!-- HERO --%>
      <section class="relative overflow-hidden">
        <div class="absolute -top-24 -right-24 w-96 h-96 rounded-full spot-blob opacity-60"></div>
        <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-12 lg:py-20 grid lg:grid-cols-2 gap-10 items-center relative">
          <div>
            <p class="text-xs uppercase tracking-[0.25em] text-[#7C3AED] font-semibold">{get_in(@theme, [:hero, :overline]) || "The one you reach for"}</p>
            <h1 class="spot-display text-5xl sm:text-6xl lg:text-7xl text-[#16130F] mt-4 uppercase">{@product.title}</h1>
            <p class="text-[#6B675F] text-base mt-5 max-w-md leading-relaxed">{@product.description || get_in(@theme, [:hero, :tagline])}</p>
            <div class="flex items-center gap-4 mt-7">
              <span class="spot-heading text-2xl font-extrabold">{EmakolaWeb.Helpers.Currency.format_price(@price, @currency)}</span>
              <span :if={Map.get(@product, :review_count, 0) > 0} class="text-sm text-[#6B675F]"><span class="text-[#16130F]">{stars(@product)}</span> {@product.review_count}</span>
            </div>
            <div class="flex flex-wrap gap-3 mt-7">
              <button type="button" phx-click="add_to_cart" disabled={!in_stock?(@selected_variant)} class={"rounded-full px-7 py-3.5 text-sm font-semibold uppercase tracking-wider " <> if(in_stock?(@selected_variant), do: "spot-cta", else: "bg-[#ECE7DE] text-[#9b968c] cursor-not-allowed")}>
                {if in_stock?(@selected_variant), do: "Add to cart", else: "Sold out"}
              </button>
              <a :if={@wa_link} href={@wa_link} target="_blank" rel="noopener" class="rounded-full px-7 py-3.5 text-sm font-semibold border border-[#25D366] text-[#128C3A] hover:bg-[#25D366]/5">Order on WhatsApp</a>
            </div>
            <p class="text-[11px] uppercase tracking-wider text-[#9b968c] mt-5">{get_in(@theme, [:hero, :badge]) || "100% Made in Ghana"}</p>
          </div>
          <div class="relative">
            <div class="rounded-3xl overflow-hidden bg-white border border-[#ECE7DE] aspect-[4/5]">
              <.optimized_image :if={Shared.current_image(@product, @current_image_index)} src={Shared.current_image(@product, @current_image_index)} alt={@product.title} class="w-full h-full object-cover" />
              <div :if={!Shared.current_image(@product, @current_image_index)} class="w-full h-full flex items-center justify-center bg-[#F3EFE8]">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-24 h-24 text-[#d8d0c2]" fill="currentColor" aria-hidden="true"><path d="M3.6 5.4a1 1 0 0 1 .9-.6h15a1 1 0 0 1 .9.6l1.6 3.6a1 1 0 0 1-.1.94 3.5 3.5 0 0 1-2.9 1.56V19a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7.5a3.5 3.5 0 0 1-2.9-1.56 1 1 0 0 1-.1-.94l1.6-3.6Zm5.4 8.6h6v4H9v-4Z" /></svg>
              </div>
            </div>
            <div :if={length(@product.images) > 1} class="flex gap-2 mt-3">
              <button :for={{image, idx} <- Enum.with_index(@product.images)} type="button" phx-click="select_image" phx-value-index={idx} class={"w-14 h-14 rounded-xl overflow-hidden border " <> if(idx == @current_image_index, do: "border-[#7C3AED]", else: "border-[#ECE7DE] opacity-70")}>
                <img src={Map.get(image, :thumbnail_url) || Map.get(image, :url)} alt={"#{@product.title} #{idx + 1}"} class="w-full h-full object-cover" />
              </button>
            </div>
          </div>
        </div>
      </section>

      <%!-- BENEFITS --%>
      <section id="benefits" phx-hook="ScrollReveal" class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <h2 class="spot-heading text-3xl font-bold text-center mb-10">{Map.get(@trust, :title, "What makes it different")}</h2>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-6">
          <div :for={item <- Map.get(@trust, :items, [])} class="rounded-2xl bg-white border border-[#ECE7DE] p-6 text-center">
            <span class="material-symbols-outlined text-[#7C3AED] text-3xl">{Map.get(item, :icon, "star")}</span>
            <h3 class="spot-heading text-base font-semibold mt-3">{item.title}</h3>
            <p class="text-sm text-[#6B675F] mt-1 leading-relaxed">{item.description}</p>
          </div>
        </div>
      </section>

      <%!-- STATEMENT --%>
      <section class="bg-[var(--theme-accent-soft)]">
        <div class="max-w-[900px] mx-auto px-4 sm:px-6 lg:px-8 py-20 text-center">
          <span class="material-symbols-outlined text-[#7C3AED] text-3xl">auto_awesome</span>
          <p class="spot-display text-3xl sm:text-4xl text-[#16130F] mt-4 leading-tight">{Map.get(@closing, :title, "One product, done properly.")}</p>
          <p class="text-[#6B675F] mt-4">{Map.get(@closing, :subtitle)}</p>
          <a href="#buy" class="inline-block mt-7 rounded-full spot-cta px-7 py-3.5 text-sm font-semibold uppercase tracking-wider">{Map.get(@closing, :button_text, "Get yours")}</a>
        </div>
      </section>

      <%!-- INGREDIENTS --%>
      <section id="ingredients" phx-hook="ScrollReveal" class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <h2 class="spot-heading text-3xl font-bold mb-2">{length(@ingredients)} reasons it works</h2>
        <p class="text-[#6B675F] mb-10 max-w-xl">Everything that goes in, and why it matters. Nothing superfluous.</p>
        <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-x-10 gap-y-8">
          <div :for={ing <- @ingredients} class="border-t border-[#ECE7DE] pt-4">
            <h3 class="spot-heading text-lg font-semibold">{ing.name}</h3>
            <p class="text-sm text-[#6B675F] mt-1 leading-relaxed">{ing.description}</p>
          </div>
        </div>
      </section>

      <%!-- BUY: taste selector --%>
      <section id="buy" class="bg-white border-y border-[#ECE7DE]">
        <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16 grid lg:grid-cols-2 gap-10 items-center">
          <div class="rounded-3xl overflow-hidden bg-[#F3EFE8] aspect-square">
            <.optimized_image :if={Shared.first_image(@product)} src={Shared.first_image(@product)} alt={@product.title} class="w-full h-full object-cover" />
          </div>
          <div>
            <h2 class="spot-heading text-3xl font-bold">{@product.title}</h2>
            <div :if={@option_types != []} class="space-y-5 mt-6">
              <div :for={option_type <- @option_types}>
                <div class="text-xs uppercase tracking-wider text-[#6B675F] mb-2">{option_type.name}: <span class="text-[#16130F] font-semibold">{selected_label(option_type, @selected_options)}</span></div>
                <div class="flex flex-wrap gap-2">
                  <button :for={ov <- option_type.option_values || []} type="button" phx-click="select_option" phx-value-option_type_id={option_type.id} phx-value-value={ov.id}
                    class={"min-h-[44px] px-5 py-2.5 rounded-full text-sm border transition-colors " <> if(Map.get(@selected_options, option_type.id) == ov.id, do: "border-[#7C3AED] bg-[#7C3AED] text-white font-medium", else: "border-[#ECE7DE] bg-white hover:border-[#7C3AED]")}>
                    {ov.value}
                  </button>
                </div>
              </div>
            </div>
            <div class="flex items-center gap-4 mt-7">
              <span class="spot-heading text-2xl font-extrabold">{EmakolaWeb.Helpers.Currency.format_price(@price, @currency)}</span>
              <div class="flex items-center border border-[#ECE7DE] rounded-full">
                <button type="button" phx-click="decrement_quantity" class="w-10 h-10 flex items-center justify-center" aria-label="Decrease quantity">−</button>
                <span class="w-10 text-center text-sm font-medium">{@quantity}</span>
                <button type="button" phx-click="increment_quantity" class="w-10 h-10 flex items-center justify-center" aria-label="Increase quantity">+</button>
              </div>
              <span class="text-xs" style={"color: #{stock_color(@selected_variant)}"}>{stock_label(@selected_variant)}</span>
            </div>
            <button type="button" phx-click="add_to_cart" disabled={!in_stock?(@selected_variant)} class={"w-full sm:w-auto mt-6 rounded-full px-10 py-4 text-sm font-semibold uppercase tracking-wider " <> if(in_stock?(@selected_variant), do: "spot-cta", else: "bg-[#ECE7DE] text-[#9b968c] cursor-not-allowed")}>
              {if in_stock?(@selected_variant), do: "Add to cart", else: "Out of stock"}
            </button>
            <a :if={@wa_link} href={@wa_link} target="_blank" rel="noopener" class="block sm:inline-block mt-3 sm:ml-3 text-center rounded-full px-8 py-4 text-sm font-semibold border border-[#25D366] text-[#128C3A] hover:bg-[#25D366]/5">Order on WhatsApp</a>
            <a href={"/s/#{@store.slug}/cart"} class="block mt-4 text-sm text-[#7C3AED] hover:underline">View cart ({@cart_count}) →</a>
          </div>
        </div>
      </section>

      <%!-- TESTIMONIALS --%>
      <section phx-hook="ScrollReveal" id="testimonials" class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <h2 class="spot-heading text-3xl font-bold text-center mb-10">{Map.get(@testimonials, :title, "Loved by everyday people")}</h2>
        <div class="grid md:grid-cols-3 gap-6">
          <figure :for={t <- Map.get(@testimonials, :items, [])} class="rounded-2xl bg-white border border-[#ECE7DE] p-6">
            <div class="text-[#7C3AED]">★★★★★</div>
            <blockquote class="text-sm text-[#16130F] mt-3 leading-relaxed">"{t.quote}"</blockquote>
            <figcaption class="text-xs text-[#6B675F] mt-4 font-semibold">{t.name}<span :if={Map.get(t, :location)} class="font-normal"> · {t.location}</span></figcaption>
          </figure>
        </div>
      </section>

      <%!-- REVIEWS (only when LiveView provides review assigns) --%>
      <section :if={assigns[:reviews] != nil} id="reviews" class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16 border-t border-[#ECE7DE]">
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

      <Shared.footer store={@store} />
    </div>
    """
  end

  # ── Helpers ──
  defp price_for(_product, %{price: price}) when is_integer(price), do: price
  defp price_for(product, _), do: Map.get(product, :min_price) || 0

  defp compare_at(%{compare_at_price: cap}) when is_integer(cap), do: cap
  defp compare_at(_), do: nil

  defp in_stock?(%{stock_quantity: q}) when is_integer(q), do: q > 0
  defp in_stock?(_), do: true

  defp stock_label(%{stock_quantity: q}) when is_integer(q) and q <= 0, do: "Out of stock"
  defp stock_label(%{stock_quantity: q}) when is_integer(q) and q <= 5, do: "Only #{q} left"
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

  defp stars(product) do
    n =
      case Map.get(product, :avg_rating) do
        %Decimal{} = r -> r |> Decimal.to_float() |> round()
        r when is_number(r) -> round(r)
        _ -> 0
      end

    String.duplicate("★", n) <> String.duplicate("☆", 5 - n)
  end
end
```

- [ ] **Step 5: Run, verify PASS** — `mix test test/emakola/themes/spotlight_test.exs test/emakola/themes/product_detail_variants_test.exs`. If the variants test fails for spotlight, check note 1 (Access on optional assigns).
- [ ] **Step 6: Format & commit** — `git commit -m "feat(themes): Spotlight single-product detail page"`.

---

## Task 4: Spotlight.Home (marketing funnel)

**Files:** modify `home.ex`; tests in `spotlight_test.exs`.

- [ ] **Step 1: Failing tests** — append inside `Emakola.Themes.SpotlightTest`:

```elixir
  describe "Home" do
    test "renders hero from first product and funnels to its page" do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS"}
      theme = ThemeResolver.resolve(%{"theme" => "spotlight"})
      product = %{slug: "lively", title: "Lively Drink", min_price: 9900, images: []}
      assigns = %{__changed__: nil, store: store, theme: theme, cart_count: 0, products: [product], categories: []}
      out = Emakola.Themes.Spotlight.Home.render(assigns) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      assert out =~ "Lively Drink"
      assert out =~ "/s/demo/products/lively"
    end

    test "empty products renders a coming-soon hero without raising" do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS"}
      theme = ThemeResolver.resolve(%{"theme" => "spotlight"})
      assigns = %{__changed__: nil, store: store, theme: theme, cart_count: 0, products: [], categories: []}
      out = Emakola.Themes.Spotlight.Home.render(assigns) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      assert is_binary(out)
      assert out =~ "Demo Store"
    end

    test "hides newsletter when disabled" do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS"}
      theme = ThemeResolver.resolve(%{"theme" => "spotlight", "sections" => %{"newsletter" => false}})
      assigns = %{__changed__: nil, store: store, theme: theme, cart_count: 0, products: [], categories: []}
      out = Emakola.Themes.Spotlight.Home.render(assigns) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      refute out =~ (get_in(theme, [:newsletter, :title]) || "Stay in the loop")
    end
  end
```

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Implement Home** — replace `lib/emakola/themes/spotlight/home.ex`:

```elixir
defmodule Emakola.Themes.Spotlight.Home do
  @moduledoc "Spotlight home — immersive marketing landing that funnels to the hero product page."

  use Phoenix.Component

  alias Emakola.Themes.Spotlight.Shared

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :products, :list, default: []
  attr :categories, :list, default: []

  def render(assigns) do
    assigns =
      assigns
      |> assign(:hero_product, List.first(assigns.products))
      |> assign(:hero, get_in(assigns.theme, [:hero]) || %{})
      |> assign(:trust, get_in(assigns.theme, [:trust]) || %{})
      |> assign(:testimonials, get_in(assigns.theme, [:testimonials]) || %{})
      |> assign(:closing, get_in(assigns.theme, [:closing_cta]) || %{})
      |> assign(:ingredients, Emakola.Themes.Spotlight.ingredients())

    ~H"""
    <div class="spot-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.nav store={@store} cart_count={@cart_count} />

      <%!-- HERO --%>
      <section class="relative overflow-hidden">
        <div class="absolute -top-24 -right-24 w-96 h-96 rounded-full spot-blob opacity-60"></div>
        <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16 lg:py-24 grid lg:grid-cols-2 gap-10 items-center relative">
          <div>
            <p class="text-xs uppercase tracking-[0.25em] text-[#7C3AED] font-semibold">{Map.get(@hero, :overline, "The one you reach for")}</p>
            <h1 class="spot-display text-5xl sm:text-6xl lg:text-7xl text-[#16130F] mt-4 uppercase">
              {if @hero_product, do: @hero_product.title, else: Map.get(@hero, :title, "One product.")}
            </h1>
            <p class="text-[#6B675F] text-base mt-5 max-w-md leading-relaxed">{Map.get(@hero, :tagline)}</p>
            <div :if={@hero_product} class="mt-7">
              <a href={"/s/#{@store.slug}/products/#{@hero_product.slug}"} class="inline-block rounded-full spot-cta px-8 py-3.5 text-sm font-semibold uppercase tracking-wider">{Map.get(@hero, :cta_text, "Choose yours")}</a>
              <p class="text-[11px] uppercase tracking-wider text-[#9b968c] mt-4">{Map.get(@hero, :badge, "100% Made in Ghana")}</p>
            </div>
            <p :if={!@hero_product} class="mt-7 text-[#6B675F]">Our product launches soon — check back shortly.</p>
          </div>
          <div class="relative">
            <div class="rounded-3xl overflow-hidden bg-white border border-[#ECE7DE] aspect-[4/5]">
              <.optimized_image :if={@hero_product && Shared.first_image(@hero_product)} src={Shared.first_image(@hero_product)} alt={@hero_product.title} class="w-full h-full object-cover" />
              <div :if={!(@hero_product && Shared.first_image(@hero_product))} class="w-full h-full flex items-center justify-center bg-[#F3EFE8]">
                <span class="material-symbols-outlined text-[#d8d0c2] text-6xl">image</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- BENEFITS --%>
      <section :if={Shared.section_enabled?(@theme, :why_us)} id="benefits" phx-hook="ScrollReveal" class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <h2 class="spot-heading text-3xl font-bold text-center mb-10">{Map.get(@trust, :title, "What makes it different")}</h2>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-6">
          <div :for={item <- Map.get(@trust, :items, [])} class="rounded-2xl bg-white border border-[#ECE7DE] p-6 text-center">
            <span class="material-symbols-outlined text-[#7C3AED] text-3xl">{Map.get(item, :icon, "star")}</span>
            <h3 class="spot-heading text-base font-semibold mt-3">{item.title}</h3>
            <p class="text-sm text-[#6B675F] mt-1 leading-relaxed">{item.description}</p>
          </div>
        </div>
      </section>

      <%!-- INGREDIENTS --%>
      <section id="ingredients" phx-hook="ScrollReveal" class="bg-white border-y border-[#ECE7DE]">
        <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <h2 class="spot-heading text-3xl font-bold mb-10">{length(@ingredients)} reasons it works</h2>
          <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-x-10 gap-y-8">
            <div :for={ing <- @ingredients} class="border-t border-[#ECE7DE] pt-4">
              <h3 class="spot-heading text-lg font-semibold">{ing.name}</h3>
              <p class="text-sm text-[#6B675F] mt-1 leading-relaxed">{ing.description}</p>
            </div>
          </div>
        </div>
      </section>

      <%!-- TESTIMONIALS --%>
      <section :if={Shared.section_enabled?(@theme, :testimonials)} phx-hook="ScrollReveal" id="testimonials" class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <h2 class="spot-heading text-3xl font-bold text-center mb-10">{Map.get(@testimonials, :title, "Loved by everyday people")}</h2>
        <div class="grid md:grid-cols-3 gap-6">
          <figure :for={t <- Map.get(@testimonials, :items, [])} class="rounded-2xl bg-white border border-[#ECE7DE] p-6">
            <div class="text-[#7C3AED]">★★★★★</div>
            <blockquote class="text-sm text-[#16130F] mt-3 leading-relaxed">"{t.quote}"</blockquote>
            <figcaption class="text-xs text-[#6B675F] mt-4 font-semibold">{t.name}<span :if={Map.get(t, :location)} class="font-normal"> · {t.location}</span></figcaption>
          </figure>
        </div>
      </section>

      <%!-- STATEMENT / CLOSING CTA --%>
      <section :if={Shared.section_enabled?(@theme, :closing_cta)} class="bg-[var(--theme-accent-soft)]">
        <div class="max-w-[900px] mx-auto px-4 sm:px-6 lg:px-8 py-20 text-center">
          <p class="spot-display text-3xl sm:text-4xl text-[#16130F] leading-tight">{Map.get(@closing, :title, "One product, done properly.")}</p>
          <p class="text-[#6B675F] mt-4">{Map.get(@closing, :subtitle)}</p>
          <a :if={@hero_product} href={"/s/#{@store.slug}/products/#{@hero_product.slug}"} class="inline-block mt-7 rounded-full spot-cta px-8 py-3.5 text-sm font-semibold uppercase tracking-wider">{Map.get(@closing, :button_text, "Get yours")}</a>
        </div>
      </section>

      <%!-- NEWSLETTER --%>
      <section :if={Shared.section_enabled?(@theme, :newsletter)} class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16 text-center">
        <h2 class="spot-heading text-2xl font-bold">{get_in(@theme, [:newsletter, :title]) || "Stay in the loop"}</h2>
        <p class="text-sm text-[#6B675F] mt-2">{get_in(@theme, [:newsletter, :subtitle])}</p>
        <form class="flex max-w-md mx-auto mt-6 gap-2">
          <input type="email" placeholder="you@email.com" class="flex-1 px-4 py-3 rounded-full border border-[#ECE7DE] text-sm focus:outline-none focus:border-[#7C3AED]" />
          <button type="button" class="rounded-full spot-cta px-6 py-3 text-sm font-semibold">{get_in(@theme, [:newsletter, :button_text]) || "Subscribe"}</button>
        </form>
      </section>

      <Shared.footer store={@store} />
    </div>
    """
  end
end
```

- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Format & commit** — `git commit -m "feat(themes): Spotlight home (single-product funnel)"`.

---

## Task 5: Spotlight.ProductList

**Files:** modify `product_list.ex`; tests in `spotlight_test.exs`.

- [ ] **Step 1: Failing test** — append inside `Emakola.Themes.SpotlightTest`:

```elixir
  describe "ProductList" do
    test "renders product grid + empty state" do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS"}
      theme = ThemeResolver.resolve(%{"theme" => "spotlight"})
      products = [%{slug: "a", title: "Alpha", min_price: 1000, images: []}, %{slug: "b", title: "Beta", min_price: 2000, images: []}]
      out = Emakola.Themes.Spotlight.ProductList.render(%{__changed__: nil, store: store, theme: theme, cart_count: 0, products: products, categories: []}) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      assert out =~ "Alpha"
      assert out =~ "Beta"
      assert out =~ "/s/demo/products/a"

      empty = Emakola.Themes.Spotlight.ProductList.render(%{__changed__: nil, store: store, theme: theme, cart_count: 0, products: [], categories: []}) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      assert empty =~ "Demo Store"
    end
  end
```

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Implement ProductList** — replace `lib/emakola/themes/spotlight/product_list.ex`:

```elixir
defmodule Emakola.Themes.Spotlight.ProductList do
  @moduledoc "Spotlight product list — branded responsive grid."

  use Phoenix.Component

  alias Emakola.Themes.Spotlight.Shared

  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :products, :list, default: []
  attr :categories, :list, default: []

  def render(assigns) do
    ~H"""
    <div class="spot-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.nav store={@store} cart_count={@cart_count} />

      <section class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div class="flex items-baseline justify-between mb-8">
          <h1 class="spot-display text-4xl uppercase">Shop</h1>
          <span class="text-sm text-[#9b968c]">{length(@products)} items</span>
        </div>
        <div :if={@products != []} class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-5 sm:gap-6">
          <Shared.product_card :for={product <- @products} product={product} store={@store} />
        </div>
        <div :if={@products == []} class="text-center py-24 text-[#9b968c]">
          <p class="text-sm">No products yet. Check back soon.</p>
        </div>
      </section>

      <Shared.footer store={@store} />
    </div>
    """
  end
end
```

- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Format & commit** — `git commit -m "feat(themes): Spotlight product list page"`.

---

## Task 6: Full verification

- [ ] **Step 1:** `mix compile --warnings-as-errors 2>&1 | tail -20` — clean.
- [ ] **Step 2:** `mix test test/emakola/themes/ 2>&1 | tail -30` — all pass (incl. consistency + variants tests now covering spotlight).
- [ ] **Step 3:** `mix test test/emakola_web/live/storefront/ 2>&1 | tail -30` — no regressions (theme is additive). Distinguish any pre-existing/unrelated failures (e.g. ChromicPDF PDF timeout) from spotlight-caused ones.
- [ ] **Step 4:** `mix format --check-formatted` — clean (run `mix format` if not).
- [ ] **Step 5:** `mix credo --strict 2>&1 | tail -30` — no new issues on spotlight files.
- [ ] **Step 6:** Confirm registration: `grep -n spotlight lib/emakola/themes/theme_resolver.ex lib/emakola_web/live/admin/theme_live.ex`.
- [ ] **Step 7:** Integration spot-check — confirm `StoreLive` assigns `:products` (Home reads `@products`) and `ProductListLive` assigns `:products` (ProductList reads `@products`), and `Spotlight.ProductDetail` uses only events ProductDetailLive handles. Fix minimally if any mismatch; commit `chore(themes): verification fixes for Spotlight`.

---

## Self-review notes
- Spec coverage: scaffold+register (T1), Shared (T2), immersive PDP centerpiece with taste selector + benefits + ingredients + statement + testimonials + reviews (T3), funnel home (T4), product list (T5), verification (T6). ✓
- Optional-assign Access safety + option contract + Decimal ratings encoded (notes 1–3, T3). ✓
- Content sourcing: resolved `@theme` for hero/trust/testimonials/closing_cta/newsletter; `ingredients/0` for ingredients. ✓
- No `StoreLive`/`ProductDetailLive`/resource changes. ✓
- ScrollReveal: implementer reads the hook; content visible without JS. ✓
