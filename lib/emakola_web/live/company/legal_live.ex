defmodule EmakolaWeb.Company.LegalLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents

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
    <div class="min-h-screen bg-white font-body antialiased">
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main class="pt-16">
        <.page_hero
          eyebrow="Legal"
          title="Legal & policies"
          subtitle="The agreements and policies that govern how Emakola works."
        />

        <section class="px-4 py-12">
          <div class="max-w-4xl mx-auto grid grid-cols-1 sm:grid-cols-3 gap-4">
            <a
              href="/privacy"
              class="p-6 rounded-2xl border border-slate-200 hover:border-[#d4a843] hover:shadow-md transition-all"
            >
              <h2 class="text-lg font-headline font-semibold text-[#0c1526] mb-1">
                Privacy Policy
              </h2>
              <p class="text-sm text-[#5f6b7a]">How we collect, use, and protect data.</p>
            </a>
            <a
              href="/terms"
              class="p-6 rounded-2xl border border-slate-200 hover:border-[#d4a843] hover:shadow-md transition-all"
            >
              <h2 class="text-lg font-headline font-semibold text-[#0c1526] mb-1">
                Terms of Service
              </h2>
              <p class="text-sm text-[#5f6b7a]">The rules for using Emakola.</p>
            </a>
            <a
              href="/cookies"
              class="p-6 rounded-2xl border border-slate-200 hover:border-[#d4a843] hover:shadow-md transition-all"
            >
              <h2 class="text-lg font-headline font-semibold text-[#0c1526] mb-1">
                Cookie Policy
              </h2>
              <p class="text-sm text-[#5f6b7a]">How and why we use cookies.</p>
            </a>
          </div>
        </section>
      </main>
      <.landing_footer />
    </div>
    """
  end
end
