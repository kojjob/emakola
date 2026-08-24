defmodule EmakolaWeb.LandingComponents do
  @moduledoc """
  Shared marketing/landing components (nav and footer) used by the dead
  landing page and the marketing LiveViews (pricing, company, docs).
  Stateless markup helpers; the mobile menu is pure client state driven by
  `Phoenix.LiveView.JS` commands, so the nav works identically on dead pages
  and LiveViews with no server round-trip or parent event handler.
  """

  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [icon: 1]

  alias EmakolaWeb.BrandComponents
  alias Phoenix.LiveView.JS

  # ─────────────────────────────────────────────────────────────────────
  # landing_nav/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Marketing nav shared by the landing and pricing pages.

  Anchor links use absolute paths ("/#features") so they work from /pricing too.
  The scrolled-glass effect binds via `data-scroll-glass` (see app.js), which
  runs on dead pages and live navigation alike.
  """
  def landing_nav(assigns) do
    ~H"""
    <nav
      id="main-nav"
      data-scroll-glass
      class="fixed top-0 left-0 right-0 z-50 bg-[#0c1526]/80 backdrop-blur-md border-b border-transparent transition-all duration-300"
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <a href="/" class="flex items-center gap-2">
            <BrandComponents.logo_mark
              motion="reveal"
              tone="reversed"
              size={32}
              class="shrink-0"
            />
            <span class="text-xl font-headline font-bold text-[#f1f5f9]">Makola</span>
          </a>
          <div class="hidden md:flex items-center gap-6">
            <a
              href="/how-it-works"
              class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
            >
              How it works
            </a>
            <a
              href="/how-it-works/tour"
              class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
            >
              Watch the tour
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
            <a
              href="/auth/login"
              class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
            >
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
            id="landing-menu-button"
            phx-click={toggle_mobile_menu()}
            class="md:hidden p-2 text-[#8896ab] hover:text-[#f1f5f9]"
            aria-label="Toggle menu"
            aria-expanded="false"
          >
            <span
              id="landing-menu-closed-icon"
              aria-hidden="true"
            >
              <.icon name="hero-bars-3" class="size-6" />
            </span>
            <span
              id="landing-menu-open-icon"
              aria-hidden="true"
            >
              <.icon name="hero-x-mark" class="size-6" />
            </span>
          </button>
        </div>
      </div>
    </nav>

    <%!-- Mobile menu lives OUTSIDE <nav>: the nav's backdrop-blur would
          otherwise become the containing block for this fixed overlay and
          collapse its height. --%>
    <div
      id="landing-mobile-menu"
      class="hidden md:hidden fixed inset-0 top-16 z-40 bg-[#0c1526] flex-col items-center justify-start pt-12 gap-6 animate-slide-down [&:not(.hidden)]:flex"
    >
      <a href="/how-it-works" phx-click={toggle_mobile_menu()} class="text-lg text-[#e2e8f0]">
        How it works
      </a>
      <a
        href="/how-it-works/tour"
        phx-click={toggle_mobile_menu()}
        class="text-lg text-[#e2e8f0]"
      >
        Watch the tour
      </a>
      <a href="/#features" phx-click={toggle_mobile_menu()} class="text-lg text-[#e2e8f0]">
        Features
      </a>
      <a href="/#faq" phx-click={toggle_mobile_menu()} class="text-lg text-[#e2e8f0]">FAQ</a>
      <a href="/pricing" phx-click={toggle_mobile_menu()} class="text-lg text-[#e2e8f0]">Pricing</a>
      <a href="/stores" class="text-lg text-[#e2e8f0]">Browse stores</a>
      <hr class="w-24 border-[#1a2744]" />
      <a href="/auth/login" class="text-lg text-[#e2e8f0]">Login</a>
      <a
        href="/auth/register"
        class="inline-flex items-center px-6 py-3 text-base font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg"
      >
        Get Started
      </a>
    </div>
    """
  end

  # Pure client-side toggle: works on the dead landing page and inside
  # LiveViews without any parent handle_event or server round-trip.
  defp toggle_mobile_menu do
    JS.toggle_class("hidden", to: "#landing-mobile-menu")
    |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "#landing-menu-button")
  end

  # ─────────────────────────────────────────────────────────────────────
  # landing_footer/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders the landing-page footer — four-column link grid + copyright +
  social links. Stateless; the only dynamic piece is the current year.
  """
  def landing_footer(assigns) do
    assigns = assign_new(assigns, :year, fn -> DateTime.utc_now().year end)

    ~H"""
    <footer class="bg-[#0c1526] border-t border-[#1a2744] py-12 px-4">
      <div class="max-w-5xl mx-auto">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-8 mb-10">
          <.footer_column title="Product">
            <:link href="/how-it-works">How it works</:link>
            <:link href="/#features">Features</:link>
            <:link href="/pricing">Pricing</:link>
            <:link href="/#features">Demo</:link>
            <:link href="/docs">API</:link>
          </.footer_column>

          <.footer_column title="Resources">
            <:link href="/blog">Blog</:link>
            <:link href="/contact">Help Center</:link>
            <:link href="/docs">Developer Docs</:link>
            <:link href="/stores">Browse stores</:link>
          </.footer_column>

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
        </div>

        <div class="border-t border-[#1a2744] pt-6 pb-6">
          <p class="text-xs font-semibold uppercase tracking-wide text-[#8896ab]">
            Shop by region
          </p>
          <div class="mt-3 flex flex-wrap gap-x-4 gap-y-2">
            <a
              :for={region <- EmakolaWeb.SEO.Regions.names()}
              href={"/shops/#{EmakolaWeb.SEO.Regions.slug(region)}"}
              class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
            >
              {region}
            </a>
          </div>
        </div>

        <div class="border-t border-[#1a2744] pt-6 flex flex-col sm:flex-row items-center justify-center sm:justify-between gap-4">
          <p class="text-sm text-[#8896ab]">
            &copy; {@year} Makola. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
    """
  end

  # ── Internal helpers ──────────────────────────────────────────────

  attr :title, :string, required: true

  slot :link, required: true do
    attr :href, :string, required: true
  end

  defp footer_column(assigns) do
    ~H"""
    <div>
      <h4 class="text-sm font-semibold text-[#f1f5f9] mb-4">{@title}</h4>
      <ul class="space-y-2">
        <li :for={l <- @link}>
          <a
            href={l.href}
            class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
          >
            {render_slot(l)}
          </a>
        </li>
      </ul>
    </div>
    """
  end
end
