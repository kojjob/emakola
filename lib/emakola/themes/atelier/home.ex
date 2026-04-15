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
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Phoenix.LiveView.JS
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

      <%!-- Announcement / Coupon Bar --%>
      <.announcement_bar
        public_coupons={assigns[:public_coupons] || []}
        store={@store}
      />

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

      <%!-- New Arrivals --%>
      <.trending_section
        :if={section_enabled?(@theme, :featured_products) && length(@products) > 3}
        store={@store}
        products={@products}
      />

      <%!-- Trust / Payment Section --%>
      <.trust_section :if={section_enabled?(@theme, :trust)} store={@store} theme={@theme} />

      <%!-- Delivery Zones --%>
      <.delivery_zones_bar delivery_zones={assigns[:delivery_zones] || []} />

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

  defp hero_section(assigns) do
    assigns = prepare_hero_assigns(assigns)

    ~H"""
    <section class="relative min-h-screen flex items-end overflow-hidden -mt-16 sm:-mt-20">
      <%!-- Background: images with Ken Burns, or solid gradient fallback --%>
      <div class="absolute inset-0 overflow-hidden" style="clip-path: inset(0);">
        <%= if @has_images do %>
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
            <.optimized_image
              :for={{url, idx} <- Enum.with_index(@valid_images)}
              src={url}
              alt={"#{@store.name} collection #{idx + 1}"}
              priority={if idx == 0, do: :high, else: :auto}
              class="atelier-hero-img absolute inset-0 w-full h-full object-cover object-center"
              style={"animation-delay: #{Float.round(idx * @total_duration / @image_count - (if idx > 0, do: @total_duration * overlap / 100, else: 0), 1)}s; opacity: #{if idx == 0, do: 1, else: 0};"}
            />
          <% else %>
            <%!-- Single image: gentle Ken Burns drift --%>
            <.optimized_image
              src={List.first(@valid_images)}
              alt={"#{@store.name} collection"}
              priority={:high}
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

          <%!-- Scrim: two-layer overlay guarantees text contrast on ANY image --%>
          <div class="absolute inset-0 bg-black/30"></div>
          <div class="absolute inset-0 bg-gradient-to-t from-black/75 via-black/30 to-transparent">
          </div>
        <% else %>
          <%!-- Gradient fallback when no valid hero images exist --%>
          <div
            class="absolute inset-0"
            style="background: linear-gradient(135deg, #1C1917 0%, #292524 40%, #44403C 70%, #B45309 100%);"
          >
          </div>
          <%!-- Subtle pattern overlay for visual texture --%>
          <div
            class="absolute inset-0 opacity-10"
            style="background-image: radial-gradient(circle at 25% 25%, white 1px, transparent 1px), radial-gradient(circle at 75% 75%, white 1px, transparent 1px); background-size: 60px 60px;"
          >
          </div>
        <% end %>
      </div>

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

  @category_colors [
    {"from-[#B45309]/10 to-[#92400E]/5", "text-[#B45309]", "bg-[#B45309]"},
    {"from-[#7C3AED]/10 to-[#6D28D9]/5", "text-[#7C3AED]", "bg-[#7C3AED]"},
    {"from-[#059669]/10 to-[#047857]/5", "text-[#059669]", "bg-[#059669]"},
    {"from-[#DC2626]/10 to-[#B91C1C]/5", "text-[#DC2626]", "bg-[#DC2626]"},
    {"from-[#2563EB]/10 to-[#1D4ED8]/5", "text-[#2563EB]", "bg-[#2563EB]"}
  ]

  defp categories_section(assigns) do
    categories_with_colors =
      assigns.categories
      |> Enum.with_index()
      |> Enum.map(fn {cat, idx} ->
        {grad, text_color, dot_color} =
          Enum.at(@category_colors, rem(idx, length(@category_colors)))

        %{category: cat, gradient: grad, text_color: text_color, dot_color: dot_color}
      end)

    assigns = assign(assigns, :categories_with_colors, categories_with_colors)

    ~H"""
    <section class="py-10 sm:py-14">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between mb-6 sm:mb-8">
          <h2 class="font-serif text-xl sm:text-2xl font-semibold text-[#1C1917]">
            Shop by Category
          </h2>
          <a
            href={"/s/#{@store.slug}/products"}
            class="text-xs sm:text-sm font-medium text-[#A8A29E] hover:text-[#1C1917] transition-colors"
          >
            Browse all
          </a>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-4">
          <a
            :for={item <- @categories_with_colors}
            href={"/s/#{@store.slug}/category/#{item.category.slug}"}
            class={"group relative overflow-hidden rounded-2xl bg-gradient-to-br #{item.gradient} border border-[#E7E5E4] p-6 sm:p-8 hover:shadow-lg hover:-translate-y-0.5 transition-all duration-300 cursor-pointer"}
          >
            <%!-- Decorative accent --%>
            <div class={"absolute top-0 right-0 w-24 h-24 rounded-full #{item.dot_color} opacity-[0.04] -translate-y-8 translate-x-8 group-hover:opacity-[0.08] transition-opacity"}>
            </div>

            <%!-- Icon circle --%>
            <div class="w-12 h-12 rounded-xl bg-white/80 border border-white flex items-center justify-center mb-4 shadow-sm group-hover:scale-110 transition-transform duration-300">
              <span class={"text-lg font-bold #{item.text_color}"}>
                {String.first(item.category.name)}
              </span>
            </div>

            <%!-- Category name --%>
            <h3 class="text-base sm:text-lg font-semibold text-[#1C1917] mb-1">
              {item.category.name}
            </h3>

            <%!-- Arrow indicator --%>
            <div class="flex items-center gap-1 mt-2">
              <span class="text-xs font-medium text-[#A8A29E] group-hover:text-[#1C1917] transition-colors">
                Explore
              </span>
              <svg
                class="w-3.5 h-3.5 text-[#A8A29E] group-hover:text-[#1C1917] group-hover:translate-x-0.5 transition-all"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </div>
          </a>
        </div>
      </div>
    </section>
    """
  end

  # ── Featured Products Section ──

  attr :store, :map, required: true
  attr :products, :list, required: true

  defp products_section(assigns) do
    hero = List.first(assigns.products)
    grid_products = assigns.products |> Enum.drop(1) |> Enum.take(4)

    assigns =
      assigns
      |> assign(:hero, hero)
      |> assign(:grid_products, grid_products)

    ~H"""
    <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24">
      <%!-- Section Header --%>
      <div class="flex items-center justify-between mb-8 sm:mb-10">
        <div>
          <h2 class="font-serif text-2xl sm:text-3xl font-semibold text-[#1C1917]">
            Featured Masterpieces
          </h2>
          <p class="text-sm text-[#A8A29E] mt-1 hidden sm:block">Handpicked by our artisans</p>
        </div>
        <a
          href={"/s/#{@store.slug}/products"}
          class="group inline-flex items-center gap-1.5 text-sm font-semibold transition-colors hover:opacity-80"
          style="color: var(--theme-primary);"
        >
          View all
          <svg
            class="w-4 h-4 transition-transform group-hover:translate-x-0.5"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
            />
          </svg>
        </a>
      </div>

      <%!-- Bento Grid: Hero left + 2x2 right --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-5">
        <%!-- Hero Product --%>
        <div :if={@hero}>
          <Shared.hero_product_card product={@hero} store={@store} />
        </div>

        <%!-- Right: 2x2 grid --%>
        <div class="grid grid-cols-2 gap-3 sm:gap-4 h-full">
          <Shared.product_card
            :for={product <- @grid_products}
            product={product}
            store={@store}
          />
        </div>
      </div>

      <%!-- Extra products row --%>
    </section>
    """
  end

  # ── New Arrivals / Trending Section ──

  attr :store, :map, required: true
  attr :products, :list, required: true

  defp trending_section(assigns) do
    # Show products not in the featured hero section (skip first product used as hero)
    featured_count = min(length(assigns.products), 5)
    trending = assigns.products |> Enum.drop(featured_count) |> Enum.take(4)
    # If not enough overflow, show last 4 products in different order
    trending =
      if trending == [], do: assigns.products |> Enum.reverse() |> Enum.take(4), else: trending

    assigns = assign(assigns, :trending, trending)

    ~H"""
    <section :if={@trending != []} class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24">
      <div class="flex items-center justify-between mb-8">
        <h2 class="font-serif text-2xl sm:text-3xl font-semibold text-[#1C1917]">New Arrivals</h2>
        <a
          href={"/s/#{@store.slug}/products"}
          class="group inline-flex items-center gap-1.5 text-sm font-semibold transition-colors hover:opacity-80"
          style="color: var(--theme-primary);"
        >
          View all
          <svg
            class="w-4 h-4 transition-transform group-hover:translate-x-0.5"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
            />
          </svg>
        </a>
      </div>
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6">
        <Shared.product_card :for={product <- @trending} product={product} store={@store} />
      </div>
    </section>
    """
  end

  # ── Trust / Payment Section (Visual-First, Literacy-Aware) ──

  attr :store, :map, required: true
  attr :theme, :map, required: true

  defp trust_section(assigns) do
    ~H"""
    <section id="trust-section" class="py-14 sm:py-20 bg-[#FAFAF9]" phx-hook="ScrollReveal">
      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        <%!-- 3 big icons, 1-word labels — visual first --%>
        <div class="grid grid-cols-3 gap-4 sm:gap-8 mb-12 sm:mb-16 reveal-up">
          <div class="flex flex-col items-center text-center group cursor-default">
            <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#059669]/10 flex items-center justify-center mb-3 group-hover:bg-[#059669]/15 group-hover:scale-110 transition-all duration-300">
              <svg
                class="w-8 h-8 sm:w-10 sm:h-10 text-[#059669]"
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
            <span class="text-sm sm:text-base font-semibold text-[#1C1917]">Safe</span>
            <span class="text-[11px] sm:text-xs text-[#A8A29E] mt-0.5">Secure checkout</span>
          </div>
          <div class="flex flex-col items-center text-center group cursor-default">
            <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#B45309]/10 flex items-center justify-center mb-3 group-hover:bg-[#B45309]/15 group-hover:scale-110 transition-all duration-300">
              <svg
                class="w-8 h-8 sm:w-10 sm:h-10 text-[#B45309]"
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
            <span class="text-sm sm:text-base font-semibold text-[#1C1917]">Fast</span>
            <span class="text-[11px] sm:text-xs text-[#A8A29E] mt-0.5">Instant confirmation</span>
          </div>
          <div class="flex flex-col items-center text-center group cursor-default">
            <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#7C3AED]/10 flex items-center justify-center mb-3 group-hover:bg-[#7C3AED]/15 group-hover:scale-110 transition-all duration-300">
              <svg
                class="w-8 h-8 sm:w-10 sm:h-10 text-[#7C3AED]"
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
            <span class="text-sm sm:text-base font-semibold text-[#1C1917]">Easy</span>
            <span class="text-[11px] sm:text-xs text-[#A8A29E] mt-0.5">Pay with your phone</span>
          </div>
        </div>
        <div class="border-t border-[#E7E5E4] mb-10 sm:mb-14 reveal-up"></div>
        <div class="reveal-up">
          <p class="text-center text-xs font-semibold uppercase tracking-[0.2em] text-[#A8A29E] mb-6">
            We Accept
          </p>
          <div class="flex items-center justify-center gap-3 sm:gap-4 flex-wrap">
            <div class="flex items-center gap-2.5 bg-[#FBBF24]/10 border border-[#FBBF24]/25 rounded-full px-5 py-3 hover:bg-[#FBBF24]/15 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#FBBF24]"></div>
              <span class="text-sm font-bold text-[#92400E]">MTN MoMo</span>
            </div>
            <div class="flex items-center gap-2.5 bg-[#EF4444]/8 border border-[#EF4444]/20 rounded-full px-5 py-3 hover:bg-[#EF4444]/12 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#EF4444]"></div>
              <span class="text-sm font-bold text-[#991B1B]">Telecel Cash</span>
            </div>
            <div class="flex items-center gap-2.5 bg-[#3B82F6]/8 border border-[#3B82F6]/20 rounded-full px-5 py-3 hover:bg-[#3B82F6]/12 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#3B82F6]"></div>
              <span class="text-sm font-bold text-[#1E40AF]">Visa</span>
            </div>
            <div class="flex items-center gap-2.5 bg-[#F97316]/8 border border-[#F97316]/20 rounded-full px-5 py-3 hover:bg-[#F97316]/12 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#F97316]"></div>
              <span class="text-sm font-bold text-[#9A3412]">Mastercard</span>
            </div>
          </div>
        </div>
      </div>
      <style>
        .reveal-up { opacity: 0; transform: translateY(24px); transition: opacity 0.6s ease-out, transform 0.6s ease-out; }
        .reveal-up.revealed { opacity: 1; transform: translateY(0); }
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
      Map.get(newsletter_config, :heading, "Stay Updated.")

    nl_description =
      Map.get(
        newsletter_config,
        :description,
        "Be the first to discover new collections, exclusive offers, and updates from our store."
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

  # ── Announcement Bar ──

  attr :public_coupons, :list, default: []
  attr :store, :map, required: true

  defp announcement_bar(assigns) do
    coupon = List.first(assigns.public_coupons)

    message =
      if coupon do
        format_coupon_message(coupon)
      else
        nil
      end

    assigns =
      assigns
      |> assign(:coupon, coupon)
      |> assign(:message, message)

    ~H"""
    <div
      id="announcement-bar"
      class="py-2 text-white text-center text-xs sm:text-sm relative"
      style="background-color: #B45309;"
    >
      <div class="max-w-7xl mx-auto px-8 sm:px-10">
        <%= if @coupon do %>
          <p>
            Use code <span class="font-bold">{@coupon.code}</span> for {@message}
          </p>
        <% else %>
          <p>Free delivery in Accra &amp; Kumasi on orders over GHS 100</p>
        <% end %>
      </div>
      <button
        type="button"
        phx-click={
          JS.hide(
            to: "#announcement-bar",
            transition: {"ease-out duration-200", "opacity-100", "opacity-0"}
          )
        }
        class="absolute right-2 sm:right-4 top-1/2 -translate-y-1/2 text-white/80 hover:text-white p-1"
        aria-label="Dismiss announcement"
      >
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
        </svg>
      </button>
    </div>
    """
  end

  defp format_coupon_message(coupon) do
    case coupon.discount_type do
      :percentage ->
        percent = div(coupon.discount_value, 100)
        "#{percent}% off!"

      :fixed_amount ->
        cedis = div(coupon.discount_value, 100)
        pesewas = rem(coupon.discount_value, 100)

        if pesewas == 0 do
          "GHS #{cedis} off!"
        else
          "GHS #{cedis}.#{String.pad_leading("#{pesewas}", 2, "0")} off!"
        end

      :free_shipping ->
        "free shipping!"

      _ ->
        "a discount!"
    end
  end

  # ── Delivery Zones Bar ──

  attr :delivery_zones, :list, default: []

  defp delivery_zones_bar(assigns) do
    zone_names =
      case assigns.delivery_zones do
        [] -> nil
        zones -> zones |> Enum.map(& &1.name) |> Enum.join(", ")
      end

    assigns = assign(assigns, :zone_names, zone_names)

    ~H"""
    <div class="bg-gray-50 border-y border-gray-100">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3 sm:py-4">
        <div class="flex items-center justify-center gap-2 text-gray-600 text-xs sm:text-sm">
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="flex-shrink-0 text-gray-400"
          >
            <rect x="1" y="3" width="15" height="13" rx="2" ry="2" />
            <polygon points="16 8 20 8 23 11 23 16 16 16 16 8" />
            <circle cx="5.5" cy="18.5" r="2.5" />
            <circle cx="18.5" cy="18.5" r="2.5" />
          </svg>
          <%= if @zone_names do %>
            <span>We deliver to: <span class="font-medium text-gray-700">{@zone_names}</span></span>
          <% else %>
            <span>Delivery across Ghana</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ──

  defp section_enabled?(theme, section_name) do
    case get_in(theme, [:sections, section_name]) do
      false -> false
      _ -> true
    end
  end

  # Returns true only for local upload paths (not stock photo URLs)
  defp prepare_hero_assigns(assigns) do
    theme = assigns[:theme] || %{}
    valid_images = collect_valid_hero_images(theme)
    image_count = length(valid_images)
    hero_carousel = get_in(theme, [:hero, :carousel]) || false
    store_name = Map.get(assigns.store, :name, "Our Store")

    assigns
    |> assign(:valid_images, valid_images)
    |> assign(:has_images, image_count > 0)
    |> assign(:use_carousel, image_count > 1 && hero_carousel)
    |> assign(:image_count, image_count)
    |> assign(:total_duration, max(image_count, 1) * 7)
    |> assign_hero_text(theme, store_name)
  end

  defp collect_valid_hero_images(theme) do
    images = get_in(theme, [:hero, :images]) || []
    single = get_in(theme, [:hero, :image_url])

    cond do
      is_list(images) && images != [] -> Enum.filter(images, &valid_hero_image?/1)
      valid_hero_image?(single) -> [single]
      true -> []
    end
  end

  defp assign_hero_text(assigns, theme, store_name) do
    assigns
    |> assign(:hero_subtitle, get_in(theme, [:hero, :subtitle]) || "Welcome to #{store_name}")
    |> assign(
      :hero_title,
      get_in(theme, [:hero, :title]) || "Crafting Trust,\nCurating Excellence."
    )
    |> assign(
      :hero_description,
      get_in(theme, [:hero, :description]) ||
        "Experience the soul of West African craftsmanship. Every piece tells a story of heritage, precision, and modern elegance."
    )
    |> assign(:cta_text, get_in(theme, [:hero, :cta_text]) || "Shop Now")
    |> assign(:cta_secondary_text, get_in(theme, [:hero, :cta_secondary_text]) || "Our Story")
  end

  defp valid_hero_image?(nil), do: false
  defp valid_hero_image?(""), do: false

  defp valid_hero_image?(url) when is_binary(url) do
    String.starts_with?(url, "/uploads/") || String.starts_with?(url, "/images/")
  end

  defp valid_hero_image?(_), do: false
end
