# Landing Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the landing page as a merchant-first, image-led, Shopify-style story page with full feature coverage (incl. dropshipping), a new `/pricing` page, and SEO/AI-SEO structured data.

**Architecture:** `EmakolaWeb.LandingLive` is rewritten in place as one LiveView composed of private function components per section. A new `EmakolaWeb.PricingLive` hosts the existing 4-plan grid. A shared `landing_nav` component joins the existing `landing_footer` in `EmakolaWeb.LandingComponents`. JSON-LD flows through the existing `json_ld`/`canonical_url` assigns already supported by `EmakolaWeb.SEO.meta_tags` in the root layout.

**Tech Stack:** Phoenix 1.8 LiveView, TailwindCSS v4 (`@layer components` for custom CSS), Material Symbols icons, ExUnit + Phoenix.LiveViewTest.

**Spec:** `docs/superpowers/specs/2026-06-11-landing-redesign-design.md`

**Conventions that apply to every task:**
- Run tests with `mix test <path>`; full gate before each commit: `mix test && mix format --check-formatted && mix credo --strict` (run `mix format` first if needed).
- All money/prices on this page are display copy only — no Money math.
- The dev server should be **stopped** while editing (project rule: hot-reload races).

---

### Task 1: Download and commit the landing imagery

**Files:**
- Create: `priv/static/images/landing/hero-market-woman.jpg` (+ 13 more, see table)

The Unsplash CDN resizes on request, so we download at final size — no local resizing needed.

- [ ] **Step 1: Download all 14 images**

```bash
cd /Users/kojo/Projects/emakola/priv/static/images/landing
curl -sL -o hero-market-woman.jpg "https://images.unsplash.com/photo-1641422162969-3a3d177124d5?q=75&w=1600&fit=crop&fm=jpg"
curl -sL -o store-fruit.jpg      "https://images.unsplash.com/photo-1773858441336-7a8652acbaf1?q=75&w=600&fit=crop&fm=jpg"
curl -sL -o store-eggs.jpg       "https://images.unsplash.com/photo-1762945274836-4c2cbb75e20e?q=75&w=600&fit=crop&fm=jpg"
curl -sL -o store-tailor.jpg     "https://images.unsplash.com/photo-1687422809069-0fa3546b8471?q=75&w=600&fit=crop&fm=jpg"
curl -sL -o store-hair.jpg       "https://images.unsplash.com/photo-1702236240794-58dc4c6895e5?q=75&w=600&fit=crop&fm=jpg"
curl -sL -o store-beauty.jpg     "https://images.unsplash.com/photo-1647957902397-de1bd309fc21?q=75&w=600&fit=crop&fm=jpg"
curl -sL -o store-barber.jpg     "https://images.unsplash.com/photo-1653758265969-b048bb0b328a?q=75&w=600&fit=crop&fm=jpg"
curl -sL -o story-momo.jpg       "https://images.unsplash.com/photo-1573497019418-b400bb3ab074?q=75&w=800&fit=crop&fm=jpg"
curl -sL -o story-whatsapp.jpg   "https://images.unsplash.com/photo-1655720357872-ce227e4164ba?q=75&w=800&fit=crop&fm=jpg"
curl -sL -o story-storefront.jpg "https://images.unsplash.com/photo-1773858438654-08abe8814620?q=75&w=800&fit=crop&fm=jpg"
curl -sL -o growth-start.jpg     "https://images.unsplash.com/photo-1573497160825-0d94a2724d40?q=75&w=600&fit=crop&fm=jpg"
curl -sL -o growth-grow.jpg      "https://images.unsplash.com/photo-1614023342667-6f060e9d1e04?q=75&w=600&fit=crop&fm=jpg"
curl -sL -o growth-scale.jpg     "https://images.unsplash.com/photo-1563132337-f159f484226c?q=75&w=600&fit=crop&fm=jpg"
curl -sL -o cta-market.jpg       "https://images.unsplash.com/photo-1773858440557-cdb7fa2275bb?q=75&w=1600&fit=crop&fm=jpg"
```

- [ ] **Step 2: Verify every file is a real JPEG under budget**

Run: `file *.jpg | grep -v "JPEG image data" ; du -h *.jpg`
Expected: first command prints nothing (all JPEG); card images ≤ ~150 KB, hero/CTA ≤ ~300 KB. If one is oversized, re-download with `q=60`.

- [ ] **Step 3: Commit**

```bash
git add priv/static/images/landing/*.jpg
git commit -m "feat(web): add landing redesign photography (Unsplash, optimized)"
```

---

### Task 2: Rotating-word CSS + preload support in root layout

**Files:**
- Modify: `assets/css/app.css` (append a new `@layer components` block at the end)
- Modify: `lib/emakola_web/components/layouts/root.html.heex` (after the `<EmakolaWeb.SEO.meta_tags ... />` block, line ~18)

- [ ] **Step 1: Append rotating-word CSS to `app.css`**

```css
/* Hero rotating word (landing page). Pure CSS so LiveView DOM diffing
   cannot lose the state. @layer components so Tailwind utilities win. */
@layer components {
  .hero-rotator {
    display: inline-block;
    height: 1.15em;
    overflow: hidden;
    vertical-align: bottom;
  }
  .hero-rotator-list {
    display: flex;
    flex-direction: column;
    animation: hero-rotate 9s infinite;
  }
  .hero-rotator-list > span {
    height: 1.15em;
    line-height: 1.15em;
  }
  @keyframes hero-rotate {
    0%, 18% { transform: translateY(0); }
    25%, 43% { transform: translateY(-1.15em); }
    50%, 68% { transform: translateY(-2.3em); }
    75%, 93% { transform: translateY(-3.45em); }
    100% { transform: translateY(0); }
  }
  @media (prefers-reduced-motion: reduce) {
    .hero-rotator-list { animation: none; }
  }
}
```

- [ ] **Step 2: Add conditional preload link to the root layout**

Insert directly after the closing `/>` of `<EmakolaWeb.SEO.meta_tags ... />`:

```heex
<link :if={assigns[:preload_image]} rel="preload" as="image" href={assigns[:preload_image]} />
```

- [ ] **Step 3: Verify assets build and nothing broke**

Run: `mix assets.build && mix test test/emakola_web/live/landing_live_test.exs`
Expected: build succeeds; existing landing tests still PASS (no page change yet).

- [ ] **Step 4: Commit**

```bash
git add assets/css/app.css lib/emakola_web/components/layouts/root.html.heex
git commit -m "feat(web): hero rotating-word CSS and optional image preload in root layout"
```

---

### Task 3: Shared `landing_nav`, new `/pricing` page (TDD)

**Files:**
- Test: `test/emakola_web/live/pricing_live_test.exs` (create)
- Create: `lib/emakola_web/live/pricing_live.ex`
- Modify: `lib/emakola_web/components/landing_components.ex` (add `landing_nav/1`; fix footer `#pricing` link, line 30)
- Modify: `lib/emakola_web/router.ex` (public scope containing `live "/", LandingLive`, ~line 163)

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule EmakolaWeb.PricingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "pricing page" do
    test "renders all four plans with GHS amounts and rates", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pricing")

      assert html =~ "Simple, Transparent Pricing"
      assert html =~ "Starter"
      assert html =~ "Growth"
      assert html =~ "Pro"
      assert html =~ "Enterprise"
      assert html =~ "GHS 29"
      assert html =~ "GHS 79"
      assert html =~ "3.5% per sale"
      assert html =~ "1.2% per sale"
    end

    test "highlights the Pro plan", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pricing")
      assert html =~ "Most Popular"
    end

    test "renders shared nav and footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pricing")

      assert html =~ ~s(id="main-nav")
      assert html =~ ~s(href="/stores")
      assert html =~ ~s(href="/auth/login")
      assert html =~ "Help Center"
    end

    test "registration CTAs point to /auth/register", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pricing")
      assert html =~ ~s(href="/auth/register")
    end

    test "sets SEO title, canonical URL, and Offer JSON-LD", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pricing")

      assert html =~ "Pricing — Emakola"
      assert html =~ ~s(rel="canonical")
      assert html =~ "application/ld+json"
      assert html =~ "SoftwareApplication"
      assert html =~ ~s("priceCurrency":"GHS")
    end
  end
end
```


- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola_web/live/pricing_live_test.exs`
Expected: FAIL — no route `/pricing`.

- [ ] **Step 3: Add `landing_nav/1` to `LandingComponents`**

Append to `lib/emakola_web/components/landing_components.ex` (inside the module). Note the module already has `use Phoenix.Component` (or equivalent via `use EmakolaWeb, :html`) — match what's at the top of the file. Add `use Phoenix.VerifiedRoutes, ...` only if `~p` is not already available in this module; if it is not, use plain string paths as shown:

```elixir
  @doc """
  Marketing nav shared by the landing and pricing pages.

  Anchor links use absolute paths ("/#features") so they work from /pricing too.
  The parent LiveView must handle the "toggle_mobile_menu" event and pass
  `mobile_menu_open`.
  """
  attr :mobile_menu_open, :boolean, default: false

  def landing_nav(assigns) do
    ~H"""
    <nav
      id="main-nav"
      phx-hook="ScrollGlass"
      class="fixed top-0 left-0 right-0 z-50 bg-[#0c1526]/80 backdrop-blur-md border-b border-transparent transition-all duration-300"
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <a href="/" class="flex items-center gap-2">
            <img src="/images/emakola-logo.svg" alt="Emakola" class="h-8 w-auto" />
            <span class="text-xl font-headline font-bold text-[#f1f5f9]">Emakola</span>
          </a>
          <div class="hidden md:flex items-center gap-6">
            <a href="/#how-it-works" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
              How it works
            </a>
            <a href="/#features" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
              Features
            </a>
            <a href="/#faq" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
              FAQ
            </a>
            <a href="/pricing" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
              Pricing
            </a>
            <a href="/stores" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
              Browse stores
            </a>
          </div>
          <div class="hidden md:flex items-center gap-4">
            <a href="/auth/login" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
              Login
            </a>
            <a
              href="/auth/register"
              class="inline-flex items-center px-4 py-2 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors focus-visible:ring-2 focus-visible:ring-[#d4a843] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
            >
              Get Started
            </a>
          </div>
          <button
            phx-click="toggle_mobile_menu"
            class="md:hidden p-2 text-[#8896ab] hover:text-[#f1f5f9]"
            aria-label="Toggle menu"
          >
            <span class="material-symbols-outlined text-2xl">
              {if @mobile_menu_open, do: "close", else: "menu"}
            </span>
          </button>
        </div>
      </div>
      <div
        :if={@mobile_menu_open}
        class="md:hidden fixed inset-0 top-16 bg-[#0c1526] z-40 flex flex-col items-center justify-start pt-12 gap-6 animate-slide-down"
      >
        <a href="/#how-it-works" phx-click="toggle_mobile_menu" class="text-lg text-[#8896ab]">How it works</a>
        <a href="/#features" phx-click="toggle_mobile_menu" class="text-lg text-[#8896ab]">Features</a>
        <a href="/#faq" phx-click="toggle_mobile_menu" class="text-lg text-[#8896ab]">FAQ</a>
        <a href="/pricing" class="text-lg text-[#8896ab]">Pricing</a>
        <a href="/stores" class="text-lg text-[#8896ab]">Browse stores</a>
        <hr class="w-24 border-[#1a2744]" />
        <a href="/auth/login" class="text-lg text-[#8896ab]">Login</a>
        <a
          href="/auth/register"
          class="inline-flex items-center px-6 py-3 text-base font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg"
        >
          Get Started
        </a>
      </div>
    </nav>
    """
  end
```

Also change line 30 of the same file: `<:link href="#pricing">Pricing</:link>` → `<:link href="/pricing">Pricing</:link>`.

- [ ] **Step 4: Create `PricingLive`**

`lib/emakola_web/live/pricing_live.ex`. The plan-card grid is **copied verbatim** from the current `lib/emakola_web/live/landing_live.ex` SECTION 6 (the four `<div>` plan cards inside the `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4` container, lines ~681–827 — Starter, Growth, Pro, Enterprise). Do this copy BEFORE Task 5 deletes that section.

```elixir
defmodule EmakolaWeb.PricingLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Pricing — Emakola | Free to Start, Pay as You Grow",
       meta_description:
         "Emakola pricing: start free with 3.5% per sale, or grow with plans from GHS 29/month. Mobile money payments and WhatsApp notifications on every plan.",
       og_image: "/images/og-image.png",
       canonical_url: url(~p"/pricing"),
       json_ld: pricing_json_ld(),
       mobile_menu_open: false
     ), layout: false}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white font-body antialiased">
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main class="pt-16">
        <section class="py-20 px-4">
          <div class="max-w-5xl mx-auto">
            <h1 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] text-center mb-4">
              Simple, Transparent Pricing
            </h1>
            <p class="text-base text-[#5f6b7a] text-center mb-12 max-w-2xl mx-auto">
              All plans include SSL, mobile money payments, and basic analytics.
            </p>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <!-- PASTE the four plan cards (Starter/Growth/Pro/Enterprise) here,
                   copied verbatim from landing_live.ex SECTION 6.
                   Remove any `data-reveal` attributes (no ScrollReveal hook here). -->
            </div>
          </div>
        </section>
      </main>
      <.landing_footer />
    </div>
    """
  end

  defp pricing_json_ld do
    %{
      "@context" => "https://schema.org",
      "@type" => "SoftwareApplication",
      "name" => "Emakola",
      "applicationCategory" => "BusinessApplication",
      "operatingSystem" => "Web",
      "offers" => [
        %{"@type" => "Offer", "name" => "Starter", "price" => "0", "priceCurrency" => "GHS"},
        %{"@type" => "Offer", "name" => "Growth", "price" => "29", "priceCurrency" => "GHS"},
        %{"@type" => "Offer", "name" => "Pro", "price" => "79", "priceCurrency" => "GHS"}
      ]
    }
  end
end
```

- [ ] **Step 5: Add the route**

In `lib/emakola_web/router.ex`, in the public scope, directly under `live "/", LandingLive`:

```elixir
    live "/pricing", PricingLive
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `mix test test/emakola_web/live/pricing_live_test.exs`
Expected: PASS (5 tests). If the JSON-LD assertion fails on key order, relax it to `assert html =~ "priceCurrency"` and `assert html =~ "GHS"`.

- [ ] **Step 7: Full gate + commit**

```bash
mix format && mix test && mix credo --strict
git add lib/emakola_web/live/pricing_live.ex lib/emakola_web/components/landing_components.ex lib/emakola_web/router.ex test/emakola_web/live/pricing_live_test.exs
git commit -m "feat(web): dedicated /pricing page with shared landing nav and Offer JSON-LD"
```

Note: the old landing page still has its own inline nav and `#pricing` section — that's fine; it is replaced wholesale in Task 5.

---

### Task 4: Platform sitemap for the apex domain (TDD)

The existing sitemap is store-scoped (`/s/:store_slug/sitemap.xml`). The marketing pages need a platform-level sitemap.

**Files:**
- Test: `test/emakola_web/controllers/sitemap_controller_test.exs` (append a describe block; create the file with `use EmakolaWeb.ConnCase, async: true` if it doesn't exist)
- Modify: `lib/emakola_web/controllers/sitemap_controller.ex`
- Modify: `lib/emakola_web/router.ex`

- [ ] **Step 1: Write the failing test**

```elixir
  describe "platform sitemap" do
    test "GET /sitemap.xml lists the marketing pages", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")
      body = response(conn, 200)

      assert response_content_type(conn, :xml)
      assert body =~ "<urlset"
      assert body =~ "/pricing</loc>"
      assert body =~ "/stores</loc>"
    end
  end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `mix test test/emakola_web/controllers/sitemap_controller_test.exs`
Expected: FAIL — no route matches GET `/sitemap.xml`.

- [ ] **Step 3: Add the controller action**

Append to `SitemapController` (reuse the module's existing XML style):

```elixir
  @doc "Platform-level sitemap for the apex domain (marketing pages only)."
  def platform(conn, _params) do
    base = EmakolaWeb.Endpoint.url()

    entries =
      ["/", "/pricing", "/stores", "/docs"]
      |> Enum.map_join("\n", fn path -> "  <url><loc>#{base}#{path}</loc></url>" end)

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{entries}
    </urlset>
    """

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end
```

- [ ] **Step 4: Add the route**

In `router.ex`, next to the existing store-scoped `:seo` scope:

```elixir
  # Platform-level sitemap (apex domain marketing pages)
  scope "/", EmakolaWeb do
    pipe_through :seo
    get "/sitemap.xml", SitemapController, :platform
  end
```

- [ ] **Step 5: Run tests to verify they pass, then commit**

Run: `mix test test/emakola_web/controllers/sitemap_controller_test.exs`
Expected: PASS.

```bash
mix format && mix test && mix credo --strict
git add lib/emakola_web/controllers/sitemap_controller.ex lib/emakola_web/router.ex test/emakola_web/controllers/sitemap_controller_test.exs
git commit -m "feat(web): platform-level sitemap.xml for marketing pages"
```

---

### Task 5: Rewrite `LandingLive` (TDD — full test file first)

**Files:**
- Test: `test/emakola_web/live/landing_live_test.exs` (full rewrite)
- Modify: `lib/emakola_web/live/landing_live.ex` (full rewrite)

- [ ] **Step 1: Replace the entire test file**

```elixir
defmodule EmakolaWeb.LandingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "hero" do
    test "renders merchant-first hero with rotating words", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "For Ghana&#39;s Merchants" or html =~ "For Ghana's Merchants"
      assert html =~ "Be the next"
      assert html =~ "big name in Accra"
      assert html =~ "household brand"
      assert html =~ "MoMo success story"
      assert html =~ "market leader"
      assert html =~ "Start selling — free"
      assert html =~ "No credit card needed"
    end

    test "has no shopper hero", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      refute html =~ "Shop Trusted Local Businesses"
    end

    test "hero image is preloaded", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ ~s(rel="preload")
      assert html =~ "hero-market-woman.jpg"
    end
  end

  describe "nav" do
    test "renders marketing nav with correct links", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="main-nav")
      assert html =~ ~s(phx-hook="ScrollGlass")
      assert html =~ ~s(href="/pricing")
      assert html =~ ~s(href="/stores")
      assert html =~ ~s(href="/auth/login")
      assert html =~ ~s(href="/auth/register")
      assert html =~ ~s(href="/#faq")
    end

    test "mobile menu toggles", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      refute render(view) =~ "animate-slide-down"
      assert view |> element("button[phx-click=toggle_mobile_menu]") |> render_click() =~
               "animate-slide-down"
    end
  end

  describe "store wall" do
    test "renders six vertical-diverse example stores", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Stores built on Emakola"
      assert html =~ "Mansa Fresh"
      assert html =~ "Yaa Braids"
      assert html =~ "Adwoa Glow"
      assert html =~ "Efua&#39;s Kitchen" or html =~ "Efua's Kitchen"
      assert html =~ "Kojo the Tailor"
      assert html =~ "Kwaku Cuts"
      assert html =~ "GHS 150"
      assert html =~ "store-hair.jpg"
      assert html =~ "store-barber.jpg"
      assert html =~ "seamstresses"
    end
  end

  describe "feature stories" do
    test "renders three stories with floating UI copy", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Get paid in seconds"
      assert html =~ "Customers kept in the loop"
      assert html =~ "A storefront that loads fast everywhere"
      assert html =~ "GHS 85.00"
      assert html =~ "Order #1042 confirmed!"
      assert html =~ "story-momo.jpg"
    end
  end

  describe "features grid" do
    test "renders all nine features including dropshipping", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Everything you need to sell"

      for title <- [
            "Dropshipping &amp; suppliers",
            "Storefront themes",
            "Digital products",
            "Inventory tracking",
            "Shipping &amp; delivery",
            "Coupons &amp; discounts",
            "Analytics &amp; reports",
            "Blog &amp; recipes",
            "Multi-store"
          ] do
        assert html =~ title
      end
    end
  end

  describe "growth arc" do
    test "renders start/grow/scale cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "From first sale to household name"
      assert html =~ "START"
      assert html =~ "GROW"
      assert html =~ "SCALE"
      assert html =~ "Makola Market"
      assert html =~ "all 16 regions"
    end
  end

  describe "stats band" do
    test "renders cited stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "500+"
      assert html =~ "mobile money networks"
      assert html =~ "from checkout to payout"
    end
  end

  describe "launch steps" do
    test "renders the three launch steps", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Launch before lunch"
      assert html =~ "Add your first product"
      assert html =~ "Share your store link"
      assert html =~ "Get paid with MoMo"
    end
  end

  describe "faq" do
    test "renders seven FAQ entries as details elements", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Who can sell on Emakola?"
      assert html =~ "What is dropshipping on Emakola?"
      assert length(String.split(html, "<details")) - 1 == 7
    end
  end

  describe "no pricing on landing" do
    test "pricing grid lives on /pricing, not here", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      refute html =~ "Most Popular"
      refute html =~ "GHS 29"
    end
  end

  describe "seo" do
    test "sets merchant-first SEO meta and JSON-LD", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Start Selling Online in Ghana"
      assert html =~ ~s(rel="canonical")
      assert html =~ "application/ld+json"
      assert html =~ "FAQPage"
      assert html =~ "SoftwareApplication"
      assert html =~ "Organization"
    end
  end

  describe "page chrome" do
    test "ScrollReveal hook and footer render", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(phx-hook="ScrollReveal")
      assert html =~ ~s(href="/pricing")
    end
  end
end
```

Adjust the HTML-entity assertions (`&#39;`, `&amp;`) to whatever HEEx actually
emits — run the test and read the failure diff once before fixing.

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola_web/live/landing_live_test.exs`
Expected: most tests FAIL against the old page.

- [ ] **Step 3: Rewrite `landing_live.ex` — module head, data, mount**

Replace the entire file. Module head:

```elixir
defmodule EmakolaWeb.LandingLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]

  @rotating_words ["big name in Accra", "household brand", "MoMo success story", "market leader"]

  @faqs [
    {"What is Emakola?",
     "Emakola is an ecommerce platform for West African merchants. You create an online store, accept mobile money payments, and manage orders from one dashboard."},
    {"Who can sell on Emakola?",
     "Anyone with something to sell: market traders, seamstresses and tailors, hair stylists, beauticians and cosmetics sellers, barbers, tradesmen, food vendors, and electronics shops. Themed storefronts fit each trade."},
    {"How much does Emakola cost?",
     "Emakola is free to start — you pay 3.5% per sale on the Starter plan. Paid plans start at GHS 29 per month with lower transaction rates."},
    {"Can I accept MTN MoMo and Telecel Cash?",
     "Yes. Emakola supports MTN MoMo, Telecel Cash, AirtelTigo, and card payments through Paystack and Hubtel."},
    {"What is dropshipping on Emakola?",
     "Dropshipping lets you sell products your suppliers hold. When an order comes in, the supplier fulfills it and Emakola tracks supplier costs and settlements automatically."},
    {"Can I sell digital products?",
     "Yes. Upload files to a product and customers get automatic download access after payment."},
    {"Do customers get order updates?",
     "Yes, automatically on WhatsApp and SMS: order confirmations, shipping updates, and delivery notifications."}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Emakola — Start Selling Online in Ghana | Mobile Money & Dropshipping",
       meta_description:
         "Create your online store in Ghana. Accept MTN MoMo and Telecel Cash, dropship from local suppliers, and send WhatsApp order updates. Free to start.",
       og_title: "Emakola — Start Selling Online in Ghana",
       og_description:
         "The ecommerce platform for West African merchants. Mobile money payments, dropshipping, WhatsApp notifications.",
       og_image: "/images/og-image.png",
       twitter_card: "summary_large_image",
       canonical_url: url(~p"/"),
       preload_image: "/images/landing/hero-market-woman.jpg",
       json_ld: json_ld(),
       mobile_menu_open: false
     ), layout: false}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end
```

Data helpers (bottom of module, above `json_ld/0`):

```elixir
  defp rotating_words, do: @rotating_words
  defp faqs, do: @faqs

  defp stores do
    [
      %{name: "Mansa Fresh", dot: "bg-[#16a34a]", img: "/images/landing/store-fruit.jpg",
        alt: "Market woman in an orange dress arranging fruit at her stall", chip: "Fruit Basket · GHS 75"},
      %{name: "Yaa Braids", dot: "bg-[#ec4899]", img: "/images/landing/store-hair.jpg",
        alt: "Client smiling while having her hair styled at a salon", chip: "Braiding Bundle · GHS 150"},
      %{name: "Adwoa Glow", dot: "bg-[#9333ea]", img: "/images/landing/store-beauty.jpg",
        alt: "Beautician applying makeup for a client", chip: "Shea Glow Set · GHS 95"},
      %{name: "Efua's Kitchen", dot: "bg-[#2563eb]", img: "/images/landing/store-eggs.jpg",
        alt: "Woman selling a pyramid of fresh eggs at the market", chip: "Fresh Eggs · GHS 40"},
      %{name: "Kojo the Tailor", dot: "bg-[#d4a843]", img: "/images/landing/store-tailor.jpg",
        alt: "Tailor smiling as he works at his sewing machine", chip: "Custom Kaftan · GHS 320"},
      %{name: "Kwaku Cuts", dot: "bg-[#0ea5e9]", img: "/images/landing/store-barber.jpg",
        alt: "Barber giving a client a haircut in his shop", chip: "Grooming Kit · GHS 120"}
    ]
  end

  defp features do
    [
      %{icon: "warehouse", title: "Dropshipping & suppliers",
        blurb: "Sell products you don't stock — suppliers fulfill, Emakola tracks costs and settlements."},
      %{icon: "palette", title: "Storefront themes",
        blurb: "14 professional themes, from fashion to pharmacy. Switch anytime."},
      %{icon: "download", title: "Digital products",
        blurb: "Sell downloads — files delivered automatically after payment."},
      %{icon: "inventory_2", title: "Inventory tracking",
        blurb: "Know your stock levels across locations, always."},
      %{icon: "local_shipping", title: "Shipping & delivery",
        blurb: "Zones, rates, and live order tracking across Ghana."},
      %{icon: "percent", title: "Coupons & discounts",
        blurb: "Run promotions that bring customers back."},
      %{icon: "monitoring", title: "Analytics & reports",
        blurb: "See sales, customers, and trends — export PDF reports."},
      %{icon: "article", title: "Blog & recipes",
        blurb: "Built-in content marketing — publish posts and recipes on your store."},
      %{icon: "storefront", title: "Multi-store",
        blurb: "Run several stores from one account and dashboard."}
    ]
  end

  defp json_ld do
    base = EmakolaWeb.Endpoint.url()

    %{
      "@context" => "https://schema.org",
      "@graph" => [
        %{"@type" => "Organization", "name" => "Emakola", "url" => base,
          "logo" => base <> "/images/emakola-logo.svg"},
        %{"@type" => "WebSite", "name" => "Emakola", "url" => base},
        %{"@type" => "SoftwareApplication", "name" => "Emakola",
          "applicationCategory" => "BusinessApplication", "operatingSystem" => "Web",
          "description" =>
            "Ecommerce platform for West African merchants with mobile money payments, dropshipping, and WhatsApp notifications.",
          "offers" => %{"@type" => "Offer", "price" => "0", "priceCurrency" => "GHS"}},
        %{"@type" => "FAQPage",
          "mainEntity" =>
            Enum.map(@faqs, fn {q, a} ->
              %{"@type" => "Question", "name" => q,
                "acceptedAnswer" => %{"@type" => "Answer", "text" => a}}
            end)}
      ]
    }
  end
end
```

- [ ] **Step 4: Top-level render**

```elixir
  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="landing-scroll"
      phx-hook="ScrollReveal"
      class="min-h-screen bg-[#0c1526] text-[#f1f5f9] font-body antialiased"
    >
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main>
        <.hero />
        <.store_wall />
        <.feature_stories />
        <.features_grid />
        <.growth_arc />
        <.stats_band />
        <.launch_steps />
        <.faq_section />
        <.final_cta />
      </main>
      <.landing_footer />
    </div>
    """
  end
```

- [ ] **Step 5: Hero section component**

```elixir
  defp hero(assigns) do
    ~H"""
    <section
      class="relative bg-cover pt-16"
      style="background-image: linear-gradient(180deg, rgba(12,21,38,0.62) 0%, rgba(12,21,38,0.80) 70%, #0c1526 100%), url('/images/landing/hero-market-woman.jpg'); background-position: center 25%;"
    >
      <div class="max-w-4xl mx-auto px-4 sm:px-6 text-center py-24 lg:py-36">
        <span class="inline-block text-xs font-semibold tracking-[0.2em] uppercase text-[#d4a843] mb-4">
          For Ghana's Merchants
        </span>
        <h1 class="text-4xl sm:text-5xl lg:text-6xl font-headline font-extrabold leading-[1.1] [text-shadow:0_2px_18px_rgba(12,21,38,0.6)]">
          Be the next<br />
          <span class="hero-rotator">
            <span class="hero-rotator-list">
              <span :for={word <- rotating_words()} class="text-[#d4a843]">{word}</span>
            </span>
          </span>
        </h1>
        <p class="text-base lg:text-lg text-[#e2e8f0] mt-6 mb-8 max-w-xl mx-auto">
          Dream big and sell fast on Emakola. Mobile money payments, WhatsApp updates,
          and a storefront built for Ghana.
        </p>
        <a
          href="/auth/register"
          class="inline-flex items-center px-8 py-4 text-base font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors focus-visible:ring-2 focus-visible:ring-[#d4a843] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
        >
          Start selling — free
        </a>
        <p class="text-xs text-[#cbd5e1] mt-4">No credit card needed</p>
      </div>
    </section>
    """
  end
```

- [ ] **Step 6: Store wall component**

```elixir
  defp store_wall(assigns) do
    ~H"""
    <section class="py-16 px-4 sm:px-6" data-reveal>
      <div class="max-w-6xl mx-auto">
        <h2 class="text-center text-2xl lg:text-3xl font-headline font-bold mb-2">
          Stores built on Emakola
        </h2>
        <p class="text-center text-sm text-[#8896ab] mb-10 max-w-xl mx-auto">
          Market traders, seamstresses, hair stylists, beauticians, barbers —
          if you sell it, Emakola handles it.
        </p>
        <div class="flex gap-4 overflow-x-auto snap-x pb-4 lg:grid lg:grid-cols-3 lg:overflow-visible lg:pb-0">
          <div
            :for={{store, i} <- Enum.with_index(stores())}
            class={[
              "w-64 shrink-0 snap-start lg:w-auto bg-[#13203a] border border-[#1f2f50] rounded-2xl overflow-hidden",
              rem(i, 3) == 1 && "lg:mt-6"
            ]}
          >
            <div class="flex items-center gap-2 px-4 py-3 text-sm font-bold">
              <span class={["w-3 h-3 rounded-full", store.dot]}></span>
              {store.name}
            </div>
            <img
              src={store.img}
              alt={store.alt}
              loading="lazy"
              width="600"
              height="400"
              class="w-full h-[170px] object-cover"
            />
            <p class="px-4 py-3 text-xs font-bold text-[#d4a843]">{store.chip}</p>
          </div>
        </div>
      </div>
    </section>
    """
  end
```

- [ ] **Step 7: Feature stories component**

```elixir
  defp feature_stories(assigns) do
    ~H"""
    <section class="bg-[#f7f8fa] py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-5xl mx-auto space-y-16 lg:space-y-24">
        <div class="flex flex-col lg:flex-row items-center gap-8 lg:gap-16" data-reveal>
          <div class="flex-1">
            <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] mb-3">
              Get paid in seconds
            </h2>
            <p class="text-base text-[#5f6b7a]">
              MTN MoMo, Telecel Cash, AirtelTigo, and cards. The money lands before
              the customer hangs up.
            </p>
          </div>
          <div class="flex-1 relative w-full">
            <img
              src="/images/landing/story-momo.jpg"
              alt="Merchant smiling after receiving a mobile money payment"
              loading="lazy"
              width="800"
              height="533"
              class="w-full h-[240px] object-cover rounded-2xl"
            />
            <div class="absolute bottom-3 left-3 lg:-bottom-4 lg:-left-4 bg-white rounded-xl shadow-xl p-4">
              <p class="text-[10px] text-[#5f6b7a]">Payment received</p>
              <p class="text-sm font-extrabold text-[#0c1526]">+ GHS 85.00 · MoMo</p>
              <p class="text-[10px] font-bold text-[#16a34a]">✓ In your wallet</p>
            </div>
          </div>
        </div>

        <div class="flex flex-col lg:flex-row-reverse items-center gap-8 lg:gap-16" data-reveal>
          <div class="flex-1">
            <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] mb-3">
              Customers kept in the loop
            </h2>
            <p class="text-base text-[#5f6b7a]">
              Order confirmations and delivery updates sent on WhatsApp and SMS —
              no extra work for you.
            </p>
          </div>
          <div class="flex-1 relative w-full">
            <img
              src="/images/landing/story-whatsapp.jpg"
              alt="Friends checking an order update together on a laptop"
              loading="lazy"
              width="800"
              height="533"
              class="w-full h-[240px] object-cover rounded-2xl"
            />
            <div class="absolute bottom-3 right-3 lg:-bottom-4 lg:-right-4 bg-[#dcf8c6] rounded-xl rounded-br-sm shadow-xl p-3 max-w-[70%]">
              <p class="text-xs text-[#0c1526]">
                🛍️ <b>Order #1042 confirmed!</b><br />Hi Akosua — your order ships today.
              </p>
              <p class="text-[9px] text-[#5f6b7a] mt-1 text-right">WhatsApp · automatic</p>
            </div>
          </div>
        </div>

        <div class="flex flex-col lg:flex-row items-center gap-8 lg:gap-16" data-reveal>
          <div class="flex-1">
            <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] mb-3">
              A storefront that loads fast everywhere
            </h2>
            <p class="text-base text-[#5f6b7a]">
              Built for real Ghanaian networks — light pages, lazy images, works on
              any phone.
            </p>
          </div>
          <div class="flex-1 relative w-full">
            <img
              src="/images/landing/story-storefront.jpg"
              alt="Woman in a green dress shopping at a bustling Accra market"
              loading="lazy"
              width="800"
              height="533"
              class="w-full h-[240px] object-cover rounded-2xl"
            />
            <div class="absolute top-3 right-3 bg-white rounded-xl shadow-xl px-3 py-2">
              <p class="text-[10px] text-[#5f6b7a]">🔒 amas-fashion.emakola.com</p>
              <p class="text-xs font-extrabold text-[#16a34a]">Loads in 1.2s on 3G</p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end
```

- [ ] **Step 8: Features grid component**

```elixir
  defp features_grid(assigns) do
    ~H"""
    <section id="features" class="bg-white py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-6xl mx-auto">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] text-center mb-2">
          Everything you need to sell
        </h2>
        <p class="text-base text-[#5f6b7a] text-center mb-12">
          The full toolkit, built for Ghana
        </p>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          <div :for={feature <- features()} class="bg-[#f7f8fa] rounded-2xl p-6" data-reveal>
            <span class="material-symbols-outlined text-2xl text-[#d4a843] mb-3">
              {feature.icon}
            </span>
            <h3 class="text-base font-bold text-[#0c1526] mb-1">{feature.title}</h3>
            <p class="text-sm text-[#5f6b7a]">{feature.blurb}</p>
          </div>
        </div>
      </div>
    </section>
    """
  end
```

- [ ] **Step 9: Growth arc, stats band, launch steps**

```elixir
  defp growth_arc(assigns) do
    ~H"""
    <section id="how-it-works" class="py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-6xl mx-auto">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-center mb-2">
          From first sale to household name
        </h2>
        <p class="text-base text-[#8896ab] text-center mb-12">Wherever you are, Emakola fits.</p>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
          <div class="bg-[#13203a] rounded-2xl overflow-hidden" data-reveal>
            <img
              src="/images/landing/growth-start.jpg"
              alt="Young woman smiling as she starts her first online store"
              loading="lazy"
              width="600"
              height="400"
              class="w-full h-[180px] object-cover"
            />
            <div class="p-6">
              <p class="text-xs font-extrabold tracking-widest text-[#d4a843] mb-2">START</p>
              <h3 class="text-lg font-bold mb-2">From her phone in Makola Market</h3>
              <p class="text-sm text-[#8896ab]">
                Ama listed 12 products on a Sunday. First MoMo payment by Wednesday.
              </p>
            </div>
          </div>
          <div class="bg-[#13203a] rounded-2xl overflow-hidden" data-reveal>
            <img
              src="/images/landing/growth-grow.jpg"
              alt="Shop owner in glasses managing his stores"
              loading="lazy"
              width="600"
              height="400"
              class="w-full h-[180px] object-cover"
            />
            <div class="p-6">
              <p class="text-xs font-extrabold tracking-widest text-[#d4a843] mb-2">GROW</p>
              <h3 class="text-lg font-bold mb-2">Three stores, one dashboard</h3>
              <p class="text-sm text-[#8896ab]">
                Kwame runs electronics, accessories, and repairs from a single account.
              </p>
            </div>
          </div>
          <div class="bg-[#13203a] border border-[#d4a843]/30 rounded-2xl overflow-hidden" data-reveal>
            <img
              src="/images/landing/growth-scale.jpg"
              alt="Businesswoman in an orange blazer scaling her brand nationwide"
              loading="lazy"
              width="600"
              height="400"
              class="w-full h-[180px] object-cover"
            />
            <div class="p-6">
              <p class="text-xs font-extrabold tracking-widest text-[#d4a843] mb-2">SCALE</p>
              <h3 class="text-lg font-bold mb-2">Selling across all 16 regions</h3>
              <p class="text-sm text-[#8896ab]">
                Efua's Kitchen ships nationwide with delivery zones and order tracking.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp stats_band(assigns) do
    ~H"""
    <section class="bg-[#0a1120] border-y border-[#1a2744] py-12 px-4">
      <div class="max-w-4xl mx-auto grid grid-cols-1 sm:grid-cols-3 gap-8 text-center">
        <div>
          <p class="text-4xl font-headline font-extrabold text-[#d4a843]">500+</p>
          <p class="text-sm text-[#8896ab] mt-1">merchants on Emakola</p>
        </div>
        <div>
          <p class="text-4xl font-headline font-extrabold text-[#d4a843]">3</p>
          <p class="text-sm text-[#8896ab] mt-1">mobile money networks</p>
        </div>
        <div>
          <p class="text-4xl font-headline font-extrabold text-[#d4a843]">Seconds</p>
          <p class="text-sm text-[#8896ab] mt-1">from checkout to payout</p>
        </div>
      </div>
    </section>
    """
  end

  defp launch_steps(assigns) do
    ~H"""
    <section class="bg-[#f7f8fa] py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-5xl mx-auto text-center">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] mb-2">
          Launch before lunch
        </h2>
        <p class="text-base text-[#5f6b7a] mb-12">Most merchants go live in under an hour.</p>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-5 text-left">
          <div class="bg-white rounded-2xl p-6 shadow-sm" data-reveal>
            <p class="text-2xl font-headline font-black text-[#d4a843] mb-2">01</p>
            <h3 class="text-base font-bold text-[#0c1526]">Add your first product</h3>
          </div>
          <div class="bg-white rounded-2xl p-6 shadow-sm" data-reveal>
            <p class="text-2xl font-headline font-black text-[#d4a843] mb-2">02</p>
            <h3 class="text-base font-bold text-[#0c1526]">Share your store link</h3>
          </div>
          <div class="bg-white rounded-2xl p-6 shadow-sm" data-reveal>
            <p class="text-2xl font-headline font-black text-[#d4a843] mb-2">03</p>
            <h3 class="text-base font-bold text-[#0c1526]">Get paid with MoMo</h3>
          </div>
        </div>
      </div>
    </section>
    """
  end
```

- [ ] **Step 10: FAQ + final CTA components**

```elixir
  defp faq_section(assigns) do
    assigns = assign(assigns, :faqs, faqs())

    ~H"""
    <section id="faq" class="bg-white py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-5xl mx-auto">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] text-center mb-12">
          Questions, answered
        </h2>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 items-start">
          <details :for={{question, answer} <- @faqs} class="group bg-[#f7f8fa] rounded-xl p-5">
            <summary class="cursor-pointer text-base font-semibold text-[#0c1526] list-none flex items-center justify-between gap-3">
              {question}
              <span class="material-symbols-outlined text-[#8896ab] group-open:rotate-180 transition-transform">
                expand_more
              </span>
            </summary>
            <p class="text-sm text-[#5f6b7a] mt-3">{answer}</p>
          </details>
        </div>
      </div>
    </section>
    """
  end

  defp final_cta(assigns) do
    ~H"""
    <section
      class="relative bg-cover py-24 px-4 text-center"
      style="background-image: linear-gradient(180deg, rgba(12,21,38,0.78), rgba(12,21,38,0.9)), url('/images/landing/cta-market.jpg'); background-position: center;"
    >
      <h2 class="text-3xl lg:text-4xl font-headline font-bold mb-8">Ready when you are</h2>
      <div class="flex flex-col sm:flex-row flex-wrap justify-center items-center gap-4">
        <a
          href="/auth/register"
          class="inline-flex items-center px-8 py-3 text-base font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors"
        >
          Start selling — free
        </a>
        <a
          href="/stores"
          class="inline-flex items-center px-8 py-3 text-base font-semibold text-[#f1f5f9] border border-[#2a3a5c] rounded-lg hover:border-[#f1f5f9] transition-colors"
        >
          Browse stores
        </a>
      </div>
    </section>
    """
  end
```

- [ ] **Step 11: Run the landing tests until green**

Run: `mix test test/emakola_web/live/landing_live_test.exs`
Expected: PASS (all describes). Fix HTML-entity mismatches in assertions as found.

- [ ] **Step 12: Full gate + commit**

```bash
mix format && mix test && mix credo --strict
git add lib/emakola_web/live/landing_live.ex test/emakola_web/live/landing_live_test.exs
git commit -m "feat(web): merchant-first landing page — image-led story, features grid, FAQ, JSON-LD"
```

---

### Task 6: Remove orphaned landing images

The rewrite stops referencing the old landing photos. Delete only what nothing references.

**Files:**
- Delete (after verification): old files in `priv/static/images/landing/`

- [ ] **Step 1: Verify each old image is unreferenced**

```bash
cd /Users/kojo/Projects/emakola
for img in hero-merchant hero-shopper step-sell-1 step-sell-2 step-sell-3 \
           step-buy-1 step-buy-2 step-buy-3 feature-mobile-money feature-whatsapp \
           feature-dashboard feature-multi-store feature-inventory feature-shipping \
           product-kente product-shea product-ankara \
           testimonial-1 testimonial-2 testimonial-3 testimonial-4 testimonial-5 testimonial-6; do
  hits=$(grep -rl "$img" lib assets 2>/dev/null | wc -l | tr -d ' ')
  echo "$img: $hits references"
done
```

Expected: `0 references` for every name. **Skip deletion of any image with hits.**

- [ ] **Step 2: Delete unreferenced images (both plain and digest-suffixed copies)**

```bash
cd priv/static/images/landing
for img in <only-the-zero-reference-names-from-step-1>; do rm -f "$img"*.jpg; done
```

- [ ] **Step 3: Run the full suite to prove nothing broke, then commit**

Run: `mix test`
Expected: PASS.

```bash
git add -A priv/static/images/landing
git commit -m "chore(web): remove landing images orphaned by the redesign"
```

---

### Task 7: Final verification

- [ ] **Step 1: Full quality gate**

```bash
mix format --check-formatted && mix credo --strict && mix test
```
Expected: all clean, full suite green.

- [ ] **Step 2: Visual smoke check**

Run `mix phx.server`, open `http://localhost:4000/` and `http://localhost:4000/pricing`. Confirm: rotating hero word animates; store wall scrolls horizontally on a narrow window; FAQ accordions open; no horizontal overflow on mobile width (375px); pricing page renders 4 plans. Stop the server afterwards.

- [ ] **Step 3: Push and open PR**

```bash
git push -u origin feature/landing-redesign
```
PR title: `feat(web): merchant-first landing page redesign + /pricing page`. Target `develop` if it exists, else `main` (project convention says PRs target develop).
