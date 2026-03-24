defmodule EmakolaWeb.LandingLive do
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Emakola — Online Stores for Ghana | Accept Mobile Money",
       meta_description:
         "Launch your online store in Ghana. Accept MTN MoMo, Vodafone Cash, and card payments. WhatsApp order notifications. Join 500+ merchants on Emakola.",
       og_title: "Emakola — Sell Online in Ghana",
       og_description:
         "The easiest way to create an online store in West Africa. Mobile money payments, WhatsApp notifications, and more.",
       og_image: "/images/og-image.png",
       twitter_card: "summary_large_image",
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
      <style>
        #main-nav.scrolled {
          background-color: rgba(12, 21, 38, 0.95);
          border-bottom-color: rgba(26, 39, 68, 1);
          backdrop-filter: blur(12px);
          -webkit-backdrop-filter: blur(12px);
        }
        @keyframes slide-down {
          from { opacity: 0; transform: translateY(-10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .animate-slide-down { animation: slide-down 0.2s ease-out; }
      </style>
      
    <!-- ============================================ -->
      <!-- SECTION 1: NAVIGATION                        -->
      <!-- ============================================ -->
      <nav
        id="main-nav"
        phx-hook="ScrollGlass"
        class="fixed top-0 left-0 right-0 z-50 bg-[#0c1526]/80 backdrop-blur-md border-b border-transparent transition-all duration-300"
      >
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <!-- Logo -->
            <a href="/" class="flex items-center gap-2">
              <img src={~p"/images/logo.svg"} alt="Emakola" class="h-8 w-auto" />
              <span class="text-xl font-headline font-bold text-[#f1f5f9]">Emakola</span>
            </a>
            <!-- Desktop Nav Links -->
            <div class="hidden md:flex items-center gap-8">
              <a
                href="#features"
                class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
              >
                Features
              </a>
              <a
                href="#pricing"
                class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
              >
                Pricing
              </a>
              <a
                href="#how-it-works"
                class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
              >
                How It Works
              </a>
            </div>
            <!-- Desktop CTAs -->
            <div class="hidden md:flex items-center gap-4">
              <a
                href="/auth/login"
                class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
              >
                Login
              </a>
              <a
                href="/auth/register"
                class="inline-flex items-center px-4 py-2 text-sm font-semibold text-white bg-[#2563eb] rounded-lg hover:bg-[#1d4ed8] transition-colors focus-visible:ring-2 focus-visible:ring-[#2563eb] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
              >
                Get Started
              </a>
            </div>
            <!-- Mobile Hamburger -->
            <button
              phx-click="toggle_mobile_menu"
              class="md:hidden p-2 text-[#8896ab] hover:text-[#f1f5f9]"
              aria-label="Toggle menu"
            >
              <span class="material-symbols-outlined text-2xl">
                {if @mobile_menu_open, do: "close", else: "menu"}
              </span>
            </button>
          </div>
        </div>
        <!-- Mobile Menu Overlay -->
        <div
          :if={@mobile_menu_open}
          class="md:hidden fixed inset-0 top-16 bg-[#0c1526] z-40 flex flex-col items-center justify-start pt-12 gap-6 animate-slide-down"
        >
          <a
            href="#features"
            phx-click="toggle_mobile_menu"
            class="text-lg text-[#8896ab] hover:text-[#f1f5f9]"
          >
            Features
          </a>
          <a
            href="#pricing"
            phx-click="toggle_mobile_menu"
            class="text-lg text-[#8896ab] hover:text-[#f1f5f9]"
          >
            Pricing
          </a>
          <a
            href="#how-it-works"
            phx-click="toggle_mobile_menu"
            class="text-lg text-[#8896ab] hover:text-[#f1f5f9]"
          >
            How It Works
          </a>
          <hr class="w-24 border-[#1a2744]" />
          <a href="/auth/login" class="text-lg text-[#8896ab] hover:text-[#f1f5f9]">Login</a>
          <a
            href="/auth/register"
            class="inline-flex items-center px-6 py-3 text-base font-semibold text-white bg-[#2563eb] rounded-lg hover:bg-[#1d4ed8]"
          >
            Get Started
          </a>
        </div>
      </nav>
      
    <!-- ============================================ -->
      <!-- SECTION 2: HERO (SPLIT SCREEN)               -->
      <!-- ============================================ -->
      <section class="min-h-screen flex flex-col lg:flex-row pt-16">
        <!-- Merchant Side (Dark) -->
        <div class="flex-1 flex items-center overflow-hidden bg-gradient-to-br from-[#0c1526] to-[#1a2744]">
          <div class="max-w-lg px-8 py-20 lg:py-24 lg:px-16">
            <span class="inline-block text-xs font-semibold tracking-[0.15em] uppercase text-[#d4a843] mb-4">
              FOR MERCHANTS
            </span>
            <h1 class="text-4xl lg:text-5xl font-headline font-bold text-[#f1f5f9] leading-tight mb-4">
              Launch Your Online Store in Ghana
            </h1>
            <p class="text-base text-[#8896ab] mb-8 max-w-md">
              Accept MTN MoMo, Vodafone Cash, and card payments. Notify customers on WhatsApp.
              Manage everything from one dashboard.
            </p>
            <div class="flex flex-wrap gap-3 mb-8">
              <a
                href="/auth/register"
                class="inline-flex items-center px-6 py-3 text-sm font-semibold text-white bg-[#2563eb] rounded-lg hover:bg-[#1d4ed8] transition-colors focus-visible:ring-2 focus-visible:ring-[#2563eb] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
              >
                Start Selling
              </a>
              <a
                href="#features"
                class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#8896ab] border border-[#2a3a5c] rounded-lg hover:text-[#f1f5f9] hover:border-[#f1f5f9] transition-colors"
              >
                Watch Demo
              </a>
            </div>
            <!-- Payment Provider Badges -->
            <div class="flex flex-wrap gap-3">
              <div class="flex items-center gap-2 px-3 py-1.5 rounded-md border border-[#1a2744] bg-[#0c1526]/50 text-xs text-[#8896ab]">
                <span class="material-symbols-outlined text-base">account_balance_wallet</span>
                MTN MoMo
              </div>
              <div class="flex items-center gap-2 px-3 py-1.5 rounded-md border border-[#1a2744] bg-[#0c1526]/50 text-xs text-[#8896ab]">
                <span class="material-symbols-outlined text-base">payments</span> Vodafone Cash
              </div>
              <div class="flex items-center gap-2 px-3 py-1.5 rounded-md border border-[#1a2744] bg-[#0c1526]/50 text-xs text-[#8896ab]">
                <span class="material-symbols-outlined text-base">credit_card</span> Paystack
              </div>
              <div class="flex items-center gap-2 px-3 py-1.5 rounded-md border border-[#1a2744] bg-[#0c1526]/50 text-xs text-[#8896ab]">
                <span class="material-symbols-outlined text-base">storefront</span> Hubtel
              </div>
            </div>
          </div>
        </div>
        <!-- Shopper Side (Light) -->
        <div class="flex-1 flex items-center overflow-hidden bg-gradient-to-bl from-[#f7f8fa] to-[#e8eaed]">
          <div class="max-w-lg px-8 py-20 lg:py-24 lg:px-16">
            <span class="inline-block text-xs font-semibold tracking-[0.15em] uppercase text-[#2563eb] mb-4">
              FOR SHOPPERS
            </span>
            <h1 class="text-4xl lg:text-5xl font-headline font-bold text-[#0c1526] leading-tight mb-4">
              Shop Trusted Local Businesses
            </h1>
            <p class="text-base text-[#5f6b7a] mb-8 max-w-md">
              Pay with mobile money. Get order updates on WhatsApp. Support local merchants.
            </p>
            <a
              href="/auth/register?role=shopper"
              class="inline-flex items-center px-6 py-3 text-sm font-semibold text-white bg-[#0c1526] rounded-lg hover:bg-[#1a2744] transition-colors focus-visible:ring-2 focus-visible:ring-[#0c1526] focus-visible:ring-offset-2"
            >
              Browse Stores
            </a>
            <!-- Mini Product Cards -->
            <div class="flex gap-2.5 mt-6">
              <div class="bg-white/90 backdrop-blur-sm rounded-lg p-2 shadow-md flex-1 max-w-[120px]">
                <img
                  src={~p"/images/landing/product-kente.jpg"}
                  alt="Kente cloth"
                  class="rounded h-16 w-full object-cover mb-1.5"
                />
                <p class="text-[11px] font-semibold text-[#0c1526]">Kente Cloth</p>
                <p class="text-[11px] text-[#5f6b7a]">GHS 150</p>
              </div>
              <div class="bg-white/90 backdrop-blur-sm rounded-lg p-2 shadow-md flex-1 max-w-[120px]">
                <img
                  src={~p"/images/landing/product-shea.jpg"}
                  alt="Shea butter"
                  class="rounded h-16 w-full object-cover mb-1.5"
                />
                <p class="text-[11px] font-semibold text-[#0c1526]">Shea Butter</p>
                <p class="text-[11px] text-[#5f6b7a]">GHS 45</p>
              </div>
              <div class="bg-white/90 backdrop-blur-sm rounded-lg p-2 shadow-md flex-1 max-w-[120px] hidden sm:block">
                <img
                  src={~p"/images/landing/product-ankara.jpg"}
                  alt="Ankara dress"
                  class="rounded h-16 w-full object-cover mb-1.5"
                />
                <p class="text-[11px] font-semibold text-[#0c1526]">Ankara Dress</p>
                <p class="text-[11px] text-[#5f6b7a]">GHS 85</p>
              </div>
            </div>
          </div>
        </div>
      </section>
      
    <!-- ============================================ -->
      <!-- SECTION 3: TRUST BAR                         -->
      <!-- ============================================ -->
      <section class="bg-[#f0f1f4] py-6 px-4">
        <div class="max-w-5xl mx-auto flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-8">
          <span class="text-sm text-[#5f6b7a] font-medium whitespace-nowrap">
            Trusted by 500+ merchants across Ghana
          </span>
          <div class="flex flex-wrap items-center justify-center gap-3 sm:gap-5">
            <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#ffcb05]/10 border border-[#ffcb05]/30">
              <span class="w-2 h-2 rounded-full bg-[#ffcb05]"></span>
              <span class="text-xs font-bold text-[#3f3f46]">MTN MoMo</span>
            </span>
            <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#e60000]/10 border border-[#e60000]/30">
              <span class="w-2 h-2 rounded-full bg-[#e60000]"></span>
              <span class="text-xs font-bold text-[#3f3f46]">Vodafone Cash</span>
            </span>
            <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#0033a1]/10 border border-[#0033a1]/30">
              <span class="w-2 h-2 rounded-full bg-[#0033a1]"></span>
              <span class="text-xs font-bold text-[#3f3f46]">AirtelTigo</span>
            </span>
            <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#00c3f7]/10 border border-[#00c3f7]/30">
              <span class="w-2 h-2 rounded-full bg-[#00c3f7]"></span>
              <span class="text-xs font-bold text-[#3f3f46]">Paystack</span>
            </span>
            <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#00a651]/10 border border-[#00a651]/30">
              <span class="w-2 h-2 rounded-full bg-[#00a651]"></span>
              <span class="text-xs font-bold text-[#3f3f46]">Hubtel</span>
            </span>
          </div>
        </div>
      </section>
      
    <!-- ============================================ -->
      <!-- SECTION 4: HOW IT WORKS                      -->
      <!-- ============================================ -->
      <section id="how-it-works" class="bg-white py-20 px-4" data-reveal>
        <div class="max-w-6xl mx-auto">
          <h2 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] text-center mb-4">
            How It Works
          </h2>
          <p class="text-base text-[#5f6b7a] text-center mb-16">
            3 simple steps
          </p>

          <!-- === SELL ON EMAKOLA === -->
          <div class="mb-20" data-reveal>
            <div class="flex items-center justify-center gap-3 mb-12">
              <span class="material-symbols-outlined text-2xl text-[#d4a843]">storefront</span>
              <h3 class="text-xl font-bold text-[#0c1526]">Sell on Emakola</h3>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 lg:gap-10">
              <!-- Step 1: Sign Up -->
              <div class="group text-center" data-reveal>
                <div class="relative mb-5">
                  <div class="overflow-hidden rounded-2xl shadow-md">
                    <img
                      src={~p"/images/landing/step-sell-1.jpg"}
                      alt="Sign up on your phone"
                      class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  </div>
                  <div class="absolute -top-3 -left-3 w-12 h-12 rounded-full bg-[#d4a843] text-[#0c1526] flex items-center justify-center text-xl font-black shadow-lg">
                    1
                  </div>
                </div>
                <h4 class="text-lg font-bold text-[#0c1526] mb-1">Sign Up</h4>
                <p class="text-sm text-[#5f6b7a]">Create your free store</p>
              </div>

              <!-- Arrow connector (desktop only) -->

              <!-- Step 2: Add Products -->
              <div class="group text-center" data-reveal>
                <div class="relative mb-5">
                  <div class="overflow-hidden rounded-2xl shadow-md">
                    <img
                      src={~p"/images/landing/step-sell-2.jpg"}
                      alt="Add your products"
                      class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  </div>
                  <div class="absolute -top-3 -left-3 w-12 h-12 rounded-full bg-[#d4a843] text-[#0c1526] flex items-center justify-center text-xl font-black shadow-lg">
                    2
                  </div>
                </div>
                <h4 class="text-lg font-bold text-[#0c1526] mb-1">Add Products</h4>
                <p class="text-sm text-[#5f6b7a]">Upload photos, set prices</p>
              </div>

              <!-- Step 3: Get Paid -->
              <div class="group text-center" data-reveal>
                <div class="relative mb-5">
                  <div class="overflow-hidden rounded-2xl shadow-md">
                    <img
                      src={~p"/images/landing/step-sell-3.jpg"}
                      alt="Receive mobile money payment"
                      class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  </div>
                  <div class="absolute -top-3 -left-3 w-12 h-12 rounded-full bg-[#d4a843] text-[#0c1526] flex items-center justify-center text-xl font-black shadow-lg">
                    3
                  </div>
                </div>
                <h4 class="text-lg font-bold text-[#0c1526] mb-1">Get Paid</h4>
                <p class="text-sm text-[#5f6b7a]">Receive money via MoMo</p>
              </div>
            </div>
          </div>

          <!-- Divider -->
          <div class="flex items-center gap-4 mb-20">
            <div class="flex-1 h-px bg-[#e8eaed]"></div>
            <span class="text-xs font-semibold tracking-widest uppercase text-[#8896ab]">or</span>
            <div class="flex-1 h-px bg-[#e8eaed]"></div>
          </div>

          <!-- === BUY ON EMAKOLA === -->
          <div data-reveal>
            <div class="flex items-center justify-center gap-3 mb-12">
              <span class="material-symbols-outlined text-2xl text-[#2563eb]">shopping_bag</span>
              <h3 class="text-xl font-bold text-[#0c1526]">Buy on Emakola</h3>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 lg:gap-10">
              <!-- Step 1: Browse -->
              <div class="group text-center" data-reveal>
                <div class="relative mb-5">
                  <div class="overflow-hidden rounded-2xl shadow-md">
                    <img
                      src={~p"/images/landing/step-buy-1.jpg"}
                      alt="Browse stores on your phone"
                      class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  </div>
                  <div class="absolute -top-3 -left-3 w-12 h-12 rounded-full bg-[#2563eb] text-white flex items-center justify-center text-xl font-black shadow-lg">
                    1
                  </div>
                </div>
                <h4 class="text-lg font-bold text-[#0c1526] mb-1">Browse</h4>
                <p class="text-sm text-[#5f6b7a]">Find what you need</p>
              </div>

              <!-- Step 2: Pay with MoMo -->
              <div class="group text-center" data-reveal>
                <div class="relative mb-5">
                  <div class="overflow-hidden rounded-2xl shadow-md">
                    <img
                      src={~p"/images/landing/step-buy-2.jpg"}
                      alt="Pay with mobile money"
                      class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  </div>
                  <div class="absolute -top-3 -left-3 w-12 h-12 rounded-full bg-[#2563eb] text-white flex items-center justify-center text-xl font-black shadow-lg">
                    2
                  </div>
                </div>
                <h4 class="text-lg font-bold text-[#0c1526] mb-1">Pay with MoMo</h4>
                <p class="text-sm text-[#5f6b7a]">MTN MoMo, Vodafone Cash</p>
              </div>

              <!-- Step 3: Receive -->
              <div class="group text-center" data-reveal>
                <div class="relative mb-5">
                  <div class="overflow-hidden rounded-2xl shadow-md">
                    <img
                      src={~p"/images/landing/step-buy-3.jpg"}
                      alt="Receive your delivery"
                      class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  </div>
                  <div class="absolute -top-3 -left-3 w-12 h-12 rounded-full bg-[#2563eb] text-white flex items-center justify-center text-xl font-black shadow-lg">
                    3
                  </div>
                </div>
                <h4 class="text-lg font-bold text-[#0c1526] mb-1">Receive</h4>
                <p class="text-sm text-[#5f6b7a]">Get it delivered to you</p>
              </div>
            </div>
          </div>
        </div>
      </section>
      
    <!-- ============================================ -->
      <!-- SECTION 5: FEATURES GRID (BENTO)             -->
      <!-- ============================================ -->
      <section id="features" class="bg-[#f7f8fa] py-20 px-4" data-reveal>
        <div class="max-w-6xl mx-auto">
          <h2 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] text-center mb-4">
            Everything You Need
          </h2>
          <p class="text-base text-[#5f6b7a] text-center mb-14">
            All the tools to sell online in Ghana
          </p>

          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            <!-- Mobile Money -->
            <div class="group bg-white rounded-2xl shadow-sm hover:shadow-lg overflow-hidden transition-all" data-reveal>
              <div class="overflow-hidden">
                <img
                  src={~p"/images/landing/feature-mobile-money.jpg"}
                  alt="Mobile money payment"
                  class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                />
              </div>
              <div class="p-5">
                <div class="flex items-center gap-2 mb-2">
                  <span class="material-symbols-outlined text-xl text-[#d4a843]">account_balance_wallet</span>
                  <h3 class="text-base font-bold text-[#0c1526]">Mobile Money</h3>
                </div>
                <p class="text-sm text-[#5f6b7a]">Accept MTN MoMo, Vodafone Cash, AirtelTigo</p>
              </div>
            </div>

            <!-- WhatsApp -->
            <div class="group bg-white rounded-2xl shadow-sm hover:shadow-lg overflow-hidden transition-all" data-reveal>
              <div class="overflow-hidden">
                <img
                  src={~p"/images/landing/feature-whatsapp.jpg"}
                  alt="WhatsApp notifications"
                  class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                />
              </div>
              <div class="p-5">
                <div class="flex items-center gap-2 mb-2">
                  <span class="material-symbols-outlined text-xl text-[#25D366]">chat</span>
                  <h3 class="text-base font-bold text-[#0c1526]">WhatsApp Notifications</h3>
                </div>
                <p class="text-sm text-[#5f6b7a]">Order updates sent to customers</p>
              </div>
            </div>

            <!-- Dashboard -->
            <div class="group bg-white rounded-2xl shadow-sm hover:shadow-lg overflow-hidden transition-all" data-reveal>
              <div class="overflow-hidden">
                <img
                  src={~p"/images/landing/feature-dashboard.jpg"}
                  alt="Merchant dashboard"
                  class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                />
              </div>
              <div class="p-5">
                <div class="flex items-center gap-2 mb-2">
                  <span class="material-symbols-outlined text-xl text-[#2563eb]">dashboard</span>
                  <h3 class="text-base font-bold text-[#0c1526]">Merchant Dashboard</h3>
                </div>
                <p class="text-sm text-[#5f6b7a]">See your sales, orders, customers</p>
              </div>
            </div>

            <!-- Multi-Store -->
            <div class="group bg-white rounded-2xl shadow-sm hover:shadow-lg overflow-hidden transition-all" data-reveal>
              <div class="overflow-hidden">
                <img
                  src={~p"/images/landing/feature-multi-store.jpg"}
                  alt="Multiple stores"
                  class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                />
              </div>
              <div class="p-5">
                <div class="flex items-center gap-2 mb-2">
                  <span class="material-symbols-outlined text-xl text-[#2563eb]">store</span>
                  <h3 class="text-base font-bold text-[#0c1526]">Multi-Store Management</h3>
                </div>
                <p class="text-sm text-[#5f6b7a]">Run many stores from one account</p>
              </div>
            </div>

            <!-- Inventory -->
            <div class="group bg-white rounded-2xl shadow-sm hover:shadow-lg overflow-hidden transition-all" data-reveal>
              <div class="overflow-hidden">
                <img
                  src={~p"/images/landing/feature-inventory.jpg"}
                  alt="Inventory tracking"
                  class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                />
              </div>
              <div class="p-5">
                <div class="flex items-center gap-2 mb-2">
                  <span class="material-symbols-outlined text-xl text-[#2563eb]">inventory_2</span>
                  <h3 class="text-base font-bold text-[#0c1526]">Inventory Tracking</h3>
                </div>
                <p class="text-sm text-[#5f6b7a]">Know your stock levels always</p>
              </div>
            </div>

            <!-- Shipping -->
            <div class="group bg-white rounded-2xl shadow-sm hover:shadow-lg overflow-hidden transition-all" data-reveal>
              <div class="overflow-hidden">
                <img
                  src={~p"/images/landing/feature-shipping.jpg"}
                  alt="Shipping and delivery"
                  class="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                />
              </div>
              <div class="p-5">
                <div class="flex items-center gap-2 mb-2">
                  <span class="material-symbols-outlined text-xl text-[#2563eb]">local_shipping</span>
                  <h3 class="text-base font-bold text-[#0c1526]">Shipping & Delivery</h3>
                </div>
                <p class="text-sm text-[#5f6b7a]">Deliver across Ghana</p>
              </div>
            </div>
          </div>
        </div>
      </section>
      
    <!-- ============================================ -->
      <!-- SECTION 6: PRICING                           -->
      <!-- ============================================ -->
      <section id="pricing" class="bg-white py-20 px-4" data-reveal>
        <div class="max-w-5xl mx-auto">
          <h2 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] text-center mb-4">
            Simple, Transparent Pricing
          </h2>
          <p class="text-base text-[#5f6b7a] text-center mb-12 max-w-2xl mx-auto">
            All plans include SSL, mobile money payments, and basic analytics.
          </p>

          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <!-- Starter -->
            <div class="bg-[#f7f8fa] rounded-xl shadow-sm p-6 flex flex-col" data-reveal>
              <h3 class="text-lg font-semibold text-[#0c1526] mb-1">Starter</h3>
              <div class="flex items-baseline gap-1 mb-1">
                <span class="text-3xl font-bold text-[#0c1526]">Free</span>
              </div>
              <p class="text-sm text-[#d4a843] font-medium mb-6">3.5% per sale</p>
              <ul class="space-y-2 mb-8 flex-1">
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                  1 store
                </li>
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                  25 products
                </li>
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                  Basic dashboard
                </li>
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
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
            
    <!-- Growth -->
            <div class="bg-[#f7f8fa] rounded-xl shadow-sm p-6 flex flex-col" data-reveal>
              <h3 class="text-lg font-semibold text-[#0c1526] mb-1">Growth</h3>
              <div class="flex items-baseline gap-1 mb-1">
                <span class="text-3xl font-bold text-[#0c1526]">GHS 29</span>
                <span class="text-sm text-[#5f6b7a]">/mo</span>
              </div>
              <p class="text-sm text-[#d4a843] font-medium mb-6">2.0% per sale</p>
              <ul class="space-y-2 mb-8 flex-1">
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                  1 store
                </li>
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                  250 products
                </li>
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                  WhatsApp notifications
                </li>
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
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
            
    <!-- Pro (Highlighted) -->
            <div
              class="bg-[#0c1526] rounded-xl shadow-lg shadow-[#d4a843]/20 ring-1 ring-[#d4a843]/40 p-6 flex flex-col relative"
              data-reveal
            >
              <span class="absolute -top-3 left-1/2 -translate-x-1/2 bg-[#d4a843] text-[#0c1526] text-xs font-bold px-3 py-0.5 rounded-full">
                Most Popular
              </span>
              <h3 class="text-lg font-semibold text-[#f1f5f9] mb-1">Pro</h3>
              <div class="flex items-baseline gap-1 mb-1">
                <span class="text-3xl font-bold text-[#f1f5f9]">GHS 79</span>
                <span class="text-sm text-[#8896ab]">/mo</span>
              </div>
              <p class="text-sm text-[#d4a843] font-medium mb-6">1.2% per sale</p>
              <ul class="space-y-2 mb-8 flex-1">
                <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                  <span class="material-symbols-outlined text-base text-[#d4a843] mt-0.5">check</span>
                  3 stores
                </li>
                <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                  <span class="material-symbols-outlined text-base text-[#d4a843] mt-0.5">check</span>
                  Unlimited products
                </li>
                <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                  <span class="material-symbols-outlined text-base text-[#d4a843] mt-0.5">check</span>
                  Custom domain
                </li>
                <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                  <span class="material-symbols-outlined text-base text-[#d4a843] mt-0.5">check</span>
                  Analytics
                </li>
                <li class="flex items-start gap-2 text-sm text-[#8896ab]">
                  <span class="material-symbols-outlined text-base text-[#d4a843] mt-0.5">check</span>
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
            
    <!-- Enterprise -->
            <div class="bg-[#f7f8fa] rounded-xl shadow-sm p-6 flex flex-col" data-reveal>
              <h3 class="text-lg font-semibold text-[#0c1526] mb-1">Enterprise</h3>
              <div class="flex items-baseline gap-1 mb-1">
                <span class="text-3xl font-bold text-[#0c1526]">Custom</span>
              </div>
              <p class="text-sm text-[#d4a843] font-medium mb-6">Custom rate</p>
              <ul class="space-y-2 mb-8 flex-1">
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                  Unlimited stores
                </li>
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                  Dedicated account manager
                </li>
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                  SLA
                </li>
                <li class="flex items-start gap-2 text-sm text-[#5f6b7a]">
                  <span class="material-symbols-outlined text-base text-[#2563eb] mt-0.5">check</span>
                  API access
                </li>
              </ul>
              <a
                href="mailto:sales@emakola.com"
                class="block text-center px-4 py-2.5 text-sm font-semibold text-[#0c1526] bg-[#f0f1f4] rounded-lg hover:bg-[#e8eaed] transition-colors"
              >
                Contact Sales
              </a>
            </div>
          </div>
        </div>
      </section>
      
    <!-- ============================================ -->
      <!-- SECTION 7: TESTIMONIALS                      -->
      <!-- ============================================ -->
      <section class="bg-[#0c1526] py-20 px-4" data-reveal>
        <div class="max-w-6xl mx-auto">
          <div class="text-center mb-14">
            <span class="inline-block text-xs font-semibold tracking-[0.15em] uppercase text-[#d4a843] mb-3">
              Testimonials
            </span>
            <h2 class="text-3xl lg:text-4xl font-headline font-bold text-[#f1f5f9] mb-3">
              Trusted by Merchants Across Ghana
            </h2>
            <p class="text-base text-[#8896ab]">Real stories from real merchants</p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            <!-- Testimonial 1 - Featured (larger) -->
            <div class="md:row-span-2 bg-gradient-to-br from-[#1a2744] to-[#0c1526] rounded-2xl p-6 flex flex-col" data-reveal>
              <div class="flex gap-0.5 mb-4">
                <svg :for={_i <- 1..5} class="w-4 h-4 text-[#d4a843] fill-current" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
              </div>
              <p class="text-base text-[#e2e8f0] leading-relaxed flex-1 mb-6">
                "Emakola made it so easy to start selling online. My customers love paying with MoMo and I get instant notifications on every order. My sales have doubled since I moved online. I never thought ecommerce would be this simple."
              </p>
              <div class="flex items-center gap-3">
                <img src={~p"/images/landing/testimonial-1.jpg"} alt="Ama Mensah" class="w-12 h-12 rounded-full object-cover ring-2 ring-[#d4a843]" />
                <div>
                  <p class="text-sm font-bold text-[#f1f5f9]">Ama Mensah</p>
                  <p class="text-xs text-[#8896ab]">Ama's Fashion, Accra</p>
                </div>
              </div>
            </div>

            <!-- Testimonial 2 -->
            <div class="bg-white rounded-2xl p-5 shadow-sm" data-reveal>
              <div class="flex gap-0.5 mb-3">
                <svg :for={_i <- 1..5} class="w-3.5 h-3.5 text-[#d4a843] fill-current" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
              </div>
              <p class="text-sm text-[#5f6b7a] leading-relaxed mb-4">
                "I run three stores on Emakola. Managing all of them from one dashboard saves me hours every week."
              </p>
              <div class="flex items-center gap-3">
                <img src={~p"/images/landing/testimonial-2.jpg"} alt="Kwame Asante" class="w-10 h-10 rounded-full object-cover" />
                <div>
                  <p class="text-sm font-semibold text-[#0c1526]">Kwame Asante</p>
                  <p class="text-xs text-[#8896ab]">TechHub GH, Kumasi</p>
                </div>
              </div>
            </div>

            <!-- Testimonial 3 -->
            <div class="bg-white rounded-2xl p-5 shadow-sm" data-reveal>
              <div class="flex gap-0.5 mb-3">
                <svg :for={_i <- 1..5} class="w-3.5 h-3.5 text-[#d4a843] fill-current" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
              </div>
              <p class="text-sm text-[#5f6b7a] leading-relaxed mb-4">
                "As a food vendor, I needed something simple. My customers in Takoradi can now order from home."
              </p>
              <div class="flex items-center gap-3">
                <img src={~p"/images/landing/testimonial-3.jpg"} alt="Efua Owusu" class="w-10 h-10 rounded-full object-cover" />
                <div>
                  <p class="text-sm font-semibold text-[#0c1526]">Efua Owusu</p>
                  <p class="text-xs text-[#8896ab]">Efua's Kitchen, Takoradi</p>
                </div>
              </div>
            </div>

            <!-- Testimonial 4 -->
            <div class="bg-white rounded-2xl p-5 shadow-sm" data-reveal>
              <div class="flex gap-0.5 mb-3">
                <svg :for={_i <- 1..5} class="w-3.5 h-3.5 text-[#d4a843] fill-current" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
              </div>
              <p class="text-sm text-[#5f6b7a] leading-relaxed mb-4">
                "The WhatsApp notifications changed everything. My customers feel confident because they know exactly when their order ships."
              </p>
              <div class="flex items-center gap-3">
                <img src={~p"/images/landing/testimonial-4.jpg"} alt="Kofi Mensah" class="w-10 h-10 rounded-full object-cover" />
                <div>
                  <p class="text-sm font-semibold text-[#0c1526]">Kofi Mensah</p>
                  <p class="text-xs text-[#8896ab]">Kofi Electronics, Cape Coast</p>
                </div>
              </div>
            </div>

            <!-- Testimonial 5 -->
            <div class="bg-white rounded-2xl p-5 shadow-sm" data-reveal>
              <div class="flex gap-0.5 mb-3">
                <svg :for={_i <- 1..5} class="w-3.5 h-3.5 text-[#d4a843] fill-current" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
              </div>
              <p class="text-sm text-[#5f6b7a] leading-relaxed mb-4">
                "I was scared of technology. But Emakola is so simple even I can use it. Now I sell my beads and jewelry to people all over Ghana."
              </p>
              <div class="flex items-center gap-3">
                <img src={~p"/images/landing/testimonial-5.jpg"} alt="Abena Darko" class="w-10 h-10 rounded-full object-cover" />
                <div>
                  <p class="text-sm font-semibold text-[#0c1526]">Abena Darko</p>
                  <p class="text-xs text-[#8896ab]">Abena Beads, Koforidua</p>
                </div>
              </div>
            </div>

            <!-- Testimonial 6 -->
            <div class="bg-gradient-to-br from-[#1a2744] to-[#0c1526] rounded-2xl p-5" data-reveal>
              <div class="flex gap-0.5 mb-3">
                <svg :for={_i <- 1..5} class="w-3.5 h-3.5 text-[#d4a843] fill-current" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
              </div>
              <p class="text-sm text-[#e2e8f0] leading-relaxed mb-4">
                "Mobile money integration is seamless. My customers pay with MoMo and I see it instantly on my dashboard. No more chasing payments."
              </p>
              <div class="flex items-center gap-3">
                <img src={~p"/images/landing/testimonial-6.jpg"} alt="Yaw Boateng" class="w-10 h-10 rounded-full object-cover ring-2 ring-[#d4a843]" />
                <div>
                  <p class="text-sm font-bold text-[#f1f5f9]">Yaw Boateng</p>
                  <p class="text-xs text-[#8896ab]">YB Auto Parts, Tamale</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
      
    <!-- ============================================ -->
      <!-- SECTION 8: FINAL CTA + FOOTER                -->
      <!-- ============================================ -->
      <section class="bg-gradient-to-b from-[#0c1526] to-[#1a2744] py-20 px-4" data-reveal>
        <div class="max-w-3xl mx-auto text-center">
          <h2 class="text-3xl lg:text-4xl font-headline font-bold text-[#f1f5f9] mb-4">
            Ready to Grow Your Business?
          </h2>
          <p class="text-base text-[#8896ab] mb-8">
            Join 500+ merchants selling online across Ghana
          </p>
          <div class="flex flex-wrap justify-center gap-4">
            <a
              href="/auth/register"
              class="inline-flex items-center px-8 py-3 text-base font-semibold text-white bg-[#2563eb] rounded-lg hover:bg-[#1d4ed8] transition-colors focus-visible:ring-2 focus-visible:ring-[#2563eb] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
            >
              Start Selling
            </a>
            <a
              href="/auth/register?role=shopper"
              class="inline-flex items-center px-8 py-3 text-base font-semibold text-[#8896ab] border border-[#2a3a5c] rounded-lg hover:text-[#f1f5f9] hover:border-[#f1f5f9] transition-colors"
            >
              Browse Stores
            </a>
          </div>
        </div>
      </section>
      
    <!-- Footer -->
      <footer class="bg-[#0c1526] border-t border-[#1a2744] py-12 px-4">
        <div class="max-w-5xl mx-auto">
          <div class="grid grid-cols-2 md:grid-cols-4 gap-8 mb-10">
            <!-- Product -->
            <div>
              <h4 class="text-sm font-semibold text-[#f1f5f9] mb-4">Product</h4>
              <ul class="space-y-2">
                <li>
                  <a
                    href="#features"
                    class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
                  >
                    Features
                  </a>
                </li>
                <li>
                  <a
                    href="#pricing"
                    class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
                  >
                    Pricing
                  </a>
                </li>
                <li>
                  <a
                    href="#features"
                    class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
                  >
                    Demo
                  </a>
                </li>
                <li>
                  <a
                    href="/docs"
                    class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
                  >
                    API
                  </a>
                </li>
              </ul>
            </div>
            <!-- Resources -->
            <div>
              <h4 class="text-sm font-semibold text-[#f1f5f9] mb-4">Resources</h4>
              <ul class="space-y-2">
                <li>
                  <a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Help Center
                  </a>
                </li>
                <li>
                  <a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Blog
                  </a>
                </li>
                <li>
                  <a
                    href="/docs"
                    class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
                  >
                    Developer Docs
                  </a>
                </li>
                <li>
                  <a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Status
                  </a>
                </li>
              </ul>
            </div>
            <!-- Company -->
            <div>
              <h4 class="text-sm font-semibold text-[#f1f5f9] mb-4">Company</h4>
              <ul class="space-y-2">
                <li>
                  <a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    About
                  </a>
                </li>
                <li>
                  <a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Careers
                  </a>
                </li>
                <li>
                  <a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Press
                  </a>
                </li>
                <li>
                  <a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Contact
                  </a>
                </li>
              </ul>
            </div>
            <!-- Legal -->
            <div>
              <h4 class="text-sm font-semibold text-[#f1f5f9] mb-4">Legal</h4>
              <ul class="space-y-2">
                <li>
                  <a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Privacy Policy
                  </a>
                </li>
                <li>
                  <a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Terms of Service
                  </a>
                </li>
                <li>
                  <a href="#" class="text-sm text-[#8896ab] hover:text-[#f1f5f9] transition-colors">
                    Cookie Policy
                  </a>
                </li>
              </ul>
            </div>
          </div>
          <!-- Bottom Bar -->
          <div class="border-t border-[#1a2744] pt-6 flex flex-col sm:flex-row items-center justify-between gap-4">
            <p class="text-sm text-[#8896ab]">
              &copy; {DateTime.utc_now().year} Emakola. All rights reserved.
            </p>
            <div class="flex items-center gap-4">
              <!-- Twitter/X -->
              <a
                href="#"
                class="text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
                aria-label="Twitter"
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                </svg>
              </a>
              <!-- LinkedIn -->
              <a
                href="#"
                class="text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
                aria-label="LinkedIn"
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
                </svg>
              </a>
              <!-- GitHub -->
              <a
                href="#"
                class="text-[#8896ab] hover:text-[#f1f5f9] transition-colors"
                aria-label="GitHub"
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
                </svg>
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
    """
  end
end
