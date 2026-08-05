defmodule EmakolaWeb.Company.LegalLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents, only: [marketing_hero: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Legal — Makola",
       meta_description: "Makola legal policies: privacy, terms of service, and cookie policy.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/legal")
     ), layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant={:plain}>
      <div
        id="legal-scroll"
        phx-hook="ScrollReveal"
        class="min-h-screen bg-white font-body antialiased"
      >
        <.landing_nav />
        <main>
          <.marketing_hero
            eyebrow="Legal"
            title="Legal &"
            highlight="policies"
            subtitle="The agreements and policies that govern how Makola works."
          />

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
                The rules for using Makola.
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
    </Layouts.app>
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
