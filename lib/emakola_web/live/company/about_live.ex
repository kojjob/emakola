defmodule EmakolaWeb.Company.AboutLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "About — Emakola | Commerce for West Africa",
       meta_description:
         "Emakola helps West African merchants sell online with mobile money, WhatsApp orders, and storefronts built for low-bandwidth phones.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/about"),
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
            <h2 class="text-2xl font-headline font-bold text-[#0c1526] text-center mb-10">
              What we believe
            </h2>
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
      </main>
      <.landing_footer />
    </div>
    """
  end
end
