defmodule EmakolaWeb.LandingComponents do
  @moduledoc """
  Function components extracted from `EmakolaWeb.LandingLive`.

  These are stateless markup helpers — the landing LiveView itself
  remains a process for the mobile-menu toggle interaction, but the
  large static sections (footer today, navbar/hero/features over time)
  live here so the LV's `render/1` is comprehensible.
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
        <a href="/#how-it-works" phx-click="toggle_mobile_menu" class="text-lg text-[#8896ab]">
          How it works
        </a>
        <a href="/#features" phx-click="toggle_mobile_menu" class="text-lg text-[#8896ab]">
          Features
        </a>
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
            <:link href="#features">Features</:link>
            <:link href="/pricing">Pricing</:link>
            <:link href="#features">Demo</:link>
            <:link href="/docs">API</:link>
          </.footer_column>

          <.footer_column title="Resources">
            <:link href="#">Help Center</:link>
            <:link href="#">Blog</:link>
            <:link href="/docs">Developer Docs</:link>
            <:link href="#">Status</:link>
          </.footer_column>

          <.footer_column title="Company">
            <:link href="#">About</:link>
            <:link href="#">Careers</:link>
            <:link href="#">Press</:link>
            <:link href="#">Contact</:link>
          </.footer_column>

          <.footer_column title="Legal">
            <:link href="#">Privacy Policy</:link>
            <:link href="#">Terms of Service</:link>
            <:link href="#">Cookie Policy</:link>
          </.footer_column>
        </div>

        <div class="border-t border-[#1a2744] pt-6 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p class="text-sm text-[#8896ab]">
            &copy; {@year} Emakola. All rights reserved.
          </p>
          <div class="flex items-center gap-4">
            <.social_link href="#" label="Twitter">
              <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
            </.social_link>

            <.social_link href="#" label="LinkedIn">
              <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
            </.social_link>

            <.social_link href="#" label="GitHub">
              <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
            </.social_link>
          </div>
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

  attr :href, :string, required: true
  attr :label, :string, required: true
  slot :inner_block, required: true

  defp social_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
      aria-label={@label}
    >
      <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
        {render_slot(@inner_block)}
      </svg>
    </a>
    """
  end
end
