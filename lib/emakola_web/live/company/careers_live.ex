defmodule EmakolaWeb.Company.CareersLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Careers — Emakola",
       meta_description:
         "Join Emakola and help build commerce tools for West African merchants. Remote-friendly, mission-driven, early-stage.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/careers"),
       mobile_menu_open: false,
       careers_email: Application.get_env(:emakola, :careers_email, "careers@emakola.com")
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
      id="careers-scroll"
      phx-hook="ScrollReveal"
      class="min-h-screen bg-white font-body antialiased"
    >
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main>
        <.hero />
        <.life />
        <.perks />
        <.open_roles careers_email={@careers_email} />
      </main>
      <.landing_footer />
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # Hero — dark, cinematic, with atmospheric glow + animated underline.
  # ─────────────────────────────────────────────────────────────────────
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
          <span class="w-1.5 h-1.5 rounded-full bg-[#d4a843] animate-pulse"></span> Careers
        </span>
        <h1
          class="about-rise mt-7 text-4xl sm:text-5xl lg:text-6xl font-headline font-extrabold leading-[1.08] [text-shadow:0_2px_20px_rgba(12,21,38,0.55)]"
          style="animation-delay: 0.12s"
        >
          Help merchants across West Africa
          <span class="relative whitespace-nowrap text-[#d4a843]">
            grow
            <svg
              aria-hidden="true"
              viewBox="0 0 160 14"
              preserveAspectRatio="none"
              class="absolute -bottom-2 left-0 w-full h-2.5 text-[#d4a843]/70"
            >
              <path
                class="about-underline"
                d="M2 9 C 40 3, 80 3, 110 7 S 150 11, 158 5"
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
          We're building the commerce platform the region deserves. If that excites you,
          we'd love to meet you.
        </p>
      </div>
    </section>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # Life at Emakola — asymmetric editorial: label column beside a lead.
  # ─────────────────────────────────────────────────────────────────────
  defp life(assigns) do
    ~H"""
    <section class="bg-white px-4 sm:px-6 py-20 lg:py-28">
      <div class="max-w-6xl mx-auto grid lg:grid-cols-[0.75fr_1.45fr] gap-10 lg:gap-20">
        <div data-reveal>
          <p class="text-xs font-semibold uppercase tracking-[0.22em] text-[#d4a843]">
            01 — Life at Emakola
          </p>
          <div class="mt-4 h-px w-14 bg-[#d4a843]"></div>
          <h2 class="mt-6 text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] leading-[1.15]">
            A small team that ships, close to the people we serve.
          </h2>
        </div>

        <div class="space-y-6" data-reveal style="transition-delay: 0.12s">
          <p class="text-lg lg:text-xl text-[#3a4658] leading-relaxed font-medium">
            We're a small, focused team that ships. We care about merchants, sweat the
            details on low-bandwidth performance, and make decisions close to the people
            we serve.
          </p>
          <p class="text-base text-[#5f6b7a] leading-relaxed">
            You'll have real ownership and see your work in merchants' hands fast — no
            layers of process between you and the people you're building for.
          </p>
        </div>
      </div>
    </section>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # Why work here — premium floating cards mirroring the About page.
  # ─────────────────────────────────────────────────────────────────────
  defp perks(assigns) do
    ~H"""
    <section class="relative isolate overflow-hidden bg-[#f8fafc] px-4 sm:px-6 py-20 lg:py-28">
      <div
        aria-hidden="true"
        class="absolute inset-0 -z-10"
        style="background: radial-gradient(42rem 24rem at 100% 0%, rgba(212,168,67,0.12), transparent 60%);"
      >
      </div>

      <div class="max-w-6xl mx-auto">
        <div class="max-w-2xl" data-reveal>
          <p class="inline-flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.22em] text-[#d4a843]">
            <span class="h-px w-8 bg-[#d4a843]"></span> 02 — Why work here
          </p>
          <h2 class="mt-4 text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] leading-[1.15]">
            Work that matters, with room to lead
          </h2>
        </div>

        <div class="mt-14 grid sm:grid-cols-2 gap-5 lg:gap-6">
          <.perk index="01" icon="public" title="Real impact" delay="0.0s">
            Your work helps real merchants earn a living across Ghana and Nigeria.
          </.perk>
          <.perk index="02" icon="rocket_launch" title="Ownership" delay="0.08s">
            Small team, big surface area. You'll lead, not wait for permission.
          </.perk>
          <.perk index="03" icon="laptop_mac" title="Remote-friendly" delay="0.16s">
            Work from wherever you do your best thinking, with flexible hours.
          </.perk>
          <.perk index="04" icon="school" title="Grow fast" delay="0.24s">
            Ship across the whole stack and learn from a team that loves the craft.
          </.perk>
        </div>
      </div>
    </section>
    """
  end

  attr :index, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :delay, :string, default: "0s"
  slot :inner_block, required: true

  defp perk(assigns) do
    ~H"""
    <div
      data-reveal
      style={"transition-delay: #{@delay}"}
      class="group relative overflow-hidden rounded-3xl border border-slate-200/80 bg-white p-8 lg:p-10 shadow-sm transition-all duration-300 hover:-translate-y-1.5 hover:border-[#d4a843]/40 hover:shadow-xl hover:shadow-[#0c1526]/[0.06]"
    >
      <span
        aria-hidden="true"
        class="pointer-events-none absolute -top-5 right-1 select-none font-headline text-8xl font-extrabold leading-none text-slate-100 transition-colors duration-500 group-hover:text-[#d4a843]/15"
      >
        {@index}
      </span>

      <span class="relative inline-flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-[#0c1526] to-[#1a2744] text-[#d4a843] shadow-lg ring-1 ring-white/5 transition-all duration-300 group-hover:scale-105 group-hover:from-[#d4a843] group-hover:to-[#c2643c] group-hover:text-[#0c1526]">
        <span class="material-symbols-outlined text-2xl">{@icon}</span>
      </span>

      <h3 class="relative mt-6 text-xl font-headline font-bold text-[#0c1526]">{@title}</h3>
      <p class="relative mt-3 text-[15px] leading-relaxed text-[#5f6b7a]">
        {render_slot(@inner_block)}
      </p>

      <span class="absolute bottom-0 left-0 h-1 w-full origin-left scale-x-0 bg-gradient-to-r from-[#d4a843] to-[#c2643c] transition-transform duration-300 ease-out group-hover:scale-x-100">
      </span>
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # Open roles — dark closing band with a general-application mailto.
  # ─────────────────────────────────────────────────────────────────────
  attr :careers_email, :string, required: true

  defp open_roles(assigns) do
    ~H"""
    <section class="px-4 sm:px-6 py-16 lg:py-24">
      <div
        data-reveal
        class="relative isolate overflow-hidden rounded-3xl bg-[#0c1526] text-center px-6 py-12 lg:py-16 ring-1 ring-white/10 max-w-3xl mx-auto"
      >
        <div
          aria-hidden="true"
          class="absolute inset-0 -z-10"
          style="background: radial-gradient(34rem 20rem at 50% -10%, rgba(212,168,67,0.18), transparent 60%);"
        >
        </div>

        <span class="inline-flex h-14 w-14 items-center justify-center rounded-2xl bg-[#d4a843]/12 text-[#d4a843] ring-1 ring-[#d4a843]/20">
          <span class="material-symbols-outlined text-2xl">work</span>
        </span>

        <h2 class="mt-6 text-2xl lg:text-3xl font-headline font-bold text-[#f1f5f9]">
          No open roles right now
        </h2>
        <p class="mt-3 text-[#8896ab] max-w-xl mx-auto leading-relaxed">
          We're not actively hiring at the moment — but we're always glad to hear from
          great people. Send us your CV and a note about what you'd want to work on.
        </p>

        <a
          href={"mailto:" <> @careers_email}
          class="group mt-8 inline-flex items-center gap-2 px-6 py-3.5 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-xl shadow-lg shadow-[#d4a843]/25 transition-all duration-200 hover:bg-[#c49a3a] hover:-translate-y-0.5 focus-visible:ring-2 focus-visible:ring-[#d4a843] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
        >
          <span class="material-symbols-outlined text-lg">mail</span> Email {@careers_email}
        </a>
      </div>
    </section>
    """
  end
end
