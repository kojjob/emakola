# Company & Footer Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build 8 responsive, production-grade company/legal pages (About, Careers, Press, Contact, Legal, Privacy, Terms, Cookie) for the apex marketing site and wire up the currently-dead footer links.

**Architecture:** 8 LiveViews under `EmakolaWeb.Company.*` mirroring `EmakolaWeb.PricingLive` (`layout: false`, shared `landing_nav`/`landing_footer`, SEO assigns, `toggle_mobile_menu`). Shared `EmakolaWeb.CompanyComponents` provides hero/card/cta building blocks and a `legal_layout` (TOC + prose + disclaimer). Contact posts to a Swoosh `ContactMailer` with a honeypot. Spec: `docs/superpowers/specs/2026-06-15-company-footer-pages-design.md`.

**Tech Stack:** Elixir/Phoenix 1.8 LiveView, TailwindCSS, Swoosh (Test adapter in tests), ExUnit + Phoenix.LiveViewTest.

**Branch:** `feature/company-pages` (already created off `main`).

**Conventions every page LiveView follows (the "page skeleton"):**

```elixir
defmodule EmakolaWeb.Company.<Name>Live do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "<Title> — Emakola",
       meta_description: "<150-char description>",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/<path>"),
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
        <!-- page sections here -->
      </main>
      <.landing_footer />
    </div>
    """
  end
end
```

**Palette (from existing pages):** dark `#0c1526`, muted `#5f6b7a` / `#8896ab`, gold accent `#d4a843`, borders `#1a2744`, fonts `font-headline` (titles) / `font-body` (prose).

**Run all tests with:** `mix test <path>` ; full suite `mix test`.

---

### Task 1: Config keys for contact/careers/press channels

**Files:**
- Modify: `config/config.exs` (after the `Emakola.Mailer` block near line 32)
- Modify: `config/runtime.exs` (env overrides, inside the prod block)

- [ ] **Step 1: Add defaults to `config/config.exs`**

Add after the existing `config :emakola, Emakola.Mailer, adapter: Swoosh.Adapters.Local` line:

```elixir
# Company/contact page channels (env-overridable in runtime.exs)
config :emakola,
  contact_email: "support@emakola.com",
  careers_email: "careers@emakola.com",
  press_email: "press@emakola.com",
  support_whatsapp: "233200000000",
  support_phone: "+233 20 000 0000"
```

- [ ] **Step 2: Add env overrides to `config/runtime.exs`**

Inside `if config_env() == :prod do ... end`, add:

```elixir
config :emakola,
  contact_email: System.get_env("CONTACT_EMAIL", "support@emakola.com"),
  careers_email: System.get_env("CAREERS_EMAIL", "careers@emakola.com"),
  press_email: System.get_env("PRESS_EMAIL", "press@emakola.com"),
  support_whatsapp: System.get_env("SUPPORT_WHATSAPP", "233200000000"),
  support_phone: System.get_env("SUPPORT_PHONE", "+233 20 000 0000")
```

- [ ] **Step 3: Verify it compiles**

Run: `mix compile`
Expected: compiles, no errors.

- [ ] **Step 4: Commit**

```bash
git add config/config.exs config/runtime.exs
git commit -m "feat(web): config keys for company contact channels"
```

---

### Task 2: Shared `CompanyComponents`

**Files:**
- Create: `lib/emakola_web/components/company_components.ex`
- Test: `test/emakola_web/components/company_components_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.CompanyComponentsTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import EmakolaWeb.CompanyComponents

  test "page_hero renders eyebrow, title, subtitle" do
    html =
      render_component(&page_hero/1, %{
        eyebrow: "Our story",
        title: "Building commerce",
        subtitle: "For West Africa"
      })

    assert html =~ "Our story"
    assert html =~ "Building commerce"
    assert html =~ "For West Africa"
  end

  test "legal_layout renders TOC links and anchored sections from slots" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <EmakolaWeb.CompanyComponents.legal_layout title="Privacy Policy" last_updated="June 15, 2026">
        <:section id="intro" title="Introduction">Hello intro</:section>
        <:section id="data" title="Data we collect">Hello data</:section>
      </EmakolaWeb.CompanyComponents.legal_layout>
      """)

    assert html =~ "Privacy Policy"
    assert html =~ "Last updated"
    assert html =~ "June 15, 2026"
    # disclaimer banner
    assert html =~ "not legal advice"
    # TOC anchors
    assert html =~ ~s(href="#intro")
    assert html =~ ~s(href="#data")
    # anchored sections
    assert html =~ ~s(id="intro")
    assert html =~ ~s(id="data")
    assert html =~ "Hello intro"
    assert html =~ "Hello data"
  end
end
```

Note: add `import Phoenix.Component` is provided by `EmakolaWeb.ConnCase`? It is not — for the `~H` sigil in the test, add `import Phoenix.Component` and `import Phoenix.LiveViewTest` (the latter provides `rendered_to_string/1`). Add at top of the test module:

```elixir
  import Phoenix.Component
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/components/company_components_test.exs`
Expected: FAIL (module `EmakolaWeb.CompanyComponents` not defined).

- [ ] **Step 3: Implement `company_components.ex`**

```elixir
defmodule EmakolaWeb.CompanyComponents do
  @moduledoc """
  Shared building blocks for the apex company/legal pages
  (About, Careers, Press, Contact, Legal, Privacy, Terms, Cookie).
  Stateless function components matching the marketing aesthetic.
  """
  use Phoenix.Component

  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil

  def page_hero(assigns) do
    ~H"""
    <section class="px-4 pt-16 pb-12 lg:pt-24 lg:pb-16 bg-gradient-to-b from-[#f8fafc] to-white">
      <div class="max-w-4xl mx-auto text-center">
        <p
          :if={@eyebrow}
          class="inline-block mb-4 px-3 py-1 rounded-full text-xs font-semibold uppercase tracking-wider text-[#0c1526] bg-[#d4a843]/15"
        >
          {@eyebrow}
        </p>
        <h1 class="text-3xl lg:text-5xl font-headline font-bold text-[#0c1526] leading-tight">
          {@title}
        </h1>
        <p :if={@subtitle} class="mt-4 text-base lg:text-lg text-[#5f6b7a] max-w-2xl mx-auto">
          {@subtitle}
        </p>
      </div>
    </section>
    """
  end

  attr :icon, :string, default: nil
  attr :title, :string, required: true
  slot :inner_block, required: true

  def value_card(assigns) do
    ~H"""
    <div class="p-6 rounded-2xl border border-slate-200 bg-white hover:shadow-md transition-shadow">
      <span :if={@icon} class="material-symbols-outlined text-2xl text-[#d4a843] mb-3 block">
        {@icon}
      </span>
      <h3 class="text-lg font-headline font-semibold text-[#0c1526] mb-2">{@title}</h3>
      <p class="text-sm text-[#5f6b7a] leading-relaxed">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  attr :value, :string, required: true
  attr :label, :string, required: true

  def stat(assigns) do
    ~H"""
    <div class="text-center">
      <p class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526]">{@value}</p>
      <p class="text-sm text-[#5f6b7a] mt-1">{@label}</p>
    </div>
    """
  end

  attr :icon, :string, default: nil
  attr :title, :string, required: true
  slot :inner_block, required: true

  def benefit_item(assigns) do
    ~H"""
    <div class="flex gap-3">
      <span :if={@icon} class="material-symbols-outlined text-xl text-[#d4a843] shrink-0">
        {@icon}
      </span>
      <div>
        <h3 class="text-base font-semibold text-[#0c1526]">{@title}</h3>
        <p class="text-sm text-[#5f6b7a] mt-1 leading-relaxed">{render_slot(@inner_block)}</p>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :primary_label, :string, required: true
  attr :primary_href, :string, required: true
  attr :secondary_label, :string, default: nil
  attr :secondary_href, :string, default: nil

  def cta_band(assigns) do
    ~H"""
    <section class="px-4 py-16">
      <div class="max-w-4xl mx-auto text-center rounded-3xl bg-[#0c1526] px-6 py-12 lg:py-16">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#f1f5f9]">{@title}</h2>
        <p :if={@subtitle} class="mt-3 text-[#8896ab] max-w-xl mx-auto">{@subtitle}</p>
        <div class="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3">
          <a
            href={@primary_href}
            class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors"
          >
            {@primary_label}
          </a>
          <a
            :if={@secondary_label}
            href={@secondary_href}
            class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#f1f5f9] border border-[#1a2744] rounded-lg hover:border-[#d4a843] transition-colors"
          >
            {@secondary_label}
          </a>
        </div>
      </div>
    </section>
    """
  end

  @doc """
  Legal-document chrome: disclaimer banner, sticky TOC (desktop) / collapsible
  (mobile), and anchored prose sections. Each `:section` slot supplies `id` and
  `title`; its inner block is the prose (write paragraphs with explicit classes,
  e.g. `<p class="text-[#5f6b7a] leading-relaxed mb-4">…</p>`).
  """
  attr :title, :string, required: true
  attr :last_updated, :string, required: true

  slot :section, required: true do
    attr :id, :string, required: true
    attr :title, :string, required: true
  end

  def legal_layout(assigns) do
    ~H"""
    <section class="px-4 py-12 lg:py-16">
      <div class="max-w-5xl mx-auto">
        <h1 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526]">{@title}</h1>
        <p class="mt-2 text-sm text-[#8896ab]">Last updated {@last_updated}</p>

        <div class="mt-6 p-4 rounded-xl bg-amber-50 border border-amber-200 text-sm text-amber-900">
          This document is a template provided for information only and is
          <strong>not legal advice</strong>. Have it reviewed by qualified counsel
          before relying on it.
        </div>

        <div class="mt-10 grid lg:grid-cols-[240px_1fr] gap-10">
          <%!-- Table of contents --%>
          <nav class="lg:sticky lg:top-24 lg:self-start">
            <details open>
              <summary class="lg:hidden cursor-pointer text-sm font-semibold text-[#0c1526] mb-2">
                On this page
              </summary>
              <p class="hidden lg:block text-xs font-semibold uppercase tracking-wider text-[#8896ab] mb-3">
                On this page
              </p>
              <ul class="space-y-2">
                <li :for={s <- @section}>
                  <a
                    href={"#" <> s.id}
                    class="text-sm text-[#5f6b7a] hover:text-[#0c1526] transition-colors"
                  >
                    {s.title}
                  </a>
                </li>
              </ul>
            </details>
          </nav>

          <%!-- Prose --%>
          <article class="min-w-0">
            <section :for={s <- @section} id={s.id} class="mb-10 scroll-mt-24">
              <h2 class="text-xl font-headline font-semibold text-[#0c1526] mb-4">{s.title}</h2>
              <div class="space-y-4">{render_slot(s)}</div>
            </section>
          </article>
        </div>
      </div>
    </section>
    """
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/emakola_web/components/company_components_test.exs`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/emakola_web/components/company_components.ex test/emakola_web/components/company_components_test.exs
git commit -m "feat(web): shared CompanyComponents (hero, cards, cta, legal_layout)"
```

---

### Task 3: About page

**Files:**
- Create: `lib/emakola_web/live/company/about_live.ex`
- Modify: `lib/emakola_web/router.ex` (apex marketing `scope "/", EmakolaWeb` — the block containing `live "/pricing", PricingLive`)
- Test: `test/emakola_web/live/company/about_live_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.Company.AboutLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders mission, values and CTAs", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/about")

    assert html =~ "West Africa"
    assert html =~ "Our mission"
    assert html =~ ~s(id="main-nav")
    assert html =~ ~s(href="/careers")
    assert html =~ ~s(href="/auth/register")
  end

  test "sets SEO title and canonical", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/about")
    assert html =~ "About"
    assert html =~ ~s(rel="canonical")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/company/about_live_test.exs`
Expected: FAIL (no route / module).

- [ ] **Step 3: Create the LiveView (use the page skeleton)**

Create `lib/emakola_web/live/company/about_live.ex` using the page skeleton with:
- `page_title: "About — Emakola | Commerce for West Africa"`
- `meta_description: "Emakola helps West African merchants sell online with mobile money, WhatsApp orders, and storefronts built for low-bandwidth phones."`
- `canonical_url: url(~p"/about")`

`<main>` content:

```heex
<.page_hero
  eyebrow="Our story"
  title="Building commerce for West Africa"
  subtitle="Emakola gives every merchant the tools to sell online — mobile money, WhatsApp orders, and storefronts that load on any phone."
/>

<section class="px-4 py-12">
  <div class="max-w-3xl mx-auto">
    <h2 class="text-2xl font-headline font-bold text-[#0c1526] mb-4">Our mission</h2>
    <p class="text-[#5f6b7a] leading-relaxed mb-4">
      Across Ghana and Nigeria, millions of merchants sell on WhatsApp, in markets,
      and from their phones — but the tools built for them assume fast internet,
      cards, and addresses that don't match how commerce actually works here.
    </p>
    <p class="text-[#5f6b7a] leading-relaxed mb-4">
      Emakola is online retail rebuilt for West Africa: mobile money first
      (MTN MoMo, Vodafone Cash, AirtelTigo), WhatsApp and SMS order alerts, and
      storefronts optimized for low-bandwidth devices. We handle the technology so
      merchants can focus on selling.
    </p>
    <p class="text-[#5f6b7a] leading-relaxed">
      We started in Ghana and are expanding across the region, one merchant at a time.
    </p>
  </div>
</section>

<section class="px-4 py-12 bg-[#f8fafc]">
  <div class="max-w-5xl mx-auto">
    <h2 class="text-2xl font-headline font-bold text-[#0c1526] text-center mb-10">What we believe</h2>
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <.value_card icon="smartphone" title="Mobile money first">
        Payments built around how West Africa actually pays — not cards bolted on later.
      </.value_card>
      <.value_card icon="bolt" title="Low-bandwidth ready">
        Fast on any phone and any network, because that's what our merchants use.
      </.value_card>
      <.value_card icon="storefront" title="Merchant-obsessed">
        Every decision starts with the person running the store, not the spreadsheet.
      </.value_card>
      <.value_card icon="public" title="Built for the region">
        Local languages, local payments, local logistics — designed for here.
      </.value_card>
    </div>
  </div>
</section>

<section class="px-4 py-12">
  <div class="max-w-4xl mx-auto grid grid-cols-2 sm:grid-cols-4 gap-6">
    <.stat value="Ghana" label="Where we started" />
    <.stat value="Nigeria" label="Expanding next" />
    <.stat value="Mobile money" label="Payments, first-class" />
    <.stat value="WhatsApp" label="Orders & alerts" />
  </div>
</section>

<.cta_band
  title="Want to build the future of commerce with us?"
  subtitle="We're a small team with a big mission. Come help merchants across the region grow."
  primary_label="See open roles"
  primary_href="/careers"
  secondary_label="Start selling"
  secondary_href="/auth/register"
/>
```

(Stats use qualitative copy only — do NOT invent store/GMV numbers.)

- [ ] **Step 4: Add the route**

In `lib/emakola_web/router.ex`, in the apex marketing scope (alongside `live "/pricing", PricingLive`), add:

```elixir
live "/about", Company.AboutLive
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/emakola_web/live/company/about_live_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/live/company/about_live.ex lib/emakola_web/router.ex test/emakola_web/live/company/about_live_test.exs
git commit -m "feat(web): About page"
```

---

### Task 4: Careers page

**Files:**
- Create: `lib/emakola_web/live/company/careers_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Test: `test/emakola_web/live/company/careers_live_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.Company.CareersLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders culture, benefits and a general-application mailto", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/careers")

    assert html =~ "Life at Emakola"
    assert html =~ "No open roles"
    assert html =~ ~s(href="mailto:careers@emakola.com")
    assert html =~ ~s(id="main-nav")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/company/careers_live_test.exs`
Expected: FAIL.

- [ ] **Step 3: Create the LiveView**

`lib/emakola_web/live/company/careers_live.ex` using the page skeleton.
- `page_title: "Careers — Emakola"`
- `meta_description: "Join Emakola and help build commerce tools for West African merchants. Remote-friendly, mission-driven, early-stage."`
- `canonical_url: url(~p"/careers")`
- Read the careers email in `mount`: add to assigns `careers_email: Application.get_env(:emakola, :careers_email)`.

`<main>`:

```heex
<.page_hero
  eyebrow="Careers"
  title="Help merchants across West Africa grow"
  subtitle="We're building the commerce platform the region deserves. If that excites you, we'd love to meet you."
/>

<section class="px-4 py-12">
  <div class="max-w-3xl mx-auto">
    <h2 class="text-2xl font-headline font-bold text-[#0c1526] mb-4">Life at Emakola</h2>
    <p class="text-[#5f6b7a] leading-relaxed mb-4">
      We're a small, focused team that ships. We care about merchants, sweat the
      details on low-bandwidth performance, and make decisions close to the people
      we serve. You'll have real ownership and see your work in merchants' hands fast.
    </p>
  </div>
</section>

<section class="px-4 py-12 bg-[#f8fafc]">
  <div class="max-w-4xl mx-auto">
    <h2 class="text-2xl font-headline font-bold text-[#0c1526] text-center mb-10">Why work here</h2>
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
      <.benefit_item icon="public" title="Real impact">
        Your work helps real merchants earn a living across Ghana and Nigeria.
      </.benefit_item>
      <.benefit_item icon="rocket_launch" title="Ownership">
        Small team, big surface area. You'll lead, not wait for permission.
      </.benefit_item>
      <.benefit_item icon="laptop_mac" title="Remote-friendly">
        Work from wherever you do your best thinking, with flexible hours.
      </.benefit_item>
      <.benefit_item icon="school" title="Grow fast">
        Ship across the whole stack and learn from a team that loves the craft.
      </.benefit_item>
    </div>
  </div>
</section>

<section class="px-4 py-16">
  <div class="max-w-2xl mx-auto text-center rounded-2xl border border-slate-200 p-8">
    <h2 class="text-xl font-headline font-bold text-[#0c1526] mb-2">No open roles right now</h2>
    <p class="text-[#5f6b7a] mb-6">
      We're not actively hiring at the moment — but we're always glad to hear from
      great people. Send us your CV and a note about what you'd want to work on.
    </p>
    <a
      href={"mailto:" <> @careers_email}
      class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors"
    >
      Email {@careers_email}
    </a>
  </div>
</section>
```

- [ ] **Step 4: Add the route**

```elixir
live "/careers", Company.CareersLive
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/emakola_web/live/company/careers_live_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/live/company/careers_live.ex lib/emakola_web/router.ex test/emakola_web/live/company/careers_live_test.exs
git commit -m "feat(web): Careers page"
```

---

### Task 5: Press page

**Files:**
- Create: `lib/emakola_web/live/company/press_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Test: `test/emakola_web/live/company/press_live_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.Company.PressLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders boilerplate, brand asset download, and press contact", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/press")

    assert html =~ "Press &amp; media" or html =~ "Press"
    assert html =~ "Brand assets"
    assert html =~ ~s(href="/images/emakola-logo.svg")
    assert html =~ ~s(href="mailto:press@emakola.com")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/company/press_live_test.exs`
Expected: FAIL.

- [ ] **Step 3: Create the LiveView**

`lib/emakola_web/live/company/press_live.ex` using the page skeleton.
- `page_title: "Press — Emakola"`
- `meta_description: "Press resources, brand assets, and media contact for Emakola — the commerce platform for West African merchants."`
- `canonical_url: url(~p"/press")`
- assigns: `press_email: Application.get_env(:emakola, :press_email)`

`<main>`:

```heex
<.page_hero
  eyebrow="Press & media"
  title="Press resources"
  subtitle="Everything you need to write about Emakola. For interviews or anything else, reach out below."
/>

<section class="px-4 py-12">
  <div class="max-w-3xl mx-auto">
    <h2 class="text-2xl font-headline font-bold text-[#0c1526] mb-4">About Emakola</h2>
    <p class="text-[#5f6b7a] leading-relaxed mb-4">
      <strong>Short:</strong> Emakola is a multi-tenant commerce platform for West Africa —
      Shopify localized for the region, with mobile money payments and WhatsApp order alerts.
    </p>
    <p class="text-[#5f6b7a] leading-relaxed">
      <strong>Long:</strong> Emakola lets merchants in Ghana and Nigeria launch online stores
      built for how commerce actually works here: mobile money first (MTN MoMo, Vodafone Cash,
      AirtelTigo), local payment gateways (Paystack, Hubtel), WhatsApp and SMS notifications,
      and storefronts optimized for low-bandwidth phones.
    </p>
  </div>
</section>

<section class="px-4 py-12 bg-[#f8fafc]">
  <div class="max-w-3xl mx-auto">
    <h2 class="text-2xl font-headline font-bold text-[#0c1526] mb-6">Key facts</h2>
    <ul class="space-y-2 text-[#5f6b7a]">
      <li><strong class="text-[#0c1526]">What:</strong> Online store platform for West African merchants</li>
      <li><strong class="text-[#0c1526]">Markets:</strong> Ghana today, Nigeria next</li>
      <li><strong class="text-[#0c1526]">Payments:</strong> Mobile money, Paystack, Hubtel</li>
      <li><strong class="text-[#0c1526]">Notifications:</strong> WhatsApp &amp; SMS</li>
    </ul>
  </div>
</section>

<section class="px-4 py-12">
  <div class="max-w-3xl mx-auto">
    <h2 class="text-2xl font-headline font-bold text-[#0c1526] mb-6">Brand assets</h2>
    <div class="flex flex-wrap gap-4">
      <a
        href="/images/emakola-logo.svg"
        download
        class="inline-flex items-center gap-2 px-4 py-3 rounded-lg border border-slate-200 hover:border-[#d4a843] transition-colors text-sm font-medium text-[#0c1526]"
      >
        <span class="material-symbols-outlined text-base">download</span> Logo (SVG)
      </a>
      <a
        href="/images/og-image.png"
        download
        class="inline-flex items-center gap-2 px-4 py-3 rounded-lg border border-slate-200 hover:border-[#d4a843] transition-colors text-sm font-medium text-[#0c1526]"
      >
        <span class="material-symbols-outlined text-base">download</span> Social card (PNG)
      </a>
    </div>
  </div>
</section>

<section class="px-4 py-16">
  <div class="max-w-2xl mx-auto text-center rounded-2xl border border-slate-200 p-8">
    <h2 class="text-xl font-headline font-bold text-[#0c1526] mb-2">Media enquiries</h2>
    <p class="text-[#5f6b7a] mb-6">For interviews, quotes, or more information, get in touch.</p>
    <a
      href={"mailto:" <> @press_email}
      class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors"
    >
      Email {@press_email}
    </a>
  </div>
</section>
```

- [ ] **Step 4: Add the route**

```elixir
live "/press", Company.PressLive
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/emakola_web/live/company/press_live_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/live/company/press_live.ex lib/emakola_web/router.ex test/emakola_web/live/company/press_live_test.exs
git commit -m "feat(web): Press page"
```

---

### Task 6: Legal hub page

**Files:**
- Create: `lib/emakola_web/live/company/legal_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Test: `test/emakola_web/live/company/legal_live_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.Company.LegalLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "links to privacy, terms and cookie pages", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/legal")

    assert html =~ ~s(href="/privacy")
    assert html =~ ~s(href="/terms")
    assert html =~ ~s(href="/cookies")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/company/legal_live_test.exs`
Expected: FAIL.

- [ ] **Step 3: Create the LiveView**

`lib/emakola_web/live/company/legal_live.ex` using the page skeleton.
- `page_title: "Legal — Emakola"`, `canonical_url: url(~p"/legal")`,
  `meta_description: "Emakola legal policies: privacy, terms of service, and cookie policy."`

`<main>`:

```heex
<.page_hero eyebrow="Legal" title="Legal & policies" subtitle="The agreements and policies that govern how Emakola works." />

<section class="px-4 py-12">
  <div class="max-w-4xl mx-auto grid grid-cols-1 sm:grid-cols-3 gap-4">
    <a href="/privacy" class="p-6 rounded-2xl border border-slate-200 hover:border-[#d4a843] hover:shadow-md transition-all">
      <h2 class="text-lg font-headline font-semibold text-[#0c1526] mb-1">Privacy Policy</h2>
      <p class="text-sm text-[#5f6b7a]">How we collect, use, and protect data.</p>
    </a>
    <a href="/terms" class="p-6 rounded-2xl border border-slate-200 hover:border-[#d4a843] hover:shadow-md transition-all">
      <h2 class="text-lg font-headline font-semibold text-[#0c1526] mb-1">Terms of Service</h2>
      <p class="text-sm text-[#5f6b7a]">The rules for using Emakola.</p>
    </a>
    <a href="/cookies" class="p-6 rounded-2xl border border-slate-200 hover:border-[#d4a843] hover:shadow-md transition-all">
      <h2 class="text-lg font-headline font-semibold text-[#0c1526] mb-1">Cookie Policy</h2>
      <p class="text-sm text-[#5f6b7a]">How and why we use cookies.</p>
    </a>
  </div>
</section>
```

- [ ] **Step 4: Add the route**

```elixir
live "/legal", Company.LegalLive
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/emakola_web/live/company/legal_live_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/live/company/legal_live.ex lib/emakola_web/router.ex test/emakola_web/live/company/legal_live_test.exs
git commit -m "feat(web): Legal hub page"
```

---

### Task 7: Privacy Policy page

**Files:**
- Create: `lib/emakola_web/live/company/privacy_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Test: `test/emakola_web/live/company/privacy_live_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.Company.PrivacyLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders privacy sections and last-updated", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/privacy")

    assert html =~ "Privacy Policy"
    assert html =~ "Last updated"
    assert html =~ "Information we collect"
    assert html =~ "Your rights"
    assert html =~ ~s(href="#data-we-collect")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/company/privacy_live_test.exs`
Expected: FAIL.

- [ ] **Step 3: Create the LiveView**

`lib/emakola_web/live/company/privacy_live.ex` using the page skeleton.
- `page_title: "Privacy Policy — Emakola"`, `canonical_url: url(~p"/privacy")`,
  `meta_description: "How Emakola collects, uses, and protects merchant and customer data."`

`<main>` uses `<.legal_layout>` with `last_updated="June 15, 2026"` and one `<:section>` per item below. **Section list (id / title)** — write 1–2 short paragraphs of professional template copy per section (explicit classes: `<p class="text-[#5f6b7a] leading-relaxed">…</p>`, lists `<ul class="list-disc pl-5 text-[#5f6b7a] space-y-1">`):

1. `introduction` / "Introduction"
2. `who-we-are` / "Who we are" — Emakola operates a multi-tenant marketplace; merchants are independent data controllers for their own customers; Emakola is the platform processor.
3. `data-we-collect` / "Information we collect" — account details, store config, order/transaction metadata, device & usage data, cookies.
4. `how-we-use-it` / "How we use it"
5. `payments` / "Payment processing" — processed by Paystack, Hubtel, and mobile-money providers; Emakola does not store full card numbers or mobile-money PINs.
6. `sharing` / "Sharing & third parties"
7. `retention` / "Data retention"
8. `security` / "Security"
9. `your-rights` / "Your rights" — access, correction, deletion, objection.
10. `children` / "Children"
11. `international` / "International transfers"
12. `changes` / "Changes to this policy"
13. `contact` / "Contact us" — reference the privacy contact email.

Example for two sections (match this tone for the rest):

```heex
<.legal_layout title="Privacy Policy" last_updated="June 15, 2026">
  <:section id="introduction" title="Introduction">
    <p class="text-[#5f6b7a] leading-relaxed">
      This Privacy Policy explains how Emakola ("we", "us") collects, uses, and
      protects personal information when you use our platform, websites, and
      services. By using Emakola you agree to the practices described here.
    </p>
  </:section>
  <:section id="who-we-are" title="Who we are">
    <p class="text-[#5f6b7a] leading-relaxed">
      Emakola operates a multi-tenant commerce platform. Each merchant runs their
      own independent store and is the controller of their customers' data; Emakola
      provides and processes data on the merchant's behalf as the platform operator.
    </p>
  </:section>
  <%!-- …remaining sections from the list above… --%>
</.legal_layout>
```

- [ ] **Step 4: Add the route**

```elixir
live "/privacy", Company.PrivacyLive
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/emakola_web/live/company/privacy_live_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/live/company/privacy_live.ex lib/emakola_web/router.ex test/emakola_web/live/company/privacy_live_test.exs
git commit -m "feat(web): Privacy Policy page"
```

---

### Task 8: Terms of Service page

**Files:**
- Create: `lib/emakola_web/live/company/terms_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Test: `test/emakola_web/live/company/terms_live_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.Company.TermsLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders terms sections", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/terms")

    assert html =~ "Terms of Service"
    assert html =~ "Acceptance"
    assert html =~ "Merchant obligations"
    assert html =~ "Limitation of liability"
    assert html =~ ~s(href="#merchant-obligations")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/company/terms_live_test.exs`
Expected: FAIL.

- [ ] **Step 3: Create the LiveView**

`lib/emakola_web/live/company/terms_live.ex` using the page skeleton.
- `page_title: "Terms of Service — Emakola"`, `canonical_url: url(~p"/terms")`,
  `meta_description: "The terms governing use of the Emakola commerce platform."`

`<main>` uses `<.legal_layout title="Terms of Service" last_updated="June 15, 2026">` with one `<:section>` per item (1–2 paragraphs each, same prose classes as Task 7):

1. `acceptance` / "Acceptance of terms"
2. `definitions` / "Definitions"
3. `accounts` / "Eligibility & accounts"
4. `merchant-obligations` / "Merchant obligations"
5. `acceptable-use` / "Acceptable use & prohibited goods"
6. `payments-fees` / "Payments, fees & payouts"
7. `orders` / "Orders & fulfillment" — Emakola facilitates the sale between merchant and customer; the merchant is the seller of record.
8. `intellectual-property` / "Intellectual property"
9. `third-party` / "Third-party services"
10. `disclaimers` / "Disclaimers"
11. `liability` / "Limitation of liability"
12. `indemnification` / "Indemnification"
13. `termination` / "Suspension & termination"
14. `governing-law` / "Governing law" — Ghana, expanding to other markets.
15. `changes` / "Changes to these terms"
16. `contact` / "Contact us"

- [ ] **Step 4: Add the route**

```elixir
live "/terms", Company.TermsLive
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/emakola_web/live/company/terms_live_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/live/company/terms_live.ex lib/emakola_web/router.ex test/emakola_web/live/company/terms_live_test.exs
git commit -m "feat(web): Terms of Service page"
```

---

### Task 9: Cookie Policy page

**Files:**
- Create: `lib/emakola_web/live/company/cookies_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Test: `test/emakola_web/live/company/cookies_live_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.Company.CookiesLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders cookie sections", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/cookies")

    assert html =~ "Cookie Policy"
    assert html =~ "What cookies are"
    assert html =~ "Managing cookies"
    assert html =~ ~s(href="#categories")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/company/cookies_live_test.exs`
Expected: FAIL.

- [ ] **Step 3: Create the LiveView**

`lib/emakola_web/live/company/cookies_live.ex` using the page skeleton.
- `page_title: "Cookie Policy — Emakola"`, `canonical_url: url(~p"/cookies")`,
  `meta_description: "How and why Emakola uses cookies and similar technologies."`

`<main>` uses `<.legal_layout title="Cookie Policy" last_updated="June 15, 2026">` with one `<:section>` per item (1–2 paragraphs each):

1. `what-cookies-are` / "What cookies are"
2. `why-we-use` / "Why we use them"
3. `categories` / "Categories of cookies" — strictly necessary (session, cart, CSRF), functional, analytics, plus the PWA service-worker caches.
4. `managing` / "Managing cookies" — browser controls; disabling strictly-necessary cookies may break checkout/login.
5. `third-party` / "Third-party cookies"
6. `changes` / "Changes to this policy"
7. `contact` / "Contact us"

- [ ] **Step 4: Add the route**

```elixir
live "/cookies", Company.CookiesLive
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/emakola_web/live/company/cookies_live_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/live/company/cookies_live.ex lib/emakola_web/router.ex test/emakola_web/live/company/cookies_live_test.exs
git commit -m "feat(web): Cookie Policy page"
```

---

### Task 10: ContactMailer

**Files:**
- Create: `lib/emakola/notifications/mailers/contact_mailer.ex` (module `Emakola.Notifications.ContactMailer`)
- Test: `test/emakola/notifications/contact_mailer_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Emakola.Notifications.ContactMailerTest do
  use ExUnit.Case, async: true
  import Swoosh.TestAssertions

  alias Emakola.Notifications.ContactMailer

  test "delivers a contact message to the configured address with reply-to" do
    {:ok, _} =
      ContactMailer.deliver_contact_message(%{
        name: "Ama",
        email: "ama@example.com",
        subject: "Help with payouts",
        message: "How do payouts work?"
      })

    assert_email_sent(fn email ->
      assert {_, "support@emakola.com"} = hd(email.to)
      assert {_, "ama@example.com"} = hd(email.reply_to)
      assert email.subject =~ "Help with payouts"
      assert email.text_body =~ "How do payouts work?"
      assert email.text_body =~ "ama@example.com"
    end)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/notifications/contact_mailer_test.exs`
Expected: FAIL (module not defined).

- [ ] **Step 3: Implement the mailer**

```elixir
defmodule Emakola.Notifications.ContactMailer do
  @moduledoc "Sends contact-form submissions to the support inbox."
  import Swoosh.Email

  alias Emakola.Mailer

  @from {"Emakola Contact Form", "noreply@founderpad.io"}

  def deliver_contact_message(%{name: name, email: email, subject: subject, message: message}) do
    to_address = Application.get_env(:emakola, :contact_email, "support@emakola.com")

    new()
    |> to(to_address)
    |> from(@from)
    |> reply_to(email)
    |> subject("[Contact] #{subject}")
    |> text_body("""
    New contact form submission

    Name: #{name}
    Email: #{email}
    Subject: #{subject}

    #{message}
    """)
    |> html_body("""
    <h2>New contact form submission</h2>
    <p><strong>Name:</strong> #{Phoenix.HTML.html_escape(name) |> Phoenix.HTML.safe_to_string()}</p>
    <p><strong>Email:</strong> #{Phoenix.HTML.html_escape(email) |> Phoenix.HTML.safe_to_string()}</p>
    <p><strong>Subject:</strong> #{Phoenix.HTML.html_escape(subject) |> Phoenix.HTML.safe_to_string()}</p>
    <p>#{Phoenix.HTML.html_escape(message) |> Phoenix.HTML.safe_to_string()}</p>
    """)
    |> Mailer.deliver()
  end
end
```

(HTML-escape user input to prevent injection into the email body.)

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/emakola/notifications/contact_mailer_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/notifications/mailers/contact_mailer.ex test/emakola/notifications/contact_mailer_test.exs
git commit -m "feat(notifications): ContactMailer for contact form"
```

---

### Task 11: Contact page (form + honeypot + channels)

**Files:**
- Create: `lib/emakola_web/live/company/contact_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Test: `test/emakola_web/live/company/contact_live_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.Company.ContactLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  test "renders form and support channels", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/contact")
    assert html =~ "Contact us"
    assert html =~ ~s(name="contact[email]")
    assert html =~ "wa.me"
    assert html =~ ~s(href="mailto:support@emakola.com")
  end

  test "valid submission sends an email and shows success", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/contact")

    html =
      view
      |> form("#contact-form", contact: %{
        name: "Ama",
        email: "ama@example.com",
        subject: "Hi",
        message: "Hello there",
        company_url: ""
      })
      |> render_submit()

    assert html =~ "Thanks" or html =~ "sent"
    assert_email_sent(fn email -> assert {_, "support@emakola.com"} = hd(email.to) end)
  end

  test "honeypot filled drops the submission silently (no email)", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/contact")

    view
    |> form("#contact-form", contact: %{
      name: "Bot",
      email: "bot@example.com",
      subject: "spam",
      message: "spam",
      company_url: "http://spam.example"
    })
    |> render_submit()

    refute_email_sent()
  end

  test "invalid email shows an error and sends nothing", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/contact")

    html =
      view
      |> form("#contact-form", contact: %{
        name: "Ama",
        email: "not-an-email",
        subject: "Hi",
        message: "Hello",
        company_url: ""
      })
      |> render_submit()

    assert html =~ "valid email"
    refute_email_sent()
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/company/contact_live_test.exs`
Expected: FAIL.

- [ ] **Step 3: Create the LiveView**

`lib/emakola_web/live/company/contact_live.ex`. Use the page skeleton plus form state. Full module:

```elixir
defmodule EmakolaWeb.Company.ContactLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents

  alias Emakola.Notifications.ContactMailer

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Contact — Emakola",
       meta_description: "Get in touch with the Emakola team — contact form, WhatsApp, email, and phone.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/contact"),
       mobile_menu_open: false,
       form: empty_form(),
       sent: false,
       error: nil,
       support_email: Application.get_env(:emakola, :contact_email, "support@emakola.com"),
       whatsapp: Application.get_env(:emakola, :support_whatsapp, "233200000000"),
       phone: Application.get_env(:emakola, :support_phone, "+233 20 000 0000")
     ), layout: false}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  def handle_event("submit", %{"contact" => params}, socket) do
    cond do
      # Honeypot: a real user never fills this hidden field. Pretend success.
      params["company_url"] not in [nil, ""] ->
        {:noreply, assign(socket, sent: true, error: nil)}

      not valid?(params) ->
        {:noreply, assign(socket, error: "Please enter your name, a valid email, and a message.", form: params)}

      true ->
        _ =
          ContactMailer.deliver_contact_message(%{
            name: params["name"],
            email: params["email"],
            subject: blank_to(params["subject"], "(no subject)"),
            message: params["message"]
          })

        {:noreply, assign(socket, sent: true, error: nil, form: empty_form())}
    end
  end

  defp empty_form, do: %{"name" => "", "email" => "", "subject" => "", "message" => "", "company_url" => ""}

  defp valid?(params) do
    present?(params["name"]) and present?(params["message"]) and valid_email?(params["email"])
  end

  defp present?(v), do: is_binary(v) and String.trim(v) != ""
  defp valid_email?(v), do: is_binary(v) and Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, v)
  defp blank_to(v, default), do: if(present?(v), do: v, else: default)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white font-body antialiased">
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main class="pt-16">
        <.page_hero eyebrow="Contact" title="Contact us" subtitle="Questions, feedback, or need a hand? We'd love to hear from you." />

        <section class="px-4 pb-16">
          <div class="max-w-5xl mx-auto grid lg:grid-cols-2 gap-10">
            <%!-- Form --%>
            <div>
              <div :if={@sent} class="p-6 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800">
                Thanks — your message has been sent. We'll get back to you soon.
              </div>

              <form :if={!@sent} id="contact-form" phx-submit="submit" class="space-y-4">
                <p :if={@error} class="text-sm text-red-600">{@error}</p>

                <%!-- Honeypot: visually hidden, off the tab order --%>
                <div class="hidden" aria-hidden="true">
                  <label>Company URL
                    <input type="text" name="contact[company_url]" tabindex="-1" autocomplete="off" />
                  </label>
                </div>

                <div>
                  <label class="block text-sm font-medium text-[#0c1526] mb-1">Name</label>
                  <input type="text" name="contact[name]" value={@form["name"]} required
                    class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-[#d4a843] focus:border-[#d4a843]" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-[#0c1526] mb-1">Email</label>
                  <input type="email" name="contact[email]" value={@form["email"]} required
                    class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-[#d4a843] focus:border-[#d4a843]" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-[#0c1526] mb-1">Subject</label>
                  <input type="text" name="contact[subject]" value={@form["subject"]}
                    class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-[#d4a843] focus:border-[#d4a843]" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-[#0c1526] mb-1">Message</label>
                  <textarea name="contact[message]" rows="5" required
                    class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-[#d4a843] focus:border-[#d4a843]">{@form["message"]}</textarea>
                </div>
                <button type="submit"
                  class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors">
                  Send message
                </button>
              </form>
            </div>

            <%!-- Channels --%>
            <div class="space-y-6">
              <h2 class="text-xl font-headline font-semibold text-[#0c1526]">Other ways to reach us</h2>
              <.benefit_item icon="mail" title="Email">
                <a href={"mailto:" <> @support_email} class="text-[#d4a843] hover:underline">{@support_email}</a>
              </.benefit_item>
              <.benefit_item icon="chat" title="WhatsApp">
                <a href={"https://wa.me/" <> @whatsapp} class="text-[#d4a843] hover:underline">Chat with us on WhatsApp</a>
              </.benefit_item>
              <.benefit_item icon="call" title="Phone">
                <a href={"tel:" <> @phone} class="text-[#d4a843] hover:underline">{@phone}</a>
              </.benefit_item>
              <.benefit_item icon="schedule" title="Hours">
                Monday–Friday, 9am–6pm GMT.
              </.benefit_item>
            </div>
          </div>
        </section>
      </main>
      <.landing_footer />
    </div>
    """
  end
end
```

- [ ] **Step 4: Add the route**

```elixir
live "/contact", Company.ContactLive
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/emakola_web/live/company/contact_live_test.exs`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/live/company/contact_live.ex lib/emakola_web/router.ex test/emakola_web/live/company/contact_live_test.exs
git commit -m "feat(web): Contact page with form + honeypot + channels"
```

---

### Task 12: Wire up footer links

**Files:**
- Modify: `lib/emakola_web/components/landing_components.ex:137-148` (Company + Legal `footer_column` blocks)
- Test: `test/emakola_web/components/landing_footer_links_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.LandingFooterLinksTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import EmakolaWeb.LandingComponents

  test "Company and Legal footer links point to real routes, not '#'" do
    html = render_component(&landing_footer/1, %{})

    for path <- ~w(/about /careers /press /contact /privacy /terms /cookies) do
      assert html =~ ~s(href="#{path}")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/components/landing_footer_links_test.exs`
Expected: FAIL (links still `href="#"`).

- [ ] **Step 3: Update the footer columns**

In `lib/emakola_web/components/landing_components.ex`, replace the Company and Legal `footer_column` blocks:

```heex
          <.footer_column title="Company">
            <:link href="/about">About</:link>
            <:link href="/careers">Careers</:link>
            <:link href="/press">Press</:link>
            <:link href="/contact">Contact</:link>
          </.footer_column>

          <.footer_column title="Legal">
            <:link href="/privacy">Privacy Policy</:link>
            <:link href="/terms">Terms of Service</:link>
            <:link href="/cookies">Cookie Policy</:link>
          </.footer_column>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/emakola_web/components/landing_footer_links_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola_web/components/landing_components.ex test/emakola_web/components/landing_footer_links_test.exs
git commit -m "feat(web): wire footer Company/Legal links to new pages"
```

---

### Task 13: Sitemap + full-suite verification

**Files:**
- Check (maybe modify): `lib/emakola_web/controllers/sitemap_controller.ex`

- [ ] **Step 1: Check whether the sitemap enumerates marketing pages**

Run: `grep -n "pricing\|/about\|paths\|marketing\|urls" lib/emakola_web/controllers/sitemap_controller.ex`
- If it lists static marketing paths (e.g. `/pricing`), add `/about`, `/careers`, `/press`, `/contact`, `/legal`, `/privacy`, `/terms`, `/cookies` to that list. If it doesn't enumerate them, skip (no change).

- [ ] **Step 2: If modified, update/extend the sitemap test if one exists**

Run: `find test -iname "sitemap*test*"` — if present, add assertions for the new paths; otherwise skip.

- [ ] **Step 3: Format + full suite (fresh compile, warnings as errors)**

Run: `mix format && mix test --warnings-as-errors`
Expected: all tests pass, no warnings.

- [ ] **Step 4: Browser-faithful check (manual, per project rule "green tests ≠ works")**

Start `mix phx.server`, then visit each of `/about`, `/careers`, `/press`, `/contact`, `/legal`, `/privacy`, `/terms`, `/cookies` and the landing footer — verify rendering at mobile (375px) and desktop widths, the contact form submits to a success state, and the legal TOC anchors jump correctly. (No code change unless a defect is found.)

- [ ] **Step 5: Commit any sitemap change**

```bash
git add lib/emakola_web/controllers/sitemap_controller.ex
git commit -m "feat(web): add company pages to sitemap"
```

---

## Self-Review Notes

- **Spec coverage:** All 8 pages (Tasks 3–9, 11), shared components incl. `legal_layout` (Task 2), ContactMailer + honeypot (Tasks 10–11), footer rewiring (Task 12), config/channels (Task 1), SEO assigns (every page skeleton), sitemap (Task 13), responsive (Tailwind breakpoints throughout), TDD (every task test-first). ✔
- **Routing:** all 8 routes added to the apex marketing scope (the one with `LandingLive`/`PricingLive`); no collision with the tenant `/s/:store_slug/about`. ✔
- **Type/name consistency:** component names (`page_hero`, `value_card`, `stat`, `benefit_item`, `cta_band`, `legal_layout`) and the mailer fn (`deliver_contact_message/1`) are used identically wherever referenced. ✔
- **Honeypot field** is `contact[company_url]` everywhere (form + LiveView + tests). ✔
