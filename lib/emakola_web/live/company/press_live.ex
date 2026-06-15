defmodule EmakolaWeb.Company.PressLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents

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
       press_email: Application.get_env(:emakola, :press_email)
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
              <li>
                <strong class="text-[#0c1526]">What:</strong>
                Online store platform for West African merchants
              </li>
              <li>
                <strong class="text-[#0c1526]">Markets:</strong> Ghana today, Nigeria next
              </li>
              <li>
                <strong class="text-[#0c1526]">Payments:</strong> Mobile money, Paystack, Hubtel
              </li>
              <li>
                <strong class="text-[#0c1526]">Notifications:</strong> WhatsApp &amp; SMS
              </li>
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
            <p class="text-[#5f6b7a] mb-6">
              For interviews, quotes, or more information, get in touch.
            </p>
            <a
              href={"mailto:" <> @press_email}
              class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors"
            >
              Email {@press_email}
            </a>
          </div>
        </section>
      </main>
      <.landing_footer />
    </div>
    """
  end
end
