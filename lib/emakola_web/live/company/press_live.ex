defmodule EmakolaWeb.Company.PressLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Press — Emakola",
       meta_description:
         "Press resources, brand assets, and media contact for Emakola — the commerce platform for West African merchants.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/press"),
       mobile_menu_open: false,
       press_email: Application.get_env(:emakola, :press_email, "press@emakola.com")
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
      id="press-scroll"
      phx-hook="ScrollReveal"
      class="min-h-screen bg-white font-body antialiased"
    >
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main>
        <.hero />
        <.about />
        <.facts />
        <.assets />
        <.media_enquiries press_email={@press_email} />
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
          <span class="w-1.5 h-1.5 rounded-full bg-[#d4a843] animate-pulse"></span> Press &amp; media
        </span>
        <h1
          class="about-rise mt-7 text-4xl sm:text-5xl lg:text-6xl font-headline font-extrabold leading-[1.08] [text-shadow:0_2px_20px_rgba(12,21,38,0.55)]"
          style="animation-delay: 0.12s"
        >
          Press
          <span class="relative whitespace-nowrap text-[#d4a843]">
            resources
            <svg
              aria-hidden="true"
              viewBox="0 0 220 14"
              preserveAspectRatio="none"
              class="absolute -bottom-2 left-0 w-full h-2.5 text-[#d4a843]/70"
            >
              <path
                class="about-underline"
                d="M2 9 C 55 3, 110 3, 150 7 S 205 11, 218 5"
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
          Everything you need to write about Emakola. For interviews or anything else,
          reach out below.
        </p>
      </div>
    </section>
    """
  end

  # ── About / boilerplate ───────────────────────────────────────────────
  defp about(assigns) do
    ~H"""
    <section class="bg-white px-4 sm:px-6 py-20 lg:py-28">
      <div class="max-w-6xl mx-auto grid lg:grid-cols-[0.75fr_1.45fr] gap-10 lg:gap-20">
        <div data-reveal>
          <p class="text-xs font-semibold uppercase tracking-[0.22em] text-[#d4a843]">
            01 — About Emakola
          </p>
          <div class="mt-4 h-px w-14 bg-[#d4a843]"></div>
          <h2 class="mt-6 text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] leading-[1.15]">
            Shopify, localized for West Africa.
          </h2>
        </div>

        <div class="space-y-6" data-reveal style="transition-delay: 0.12s">
          <div class="rounded-2xl border border-slate-200 bg-[#f8fafc] p-6">
            <p class="text-xs font-semibold uppercase tracking-wider text-[#d4a843] mb-2">
              Short version
            </p>
            <p class="text-base text-[#3a4658] leading-relaxed">
              Emakola is a multi-tenant commerce platform for West Africa — Shopify localized
              for the region, with mobile money payments and WhatsApp order alerts.
            </p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-[#f8fafc] p-6">
            <p class="text-xs font-semibold uppercase tracking-wider text-[#d4a843] mb-2">
              Long version
            </p>
            <p class="text-base text-[#5f6b7a] leading-relaxed">
              Emakola lets merchants in Ghana and Nigeria launch online stores built for how
              commerce actually works here: mobile money first (MTN MoMo, Vodafone Cash,
              AirtelTigo), local payment gateways (Paystack, Hubtel), WhatsApp and SMS
              notifications, and storefronts optimized for low-bandwidth phones.
            </p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ── Key facts ─────────────────────────────────────────────────────────
  defp facts(assigns) do
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
            <span class="h-px w-8 bg-[#d4a843]"></span> 02 — Key facts
          </p>
          <h2 class="mt-4 text-3xl lg:text-4xl font-headline font-bold text-[#0c1526]">
            The essentials, at a glance
          </h2>
        </div>

        <div class="mt-12 grid sm:grid-cols-2 gap-5 lg:gap-6">
          <.fact icon="storefront" label="What" delay="0.0s">
            Online store platform for West African merchants
          </.fact>
          <.fact icon="public" label="Markets" delay="0.08s">
            Ghana today, Nigeria next
          </.fact>
          <.fact icon="payments" label="Payments" delay="0.16s">
            Mobile money, Paystack, Hubtel
          </.fact>
          <.fact icon="chat" label="Notifications" delay="0.24s">
            WhatsApp &amp; SMS
          </.fact>
        </div>
      </div>
    </section>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :delay, :string, default: "0s"
  slot :inner_block, required: true

  defp fact(assigns) do
    ~H"""
    <div
      data-reveal
      style={"transition-delay: #{@delay}"}
      class="group flex items-center gap-4 rounded-2xl border border-slate-200/80 bg-white p-6 shadow-sm transition-all duration-300 hover:-translate-y-1 hover:border-[#d4a843]/40 hover:shadow-lg hover:shadow-[#0c1526]/[0.05]"
    >
      <span class="inline-flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-[#0c1526] text-[#d4a843] transition-transform duration-300 group-hover:scale-105">
        <span class="material-symbols-outlined text-2xl">{@icon}</span>
      </span>
      <div>
        <p class="text-xs font-semibold uppercase tracking-wider text-[#8896ab]">{@label}</p>
        <p class="mt-0.5 text-base font-medium text-[#0c1526]">{render_slot(@inner_block)}</p>
      </div>
    </div>
    """
  end

  # ── Brand assets ──────────────────────────────────────────────────────
  defp assets(assigns) do
    ~H"""
    <section class="bg-white px-4 sm:px-6 py-20 lg:py-28">
      <div class="max-w-6xl mx-auto">
        <div class="max-w-2xl" data-reveal>
          <p class="inline-flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.22em] text-[#d4a843]">
            <span class="h-px w-8 bg-[#d4a843]"></span> 03 — Brand assets
          </p>
          <h2 class="mt-4 text-3xl lg:text-4xl font-headline font-bold text-[#0c1526]">
            Logos &amp; social card
          </h2>
        </div>

        <div class="mt-12 grid sm:grid-cols-2 gap-5 lg:gap-6">
          <.asset_card
            href="/images/emakola-logo.svg"
            title="Logo"
            subtitle="SVG · vector"
            delay="0.0s"
          />
          <.asset_card
            href="/images/og-image.png"
            title="Social card"
            subtitle="PNG · 1200×630"
            delay="0.08s"
          />
        </div>
      </div>
    </section>
    """
  end

  attr :href, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :delay, :string, default: "0s"

  defp asset_card(assigns) do
    ~H"""
    <a
      href={@href}
      download
      data-reveal
      style={"transition-delay: #{@delay}"}
      class="group flex items-center gap-4 rounded-3xl border border-slate-200/80 bg-white p-6 lg:p-7 shadow-sm transition-all duration-300 hover:-translate-y-1 hover:border-[#d4a843]/50 hover:shadow-xl hover:shadow-[#0c1526]/[0.06]"
    >
      <span class="inline-flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-[#d4a843]/12 text-[#d4a843] transition-transform duration-300 group-hover:scale-105">
        <span class="material-symbols-outlined text-2xl">image</span>
      </span>
      <div class="min-w-0 flex-1">
        <p class="text-base font-headline font-semibold text-[#0c1526]">{@title}</p>
        <p class="text-sm text-[#8896ab]">{@subtitle}</p>
      </div>
      <span class="inline-flex items-center gap-1 text-sm font-semibold text-[#c49a3a]">
        <span class="material-symbols-outlined text-lg transition-transform duration-200 group-hover:translate-y-0.5">
          download
        </span>
      </span>
    </a>
    """
  end

  # ── Media enquiries (closing band) ────────────────────────────────────
  attr :press_email, :string, required: true

  defp media_enquiries(assigns) do
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
          <span class="material-symbols-outlined text-2xl">campaign</span>
        </span>

        <h2 class="mt-6 text-2xl lg:text-3xl font-headline font-bold text-[#f1f5f9]">
          Media enquiries
        </h2>
        <p class="mt-3 text-[#8896ab] max-w-xl mx-auto leading-relaxed">
          For interviews, quotes, or more information, get in touch and we'll respond quickly.
        </p>

        <a
          href={"mailto:" <> @press_email}
          class="group mt-8 inline-flex items-center gap-2 px-6 py-3.5 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-xl shadow-lg shadow-[#d4a843]/25 transition-all duration-200 hover:bg-[#c49a3a] hover:-translate-y-0.5 focus-visible:ring-2 focus-visible:ring-[#d4a843] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
        >
          <span class="material-symbols-outlined text-lg">mail</span> Email {@press_email}
        </a>
      </div>
    </section>
    """
  end
end
