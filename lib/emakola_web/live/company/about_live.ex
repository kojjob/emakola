defmodule EmakolaWeb.Company.AboutLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents, only: [cta_band: 1, marketing_hero: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "About — Emakola | Commerce for West Africa",
       meta_description:
         "Emakola helps West African merchants sell online with mobile money, WhatsApp orders, and storefronts built for low-bandwidth phones.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/about"),
       json_ld: EmakolaWeb.Helpers.SEO.json_ld_organization(),
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
      id="about-scroll"
      phx-hook="ScrollReveal"
      class="min-h-screen bg-white font-body antialiased"
    >
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main>
        <.marketing_hero
          eyebrow="Our story"
          title="Building commerce for"
          highlight="West Africa"
          subtitle="Emakola gives every merchant the tools to sell online — mobile money, WhatsApp orders, and storefronts that load on any phone, on any network."
        />
        <.mission />
        <.beliefs />
        <.footprint />
        <.cta_band
          title="Want to build the future of commerce with us?"
          subtitle="We're a small team with a big mission. Come help merchants across the region grow."
          primary_label="See open roles"
          primary_href="/careers"
          secondary_label="Start selling"
          secondary_href="/auth/register"
        />
      </main>
      <.landing_footer />
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # Mission — asymmetric editorial: a sticky-feeling label column beside a
  # generous lead-paragraph column.
  # ─────────────────────────────────────────────────────────────────────
  defp mission(assigns) do
    ~H"""
    <section class="bg-white px-4 sm:px-6 py-20 lg:py-28">
      <div class="max-w-6xl mx-auto grid lg:grid-cols-[0.75fr_1.45fr] gap-10 lg:gap-20">
        <div data-reveal>
          <p class="text-xs font-semibold uppercase tracking-[0.22em] text-[#d4a843]">
            01 — Our mission
          </p>
          <div class="mt-4 h-px w-14 bg-[#d4a843]"></div>
          <h2 class="mt-6 text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] leading-[1.15]">
            Commerce, rebuilt for how West Africa actually sells.
          </h2>
        </div>

        <div class="space-y-6" data-reveal style="transition-delay: 0.12s">
          <p class="text-lg lg:text-xl text-[#3a4658] leading-relaxed font-medium">
            Across Ghana and Nigeria, millions of merchants sell on WhatsApp, in markets,
            and from their phones — but the tools built for them assume fast internet, cards,
            and addresses that don't match how commerce actually works here.
          </p>
          <p class="text-base text-[#5f6b7a] leading-relaxed">
            Emakola is online retail rebuilt for West Africa: mobile money first
            (MTN MoMo, Vodafone Cash, AirtelTigo), WhatsApp and SMS order alerts, and
            storefronts optimized for low-bandwidth devices. We handle the technology so
            merchants can focus on selling.
          </p>
          <p class="text-base text-[#5f6b7a] leading-relaxed">
            We started in Ghana and are expanding across the region, one merchant at a time.
          </p>
        </div>
      </div>
    </section>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # Beliefs — premium floating cards: ghost-number watermark, gold-gradient
  # icon tile that flips on hover, lift + shadow + gradient underline.
  # ─────────────────────────────────────────────────────────────────────
  defp beliefs(assigns) do
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
            <span class="h-px w-8 bg-[#d4a843]"></span> 02 — What we believe
          </p>
          <h2 class="mt-4 text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] leading-[1.15]">
            The principles behind every decision
          </h2>
          <p class="mt-4 text-base text-[#5f6b7a] leading-relaxed">
            Four convictions that shape every feature we ship — and every merchant we serve.
          </p>
        </div>

        <div class="mt-14 grid sm:grid-cols-2 gap-5 lg:gap-6">
          <.belief index="01" icon="smartphone" title="Mobile money first" delay="0.0s">
            Payments built around how West Africa actually pays — not cards bolted on later.
          </.belief>
          <.belief index="02" icon="bolt" title="Low-bandwidth ready" delay="0.08s">
            Fast on any phone and any network, because that's what our merchants use.
          </.belief>
          <.belief index="03" icon="storefront" title="Merchant-obsessed" delay="0.16s">
            Every decision starts with the person running the store, not the spreadsheet.
          </.belief>
          <.belief index="04" icon="public" title="Built for the region" delay="0.24s">
            Local languages, local payments, local logistics — designed for here.
          </.belief>
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

  defp belief(assigns) do
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
  # Footprint — dark band echoing the hero, the facts presented as bold
  # gold-accented tiles split by hairline dividers.
  # ─────────────────────────────────────────────────────────────────────
  defp footprint(assigns) do
    ~H"""
    <section class="relative isolate overflow-hidden bg-[#0c1526] text-[#f1f5f9] px-4 sm:px-6 py-20 lg:py-24">
      <div
        aria-hidden="true"
        class="absolute inset-0 -z-10"
        style="background: radial-gradient(46rem 26rem at 50% -20%, rgba(212,168,67,0.16), transparent 60%);"
      >
      </div>
      <div class="max-w-6xl mx-auto">
        <div class="text-center max-w-2xl mx-auto" data-reveal>
          <p class="text-xs font-semibold uppercase tracking-[0.22em] text-[#d4a843]">
            03 — Our footprint
          </p>
          <h2 class="mt-4 text-3xl lg:text-4xl font-headline font-bold">
            Live where it matters, headed where it's growing
          </h2>
        </div>

        <div class="mt-14 grid grid-cols-2 md:grid-cols-4 gap-y-10 divide-[#1a2744] md:divide-x">
          <.footprint_stat value="Ghana" label="Where we started" delay="0.0s" />
          <.footprint_stat value="Nigeria" label="Expanding next" delay="0.08s" />
          <.footprint_stat value="Mobile money" label="Payments, first-class" delay="0.16s" />
          <.footprint_stat value="WhatsApp" label="Orders & alerts" delay="0.24s" />
        </div>
      </div>
    </section>
    """
  end

  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :delay, :string, default: "0s"

  defp footprint_stat(assigns) do
    ~H"""
    <div data-reveal style={"transition-delay: #{@delay}"} class="group px-2 md:px-6 text-center">
      <p class="inline-block text-2xl lg:text-3xl font-headline font-bold text-[#d4a843]">
        {@value}
        <span class="block h-0.5 mt-1 bg-[#d4a843]/60 origin-center scale-x-0 transition-transform duration-300 ease-out group-hover:scale-x-100">
        </span>
      </p>
      <p class="mt-2 text-sm text-[#8896ab]">{@label}</p>
    </div>
    """
  end
end
