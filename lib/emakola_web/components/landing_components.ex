defmodule EmakolaWeb.LandingComponents do
  @moduledoc """
  Shared marketing/landing components (nav and footer) used by
  `EmakolaWeb.LandingLive` and `EmakolaWeb.PricingLive`.
  Stateless markup helpers; mobile-menu state lives in the parent LiveView.
  """

  use Phoenix.Component

  # ─────────────────────────────────────────────────────────────────────
  # landing_nav/1
  # ─────────────────────────────────────────────────────────────────────

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
            <a
              href="/#how-it-works"
              class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
            >
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
            phx-click="toggle_mobile_menu"
            class="md:hidden p-2 text-[#8896ab] hover:text-[#f1f5f9]"
            aria-label="Toggle menu"
            aria-expanded={to_string(@mobile_menu_open)}
          >
            <span class="material-symbols-outlined text-2xl">
              {if @mobile_menu_open, do: "close", else: "menu"}
            </span>
          </button>
        </div>
      </div>
    </nav>

    <%!-- Mobile menu lives OUTSIDE <nav>: the nav's backdrop-blur would
          otherwise become the containing block for this fixed overlay and
          collapse its height. --%>
    <div
      :if={@mobile_menu_open}
      class="md:hidden fixed inset-0 top-16 z-40 bg-[#0c1526] flex flex-col items-center justify-start pt-12 gap-6 animate-slide-down"
    >
      <a href="/#how-it-works" phx-click="toggle_mobile_menu" class="text-lg text-[#e2e8f0]">
        How it works
      </a>
      <a href="/#features" phx-click="toggle_mobile_menu" class="text-lg text-[#e2e8f0]">
        Features
      </a>
      <a href="/#faq" phx-click="toggle_mobile_menu" class="text-lg text-[#e2e8f0]">FAQ</a>
      <a href="/pricing" phx-click="toggle_mobile_menu" class="text-lg text-[#e2e8f0]">Pricing</a>
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
            <:link href="/#features">Features</:link>
            <:link href="/pricing">Pricing</:link>
            <:link href="/#features">Demo</:link>
            <:link href="/docs">API</:link>
          </.footer_column>

          <.footer_column title="Resources">
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

        <div class="border-t border-[#1a2744] pt-6 flex flex-col sm:flex-row items-center justify-center sm:justify-between gap-4">
          <p class="text-sm text-[#8896ab]">
            &copy; {@year} Emakola. All rights reserved.
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
