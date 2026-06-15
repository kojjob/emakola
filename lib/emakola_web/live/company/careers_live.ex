defmodule EmakolaWeb.Company.CareersLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents

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
    <div class="min-h-screen bg-white font-body antialiased">
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main class="pt-16">
        <.page_hero
          eyebrow="Careers"
          title="Help merchants across West Africa grow"
          subtitle="We're building the commerce platform the region deserves. If that excites you, we'd love to meet you."
        />

        <section class="px-4 py-12">
          <div class="max-w-3xl mx-auto">
            <h2 class="text-2xl font-headline font-bold text-[#0c1526] mb-4">Life at Emakola</h2>
            <p class="text-[#5f6b7a] leading-relaxed mb-4">
              We're a small, focused team that ships. We care about merchants, sweat the
              details on low-bandwidth performance, and make decisions close to the people
              we serve. You'll have real ownership and see your work in merchants' hands fast.
            </p>
          </div>
        </section>

        <section class="px-4 py-12 bg-[#f8fafc]">
          <div class="max-w-4xl mx-auto">
            <h2 class="text-2xl font-headline font-bold text-[#0c1526] text-center mb-10">
              Why work here
            </h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <.benefit_item icon="public" title="Real impact">
                Your work helps real merchants earn a living across Ghana and Nigeria.
              </.benefit_item>
              <.benefit_item icon="rocket_launch" title="Ownership">
                Small team, big surface area. You'll lead, not wait for permission.
              </.benefit_item>
              <.benefit_item icon="laptop_mac" title="Remote-friendly">
                Work from wherever you do your best thinking, with flexible hours.
              </.benefit_item>
              <.benefit_item icon="school" title="Grow fast">
                Ship across the whole stack and learn from a team that loves the craft.
              </.benefit_item>
            </div>
          </div>
        </section>

        <section class="px-4 py-16">
          <div class="max-w-2xl mx-auto text-center rounded-2xl border border-slate-200 p-8">
            <h2 class="text-xl font-headline font-bold text-[#0c1526] mb-2">
              No open roles right now
            </h2>
            <p class="text-[#5f6b7a] mb-6">
              We're not actively hiring at the moment — but we're always glad to hear from
              great people. Send us your CV and a note about what you'd want to work on.
            </p>
            <a
              href={"mailto:" <> @careers_email}
              class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors"
            >
              Email {@careers_email}
            </a>
          </div>
        </section>
      </main>
      <.landing_footer />
    </div>
    """
  end
end
