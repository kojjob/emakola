defmodule EmakolaWeb.PricingLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Pricing — Makola | Free to Start, Pay as You Grow",
       meta_description:
         "Makola pricing: start free with 3.5% per sale, or grow with plans from GHS 29/month. Mobile money payments and WhatsApp notifications on every plan.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/pricing"),
       json_ld: pricing_json_ld()
     ), layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant={:plain}>
      <div class="min-h-screen bg-white font-body antialiased">
        <.landing_nav />
        <main class="pt-16">
          <section class="py-20 px-4">
            <div class="max-w-5xl mx-auto">
              <h1 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] text-center mb-4">
                Simple, Transparent Pricing
              </h1>
              <p class="text-base text-[#5f6b7a] text-center mb-12 max-w-2xl mx-auto">
                All plans include SSL, mobile money payments, and basic analytics.
              </p>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <%!-- Starter --%>
                <div class="bg-[#f7f8fa] rounded-xl shadow-sm p-6 flex flex-col">
                  <h2 class="text-lg font-semibold text-[#0c1526] mb-1">Starter</h2>
                  <div class="flex items-baseline gap-1 mb-1">
                    <span class="text-3xl font-bold text-[#0c1526]">Free</span>
                  </div>
                  <p class="text-sm text-[#d4a843] font-medium mb-6">3.5% per sale</p>
                  <span class="inline-block text-[10px] font-semibold text-[#2563eb] bg-[#2563eb]/10 px-2 py-0.5 rounded-full mt-1">
                    No credit card needed
                  </span>
                  <ul class="space-y-2 mb-8 flex-1">
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      1 store
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      25 products
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      Basic dashboard
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      Email support
                    </li>
                  </ul>
                  <a
                    href="/auth/register"
                    class="block text-center px-4 py-2.5 text-sm font-semibold text-[#0c1526] bg-[#f0f1f4] rounded-lg hover:bg-[#e8eaed] transition-colors"
                  >
                    Get Started
                  </a>
                </div>
                <%!-- Growth --%>
                <div class="bg-[#f7f8fa] rounded-xl shadow-sm p-6 flex flex-col">
                  <h2 class="text-lg font-semibold text-[#0c1526] mb-1">Growth</h2>
                  <div class="flex items-baseline gap-1 mb-1">
                    <span class="text-3xl font-bold text-[#0c1526]">GHS 29</span>
                    <span class="text-sm text-[#5f6b7a]">/mo</span>
                  </div>
                  <p class="text-sm text-[#d4a843] font-medium mb-6">2.0% per sale</p>
                  <ul class="space-y-2 mb-8 flex-1">
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      1 store
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      250 products
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      WhatsApp notifications
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      Priority support
                    </li>
                  </ul>
                  <a
                    href="/auth/register"
                    class="block text-center px-4 py-2.5 text-sm font-semibold text-[#0c1526] bg-[#f0f1f4] rounded-lg hover:bg-[#e8eaed] transition-colors"
                  >
                    Get Started
                  </a>
                </div>
                <%!-- Pro (Highlighted) --%>
                <div class="bg-[#0c1526] rounded-xl shadow-lg shadow-[#d4a843]/20 ring-1 ring-[#d4a843]/40 p-6 flex flex-col relative">
                  <span class="absolute -top-3 left-1/2 -translate-x-1/2 bg-[#d4a843] text-[#0c1526] text-xs font-bold px-3 py-0.5 rounded-full">
                    Most Popular
                  </span>
                  <h2 class="text-lg font-semibold text-[#f1f5f9] mb-1">Pro</h2>
                  <div class="flex items-baseline gap-1 mb-1">
                    <span class="text-3xl font-bold text-[#f1f5f9]">GHS 79</span>
                    <span class="text-sm text-[#8896ab]">/mo</span>
                  </div>
                  <p class="text-sm text-[#d4a843] font-medium mb-6">1.2% per sale</p>
                  <ul class="space-y-2 mb-8 flex-1">
                    <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                      <span
                        class="material-symbols-outlined text-base text-[#d4a843] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      3 stores
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                      <span
                        class="material-symbols-outlined text-base text-[#d4a843] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      Unlimited products
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                      <span
                        class="material-symbols-outlined text-base text-[#d4a843] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      Custom domain
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                      <span
                        class="material-symbols-outlined text-base text-[#d4a843] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      Analytics
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                      <span
                        class="material-symbols-outlined text-base text-[#d4a843] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      Phone support
                    </li>
                  </ul>
                  <a
                    href="/auth/register"
                    class="block text-center px-4 py-2.5 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors"
                  >
                    Get Started
                  </a>
                </div>
                <%!-- Enterprise --%>
                <div class="bg-[#f7f8fa] rounded-xl shadow-sm p-6 flex flex-col">
                  <h2 class="text-lg font-semibold text-[#0c1526] mb-1">Enterprise</h2>
                  <div class="flex items-baseline gap-1 mb-1">
                    <span class="text-3xl font-bold text-[#0c1526]">Custom</span>
                  </div>
                  <p class="text-sm text-[#d4a843] font-medium mb-6">Custom rate</p>
                  <ul class="space-y-2 mb-8 flex-1">
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      Unlimited stores
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      Dedicated account manager
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      SLA
                    </li>
                    <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                      <span
                        class="material-symbols-outlined text-base text-[#2563eb] mt-0.5"
                        aria-hidden="true"
                      >
                        check
                      </span>
                      API access
                    </li>
                  </ul>
                  <a
                    href="mailto:sales@makola.io"
                    class="block text-center px-4 py-2.5 text-sm font-semibold text-[#0c1526] bg-[#f0f1f4] rounded-lg hover:bg-[#e8eaed] transition-colors"
                  >
                    Contact Sales
                  </a>
                </div>
              </div>
            </div>
          </section>
        </main>
        <.landing_footer />
      </div>
    </Layouts.app>
    """
  end

  defp pricing_json_ld do
    %{
      "@context" => "https://schema.org",
      "@type" => "SoftwareApplication",
      "name" => "Makola",
      "applicationCategory" => "BusinessApplication",
      "operatingSystem" => "Web",
      "offers" => [
        %{"@type" => "Offer", "name" => "Starter", "price" => "0", "priceCurrency" => "GHS"},
        %{"@type" => "Offer", "name" => "Growth", "price" => "29", "priceCurrency" => "GHS"},
        %{"@type" => "Offer", "name" => "Pro", "price" => "79", "priceCurrency" => "GHS"},
        %{
          "@type" => "Offer",
          "name" => "Enterprise",
          "priceCurrency" => "GHS",
          "description" => "Custom pricing"
        }
      ]
    }
  end
end
