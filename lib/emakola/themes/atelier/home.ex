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
      />

      <%!-- Hero Section --%>
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
      <.trust_section :if={section_enabled?(@theme, :trust)} store={@store} />

      <%!-- Newsletter --%>
      <.newsletter_section :if={section_enabled?(@theme, :newsletter)} store={@store} />

      <%!-- Footer --%>
      <Shared.footer store={@store} categories={@categories} />
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
    total_duration = image_count * 5

    hero_subtitle = get_in(assigns.theme, [:hero, :subtitle]) || "The 2024 Collection"
    hero_title = get_in(assigns.theme, [:hero, :title]) || "Crafting Trust,\nCurating Excellence."

    assigns =
      assigns
      |> assign(:effective_images, effective_images)
      |> assign(:use_carousel, use_carousel)
      |> assign(:image_count, image_count)
      |> assign(:total_duration, total_duration)
      |> assign(:hero_subtitle, hero_subtitle)
      |> assign(:hero_title, hero_title)

    ~H"""
    <section class="relative min-h-[85vh] sm:min-h-screen flex items-center overflow-hidden">
      <%!-- Carousel CSS Animation --%>
      <style :if={@use_carousel}>
        @keyframes atelier-carousel {
          0%, 30% { opacity: 1; }
          33.33%, 97% { opacity: 0; }
          100% { opacity: 1; }
        }
      </style>

      <%!-- Background Images --%>
      <%= if @use_carousel do %>
        <img
          :for={{url, idx} <- Enum.with_index(@effective_images)}
          src={url}
          alt={"#{@store.name} collection #{idx + 1}"}
          class="absolute inset-0 w-full h-full object-cover object-center"
          style={"animation: atelier-carousel #{@total_duration}s infinite #{idx * 5}s; opacity: #{if idx == 0, do: 1, else: 0};"}
        />
      <% else %>
        <img
          src={List.first(@effective_images)}
          alt={"#{@store.name} collection"}
          class="absolute inset-0 w-full h-full object-cover object-center"
        />
      <% end %>

      <%!-- Dark Overlay --%>
      <div class="absolute inset-0 bg-black/50"></div>

      <%!-- Content --%>
      <div class="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full py-20">
        <div class="max-w-3xl">
          <%!-- Badge --%>
          <span class="inline-block px-4 py-1.5 rounded-full text-xs font-semibold tracking-wider uppercase mb-6 bg-white/20 backdrop-blur-sm text-white">
            {@hero_subtitle}
          </span>

          <%!-- Heading --%>
          <h1 class="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-black text-white leading-[1.05] mb-6">
            {raw(String.replace(@hero_title, "\n", "<br>"))}
          </h1>

          <%!-- CTA Buttons --%>
          <div class="flex flex-col sm:flex-row gap-4 mt-8">
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center justify-center px-8 py-4 text-sm font-bold uppercase tracking-wider rounded-lg text-white transition-all duration-300 hover:opacity-90 min-h-[48px]"
              style="background: var(--theme-primary);"
            >
              Explore Masterpieces
            </a>
            <a
              href={"/s/#{@store.slug}/about"}
              class="inline-flex items-center justify-center px-8 py-4 text-sm font-bold uppercase tracking-wider rounded-lg text-white border-2 border-white/40 hover:bg-white/10 transition-all duration-300 min-h-[48px]"
            >
              Meet the Artisans
            </a>
          </div>
        </div>

        <%!-- Carousel Dot Indicators --%>
        <div :if={@use_carousel} class="flex gap-2 mt-10">
          <span
            :for={idx <- 0..(@image_count - 1)}
            class="w-2.5 h-2.5 rounded-full bg-white/50"
            style={"animation: atelier-carousel #{@total_duration}s infinite #{idx * 5}s;"}
          >
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

  defp trust_section(assigns) do
    ~H"""
    <section class="py-16 sm:py-24" style="background: var(--theme-bg, #F0FDF4);">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <%!-- Heading --%>
        <div class="text-center mb-12 sm:mb-16">
          <h2 class="text-3xl sm:text-4xl lg:text-5xl font-black text-gray-900 mb-4">
            Seamless Trust. Secure Commerce.
          </h2>
          <p class="text-gray-600 text-base sm:text-lg max-w-2xl mx-auto">
            Shop with confidence using your preferred payment method.
          </p>
        </div>

        <%!-- Feature Cards --%>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-12">
          <%!-- Encrypted Security --%>
          <div class="bg-white rounded-xl p-6 sm:p-8 shadow-sm border border-gray-100">
            <div
              class="w-12 h-12 rounded-lg flex items-center justify-center mb-4"
              style="background: #F0FDF4;"
            >
              <svg
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke-width="2"
                style="stroke: var(--theme-primary);"
              >
                <path
                  d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke="currentColor"
                />
              </svg>
            </div>
            <h3 class="text-lg font-bold text-gray-900 mb-2">Encrypted Security</h3>
            <p class="text-gray-600 text-sm leading-relaxed">
              Every transaction is protected with bank-level encryption. Your payment details are never stored on our servers.
            </p>
          </div>

          <%!-- Instant Settlement --%>
          <div class="bg-white rounded-xl p-6 sm:p-8 shadow-sm border border-gray-100">
            <div
              class="w-12 h-12 rounded-lg flex items-center justify-center mb-4"
              style="background: #F0FDF4;"
            >
              <svg
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke-width="2"
                style="stroke: var(--theme-primary);"
              >
                <path
                  d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke="currentColor"
                />
              </svg>
            </div>
            <h3 class="text-lg font-bold text-gray-900 mb-2">Instant Settlement</h3>
            <p class="text-gray-600 text-sm leading-relaxed">
              Payments are confirmed in real-time. No waiting, no uncertainty. Get instant order confirmation.
            </p>
          </div>

          <%!-- Mobile Money --%>
          <div class="bg-white rounded-xl p-6 sm:p-8 shadow-sm border border-gray-100 md:col-span-2 lg:col-span-1">
            <div
              class="w-12 h-12 rounded-lg flex items-center justify-center mb-4"
              style="background: #F0FDF4;"
            >
              <svg
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke-width="2"
                style="stroke: var(--theme-primary);"
              >
                <rect x="5" y="2" width="14" height="20" rx="2" ry="2" stroke="currentColor" />
                <line x1="12" y1="18" x2="12.01" y2="18" stroke="currentColor" stroke-linecap="round" />
              </svg>
            </div>
            <h3 class="text-lg font-bold text-gray-900 mb-2">Mobile Money Ready</h3>
            <p class="text-gray-600 text-sm leading-relaxed">
              Pay with MTN Mobile Money, Telecel Cash, or your debit/credit card. Your choice, your convenience.
            </p>
          </div>
        </div>

        <%!-- Payment Partners --%>
        <div class="text-center">
          <p class="text-xs font-semibold uppercase tracking-widest text-gray-500 mb-6">
            Trusted Payment Partners
          </p>
          <div class="flex items-center justify-center gap-8 sm:gap-12 flex-wrap">
            <span class="text-gray-400 font-bold text-sm sm:text-base">MTN MoMo</span>
            <span class="text-gray-400 font-bold text-sm sm:text-base">Telecel Cash</span>
            <span class="text-gray-400 font-bold text-sm sm:text-base">Visa</span>
            <span class="text-gray-400 font-bold text-sm sm:text-base">Mastercard</span>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ── Newsletter Section ──

  attr :store, :map, required: true

  defp newsletter_section(assigns) do
    ~H"""
    <section class="bg-white">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <div class="max-w-xl mx-auto text-center">
          <h2 class="text-3xl sm:text-4xl lg:text-5xl font-black text-gray-900 mb-4">
            Join the Artisan Circle.
          </h2>
          <p class="text-gray-600 text-base sm:text-lg leading-relaxed mb-8">
            Be the first to discover new artisan collections, exclusive offers, and stories from the makers.
          </p>
          <form class="flex flex-col sm:flex-row gap-3 mb-4" phx-submit="subscribe_newsletter">
            <label for="newsletter-email" class="sr-only">Email address</label>
            <input
              id="newsletter-email"
              type="email"
              name="email"
              placeholder="Enter your email"
              required
              class="flex-1 px-5 py-3.5 bg-gray-100 rounded-lg text-sm text-gray-900 placeholder-gray-500 focus:outline-none focus:ring-2 transition-shadow border-0"
              style="focus:ring-color: var(--theme-primary);"
            />
            <button
              type="submit"
              class="px-8 py-3.5 text-sm font-bold uppercase tracking-wider rounded-lg text-white transition-colors duration-300 whitespace-nowrap min-h-[48px]"
              style="background: var(--theme-primary);"
            >
              Join Now
            </button>
          </form>
          <p class="text-xs text-gray-400">
            No spam. Unsubscribe anytime.
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
