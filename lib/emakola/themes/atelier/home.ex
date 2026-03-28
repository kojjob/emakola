defmodule Emakola.Themes.Atelier.Home do
  @moduledoc """
  Atelier theme home page renderer — Stitch design reference.

  Sections (gated by `@theme.sections`):
  - Hero: Full-screen image bg, bold sans-serif heading, green CTAs
  - Categories: Horizontal scrolling circles
  - Products: Featured hero card + 2 smaller cards
  - Trust: Secure commerce section with payment partners
  - Newsletter: Email signup "Join the Artisan Circle"
  - Footer: Dark bg with store info and links
  """
  use Phoenix.Component

  import Phoenix.HTML, only: [raw: 1]

  alias Emakola.Themes.Atelier.Shared

  @doc """
  Renders the full Atelier home page.

  Required assigns:
  - `@store` - Store struct
  - `@theme` - Theme config map with `:sections` map
  - `@products` - List of products
  - `@categories` - List of categories
  - `@cart_count` - Integer cart count
  """
  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :products, :list, default: []
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    ~H"""
    <div class="atelier-body">
      <Shared.theme_styles theme={@theme} />
      <Shared.navbar
        store={@store}
        categories={@categories}
        cart_count={@cart_count}
        transparent={true}
      />

      <%!-- Hero Section (negative margin to pull under transparent navbar) --%>
      <.hero_section :if={section_enabled?(@theme, :hero)} store={@store} theme={@theme} />

      <%!-- Category Circles --%>
      <.categories_section
        :if={section_enabled?(@theme, :categories) && @categories != []}
        store={@store}
        categories={@categories}
      />

      <%!-- Featured Products --%>
      <.products_section
        :if={section_enabled?(@theme, :featured_products) && @products != []}
        store={@store}
        products={@products}
      />

      <%!-- Trust / Payment Section --%>
      <.trust_section :if={section_enabled?(@theme, :trust)} store={@store} theme={@theme} />

      <%!-- Newsletter --%>
      <.newsletter_section :if={section_enabled?(@theme, :newsletter)} store={@store} theme={@theme} />

      <%!-- Footer --%>
      <Shared.footer
        store={@store}
        categories={@categories}
        theme={@theme}
        hide_newsletter={section_enabled?(@theme, :newsletter)}
      />
    </div>
    """
  end

  # ── Hero Section ──

  attr :store, :map, required: true
  attr :theme, :map, required: true

  @default_hero_image "https://images.unsplash.com/photo-1590735213920-68192a487bc2?w=1600&h=900&fit=crop&q=80"

  defp hero_section(assigns) do
    hero_images = get_in(assigns.theme, [:hero, :images]) || []
    hero_image = get_in(assigns.theme, [:hero, :image_url])
    hero_carousel = get_in(assigns.theme, [:hero, :carousel]) || false

    effective_images =
      case hero_images do
        [_ | _] -> hero_images
        _ when hero_image not in [nil, ""] -> [hero_image]
        _ -> [@default_hero_image]
      end

    use_carousel = hero_carousel && length(effective_images) > 1
    image_count = length(effective_images)
    total_duration = image_count * 7

    hero_subtitle = get_in(assigns.theme, [:hero, :subtitle]) || "The 2024 Collection"
    hero_title = get_in(assigns.theme, [:hero, :title]) || "Crafting Trust,\nCurating Excellence."

    hero_description =
      get_in(assigns.theme, [:hero, :description]) ||
        "Experience the soul of West African craftsmanship. Every piece tells a story of heritage, precision, and modern elegance."

    cta_text = get_in(assigns.theme, [:hero, :cta_text]) || "Explore Masterpieces"

    cta_secondary_text =
      get_in(assigns.theme, [:hero, :cta_secondary_text]) || "Meet the Artisans"

    assigns =
      assigns
      |> assign(:effective_images, effective_images)
      |> assign(:use_carousel, use_carousel)
      |> assign(:image_count, image_count)
      |> assign(:total_duration, total_duration)
      |> assign(:hero_subtitle, hero_subtitle)
      |> assign(:hero_title, hero_title)
      |> assign(:hero_description, hero_description)
      |> assign(:cta_text, cta_text)
      |> assign(:cta_secondary_text, cta_secondary_text)

    ~H"""
    <section class="relative min-h-screen flex items-end overflow-hidden -mt-16 sm:-mt-20">
      <%!-- Image container: clip-path prevents Ken Burns zoom from overflowing --%>
      <div class="absolute inset-0 overflow-hidden" style="clip-path: inset(0);">
        <%!-- Carousel — smooth crossfade with subtle Ken Burns zoom --%>
        <%= if @use_carousel do %>
          <% # Each slide owns (100 / N)% of the timeline.
          # Fade overlap = 4% so there is NEVER a blank frame.
          pct = Float.round(100.0 / @image_count, 2)
          overlap = 4.0 %>
          <style>
            @keyframes atelier-slide {
              0%                                 { opacity: 0; transform: scale(1); }
              <%= overlap %>%                    { opacity: 1; transform: scale(1.005); }
              <%= Float.round(pct - overlap, 1) %>% { opacity: 1; transform: scale(1.04); }
              <%= pct %>%                        { opacity: 0; transform: scale(1.04); }
              100%                               { opacity: 0; transform: scale(1); }
            }
            .atelier-hero-img {
              will-change: opacity, transform;
              animation: atelier-slide <%= @total_duration %>s ease-in-out infinite;
            }
            @keyframes atelier-progress {
              0%   { transform: scaleX(0); transform-origin: left; }
              92%  { transform: scaleX(1); transform-origin: left; }
              100% { transform: scaleX(1); transform-origin: left; }
            }
          </style>
          <%!--
          Stagger each image by (total / N) seconds, but start the NEXT
          image's fade-in slightly BEFORE the current one fades out.
          This creates the overlap that prevents blank frames.
        --%>
          <img
            :for={{url, idx} <- Enum.with_index(@effective_images)}
            src={url}
            alt={"#{@store.name} collection #{idx + 1}"}
            class="atelier-hero-img absolute inset-0 w-full h-full object-cover object-center"
            style={"animation-delay: #{Float.round(idx * @total_duration / @image_count - (if idx > 0, do: @total_duration * overlap / 100, else: 0), 1)}s; opacity: #{if idx == 0, do: 1, else: 0};"}
          />
        <% else %>
          <%!-- Single image: gentle Ken Burns drift --%>
          <img
            src={List.first(@effective_images)}
            alt={"#{@store.name} collection"}
            class="absolute inset-0 w-full h-full object-cover object-center"
            style="animation: kb-single 20s ease-in-out infinite alternate;"
          />
          <style>
            @keyframes kb-single {
              0%   { transform: scale(1)    translate(0, 0); }
              100% { transform: scale(1.06) translate(-1%, -0.5%); }
            }
          </style>
        <% end %>

        <%!-- Scrim: two-layer overlay guarantees text contrast on ANY image (dark or light) --%>
        <div class="absolute inset-0 bg-black/30"></div>
        <div class="absolute inset-0 bg-gradient-to-t from-black/75 via-black/30 to-transparent">
        </div>
      </div>
      <%!-- /Image container --%>

      <%!-- Content --%>
      <div
        class="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full pb-16 sm:pb-24 pt-32"
        style="text-shadow: 0 1px 3px rgba(0,0,0,0.4);"
      >
        <div class="max-w-3xl">
          <%!-- Badge --%>
          <span
            class="inline-block px-4 py-1.5 rounded-full text-xs font-semibold tracking-wider uppercase mb-6 text-white"
            style="background: var(--theme-primary); text-shadow: none;"
          >
            {@hero_subtitle}
          </span>

          <%!-- Heading --%>
          <h1
            class="text-5xl sm:text-6xl md:text-7xl lg:text-8xl font-black text-white leading-[1.02] mb-6 tracking-tight"
            style="text-shadow: 0 2px 8px rgba(0,0,0,0.5);"
          >
            {raw(String.replace(@hero_title, "\n", "<br>"))}
          </h1>

          <%!-- Description --%>
          <p
            class="text-base sm:text-lg text-white max-w-xl leading-relaxed mb-8"
            style="text-shadow: 0 1px 4px rgba(0,0,0,0.6);"
          >
            {@hero_description}
          </p>

          <%!-- CTA Buttons --%>
          <div class="flex flex-col sm:flex-row gap-4">
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center justify-center gap-2 px-8 py-4 text-sm font-bold uppercase tracking-wider rounded-lg text-white transition-all duration-300 hover:opacity-90 min-h-[48px]"
              style="background: var(--theme-primary);"
            >
              {@cta_text}
              <svg
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </a>
            <a
              href={"/s/#{@store.slug}/about"}
              class="inline-flex items-center justify-center px-8 py-4 text-sm font-bold uppercase tracking-wider rounded-lg text-white border-2 border-white/40 hover:bg-white/10 transition-all duration-300 min-h-[48px]"
            >
              {@cta_secondary_text}
            </a>
          </div>
        </div>

        <%!-- Carousel Progress Indicators --%>
        <div :if={@use_carousel} class="flex gap-3 mt-10">
          <span
            :for={idx <- 0..(@image_count - 1)}
            class="relative h-1 rounded-full overflow-hidden"
            style={"width: #{max(32, 80 / @image_count)}px; background: rgba(255,255,255,0.25);"}
          >
            <span
              class="absolute inset-0 rounded-full"
              style={"background: white; animation: atelier-progress #{@total_duration / @image_count}s ease-in-out infinite #{idx * (@total_duration / @image_count)}s;"}
            >
            </span>
          </span>
        </div>
      </div>
    </section>
    """
  end

  # ── Categories Section ──

  attr :store, :map, required: true
  attr :categories, :list, required: true

  defp categories_section(assigns) do
    ~H"""
    <section class="py-12 sm:py-16">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <%!-- Horizontal scrolling category circles --%>
        <div class="flex gap-6 sm:gap-8 overflow-x-auto pb-4 scrollbar-hide -mx-4 px-4 sm:mx-0 sm:px-0 sm:justify-center sm:flex-wrap">
          <Shared.category_circle
            :for={category <- @categories}
            category={category}
            store={@store}
          />
        </div>
      </div>
    </section>
    """
  end

  # ── Featured Products Section ──

  attr :store, :map, required: true
  attr :products, :list, required: true

  defp products_section(assigns) do
    hero_product = List.first(assigns.products)
    smaller_products = assigns.products |> Enum.drop(1) |> Enum.take(2)

    assigns =
      assigns
      |> assign(:hero_product, hero_product)
      |> assign(:smaller_products, smaller_products)

    ~H"""
    <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24">
      <%!-- Section Header --%>
      <div class="flex items-center justify-between mb-8 sm:mb-12">
        <h2 class="text-2xl sm:text-3xl lg:text-4xl font-black text-gray-900">
          Featured Masterpieces
        </h2>
        <a
          href={"/s/#{@store.slug}/products"}
          class="text-sm font-semibold transition-colors hover:opacity-80"
          style="color: var(--theme-primary);"
        >
          View all &rarr;
        </a>
      </div>

      <%!-- Grid: Hero card on left, 2 smaller on right --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Hero Product Card --%>
        <div :if={@hero_product}>
          <Shared.hero_product_card product={@hero_product} store={@store} />
        </div>

        <%!-- Two smaller cards stacked --%>
        <div class="grid grid-cols-2 gap-4 sm:gap-6">
          <Shared.product_card
            :for={product <- @smaller_products}
            product={product}
            store={@store}
          />
        </div>
      </div>

      <%!-- Extra products row --%>
      <div
        :if={length(@products) > 3}
        class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6 mt-8"
      >
        <Shared.product_card
          :for={product <- Enum.drop(@products, 3) |> Enum.take(4)}
          product={product}
          store={@store}
        />
      </div>
    </section>
    """
  end

  # ── Trust / Payment Section ──

  attr :store, :map, required: true
  attr :theme, :map, required: true

  defp trust_section(assigns) do
    ~H"""
    <section
      id="trust-section"
      class="relative py-20 sm:py-28 bg-[#FAFAF9] overflow-hidden"
      phx-hook="ScrollReveal"
    >
      <%!-- Soft ambient orbs --%>
      <div class="absolute top-10 right-[10%] w-[500px] h-[500px] rounded-full bg-[#B45309]/[0.03] blur-[120px] animate-[drift_20s_ease-in-out_infinite]">
      </div>
      <div class="absolute bottom-10 left-[5%] w-[400px] h-[400px] rounded-full bg-[#B45309]/[0.02] blur-[100px] animate-[drift_25s_ease-in-out_infinite_reverse]">
      </div>

      <div class="relative max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <%!-- Header --%>
        <div class="text-center mb-16 sm:mb-20 reveal-up">
          <div class="inline-flex items-center gap-2 bg-[#B45309]/8 border border-[#B45309]/15 rounded-full px-4 py-1.5 mb-6 animate-[shimmer-light_3s_ease-in-out_infinite]">
            <svg
              class="w-3.5 h-3.5 text-[#B45309] animate-[pulse-glow_2s_ease-in-out_infinite]"
              fill="currentColor"
              viewBox="0 0 24 24"
            >
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
            </svg>
            <span class="text-xs font-semibold tracking-wider uppercase text-[#B45309]">
              Trusted Payments
            </span>
          </div>
          <h2 class="font-serif text-3xl sm:text-4xl lg:text-5xl font-semibold text-[#1C1917] tracking-tight mb-4">
            Every purchase, protected.
          </h2>
          <p class="text-[#78716C] text-base sm:text-lg max-w-xl mx-auto leading-relaxed">
            Bank-level security meets the payment methods you already use every day.
          </p>
        </div>

        <%!-- Feature Grid --%>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-5 sm:gap-6 mb-16">
          <%!-- Card 1: Security --%>
          <div class="bg-white rounded-2xl p-8 sm:p-10 border border-[#E7E5E4] group relative overflow-hidden reveal-up reveal-delay-1 cursor-default hover:shadow-xl hover:shadow-[#B45309]/[0.06] hover:-translate-y-1 transition-all duration-500">
            <%!-- Top accent line --%>
            <div class="absolute top-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-[#B45309]/30 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500">
            </div>
            <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#B45309]/10 to-[#B45309]/5 border border-[#B45309]/15 flex items-center justify-center mb-6 group-hover:scale-110 group-hover:from-[#B45309]/15 group-hover:border-[#B45309]/30 transition-all duration-300">
              <svg
                class="w-7 h-7 text-[#B45309] group-hover:scale-105 transition-transform duration-300"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
                />
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-[#1C1917] mb-2">
              End-to-end encrypted
            </h3>
            <p class="text-sm text-[#78716C] leading-relaxed">
              256-bit SSL encryption on every transaction. Payment details never touch our servers.
            </p>
          </div>

          <%!-- Card 2: Speed --%>
          <div class="bg-white rounded-2xl p-8 sm:p-10 border border-[#E7E5E4] group relative overflow-hidden reveal-up reveal-delay-2 cursor-default hover:shadow-xl hover:shadow-[#B45309]/[0.06] hover:-translate-y-1 transition-all duration-500">
            <div class="absolute top-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-[#B45309]/30 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500">
            </div>
            <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#B45309]/10 to-[#B45309]/5 border border-[#B45309]/15 flex items-center justify-center mb-6 group-hover:scale-110 group-hover:from-[#B45309]/15 group-hover:border-[#B45309]/30 transition-all duration-300">
              <svg
                class="w-7 h-7 text-[#B45309] group-hover:scale-105 transition-transform duration-300"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z"
                />
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-[#1C1917] mb-2">
              Confirmed in seconds
            </h3>
            <p class="text-sm text-[#78716C] leading-relaxed">
              Real-time payment verification. Instant order confirmation via SMS and WhatsApp.
            </p>
          </div>

          <%!-- Card 3: Mobile Money --%>
          <div class="bg-white rounded-2xl p-8 sm:p-10 border border-[#E7E5E4] group relative overflow-hidden reveal-up reveal-delay-3 cursor-default hover:shadow-xl hover:shadow-[#B45309]/[0.06] hover:-translate-y-1 transition-all duration-500">
            <div class="absolute top-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-[#B45309]/30 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500">
            </div>
            <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#B45309]/10 to-[#B45309]/5 border border-[#B45309]/15 flex items-center justify-center mb-6 group-hover:scale-110 group-hover:from-[#B45309]/15 group-hover:border-[#B45309]/30 transition-all duration-300">
              <svg
                class="w-7 h-7 text-[#B45309] group-hover:scale-105 transition-transform duration-300"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"
                />
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-[#1C1917] mb-2">
              Pay your way
            </h3>
            <p class="text-sm text-[#78716C] leading-relaxed">
              MTN MoMo, Telecel Cash, Visa, or Mastercard. The payment methods Ghanaians trust most.
            </p>
          </div>
        </div>

        <%!-- Payment Methods Visual --%>
        <div class="flex flex-col items-center reveal-up reveal-delay-4">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#A8A29E] mb-5">
            Accepted Payments
          </p>
          <div class="flex items-center gap-3 sm:gap-4">
            <div class="flex items-center gap-2 bg-white border border-[#E7E5E4] rounded-xl px-4 py-2.5 shadow-sm hover:border-[#FBBF24]/50 hover:shadow-md hover:shadow-[#FBBF24]/10 transition-all duration-300 cursor-default">
              <div class="w-2 h-2 rounded-full bg-[#FBBF24] animate-[pulse-dot_2s_ease-in-out_infinite]">
              </div>
              <span class="text-xs font-semibold text-[#44403C]">MTN MoMo</span>
            </div>
            <div class="flex items-center gap-2 bg-white border border-[#E7E5E4] rounded-xl px-4 py-2.5 shadow-sm hover:border-[#EF4444]/50 hover:shadow-md hover:shadow-[#EF4444]/10 transition-all duration-300 cursor-default">
              <div class="w-2 h-2 rounded-full bg-[#EF4444] animate-[pulse-dot_2s_ease-in-out_infinite_0.3s]">
              </div>
              <span class="text-xs font-semibold text-[#44403C]">Telecel Cash</span>
            </div>
            <div class="flex items-center gap-2 bg-white border border-[#E7E5E4] rounded-xl px-4 py-2.5 shadow-sm hover:border-[#3B82F6]/50 hover:shadow-md hover:shadow-[#3B82F6]/10 transition-all duration-300 cursor-default">
              <div class="w-2 h-2 rounded-full bg-[#3B82F6] animate-[pulse-dot_2s_ease-in-out_infinite_0.6s]">
              </div>
              <span class="text-xs font-semibold text-[#44403C]">Visa</span>
            </div>
            <div class="hidden sm:flex items-center gap-2 bg-white border border-[#E7E5E4] rounded-xl px-4 py-2.5 shadow-sm hover:border-[#F97316]/50 hover:shadow-md hover:shadow-[#F97316]/10 transition-all duration-300 cursor-default">
              <div class="w-2 h-2 rounded-full bg-[#F97316] animate-[pulse-dot_2s_ease-in-out_infinite_0.9s]">
              </div>
              <span class="text-xs font-semibold text-[#44403C]">Mastercard</span>
            </div>
          </div>
        </div>
      </div>

      <style>
        @keyframes drift {
          0%, 100% { transform: translate(0, 0); }
          25% { transform: translate(30px, -20px); }
          50% { transform: translate(-20px, 15px); }
          75% { transform: translate(15px, 25px); }
        }
        @keyframes pulse-glow {
          0%, 100% { opacity: 1; filter: drop-shadow(0 0 0 transparent); }
          50% { opacity: 0.7; filter: drop-shadow(0 0 6px rgba(180,83,9,0.4)); }
        }
        @keyframes pulse-dot {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.5; transform: scale(0.75); }
        }
        @keyframes shimmer-light {
          0%, 100% { box-shadow: 0 0 0 0 rgba(180,83,9,0); }
          50% { box-shadow: 0 0 16px 3px rgba(180,83,9,0.08); }
        }

        .reveal-up {
          opacity: 0;
          transform: translateY(30px);
          transition: opacity 0.7s ease-out, transform 0.7s ease-out;
        }
        .reveal-up.revealed {
          opacity: 1;
          transform: translateY(0);
        }
        .reveal-delay-1 { transition-delay: 0.1s; }
        .reveal-delay-2 { transition-delay: 0.2s; }
        .reveal-delay-3 { transition-delay: 0.3s; }
        .reveal-delay-4 { transition-delay: 0.4s; }
      </style>
    </section>
    """
  end

  # ── Newsletter Section ──

  attr :store, :map, required: true
  attr :theme, :map, required: true

  defp newsletter_section(assigns) do
    newsletter_config = get_in(assigns.theme, [:newsletter]) || %{}

    nl_heading =
      Map.get(newsletter_config, :heading, "Join the Artisan Circle.")

    nl_description =
      Map.get(
        newsletter_config,
        :description,
        "Be the first to discover new artisan collections, exclusive offers, and stories from the makers."
      )

    nl_button_text =
      Map.get(newsletter_config, :button_text, "Join Now")

    nl_placeholder =
      Map.get(newsletter_config, :placeholder, "Enter your email")

    nl_disclaimer =
      Map.get(newsletter_config, :disclaimer, "No spam. Unsubscribe anytime.")

    assigns =
      assigns
      |> assign(:nl_heading, nl_heading)
      |> assign(:nl_description, nl_description)
      |> assign(:nl_button_text, nl_button_text)
      |> assign(:nl_placeholder, nl_placeholder)
      |> assign(:nl_disclaimer, nl_disclaimer)

    ~H"""
    <section class="bg-white">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <div class="max-w-xl mx-auto text-center">
          <h2 class="text-3xl sm:text-4xl lg:text-5xl font-black text-gray-900 mb-4">
            {@nl_heading}
          </h2>
          <p class="text-gray-600 text-base sm:text-lg leading-relaxed mb-8">
            {@nl_description}
          </p>
          <form class="flex flex-col sm:flex-row gap-3 mb-4" phx-submit="subscribe_newsletter">
            <label for="newsletter-email" class="sr-only">Email address</label>
            <input
              id="newsletter-email"
              type="email"
              name="email"
              placeholder={@nl_placeholder}
              required
              class="flex-1 px-5 py-3.5 bg-gray-100 rounded-lg text-sm text-gray-900 placeholder-gray-500 focus:outline-none focus:ring-2 transition-shadow duration-200 border-0 min-h-[48px]"
              style="--tw-ring-color: var(--theme-primary);"
            />
            <button
              type="submit"
              class="cursor-pointer px-8 py-3.5 text-sm font-bold uppercase tracking-wider rounded-lg text-white transition-all duration-200 hover:opacity-90 whitespace-nowrap min-h-[48px]"
              style="background: var(--theme-primary);"
            >
              {@nl_button_text}
            </button>
          </form>
          <p class="text-xs text-gray-400">
            {@nl_disclaimer}
          </p>
        </div>
      </div>
    </section>
    """
  end

  # ── Helpers ──

  defp section_enabled?(theme, section_name) do
    case get_in(theme, [:sections, section_name]) do
      false -> false
      _ -> true
    end
  end
end
