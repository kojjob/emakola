defmodule EmakolaWeb.LandingLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]

  @rotating_words ["big name in Accra", "household brand", "MoMo success story", "market leader"]

  @faqs [
    {"What is Emakola?",
     "Emakola is an ecommerce platform for West African merchants. You create an online store, accept mobile money payments, and manage orders from one dashboard."},
    {"Who can sell on Emakola?",
     "Anyone with something to sell: market traders, seamstresses and tailors, hair stylists, beauticians and cosmetics sellers, barbers, tradesmen, food vendors, and electronics shops. Themed storefronts fit each trade."},
    {"How much does Emakola cost?",
     "Emakola is free to start — you pay 3.5% per sale on the Starter plan. Paid plans start at GHS 29 per month with lower transaction rates."},
    {"Can I accept MTN MoMo and Vodafone Cash?",
     "Yes. Emakola supports MTN MoMo, Vodafone Cash, AirtelTigo, and card payments through Paystack and Hubtel."},
    {"What is dropshipping on Emakola?",
     "Dropshipping lets you sell products your suppliers hold. When an order comes in, the supplier fulfills it and Emakola tracks supplier costs and settlements automatically."},
    {"Can I sell digital products?",
     "Yes. Upload files to a product and customers get automatic download access after payment."},
    {"Do customers get order updates?",
     "Yes, automatically on WhatsApp and SMS: order confirmations, shipping updates, and delivery notifications."}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Emakola — Start Selling Online in Ghana | Mobile Money & Dropshipping",
       meta_description:
         "Create your online store in Ghana. Accept MTN MoMo and Vodafone Cash, dropship from local suppliers, and send WhatsApp order updates. Free to start.",
       og_image: "/images/og-image.png",
       twitter_card: "summary_large_image",
       canonical_url: url(~p"/"),
       preload_image: "/images/landing/hero-market-woman.jpg",
       json_ld: json_ld(),
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
      id="landing-scroll"
      phx-hook="ScrollReveal"
      class="min-h-screen bg-[#0c1526] text-[#f1f5f9] font-body antialiased"
    >
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main>
        <.hero />
        <.store_wall />
        <.feature_stories />
        <.features_grid />
        <.growth_arc />
        <.stats_band />
        <.launch_steps />
        <.faq_section />
        <.final_cta />
      </main>
      <.landing_footer />
    </div>
    """
  end

  defp hero(assigns) do
    ~H"""
    <section
      class="relative bg-cover pt-16"
      style="background-image: linear-gradient(180deg, rgba(12,21,38,0.62) 0%, rgba(12,21,38,0.80) 70%, #0c1526 100%), url('/images/landing/hero-market-woman.jpg'); background-position: center 25%;"
    >
      <div class="max-w-4xl mx-auto px-4 sm:px-6 text-center py-24 lg:py-36">
        <span class="inline-block text-xs font-semibold tracking-[0.2em] uppercase text-[#d4a843] mb-4">
          For Ghana's Merchants
        </span>
        <h1 class="text-4xl sm:text-5xl lg:text-6xl font-headline font-extrabold leading-[1.1] [text-shadow:0_2px_18px_rgba(12,21,38,0.6)]">
          Be the next<br />
          <span class="hero-rotator">
            <span class="hero-rotator-list">
              <span :for={word <- rotating_words()} class="text-[#d4a843]">{word}</span>
            </span>
          </span>
        </h1>
        <p class="text-base lg:text-lg text-[#e2e8f0] mt-6 mb-8 max-w-xl mx-auto">
          Dream big and sell fast on Emakola. Mobile money payments, WhatsApp updates,
          and a storefront built for Ghana.
        </p>
        <a
          href="/auth/register"
          class="inline-flex items-center px-8 py-4 text-base font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors focus-visible:ring-2 focus-visible:ring-[#d4a843] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
        >
          Start selling — free
        </a>
        <p class="text-xs text-[#cbd5e1] mt-4">No credit card needed</p>
      </div>
    </section>
    """
  end

  defp store_wall(assigns) do
    ~H"""
    <section class="py-16 px-4 sm:px-6" data-reveal>
      <div class="max-w-6xl mx-auto">
        <h2 class="text-center text-2xl lg:text-3xl font-headline font-bold mb-2">
          Stores built on Emakola
        </h2>
        <p class="text-center text-sm text-[#8896ab] mb-10 max-w-xl mx-auto">
          Market traders, seamstresses, hair stylists, beauticians, barbers —
          if you sell it, Emakola handles it.
        </p>
        <div class="flex gap-4 overflow-x-auto snap-x pb-4 lg:grid lg:grid-cols-3 lg:overflow-visible lg:pb-0">
          <div
            :for={{store, i} <- Enum.with_index(stores())}
            class={[
              "w-64 shrink-0 snap-start lg:w-auto bg-[#13203a] border border-[#1f2f50] rounded-2xl overflow-hidden",
              rem(i, 3) == 1 && "lg:mt-6"
            ]}
          >
            <div class="flex items-center gap-2 px-4 py-3 text-sm font-bold">
              <span class={["w-3 h-3 rounded-full", store.dot]}></span>
              {store.name}
            </div>
            <img
              src={store.img}
              alt={store.alt}
              loading="lazy"
              width="600"
              height="400"
              class="w-full h-[170px] object-cover"
            />
            <p class="px-4 py-3 text-xs font-bold text-[#d4a843]">{store.chip}</p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp feature_stories(assigns) do
    ~H"""
    <section class="bg-[#f7f8fa] py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-5xl mx-auto space-y-16 lg:space-y-24">
        <div class="flex flex-col lg:flex-row items-center gap-8 lg:gap-16" data-reveal>
          <div class="flex-1">
            <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] mb-3">
              Get paid in seconds
            </h2>
            <p class="text-base text-[#5f6b7a]">
              MTN MoMo, Vodafone Cash, AirtelTigo, and cards. The money lands before
              the customer hangs up.
            </p>
          </div>
          <div class="flex-1 relative w-full">
            <img
              src="/images/landing/story-momo.jpg"
              alt="Merchant smiling after receiving a mobile money payment"
              loading="lazy"
              width="800"
              height="533"
              class="w-full h-[240px] object-cover rounded-2xl"
            />
            <div class="absolute bottom-3 left-3 lg:-bottom-4 lg:-left-4 bg-white rounded-xl shadow-xl p-4">
              <p class="text-[10px] text-[#5f6b7a]">Payment received</p>
              <p class="text-sm font-extrabold text-[#0c1526]">+ GHS 85.00 · MoMo</p>
              <p class="text-[10px] font-bold text-[#16a34a]">✓ In your wallet</p>
            </div>
          </div>
        </div>

        <div class="flex flex-col lg:flex-row-reverse items-center gap-8 lg:gap-16" data-reveal>
          <div class="flex-1">
            <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] mb-3">
              Customers kept in the loop
            </h2>
            <p class="text-base text-[#5f6b7a]">
              Order confirmations and delivery updates sent on WhatsApp and SMS —
              no extra work for you.
            </p>
          </div>
          <div class="flex-1 relative w-full">
            <img
              src="/images/landing/story-whatsapp.jpg"
              alt="Friends checking an order update together on a laptop"
              loading="lazy"
              width="800"
              height="533"
              class="w-full h-[240px] object-cover rounded-2xl"
            />
            <div class="absolute bottom-3 right-3 lg:-bottom-4 lg:-right-4 bg-[#dcf8c6] rounded-xl rounded-br-sm shadow-xl p-3 max-w-[70%]">
              <p class="text-xs text-[#0c1526]">
                🛍️ <b>Order #1042 confirmed!</b> <br />Hi Akosua — your order ships today.
              </p>
              <p class="text-[9px] text-[#5f6b7a] mt-1 text-right">WhatsApp · automatic</p>
            </div>
          </div>
        </div>

        <div class="flex flex-col lg:flex-row items-center gap-8 lg:gap-16" data-reveal>
          <div class="flex-1">
            <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] mb-3">
              A storefront that loads fast everywhere
            </h2>
            <p class="text-base text-[#5f6b7a]">
              Built for real Ghanaian networks — light pages, lazy images, works on
              any phone.
            </p>
          </div>
          <div class="flex-1 relative w-full">
            <img
              src="/images/landing/story-storefront.jpg"
              alt="Woman in a green dress shopping at a bustling Accra market"
              loading="lazy"
              width="800"
              height="533"
              class="w-full h-[240px] object-cover rounded-2xl"
            />
            <div class="absolute top-3 right-3 bg-white rounded-xl shadow-xl px-3 py-2">
              <p class="text-[10px] text-[#5f6b7a]">🔒 amas-fashion.emakola.com</p>
              <p class="text-xs font-extrabold text-[#16a34a]">Loads in 1.2s on 3G</p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp features_grid(assigns) do
    ~H"""
    <section id="features" class="bg-white py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-6xl mx-auto">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] text-center mb-2">
          Everything you need to sell
        </h2>
        <p class="text-base text-[#5f6b7a] text-center mb-12">
          The full toolkit, built for Ghana
        </p>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          <div :for={feature <- features()} class="bg-[#f7f8fa] rounded-2xl p-6" data-reveal>
            <span class="material-symbols-outlined text-2xl text-[#d4a843] mb-3">
              {feature.icon}
            </span>
            <h3 class="text-base font-bold text-[#0c1526] mb-1">{feature.title}</h3>
            <p class="text-sm text-[#5f6b7a]">{feature.blurb}</p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp growth_arc(assigns) do
    ~H"""
    <section id="how-it-works" class="py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-6xl mx-auto">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-center mb-2">
          From first sale to household name
        </h2>
        <p class="text-base text-[#8896ab] text-center mb-12">Wherever you are, Emakola fits.</p>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
          <div class="bg-[#13203a] rounded-2xl overflow-hidden" data-reveal>
            <img
              src="/images/landing/growth-start.jpg"
              alt="Young woman smiling as she starts her first online store"
              loading="lazy"
              width="600"
              height="400"
              class="w-full h-[180px] object-cover"
            />
            <div class="p-6">
              <p class="text-xs font-extrabold tracking-widest text-[#d4a843] mb-2">START</p>
              <h3 class="text-lg font-bold mb-2">From her phone in Makola Market</h3>
              <p class="text-sm text-[#8896ab]">
                Ama listed 12 products on a Sunday. First MoMo payment by Wednesday.
              </p>
            </div>
          </div>
          <div class="bg-[#13203a] rounded-2xl overflow-hidden" data-reveal>
            <img
              src="/images/landing/growth-grow.jpg"
              alt="Shop owner in glasses managing his stores"
              loading="lazy"
              width="600"
              height="400"
              class="w-full h-[180px] object-cover"
            />
            <div class="p-6">
              <p class="text-xs font-extrabold tracking-widest text-[#d4a843] mb-2">GROW</p>
              <h3 class="text-lg font-bold mb-2">Three stores, one dashboard</h3>
              <p class="text-sm text-[#8896ab]">
                Kwame runs electronics, accessories, and repairs from a single account.
              </p>
            </div>
          </div>
          <div class="bg-[#13203a] border border-[#d4a843]/30 rounded-2xl overflow-hidden" data-reveal>
            <img
              src="/images/landing/growth-scale.jpg"
              alt="Businesswoman in an orange blazer scaling her brand nationwide"
              loading="lazy"
              width="600"
              height="400"
              class="w-full h-[180px] object-cover"
            />
            <div class="p-6">
              <p class="text-xs font-extrabold tracking-widest text-[#d4a843] mb-2">SCALE</p>
              <h3 class="text-lg font-bold mb-2">Selling across all 16 regions</h3>
              <p class="text-sm text-[#8896ab]">
                Efua's Kitchen ships nationwide with delivery zones and order tracking.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp stats_band(assigns) do
    ~H"""
    <section class="bg-[#0a1120] border-y border-[#1a2744] py-12 px-4">
      <div class="max-w-4xl mx-auto grid grid-cols-1 sm:grid-cols-3 gap-8 text-center">
        <div>
          <p class="text-4xl font-headline font-extrabold text-[#d4a843]">500+</p>
          <p class="text-sm text-[#8896ab] mt-1">merchants on Emakola</p>
        </div>
        <div>
          <p class="text-4xl font-headline font-extrabold text-[#d4a843]">3</p>
          <p class="text-sm text-[#8896ab] mt-1">mobile money networks</p>
        </div>
        <div>
          <p class="text-4xl font-headline font-extrabold text-[#d4a843]">Seconds</p>
          <p class="text-sm text-[#8896ab] mt-1">from checkout to payout</p>
        </div>
      </div>
    </section>
    """
  end

  defp launch_steps(assigns) do
    ~H"""
    <section class="bg-[#f7f8fa] py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-5xl mx-auto text-center">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] mb-2">
          Launch before lunch
        </h2>
        <p class="text-base text-[#5f6b7a] mb-12">Most merchants go live in under an hour.</p>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-5 text-left">
          <div class="bg-white rounded-2xl p-6 shadow-sm" data-reveal>
            <p class="text-2xl font-headline font-black text-[#d4a843] mb-2">01</p>
            <h3 class="text-base font-bold text-[#0c1526]">Add your first product</h3>
          </div>
          <div class="bg-white rounded-2xl p-6 shadow-sm" data-reveal>
            <p class="text-2xl font-headline font-black text-[#d4a843] mb-2">02</p>
            <h3 class="text-base font-bold text-[#0c1526]">Share your store link</h3>
          </div>
          <div class="bg-white rounded-2xl p-6 shadow-sm" data-reveal>
            <p class="text-2xl font-headline font-black text-[#d4a843] mb-2">03</p>
            <h3 class="text-base font-bold text-[#0c1526]">Get paid with MoMo</h3>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp faq_section(assigns) do
    assigns = assign(assigns, :faqs, faqs())

    ~H"""
    <section id="faq" class="bg-white py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-5xl mx-auto">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] text-center mb-12">
          Questions, answered
        </h2>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 items-start">
          <details :for={{question, answer} <- @faqs} class="group bg-[#f7f8fa] rounded-xl p-5">
            <summary class="cursor-pointer text-base font-semibold text-[#0c1526] list-none flex items-center justify-between gap-3">
              {question}
              <span class="material-symbols-outlined text-[#8896ab] group-open:rotate-180 transition-transform">
                expand_more
              </span>
            </summary>
            <p class="text-sm text-[#5f6b7a] mt-3">{answer}</p>
          </details>
        </div>
      </div>
    </section>
    """
  end

  defp final_cta(assigns) do
    ~H"""
    <section
      class="relative bg-cover py-24 px-4 text-center"
      style="background-image: linear-gradient(180deg, rgba(12,21,38,0.78), rgba(12,21,38,0.9)), url('/images/landing/cta-market.jpg'); background-position: center;"
    >
      <h2 class="text-3xl lg:text-4xl font-headline font-bold mb-8">Ready when you are</h2>
      <div class="flex flex-col sm:flex-row flex-wrap justify-center items-center gap-4">
        <a
          href="/auth/register"
          class="inline-flex items-center px-8 py-3 text-base font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors"
        >
          Start selling — free
        </a>
        <a
          href="/stores"
          class="inline-flex items-center px-8 py-3 text-base font-semibold text-[#f1f5f9] border border-[#2a3a5c] rounded-lg hover:border-[#f1f5f9] transition-colors"
        >
          Browse stores
        </a>
      </div>
    </section>
    """
  end

  defp rotating_words, do: @rotating_words
  defp faqs, do: @faqs

  defp stores do
    [
      %{
        name: "Mansa Fresh",
        dot: "bg-[#16a34a]",
        img: "/images/landing/store-fruit.jpg",
        alt: "Market woman in an orange dress arranging fruit at her stall",
        chip: "Fruit Basket · GHS 75"
      },
      %{
        name: "Yaa Braids",
        dot: "bg-[#ec4899]",
        img: "/images/landing/store-hair.jpg",
        alt: "Client smiling while having her hair styled at a salon",
        chip: "Braiding Bundle · GHS 150"
      },
      %{
        name: "Adwoa Glow",
        dot: "bg-[#9333ea]",
        img: "/images/landing/store-beauty.jpg",
        alt: "Beautician applying makeup for a client",
        chip: "Shea Glow Set · GHS 95"
      },
      %{
        name: "Efua's Kitchen",
        dot: "bg-[#2563eb]",
        img: "/images/landing/store-eggs.jpg",
        alt: "Woman selling a pyramid of fresh eggs at the market",
        chip: "Fresh Eggs · GHS 40"
      },
      %{
        name: "Kojo the Tailor",
        dot: "bg-[#d4a843]",
        img: "/images/landing/store-tailor.jpg",
        alt: "Tailor smiling as he works at his sewing machine",
        chip: "Custom Kaftan · GHS 320"
      },
      %{
        name: "Kwaku Cuts",
        dot: "bg-[#0ea5e9]",
        img: "/images/landing/store-barber.jpg",
        alt: "Barber giving a client a haircut in his shop",
        chip: "Grooming Kit · GHS 120"
      }
    ]
  end

  defp features do
    [
      %{
        icon: "warehouse",
        title: "Dropshipping & suppliers",
        blurb:
          "Sell products you don't stock — suppliers fulfill, Emakola tracks costs and settlements."
      },
      %{
        icon: "palette",
        title: "Storefront themes",
        blurb: "14 professional themes, from fashion to pharmacy. Switch anytime."
      },
      %{
        icon: "download",
        title: "Digital products",
        blurb: "Sell downloads — files delivered automatically after payment."
      },
      %{
        icon: "inventory_2",
        title: "Inventory tracking",
        blurb: "Know your stock levels across locations, always."
      },
      %{
        icon: "local_shipping",
        title: "Shipping & delivery",
        blurb: "Zones, rates, and live order tracking across Ghana."
      },
      %{
        icon: "percent",
        title: "Coupons & discounts",
        blurb: "Run promotions that bring customers back."
      },
      %{
        icon: "monitoring",
        title: "Analytics & reports",
        blurb: "See sales, customers, and trends — export PDF reports."
      },
      %{
        icon: "article",
        title: "Blog & recipes",
        blurb: "Built-in content marketing — publish posts and recipes on your store."
      },
      %{
        icon: "storefront",
        title: "Multi-store",
        blurb: "Run several stores from one account and dashboard."
      }
    ]
  end

  defp json_ld do
    base = EmakolaWeb.Endpoint.url()

    %{
      "@context" => "https://schema.org",
      "@graph" => [
        %{
          "@type" => "Organization",
          "name" => "Emakola",
          "url" => base,
          "logo" => base <> "/images/emakola-logo.svg"
        },
        %{"@type" => "WebSite", "name" => "Emakola", "url" => base},
        %{
          "@type" => "SoftwareApplication",
          "name" => "Emakola",
          "applicationCategory" => "BusinessApplication",
          "operatingSystem" => "Web",
          "description" =>
            "Ecommerce platform for West African merchants with mobile money payments, dropshipping, and WhatsApp notifications.",
          "offers" => %{"@type" => "Offer", "price" => "0", "priceCurrency" => "GHS"}
        },
        %{
          "@type" => "FAQPage",
          "mainEntity" =>
            Enum.map(@faqs, fn {q, a} ->
              %{
                "@type" => "Question",
                "name" => q,
                "acceptedAnswer" => %{"@type" => "Answer", "text" => a}
              }
            end)
        }
      ]
    }
  end
end
