# Landing Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generic SaaS boilerplate landing page with a dual-audience (merchants + shoppers) split-screen design using a Deep Navy & Gold palette, real stock images, and Emakola-specific content.

**Architecture:** Single LiveView rewrite (`landing_live.ex`) with all 8 sections inline. The LiveView renders with `layout: false` (disabling the app layout) but is still wrapped by the root layout (`root.html.heex`) which provides `<!DOCTYPE html>`, `<head>`, fonts, CSS, JS, and SEO meta tags. The render function outputs only the page content `<div>`, NOT a full HTML document. Landing-page colors are scoped via Tailwind arbitrary values — the app-wide design token system in `app.css` is untouched. Images are downloaded to `priv/static/images/landing/` and served locally. Existing `ScrollGlass` and `ScrollReveal` hooks are reused. `ThemeToggle` hook is removed from this page. A new inline footer replaces the shared `public_footer` component on this page only. CSP allows `'unsafe-inline'` for styles, so inline `<style>` blocks for `.scrolled` nav state are safe.

**Tech Stack:** Elixir/Phoenix LiveView, TailwindCSS (arbitrary values), Material Symbols Outlined icons, existing JS hooks

**Spec:** `docs/superpowers/specs/2026-03-23-landing-page-redesign-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Rewrite | `lib/emakola_web/live/landing_live.ex` | Complete landing page (mount + render with all 8 sections) |
| Create | `priv/static/images/landing/hero-merchant.jpg` | Hero merchant background image |
| Create | `priv/static/images/landing/hero-shopper.jpg` | Hero shopper background image |
| Create | `priv/static/images/landing/testimonial-1.jpg` | Testimonial portrait 1 |
| Create | `priv/static/images/landing/testimonial-2.jpg` | Testimonial portrait 2 |
| Create | `priv/static/images/landing/testimonial-3.jpg` | Testimonial portrait 3 |
| Rewrite | `test/emakola_web/live/landing_live_test.exs` | Updated tests for new content |
| No change | `assets/css/app.css` | Untouched — landing uses Tailwind arbitrary values |
| No change | `assets/js/hooks/scroll_glass.js` | Reused as-is |
| No change | `assets/js/hooks/scroll_reveal.js` | Reused as-is |
| No change | `lib/emakola_web/components/core_components.ex` | `public_footer` untouched — landing has its own footer |

---

## Task 1: Download and Prepare Images

**Files:**
- Create: `priv/static/images/landing/hero-merchant.jpg`
- Create: `priv/static/images/landing/hero-shopper.jpg`
- Create: `priv/static/images/landing/testimonial-1.jpg`
- Create: `priv/static/images/landing/testimonial-2.jpg`
- Create: `priv/static/images/landing/testimonial-3.jpg`

- [ ] **Step 1: Create the landing images directory**

```bash
mkdir -p priv/static/images/landing
```

- [ ] **Step 2: Download hero merchant image**

Download a stock photo of a West African merchant/market scene from Unsplash. Resize to max 800px wide, compress to JPEG quality 80.

```bash
curl -L "https://images.unsplash.com/photo-1590099543022-bacf576c359e?w=800&q=80" -o priv/static/images/landing/hero-merchant.jpg
```

If unavailable, search Unsplash for "African merchant market Ghana" and download a suitable alternative. The image should show commerce/trading in a West African context.

- [ ] **Step 3: Download hero shopper image**

Download a stock photo of someone using a mobile phone for shopping or receiving a delivery.

```bash
curl -L "https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=800&q=80" -o priv/static/images/landing/hero-shopper.jpg
```

If unavailable, search for "african woman mobile phone shopping" and download a suitable alternative.

- [ ] **Step 4: Download testimonial portrait images**

Download 3 portrait photos of West African professionals (friendly, approachable). Resize to 200x200px.

```bash
curl -L "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=200&h=200&fit=crop&q=80" -o priv/static/images/landing/testimonial-1.jpg
curl -L "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&q=80" -o priv/static/images/landing/testimonial-2.jpg
curl -L "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=200&h=200&fit=crop&q=80" -o priv/static/images/landing/testimonial-3.jpg
```

If any URL fails, search Unsplash for "african professional portrait" and use alternatives. The key requirement: friendly, professional-looking people that Ghanaian merchants could relate to.

- [ ] **Step 5: Verify all images downloaded**

```bash
ls -la priv/static/images/landing/
```

Expected: 5 JPEG files, each between 20KB-200KB. If any are missing or zero-byte, re-download with alternative URLs.

- [ ] **Step 6: Commit image assets**

```bash
git add priv/static/images/landing/
git commit -m "chore(web): add landing page stock images from Unsplash"
```

---

## Task 2: Rewrite Landing LiveView — Mount and Navigation (Section 1)

**Files:**
- Modify: `lib/emakola_web/live/landing_live.ex` (complete rewrite, starting from line 1)

- [ ] **Step 1: Write the failing test for new landing page content**

Replace the test file with tests for the new content. Create file `test/emakola_web/live/landing_live_test.exs`:

```elixir
defmodule EmakolaWeb.LandingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "landing page" do
    test "renders with Emakola branding and key content", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Emakola"
      assert html =~ "Launch Your Online Store in Ghana"
      assert html =~ "Shop Trusted Local Businesses"
    end

    test "renders navigation with correct links", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Features"
      assert html =~ "Pricing"
      assert html =~ "How It Works"
      assert html =~ "Get Started"
      assert html =~ "Login"
    end

    test "nav has ScrollGlass hook attached", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="main-nav")
      assert html =~ ~s(phx-hook="ScrollGlass")
    end

    test "page has ScrollReveal hook attached", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(phx-hook="ScrollReveal")
    end

    test "does NOT have ThemeToggle hook", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      refute html =~ ~s(phx-hook="ThemeToggle")
    end

    test "renders hero section with dual CTAs", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Start Selling"
      assert html =~ "Browse Stores"
      assert html =~ "FOR MERCHANTS"
      assert html =~ "FOR SHOPPERS"
    end

    test "renders trust bar with payment partners", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Trusted by"
      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "Paystack"
      assert html =~ "Hubtel"
    end

    test "renders how it works section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "How It Works"
      assert html =~ "Create Your Store"
      assert html =~ "Add Products"
      assert html =~ "Pay with MoMo"
    end

    test "renders features section with Emakola features", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Mobile Money Payments"
      assert html =~ "WhatsApp Notifications"
      assert html =~ "Merchant Dashboard"
      assert html =~ "Multi-Store Management"
      assert html =~ "Inventory Tracking"
      assert html =~ "Shipping"
    end

    test "renders pricing section with GHS amounts", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Starter"
      assert html =~ "Growth"
      assert html =~ "Pro"
      assert html =~ "Enterprise"
      assert html =~ "GHS 29"
      assert html =~ "GHS 79"
      assert html =~ "3.5%"
      assert html =~ "Most Popular"
    end

    test "renders testimonials section with merchant stories", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Ama Mensah"
      assert html =~ "Kwame Asante"
      assert html =~ "Efua Owusu"
      assert html =~ "Accra"
      assert html =~ "Kumasi"
      assert html =~ "Takoradi"
    end

    test "renders footer with Emakola links", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Privacy Policy"
      assert html =~ "Terms of Service"
      assert html =~ "Help Center"
    end

    test "sets correct SEO meta tags", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Emakola"
      assert html =~ "Online Stores for Ghana"
    end

    test "hero images are referenced", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "hero-merchant.jpg"
      assert html =~ "hero-shopper.jpg"
    end

    test "testimonial images are referenced", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "testimonial-1.jpg"
      assert html =~ "testimonial-2.jpg"
      assert html =~ "testimonial-3.jpg"
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/emakola_web/live/landing_live_test.exs
```

Expected: Multiple failures — the current landing page has boilerplate content that doesn't match these assertions.

- [ ] **Step 3: Rewrite landing_live.ex — mount and navigation**

Replace the entire file. Start with mount/3 (SEO assigns) and the first section of render/1 (navigation). The file renders with `layout: false` (disabling app layout) but the root layout (`root.html.heex`) still wraps the output with `<!DOCTYPE html>`, `<head>`, `<body>`, fonts, CSS, and JS. So render/1 outputs only the page content div — NOT a full HTML document.

```elixir
defmodule EmakolaWeb.LandingLive do
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Emakola — Online Stores for Ghana | Accept Mobile Money",
       meta_description:
         "Launch your online store in Ghana. Accept MTN MoMo, Telecel Cash, and card payments. WhatsApp order notifications. Join 500+ merchants on Emakola.",
       og_title: "Emakola — Sell Online in Ghana",
       og_description:
         "The easiest way to create an online store in West Africa. Mobile money payments, WhatsApp notifications, and more.",
       og_image: "/images/og-image.png",
       twitter_card: "summary_large_image",
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
    <div
      id="landing-scroll"
      phx-hook="ScrollReveal"
      class="min-h-screen bg-[#0c1526] text-[#f1f5f9] font-body antialiased"
    >
      <%!-- Inline styles for scroll-glass nav state and mobile menu animation --%>
      <style>
        #main-nav.scrolled {
          background-color: rgba(12, 21, 38, 0.95);
          border-bottom-color: rgba(26, 39, 68, 1);
          backdrop-filter: blur(12px);
          -webkit-backdrop-filter: blur(12px);
        }
        @keyframes slide-down {
          from { opacity: 0; transform: translateY(-10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .animate-slide-down { animation: slide-down 0.2s ease-out; }
      </style>

      <!-- ============================================ -->
      <!-- SECTION 1: NAVIGATION                        -->
      <!-- ============================================ -->
          <nav
            id="main-nav"
            phx-hook="ScrollGlass"
            class="fixed top-0 left-0 right-0 z-50 bg-[#0c1526]/80 backdrop-blur-md border-b border-transparent transition-all duration-300"
          >
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
              <div class="flex items-center justify-between h-16">
                <!-- Logo -->
                <a href="/" class="flex items-center gap-2">
                  <img src={~p"/images/logo.svg"} alt="Emakola" class="h-8 w-auto" />
                  <span class="text-xl font-headline font-bold text-[#f1f5f9]">Emakola</span>
                </a>
                <!-- Desktop Nav Links -->
                <div class="hidden md:flex items-center gap-8">
                  <a href="#features" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Features
                  </a>
                  <a href="#pricing" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Pricing
                  </a>
                  <a href="#how-it-works" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    How It Works
                  </a>
                </div>
                <!-- Desktop CTAs -->
                <div class="hidden md:flex items-center gap-4">
                  <a href="/auth/login" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Login
                  </a>
                  <a
                    href="/auth/register"
                    class="inline-flex items-center px-4 py-2 text-sm font-semibold text-white bg-[#2563eb] rounded-lg hover:bg-[#1d4ed8] transition-colors focus-visible:ring-2 focus-visible:ring-[#2563eb] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
                  >
                    Get Started
                  </a>
                </div>
                <!-- Mobile Hamburger -->
                <button
                  phx-click="toggle_mobile_menu"
                  class="md:hidden p-2 text-[#8896ab] hover:text-[#f1f5f9]"
                  aria-label="Toggle menu"
                >
                  <span class="material-symbols-outlined text-2xl">
                    <%= if @mobile_menu_open, do: "close", else: "menu" %>
                  </span>
                </button>
              </div>
            </div>
            <!-- Mobile Menu Overlay -->
            <div
              :if={@mobile_menu_open}
              class="md:hidden fixed inset-0 top-16 bg-[#0c1526] z-40 flex flex-col items-center justify-start pt-12 gap-6 animate-slide-down"
            >
              <a href="#features" phx-click="toggle_mobile_menu" class="text-lg text-[#8896ab] hover:text-[#f1f5f9]">
                Features
              </a>
              <a href="#pricing" phx-click="toggle_mobile_menu" class="text-lg text-[#8896ab] hover:text-[#f1f5f9]">
                Pricing
              </a>
              <a href="#how-it-works" phx-click="toggle_mobile_menu" class="text-lg text-[#8896ab] hover:text-[#f1f5f9]">
                How It Works
              </a>
              <hr class="w-24 border-[#1a2744]" />
              <a href="/auth/login" class="text-lg text-[#8896ab] hover:text-[#f1f5f9]">Login</a>
              <a
                href="/auth/register"
                class="inline-flex items-center px-6 py-3 text-base font-semibold text-white bg-[#2563eb] rounded-lg hover:bg-[#1d4ed8]"
              >
                Get Started
              </a>
            </div>
          </nav>

      <!-- SECTIONS 2-8 WILL BE ADDED IN SUBSEQUENT TASKS -->

    </div>
    """
  end
end
```

**Important notes for the implementer:**
- `layout: false` disables the **app layout** only. The **root layout** (`root.html.heex`) still wraps this output with `<!DOCTYPE html>`, `<head>`, `<body>`, fonts, CSS, JS, and SEO meta tags. So `render/1` outputs only the content div.
- The SEO assigns (`page_title`, `meta_description`, `og_title`, etc.) are read by the root layout's `EmakolaWeb.SEO.meta_tags` component and the `<.live_title>` component — they work automatically.
- The inline `<style>` block for `.scrolled` and `.animate-slide-down` is placed inside the content div. CSP allows `'unsafe-inline'` for styles.

- [ ] **Step 4: Run tests — expect partial passes**

```bash
mix test test/emakola_web/live/landing_live_test.exs
```

Expected: Navigation-related tests pass (nav links, ScrollGlass hook, no ThemeToggle). Content tests for sections 2-8 still fail — that's expected at this stage.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola_web/live/landing_live.ex test/emakola_web/live/landing_live_test.exs
git commit -m "feat(web): rewrite landing page - mount and navigation (section 1)"
```

---

## Task 3: Hero Section (Section 2)

**Files:**
- Modify: `lib/emakola_web/live/landing_live.ex` (add hero section after nav, before the closing `</div>`)

- [ ] **Step 1: Add the hero section**

Insert after the `</nav>` closing tag and before the comment `<!-- SECTIONS 2-8 WILL BE ADDED IN SUBSEQUENT TASKS -->`. Replace that comment with the hero section:

```html
          <!-- ============================================ -->
          <!-- SECTION 2: HERO (SPLIT SCREEN)               -->
          <!-- ============================================ -->
          <section class="min-h-screen flex flex-col lg:flex-row pt-16">
            <!-- Merchant Side (Dark) -->
            <div class="relative flex-1 flex items-center justify-center overflow-hidden">
              <img
                src={~p"/images/landing/hero-merchant.jpg"}
                alt="Ghanaian merchant at market"
                class="absolute inset-0 w-full h-full object-cover"
              />
              <div class="absolute inset-0 bg-gradient-to-r from-[#0c1526]/90 to-[#0c1526]/70">
              </div>
              <div class="relative z-10 max-w-xl px-6 py-16 lg:py-0 lg:px-12">
                <span class="inline-block text-xs font-semibold tracking-[0.15em] uppercase text-[#d4a843] mb-4">
                  FOR MERCHANTS
                </span>
                <h1 class="text-4xl lg:text-5xl font-headline font-bold text-[#f1f5f9] leading-tight mb-4">
                  Launch Your Online Store in Ghana
                </h1>
                <p class="text-base text-[#8896ab] mb-8 max-w-md">
                  Accept MTN MoMo, Telecel Cash, and card payments. Notify customers on WhatsApp.
                  Manage everything from one dashboard.
                </p>
                <div class="flex flex-wrap gap-3 mb-8">
                  <a
                    href="/auth/register"
                    class="inline-flex items-center px-6 py-3 text-sm font-semibold text-white bg-[#2563eb] rounded-lg hover:bg-[#1d4ed8] transition-colors focus-visible:ring-2 focus-visible:ring-[#2563eb] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
                  >
                    Start Selling
                  </a>
                  <a
                    href="#features"
                    class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#8896ab] border border-[#2a3a5c] rounded-lg hover:text-[#f1f5f9] hover:border-[#f1f5f9] transition-colors"
                  >
                    Watch Demo
                  </a>
                </div>
                <!-- Payment Provider Badges -->
                <div class="flex flex-wrap gap-3">
                  <div class="flex items-center gap-2 px-3 py-1.5 rounded-md border border-[#1a2744] bg-[#0c1526]/50 text-xs text-[#8896ab]">
                    <span class="material-symbols-outlined text-base">account_balance_wallet</span>
                    MTN MoMo
                  </div>
                  <div class="flex items-center gap-2 px-3 py-1.5 rounded-md border border-[#1a2744] bg-[#0c1526]/50 text-xs text-[#8896ab]">
                    <span class="material-symbols-outlined text-base">payments</span>
                    Telecel Cash
                  </div>
                  <div class="flex items-center gap-2 px-3 py-1.5 rounded-md border border-[#1a2744] bg-[#0c1526]/50 text-xs text-[#8896ab]">
                    <span class="material-symbols-outlined text-base">credit_card</span>
                    Paystack
                  </div>
                  <div class="flex items-center gap-2 px-3 py-1.5 rounded-md border border-[#1a2744] bg-[#0c1526]/50 text-xs text-[#8896ab]">
                    <span class="material-symbols-outlined text-base">storefront</span>
                    Hubtel
                  </div>
                </div>
              </div>
            </div>
            <!-- Shopper Side (Light) -->
            <div class="relative flex-1 flex items-center justify-center overflow-hidden bg-[#f7f8fa]">
              <img
                src={~p"/images/landing/hero-shopper.jpg"}
                alt="Person shopping on mobile phone"
                class="absolute inset-0 w-full h-full object-cover"
              />
              <div class="absolute inset-0 bg-gradient-to-l from-[#f7f8fa]/90 to-[#f7f8fa]/70">
              </div>
              <div class="relative z-10 max-w-xl px-6 py-16 lg:py-0 lg:px-12">
                <span class="inline-block text-xs font-semibold tracking-[0.15em] uppercase text-[#2563eb] mb-4">
                  FOR SHOPPERS
                </span>
                <h1 class="text-4xl lg:text-5xl font-headline font-bold text-[#0c1526] leading-tight mb-4">
                  Shop Trusted Local Businesses
                </h1>
                <p class="text-base text-[#5f6b7a] mb-8 max-w-md">
                  Pay with mobile money. Get order updates on WhatsApp. Support local merchants.
                </p>
                <a
                  href="/auth/register?role=shopper"
                  class="inline-flex items-center px-6 py-3 text-sm font-semibold text-white bg-[#0c1526] rounded-lg hover:bg-[#1a2744] transition-colors focus-visible:ring-2 focus-visible:ring-[#0c1526] focus-visible:ring-offset-2"
                >
                  Browse Stores
                </a>
                <!-- Mini Product Cards -->
                <div class="flex gap-3 mt-8">
                  <div class="bg-white rounded-lg p-3 shadow-sm flex-1 max-w-[140px]">
                    <div class="bg-[#e2e8f0] rounded-md h-20 mb-2"></div>
                    <p class="text-xs font-semibold text-[#0c1526]">Kente Cloth</p>
                    <p class="text-xs text-[#5f6b7a]">GHS 150</p>
                  </div>
                  <div class="bg-white rounded-lg p-3 shadow-sm flex-1 max-w-[140px]">
                    <div class="bg-[#e2e8f0] rounded-md h-20 mb-2"></div>
                    <p class="text-xs font-semibold text-[#0c1526]">Shea Butter</p>
                    <p class="text-xs text-[#5f6b7a]">GHS 45</p>
                  </div>
                  <div class="bg-white rounded-lg p-3 shadow-sm flex-1 max-w-[140px] hidden sm:block">
                    <div class="bg-[#e2e8f0] rounded-md h-20 mb-2"></div>
                    <p class="text-xs font-semibold text-[#0c1526]">Ankara Dress</p>
                    <p class="text-xs text-[#5f6b7a]">GHS 85</p>
                  </div>
                </div>
              </div>
            </div>
          </section>
```

- [ ] **Step 2: Run hero-related tests**

```bash
mix test test/emakola_web/live/landing_live_test.exs
```

Expected: Hero tests pass (dual CTAs, FOR MERCHANTS/SHOPPERS, hero images referenced). Some other tests still fail.

- [ ] **Step 3: Commit**

```bash
git add lib/emakola_web/live/landing_live.ex
git commit -m "feat(web): add hero split-screen section with stock images"
```

---

## Task 4: Trust Bar and How It Works (Sections 3-4)

**Files:**
- Modify: `lib/emakola_web/live/landing_live.ex` (add after hero section closing `</section>`)

- [ ] **Step 1: Add trust bar and how it works sections**

Insert after the hero `</section>`:

```html
          <!-- ============================================ -->
          <!-- SECTION 3: TRUST BAR                         -->
          <!-- ============================================ -->
          <section class="bg-[#f0f1f4] py-6 px-4">
            <div class="max-w-5xl mx-auto flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-8">
              <span class="text-sm text-[#5f6b7a] font-medium whitespace-nowrap">
                Trusted by 500+ merchants across Ghana
              </span>
              <div class="flex flex-wrap items-center justify-center gap-4 sm:gap-6">
                <span class="text-sm font-semibold text-[#3f3f46]">MTN MoMo</span>
                <span class="text-sm font-semibold text-[#3f3f46]">Telecel Cash</span>
                <span class="text-sm font-semibold text-[#3f3f46]">AirtelTigo</span>
                <span class="text-sm font-semibold text-[#3f3f46]">Paystack</span>
                <span class="text-sm font-semibold text-[#3f3f46]">Hubtel</span>
              </div>
            </div>
          </section>

          <!-- ============================================ -->
          <!-- SECTION 4: HOW IT WORKS                      -->
          <!-- ============================================ -->
          <section id="how-it-works" class="bg-white py-20 px-4" data-reveal>
            <div class="max-w-5xl mx-auto">
              <h2 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] text-center mb-16">
                How It Works
              </h2>

              <!-- For Merchants -->
              <div class="mb-16" data-reveal>
                <h3 class="text-sm font-semibold tracking-[0.15em] uppercase text-[#d4a843] text-center mb-10">
                  FOR MERCHANTS
                </h3>
                <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
                  <div class="text-center">
                    <div class="w-12 h-12 rounded-full bg-[#0c1526] text-white flex items-center justify-center mx-auto mb-4 text-lg font-bold">
                      1
                    </div>
                    <h4 class="text-lg font-semibold text-[#0c1526] mb-2">Create Your Store</h4>
                    <p class="text-sm text-[#5f6b7a]">
                      Sign up and customize your storefront in minutes
                    </p>
                  </div>
                  <div class="text-center">
                    <div class="w-12 h-12 rounded-full bg-[#0c1526] text-white flex items-center justify-center mx-auto mb-4 text-lg font-bold">
                      2
                    </div>
                    <h4 class="text-lg font-semibold text-[#0c1526] mb-2">Add Products</h4>
                    <p class="text-sm text-[#5f6b7a]">
                      Upload products, set prices in GHS, manage inventory
                    </p>
                  </div>
                  <div class="text-center">
                    <div class="w-12 h-12 rounded-full bg-[#0c1526] text-white flex items-center justify-center mx-auto mb-4 text-lg font-bold">
                      3
                    </div>
                    <h4 class="text-lg font-semibold text-[#0c1526] mb-2">Start Selling</h4>
                    <p class="text-sm text-[#5f6b7a]">
                      Share your store link. Accept mobile money. Grow your business.
                    </p>
                  </div>
                </div>
              </div>

              <hr class="border-[#e8eaed] mb-16" />

              <!-- For Shoppers -->
              <div data-reveal>
                <h3 class="text-sm font-semibold tracking-[0.15em] uppercase text-[#2563eb] text-center mb-10">
                  FOR SHOPPERS
                </h3>
                <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
                  <div class="text-center">
                    <div class="w-12 h-12 rounded-full bg-[#2563eb] text-white flex items-center justify-center mx-auto mb-4 text-lg font-bold">
                      1
                    </div>
                    <h4 class="text-lg font-semibold text-[#0c1526] mb-2">Browse Stores</h4>
                    <p class="text-sm text-[#5f6b7a]">
                      Discover local businesses and products
                    </p>
                  </div>
                  <div class="text-center">
                    <div class="w-12 h-12 rounded-full bg-[#2563eb] text-white flex items-center justify-center mx-auto mb-4 text-lg font-bold">
                      2
                    </div>
                    <h4 class="text-lg font-semibold text-[#0c1526] mb-2">Pay with MoMo</h4>
                    <p class="text-sm text-[#5f6b7a]">
                      Checkout securely with MTN MoMo, Telecel Cash, or card
                    </p>
                  </div>
                  <div class="text-center">
                    <div class="w-12 h-12 rounded-full bg-[#2563eb] text-white flex items-center justify-center mx-auto mb-4 text-lg font-bold">
                      3
                    </div>
                    <h4 class="text-lg font-semibold text-[#0c1526] mb-2">Track Your Order</h4>
                    <p class="text-sm text-[#5f6b7a]">
                      Get real-time updates on WhatsApp
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </section>
```

- [ ] **Step 2: Run tests**

```bash
mix test test/emakola_web/live/landing_live_test.exs
```

Expected: Trust bar and how-it-works tests now pass.

- [ ] **Step 3: Commit**

```bash
git add lib/emakola_web/live/landing_live.ex
git commit -m "feat(web): add trust bar and how-it-works sections"
```

---

## Task 5: Features Grid (Section 5)

**Files:**
- Modify: `lib/emakola_web/live/landing_live.ex` (add after how-it-works section)

- [ ] **Step 1: Add features bento grid**

Insert after how-it-works `</section>`:

```html
          <!-- ============================================ -->
          <!-- SECTION 5: FEATURES GRID (BENTO)             -->
          <!-- ============================================ -->
          <section id="features" class="bg-[#f7f8fa] py-20 px-4" data-reveal>
            <div class="max-w-5xl mx-auto">
              <h2 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] text-center mb-4">
                Everything You Need to Sell Online
              </h2>
              <p class="text-base text-[#5f6b7a] text-center mb-12 max-w-2xl mx-auto">
                Built for West African merchants. Mobile money, WhatsApp, local delivery — all in one platform.
              </p>

              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <!-- Row 1: Mobile Money (2-col) + WhatsApp (1-col) -->
                <div
                  class="md:col-span-2 bg-[#f7f8fa] rounded-xl border border-[#1a2744] p-6 hover:-translate-y-1 transition-transform"
                  data-reveal
                >
                  <span class="material-symbols-outlined text-3xl text-[#2563eb] mb-4 block">
                    account_balance_wallet
                  </span>
                  <h3 class="text-lg font-semibold text-[#0c1526] mb-2">Mobile Money Payments</h3>
                  <p class="text-sm text-[#5f6b7a]">
                    Accept MTN MoMo, Telecel Cash, and AirtelTigo Money. Automatic payment confirmation and reconciliation.
                  </p>
                </div>
                <div
                  class="bg-[#f7f8fa] rounded-xl border border-[#1a2744] p-6 hover:-translate-y-1 transition-transform"
                  data-reveal
                >
                  <span class="material-symbols-outlined text-3xl text-[#2563eb] mb-4 block">
                    chat
                  </span>
                  <h3 class="text-lg font-semibold text-[#0c1526] mb-2">WhatsApp Notifications</h3>
                  <p class="text-sm text-[#5f6b7a]">
                    Order confirmations, shipping updates, and delivery alerts sent directly to your customers on WhatsApp.
                  </p>
                </div>

                <!-- Row 2: Dashboard (1-col) + Multi-Store (2-col) -->
                <div
                  class="bg-[#f7f8fa] rounded-xl border border-[#1a2744] p-6 hover:-translate-y-1 transition-transform"
                  data-reveal
                >
                  <span class="material-symbols-outlined text-3xl text-[#2563eb] mb-4 block">
                    dashboard
                  </span>
                  <h3 class="text-lg font-semibold text-[#0c1526] mb-2">Merchant Dashboard</h3>
                  <p class="text-sm text-[#5f6b7a]">
                    Track sales, orders, inventory, and customer analytics from a single dashboard.
                  </p>
                </div>
                <div
                  class="md:col-span-2 bg-[#f7f8fa] rounded-xl border border-[#1a2744] p-6 hover:-translate-y-1 transition-transform"
                  data-reveal
                >
                  <span class="material-symbols-outlined text-3xl text-[#2563eb] mb-4 block">
                    store
                  </span>
                  <h3 class="text-lg font-semibold text-[#0c1526] mb-2">Multi-Store Management</h3>
                  <p class="text-sm text-[#5f6b7a]">
                    Run multiple stores from one account. Each store gets its own storefront, products, and settings.
                  </p>
                </div>

                <!-- Row 3: Inventory (1-col) + Shipping (1-col) -->
                <div
                  class="bg-[#f7f8fa] rounded-xl border border-[#1a2744] p-6 hover:-translate-y-1 transition-transform"
                  data-reveal
                >
                  <span class="material-symbols-outlined text-3xl text-[#2563eb] mb-4 block">
                    inventory_2
                  </span>
                  <h3 class="text-lg font-semibold text-[#0c1526] mb-2">Inventory Tracking</h3>
                  <p class="text-sm text-[#5f6b7a]">
                    Real-time stock levels. Low-stock alerts. Never oversell again.
                  </p>
                </div>
                <div
                  class="bg-[#f7f8fa] rounded-xl border border-[#1a2744] p-6 hover:-translate-y-1 transition-transform"
                  data-reveal
                >
                  <span class="material-symbols-outlined text-3xl text-[#2563eb] mb-4 block">
                    local_shipping
                  </span>
                  <h3 class="text-lg font-semibold text-[#0c1526] mb-2">Shipping & Delivery</h3>
                  <p class="text-sm text-[#5f6b7a]">
                    Set delivery zones, shipping rates, and fulfillment methods for local and nationwide delivery.
                  </p>
                </div>
              </div>
            </div>
          </section>
```

- [ ] **Step 2: Run tests**

```bash
mix test test/emakola_web/live/landing_live_test.exs
```

Expected: Features tests now pass.

- [ ] **Step 3: Commit**

```bash
git add lib/emakola_web/live/landing_live.ex
git commit -m "feat(web): add features bento grid section"
```

---

## Task 6: Pricing Section (Section 6)

**Files:**
- Modify: `lib/emakola_web/live/landing_live.ex` (add after features section)

- [ ] **Step 1: Add pricing section**

Insert after features `</section>`:

```html
          <!-- ============================================ -->
          <!-- SECTION 6: PRICING                           -->
          <!-- ============================================ -->
          <section id="pricing" class="bg-white py-20 px-4" data-reveal>
            <div class="max-w-5xl mx-auto">
              <h2 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] text-center mb-4">
                Simple, Transparent Pricing
              </h2>
              <p class="text-base text-[#5f6b7a] text-center mb-12 max-w-2xl mx-auto">
                All plans include SSL, mobile money payments, and basic analytics.
              </p>

              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <!-- Starter -->
                <div class="bg-[#f7f8fa] rounded-xl border border-[#e8eaed] p-6 flex flex-col" data-reveal>
                  <h3 class="text-lg font-semibold text-[#0c1526] mb-1">Starter</h3>
                  <div class="flex items-baseline gap-1 mb-1">
                    <span class="text-3xl font-bold text-[#0c1526]">Free</span>
                  </div>
                  <p class="text-sm text-[#d4a843] font-medium mb-6">3.5% per sale</p>
                  <ul class="space-y-2 mb-8 flex-1">
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      1 store
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      25 products
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      Basic dashboard
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      Email support
                    </li>
                  </ul>
                  <a
                    href="/auth/register"
                    class="block text-center px-4 py-2.5 text-sm font-semibold text-[#0c1526] border border-[#e8eaed] rounded-lg hover:border-[#0c1526] transition-colors"
                  >
                    Get Started
                  </a>
                </div>

                <!-- Growth -->
                <div class="bg-[#f7f8fa] rounded-xl border border-[#e8eaed] p-6 flex flex-col" data-reveal>
                  <h3 class="text-lg font-semibold text-[#0c1526] mb-1">Growth</h3>
                  <div class="flex items-baseline gap-1 mb-1">
                    <span class="text-3xl font-bold text-[#0c1526]">GHS 29</span>
                    <span class="text-sm text-[#5f6b7a]">/mo</span>
                  </div>
                  <p class="text-sm text-[#d4a843] font-medium mb-6">2.0% per sale</p>
                  <ul class="space-y-2 mb-8 flex-1">
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      1 store
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      250 products
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      WhatsApp notifications
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      Priority support
                    </li>
                  </ul>
                  <a
                    href="/auth/register"
                    class="block text-center px-4 py-2.5 text-sm font-semibold text-[#0c1526] border border-[#e8eaed] rounded-lg hover:border-[#0c1526] transition-colors"
                  >
                    Get Started
                  </a>
                </div>

                <!-- Pro (Highlighted) -->
                <div
                  class="bg-[#0c1526] rounded-xl border-2 border-[#d4a843] p-6 flex flex-col relative"
                  data-reveal
                >
                  <span class="absolute -top-3 left-1/2 -translate-x-1/2 bg-[#d4a843] text-[#0c1526] text-xs font-bold px-3 py-0.5 rounded-full">
                    Most Popular
                  </span>
                  <h3 class="text-lg font-semibold text-[#f1f5f9] mb-1">Pro</h3>
                  <div class="flex items-baseline gap-1 mb-1">
                    <span class="text-3xl font-bold text-[#f1f5f9]">GHS 79</span>
                    <span class="text-sm text-[#8896ab]">/mo</span>
                  </div>
                  <p class="text-sm text-[#d4a843] font-medium mb-6">1.2% per sale</p>
                  <ul class="space-y-2 mb-8 flex-1">
                    <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                      <span class="material-symbols-outlined text-base text-[#d4a843] mt-0.5">check</span>
                      3 stores
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                      <span class="material-symbols-outlined text-base text-[#d4a843] mt-0.5">check</span>
                      Unlimited products
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                      <span class="material-symbols-outlined text-base text-[#d4a843] mt-0.5">check</span>
                      Custom domain
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                      <span class="material-symbols-outlined text-base text-[#d4a843] mt-0.5">check</span>
                      Analytics
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                      <span class="material-symbols-outlined text-base text-[#d4a843] mt-0.5">check</span>
                      Phone support
                    </li>
                  </ul>
                  <a
                    href="/auth/register"
                    class="block text-center px-4 py-2.5 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors"
                  >
                    Get Started
                  </a>
                </div>

                <!-- Enterprise -->
                <div class="bg-[#f7f8fa] rounded-xl border border-[#e8eaed] p-6 flex flex-col" data-reveal>
                  <h3 class="text-lg font-semibold text-[#0c1526] mb-1">Enterprise</h3>
                  <div class="flex items-baseline gap-1 mb-1">
                    <span class="text-3xl font-bold text-[#0c1526]">Custom</span>
                  </div>
                  <p class="text-sm text-[#d4a843] font-medium mb-6">Custom rate</p>
                  <ul class="space-y-2 mb-8 flex-1">
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      Unlimited stores
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      Dedicated account manager
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      SLA
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                      API access
                    </li>
                  </ul>
                  <a
                    href="mailto:sales@emakola.com"
                    class="block text-center px-4 py-2.5 text-sm font-semibold text-[#0c1526] border border-[#e8eaed] rounded-lg hover:border-[#0c1526] transition-colors"
                  >
                    Contact Sales
                  </a>
                </div>
              </div>
            </div>
          </section>
```

- [ ] **Step 2: Run tests**

```bash
mix test test/emakola_web/live/landing_live_test.exs
```

Expected: Pricing tests now pass.

- [ ] **Step 3: Commit**

```bash
git add lib/emakola_web/live/landing_live.ex
git commit -m "feat(web): add pricing section with GHS hybrid model"
```

---

## Task 7: Testimonials, Final CTA, and Footer (Sections 7-8)

**Files:**
- Modify: `lib/emakola_web/live/landing_live.ex` (add after pricing section, before closing `</div></body></html>`)

- [ ] **Step 1: Add testimonials, CTA, and footer sections**

Insert after pricing `</section>`:

```html
          <!-- ============================================ -->
          <!-- SECTION 7: TESTIMONIALS                      -->
          <!-- ============================================ -->
          <section class="bg-[#f7f8fa] py-20 px-4" data-reveal>
            <div class="max-w-5xl mx-auto">
              <h2 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] text-center mb-12">
                Trusted by Merchants Across Ghana
              </h2>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <!-- Testimonial 1 -->
                <div class="bg-white rounded-xl border border-[#e8eaed] p-6" data-reveal>
                  <div class="flex gap-0.5 mb-4">
                    <svg :for={_i <- 1..5} class="w-4 h-4 text-[#d4a843] fill-current" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  </div>
                  <p class="text-sm text-[#5f6b7a] mb-6 leading-relaxed">
                    "Emakola made it so easy to start selling online. My customers love paying with MoMo and I get instant notifications on every order. My sales have doubled since I moved online."
                  </p>
                  <div class="flex items-center gap-3">
                    <img
                      src={~p"/images/landing/testimonial-1.jpg"}
                      alt="Ama Mensah"
                      class="w-10 h-10 rounded-full object-cover"
                    />
                    <div>
                      <p class="text-sm font-semibold text-[#0c1526]">Ama Mensah</p>
                      <p class="text-xs text-[#5f6b7a]">Ama's Fashion, Accra</p>
                    </div>
                  </div>
                </div>

                <!-- Testimonial 2 -->
                <div class="bg-white rounded-xl border border-[#e8eaed] p-6" data-reveal>
                  <div class="flex gap-0.5 mb-4">
                    <svg :for={_i <- 1..5} class="w-4 h-4 text-[#d4a843] fill-current" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  </div>
                  <p class="text-sm text-[#5f6b7a] mb-6 leading-relaxed">
                    "I run three stores on Emakola — electronics, accessories, and phone repairs. Managing all of them from one dashboard saves me hours every week. The WhatsApp notifications keep my customers happy."
                  </p>
                  <div class="flex items-center gap-3">
                    <img
                      src={~p"/images/landing/testimonial-2.jpg"}
                      alt="Kwame Asante"
                      class="w-10 h-10 rounded-full object-cover"
                    />
                    <div>
                      <p class="text-sm font-semibold text-[#0c1526]">Kwame Asante</p>
                      <p class="text-xs text-[#5f6b7a]">TechHub GH, Kumasi</p>
                    </div>
                  </div>
                </div>

                <!-- Testimonial 3 -->
                <div class="bg-white rounded-xl border border-[#e8eaed] p-6" data-reveal>
                  <div class="flex gap-0.5 mb-4">
                    <svg :for={_i <- 1..5} class="w-4 h-4 text-[#d4a843] fill-current" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  </div>
                  <p class="text-sm text-[#5f6b7a] mb-6 leading-relaxed">
                    "As a food vendor, I needed something simple. Emakola lets me take orders on WhatsApp and collect payment through mobile money. My customers in Takoradi can now order from home."
                  </p>
                  <div class="flex items-center gap-3">
                    <img
                      src={~p"/images/landing/testimonial-3.jpg"}
                      alt="Efua Owusu"
                      class="w-10 h-10 rounded-full object-cover"
                    />
                    <div>
                      <p class="text-sm font-semibold text-[#0c1526]">Efua Owusu</p>
                      <p class="text-xs text-[#5f6b7a]">Efua's Kitchen, Takoradi</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <!-- ============================================ -->
          <!-- SECTION 8: FINAL CTA + FOOTER                -->
          <!-- ============================================ -->
          <section class="bg-gradient-to-b from-[#0c1526] to-[#1a2744] py-20 px-4" data-reveal>
            <div class="max-w-3xl mx-auto text-center">
              <h2 class="text-3xl lg:text-4xl font-headline font-bold text-[#f1f5f9] mb-4">
                Ready to Grow Your Business?
              </h2>
              <p class="text-base text-[#8896ab] mb-8">
                Join 500+ merchants selling online across Ghana
              </p>
              <div class="flex flex-wrap justify-center gap-4">
                <a
                  href="/auth/register"
                  class="inline-flex items-center px-8 py-3 text-base font-semibold text-white bg-[#2563eb] rounded-lg hover:bg-[#1d4ed8] transition-colors focus-visible:ring-2 focus-visible:ring-[#2563eb] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
                >
                  Start Selling
                </a>
                <a
                  href="/auth/register?role=shopper"
                  class="inline-flex items-center px-8 py-3 text-base font-semibold text-[#8896ab] border border-[#2a3a5c] rounded-lg hover:text-[#f1f5f9] hover:border-[#f1f5f9] transition-colors"
                >
                  Browse Stores
                </a>
              </div>
            </div>
          </section>

          <!-- Footer -->
          <footer class="bg-[#0c1526] border-t border-[#1a2744] py-12 px-4">
            <div class="max-w-5xl mx-auto">
              <div class="grid grid-cols-2 md:grid-cols-4 gap-8 mb-10">
                <!-- Product -->
                <div>
                  <h4 class="text-sm font-semibold text-[#f1f5f9] mb-4">Product</h4>
                  <ul class="space-y-2">
                    <li><a href="#features" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Features</a></li>
                    <li><a href="#pricing" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Pricing</a></li>
                    <li><a href="#features" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Demo</a></li>
                    <li><a href="/docs" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">API</a></li>
                  </ul>
                </div>
                <!-- Resources -->
                <div>
                  <h4 class="text-sm font-semibold text-[#f1f5f9] mb-4">Resources</h4>
                  <ul class="space-y-2">
                    <li><a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Help Center</a></li>
                    <li><a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Blog</a></li>
                    <li><a href="/docs" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Developer Docs</a></li>
                    <li><a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Status</a></li>
                  </ul>
                </div>
                <!-- Company -->
                <div>
                  <h4 class="text-sm font-semibold text-[#f1f5f9] mb-4">Company</h4>
                  <ul class="space-y-2">
                    <li><a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">About</a></li>
                    <li><a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Careers</a></li>
                    <li><a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Press</a></li>
                    <li><a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Contact</a></li>
                  </ul>
                </div>
                <!-- Legal -->
                <div>
                  <h4 class="text-sm font-semibold text-[#f1f5f9] mb-4">Legal</h4>
                  <ul class="space-y-2">
                    <li><a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Privacy Policy</a></li>
                    <li><a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Terms of Service</a></li>
                    <li><a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">Cookie Policy</a></li>
                  </ul>
                </div>
              </div>
              <!-- Bottom Bar -->
              <div class="border-t border-[#1a2744] pt-6 flex flex-col sm:flex-row items-center justify-between gap-4">
                <p class="text-sm text-[#8896ab]">
                  &copy; <%= DateTime.utc_now().year %> Emakola. All rights reserved.
                </p>
                <div class="flex items-center gap-4">
                  <!-- Twitter/X -->
                  <a href="#" class="text-[#8896ab] hover:text-[#f1f5f9] transition-colors" aria-label="Twitter">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
                  </a>
                  <!-- LinkedIn -->
                  <a href="#" class="text-[#8896ab] hover:text-[#f1f5f9] transition-colors" aria-label="LinkedIn">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>
                  </a>
                  <!-- GitHub -->
                  <a href="#" class="text-[#8896ab] hover:text-[#f1f5f9] transition-colors" aria-label="GitHub">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>
                  </a>
                </div>
              </div>
            </div>
          </footer>
```

- [ ] **Step 2: Run all tests**

```bash
mix test test/emakola_web/live/landing_live_test.exs
```

Expected: ALL tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/emakola_web/live/landing_live.ex
git commit -m "feat(web): add testimonials, CTA, and footer sections"
```

---

## Task 8: Final Verification and Cleanup

**Files:**
- Review: `lib/emakola_web/live/landing_live.ex`
- Review: `test/emakola_web/live/landing_live_test.exs`

- [ ] **Step 1: Run the full test suite to ensure nothing else is broken**

```bash
mix test
```

Expected: All tests pass. No regressions in other test files.

- [ ] **Step 2: Check formatting**

```bash
mix format --check-formatted
```

If formatting issues, run `mix format` and commit.

- [ ] **Step 3: Run Credo**

```bash
mix credo --strict
```

Fix any issues reported.

- [ ] **Step 4: Visual verification**

Start the dev server and open `http://localhost:4000` in a browser:

```bash
mix phx.server
```

Verify:
- Nav is sticky with glass effect on scroll
- Hero split screen renders correctly (dark left, light right)
- Hero images display with gradient overlays
- Trust bar shows payment partners
- How It Works has merchant and shopper sections
- Features bento grid has correct 2-col/1-col layout
- Pricing shows 4 tiers with Pro highlighted
- Testimonials show with portrait images
- Footer renders correctly
- Mobile responsive: hamburger menu works, sections stack

- [ ] **Step 5: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix(web): landing page cleanup and formatting"
```

- [ ] **Step 6: Add .superpowers to .gitignore if not already there**

```bash
echo ".superpowers/" >> .gitignore
git add .gitignore
git commit -m "chore: add .superpowers to gitignore"
```
