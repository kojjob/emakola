defmodule EmakolaWeb.Company.LegalLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Legal — Emakola",
       meta_description: "Emakola legal policies: privacy, terms of service, and cookie policy.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/legal"),
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
      id="legal-scroll"
      phx-hook="ScrollReveal"
      class="min-h-screen bg-white font-body antialiased"
    >
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main>
        <.hero />

        <section class="px-4 sm:px-6 py-16 lg:py-24">
          <div class="max-w-5xl mx-auto grid grid-cols-1 sm:grid-cols-3 gap-5 lg:gap-6">
            <.policy_card
              href="/privacy"
              icon="shield_person"
              title="Privacy Policy"
              delay="0.0s"
            >
              How we collect, use, and protect data.
            </.policy_card>
            <.policy_card href="/terms" icon="gavel" title="Terms of Service" delay="0.08s">
              The rules for using Emakola.
            </.policy_card>
            <.policy_card href="/cookies" icon="cookie" title="Cookie Policy" delay="0.16s">
              How and why we use cookies.
            </.policy_card>
          </div>

          <p
            data-reveal
            style="transition-delay: 0.24s"
            class="mt-12 text-center text-sm text-[#5f6b7a]"
          >
            Questions about our policies? <a
              href="/contact"
              class="font-semibold text-[#c49a3a] hover:underline"
            >Get in touch</a>.
          </p>
        </section>
      </main>
      <.landing_footer />
    </div>
    """
  end

  # ── Hero ──────────────────────────────────────────────────────────────
  defp hero(assigns) do
    ~H"""
    <section class="relative isolate overflow-hidden bg-[#0c1526] text-[#f1f5f9] pt-16">
      <div
        aria-hidden="true"
        class="absolute inset-0 -z-10"
        style="background:
          radial-gradient(58rem 30rem at 85% -12%, rgba(212,168,67,0.20), transparent 60%),
          radial-gradient(46rem 28rem at -4% 110%, rgba(181,83,46,0.16), transparent 55%);"
      >
      </div>

      <div class="relative max-w-4xl mx-auto px-4 sm:px-6 py-24 lg:py-32 text-center">
        <span class="about-rise inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-[#d4a843]/30 bg-[#d4a843]/10 text-xs font-semibold uppercase tracking-[0.22em] text-[#d4a843]">
          <span class="w-1.5 h-1.5 rounded-full bg-[#d4a843] animate-pulse"></span> Legal
        </span>
        <h1
          class="about-rise mt-7 text-4xl sm:text-5xl lg:text-6xl font-headline font-extrabold leading-[1.08] [text-shadow:0_2px_20px_rgba(12,21,38,0.55)]"
          style="animation-delay: 0.12s"
        >
          Legal &amp;
          <span class="relative whitespace-nowrap text-[#d4a843]">
            policies
            <svg
              aria-hidden="true"
              viewBox="0 0 200 14"
              preserveAspectRatio="none"
              class="absolute -bottom-2 left-0 w-full h-2.5 text-[#d4a843]/70"
            >
              <path
                class="about-underline"
                d="M2 9 C 50 3, 100 3, 135 7 S 188 11, 198 5"
                fill="none"
                stroke="currentColor"
                stroke-width="3"
                stroke-linecap="round"
              />
            </svg>
          </span>
        </h1>
        <p
          class="about-rise mt-8 text-base lg:text-xl text-[#cbd5e1] max-w-2xl mx-auto leading-relaxed"
          style="animation-delay: 0.24s"
        >
          The agreements and policies that govern how Emakola works.
        </p>
      </div>
    </section>
    """
  end

  # ── Policy card ───────────────────────────────────────────────────────
  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :delay, :string, default: "0s"
  slot :inner_block, required: true

  defp policy_card(assigns) do
    ~H"""
    <a
      href={@href}
      data-reveal
      style={"transition-delay: #{@delay}"}
      class="group relative flex flex-col overflow-hidden rounded-3xl border border-slate-200/80 bg-white p-7 lg:p-8 shadow-sm transition-all duration-300 hover:-translate-y-1.5 hover:border-[#d4a843]/40 hover:shadow-xl hover:shadow-[#0c1526]/[0.06]"
    >
      <span class="inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-[#0c1526] to-[#1a2744] text-[#d4a843] shadow-lg ring-1 ring-white/5 transition-all duration-300 group-hover:scale-105 group-hover:from-[#d4a843] group-hover:to-[#c2643c] group-hover:text-[#0c1526]">
        <span class="material-symbols-outlined text-2xl">{@icon}</span>
      </span>

      <h2 class="mt-5 text-lg font-headline font-bold text-[#0c1526]">{@title}</h2>
      <p class="mt-1.5 text-sm text-[#5f6b7a] leading-relaxed">{render_slot(@inner_block)}</p>

      <span class="mt-5 inline-flex items-center gap-1 text-sm font-semibold text-[#c49a3a]">
        Read policy
        <span class="material-symbols-outlined text-base transition-transform duration-200 group-hover:translate-x-0.5">
          arrow_forward
        </span>
      </span>

      <span class="absolute bottom-0 left-0 h-1 w-full origin-left scale-x-0 bg-gradient-to-r from-[#d4a843] to-[#c2643c] transition-transform duration-300 ease-out group-hover:scale-x-100">
      </span>
    </a>
    """
  end
end
