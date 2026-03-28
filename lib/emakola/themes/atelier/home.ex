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
  alias Emakola.Themes.DesignTokens
  alias EmakolaWeb.Helpers.Currency

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

    tokens = Map.get(assigns.theme, :design_tokens, %{})
    hero_layout = DesignTokens.hero_layout(tokens[:hero_layout])
    heading_font = DesignTokens.heading_font_family(tokens[:heading_font])
    heading_size = DesignTokens.heading_size(tokens[:typography_scale])
    btn_classes = DesignTokens.button_classes(tokens[:button_style])

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
      |> assign(:hero_layout, hero_layout)
      |> assign(:heading_font, heading_font)
      |> assign(:heading_size, heading_size)
      |> assign(:btn_classes, btn_classes)

    ~H"""
    <%= if @hero_layout == :split do %>
      <.hero_split
        store={@store}
        effective_images={@effective_images}
        hero_subtitle={@hero_subtitle}
        hero_title={@hero_title}
        hero_description={@hero_description}
        cta_text={@cta_text}
        cta_secondary_text={@cta_secondary_text}
        heading_font={@heading_font}
        heading_size={@heading_size}
        btn_classes={@btn_classes}
      />
    <% else %>
      <.hero_full_bleed
        store={@store}
        effective_images={@effective_images}
        use_carousel={@use_carousel}
        image_count={@image_count}
        total_duration={@total_duration}
        hero_subtitle={@hero_subtitle}
        hero_title={@hero_title}
        hero_description={@hero_description}
        cta_text={@cta_text}
        cta_secondary_text={@cta_secondary_text}
        heading_font={@heading_font}
        heading_size={@heading_size}
        btn_classes={@btn_classes}
      />
    <% end %>
    """
  end

  # ── Hero: Full-Bleed Variant ──

  attr :store, :map, required: true
  attr :effective_images, :list, required: true
  attr :use_carousel, :boolean, required: true
  attr :image_count, :integer, required: true
  attr :total_duration, :integer, required: true
  attr :hero_subtitle, :string, required: true
  attr :hero_title, :string, required: true
  attr :hero_description, :string, required: true
  attr :cta_text, :string, required: true
  attr :cta_secondary_text, :string, required: true
  attr :heading_font, :string, required: true
  attr :heading_size, :string, required: true
  attr :btn_classes, :string, required: true

  defp hero_full_bleed(assigns) do
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
            style={"text-shadow: 0 2px 8px rgba(0,0,0,0.5); font-family: #{@heading_font};"}
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
              class={"inline-flex items-center justify-center gap-2 px-8 py-4 text-sm font-bold uppercase tracking-wider #{@btn_classes} text-white transition-all duration-300 hover:opacity-90 min-h-[48px]"}
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
              class={"inline-flex items-center justify-center px-8 py-4 text-sm font-bold uppercase tracking-wider #{@btn_classes} text-white border-2 border-white/40 hover:bg-white/10 transition-all duration-300 min-h-[48px]"}
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

  # ── Hero: Split Variant ──

  attr :store, :map, required: true
  attr :effective_images, :list, required: true
  attr :hero_subtitle, :string, required: true
  attr :hero_title, :string, required: true
  attr :hero_description, :string, required: true
  attr :cta_text, :string, required: true
  attr :cta_secondary_text, :string, required: true
  attr :heading_font, :string, required: true
  attr :heading_size, :string, required: true
  attr :btn_classes, :string, required: true

  defp hero_split(assigns) do
    ~H"""
    <section class="bg-[#FAFAF9] pt-24 sm:pt-28 pb-12 sm:pb-20">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-16 items-center">
          <%!-- Left: Text content --%>
          <div class="order-2 lg:order-1">
            <span
              class="inline-block px-4 py-1.5 rounded-full text-xs font-semibold tracking-wider uppercase mb-6 text-white"
              style="background: var(--theme-primary);"
            >
              {@hero_subtitle}
            </span>

            <h1
              class="text-4xl sm:text-5xl lg:text-6xl xl:text-7xl font-black text-[#1C1917] leading-[1.05] mb-6 tracking-tight"
              style={"font-family: #{@heading_font};"}
            >
              {raw(String.replace(@hero_title, "\n", "<br>"))}
            </h1>

            <p class="text-base sm:text-lg text-[#78716C] max-w-lg leading-relaxed mb-8">
              {@hero_description}
            </p>

            <div class="flex flex-col sm:flex-row gap-4">
              <a
                href={"/s/#{@store.slug}/products"}
                class={"inline-flex items-center justify-center gap-2 px-8 py-4 text-sm font-bold uppercase tracking-wider #{@btn_classes} text-white transition-all duration-300 hover:opacity-90 min-h-[48px]"}
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
                class={"inline-flex items-center justify-center px-8 py-4 text-sm font-bold uppercase tracking-wider #{@btn_classes} text-[#1C1917] border-2 border-[#D6D3D1] hover:border-[#A8A29E] hover:bg-[#F5F5F4] transition-all duration-300 min-h-[48px]"}
              >
                {@cta_secondary_text}
              </a>
            </div>
          </div>

          <%!-- Right: Hero image --%>
          <div class="order-1 lg:order-2">
            <div class="relative overflow-hidden rounded-2xl aspect-[4/5] sm:aspect-[3/4] lg:aspect-[4/5] bg-[#F5F5F4]">
              <img
                src={List.first(@effective_images)}
                alt={"#{@store.name} collection"}
                loading="eager"
                class="w-full h-full object-cover"
              />
            </div>
          </div>
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
    # Take first product as hero, rest as grid (max 4)
    hero = List.first(assigns.products)
    grid_products = assigns.products |> Enum.drop(1) |> Enum.take(4)

    tokens = Map.get(assigns.theme || %{}, :design_tokens, %{})
    heading_font = DesignTokens.heading_font_family(tokens[:heading_font])
    heading_size = DesignTokens.heading_size(tokens[:typography_scale])
    grid_classes = DesignTokens.grid_classes(tokens[:product_grid_columns])
    btn_classes = DesignTokens.button_classes(tokens[:button_style])

    assigns =
      assigns
      |> assign(:hero, hero)
      |> assign(:grid_products, grid_products)
      |> assign(:heading_font, heading_font)
      |> assign(:heading_size, heading_size)
      |> assign(:grid_classes, grid_classes)
      |> assign(:btn_classes, btn_classes)

    ~H"""
    <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24">
      <%!-- Section Header --%>
      <div class="flex items-center justify-between mb-8 sm:mb-10">
        <div>
          <h2
            class={"#{@heading_size} font-semibold text-[#1C1917]"}
            style={"font-family: #{@heading_font};"}
          >
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

      <%!-- Bento Grid: Hero left + 2x2 cards right --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-5">
        <%!-- Hero Product — left half --%>
        <div :if={@hero}>
          <a
            href={"/s/#{@store.slug}/products/#{@hero.slug}"}
            class="group block relative overflow-hidden rounded-2xl bg-[#F5F5F4] h-full min-h-[320px] sm:min-h-[480px] cursor-pointer"
          >
            <img
              :if={first_product_image(@hero)}
              src={first_product_image(@hero)}
              alt={@hero.title}
              loading="lazy"
              class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
            />
            <div
              :if={!first_product_image(@hero)}
              class="w-full h-full flex items-center justify-center"
            >
              <svg
                class="w-16 h-16 text-[#D6D3D1]"
                fill="none"
                stroke="currentColor"
                stroke-width="1"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5z"
                />
              </svg>
            </div>
            <%!-- Gradient + content --%>
            <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-black/10 to-transparent">
            </div>
            <div class="absolute bottom-0 left-0 right-0 p-5 sm:p-8">
              <h3 class="font-serif text-xl sm:text-2xl font-semibold text-white mb-1.5">
                {@hero.title}
              </h3>
              <div class="flex items-center gap-3">
                <span class="text-white/90 text-base sm:text-lg font-bold tabular-nums">
                  {Currency.format_price(@hero.min_price || 0, @store.currency)}
                </span>
                <span
                  :if={@hero.max_price && @hero.max_price != @hero.min_price}
                  class="text-white/50 text-sm line-through tabular-nums"
                >
                  {Currency.format_price(@hero.max_price, @store.currency)}
                </span>
              </div>
              <div class="mt-4 inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-white/15 backdrop-blur-sm border border-white/20 text-white text-xs font-semibold uppercase tracking-wider group-hover:bg-white/25 transition-colors">
                Shop Now
                <svg
                  class="w-3.5 h-3.5 transition-transform group-hover:translate-x-0.5"
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
            </div>
          </a>
        </div>

        <%!-- Right half: grid of smaller cards (column count from design tokens) --%>
        <div class={"grid #{@grid_classes} gap-3 sm:gap-4"}>
          <div :for={product <- @grid_products}>
            <a
              href={"/s/#{@store.slug}/products/#{product.slug}"}
              class="group block cursor-pointer"
            >
              <div class="relative overflow-hidden rounded-xl bg-[#F5F5F4] aspect-[4/5] mb-3">
                <img
                  :if={first_product_image(product)}
                  src={first_product_image(product)}
                  alt={product.title}
                  loading="lazy"
                  class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                />
                <div
                  :if={!first_product_image(product)}
                  class="w-full h-full flex items-center justify-center"
                >
                  <svg
                    class="w-8 h-8 text-[#D6D3D1]"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5z"
                    />
                  </svg>
                </div>
                <%!-- Quick add button --%>
                <div class="absolute bottom-0 left-0 right-0 p-3 translate-y-full group-hover:translate-y-0 transition-transform duration-300">
                  <button
                    class={"w-full py-2.5 text-[11px] font-semibold uppercase tracking-wider #{@btn_classes} text-white cursor-pointer transition-colors min-h-[40px]"}
                    style="background: var(--theme-primary);"
                    phx-click="add_to_cart"
                    phx-value-product-id={product.id}
                  >
                    Add to Cart
                  </button>
                </div>
                <%!-- Sale badge --%>
                <div
                  :if={product.max_price && product.max_price > (product.min_price || 0)}
                  class="absolute top-3 left-3 px-2.5 py-1 rounded-full bg-[#DC2626] text-white text-[10px] font-bold uppercase tracking-wider"
                >
                  Sale
                </div>
              </div>
              <h3 class="text-sm font-medium text-[#1C1917] leading-snug mb-1 line-clamp-1 group-hover:text-[#B45309] transition-colors">
                {product.title}
              </h3>
              <div class="flex items-center gap-2">
                <span class="text-sm font-bold tabular-nums" style="color: var(--theme-primary);">
                  {Currency.format_price(product.min_price || 0, @store.currency)}
                </span>
                <span
                  :if={product.max_price && product.max_price > (product.min_price || 0)}
                  class="text-xs text-[#A8A29E] line-through tabular-nums"
                >
                  {Currency.format_price(product.max_price, @store.currency)}
                </span>
              </div>
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ── Trust / Payment Section ──

  attr :store, :map, required: true
  attr :theme, :map, required: true

  defp trust_section(assigns) do
    ~H"""
    <section id="trust-section" class="py-14 sm:py-20 bg-[#FAFAF9]" phx-hook="ScrollReveal">
      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        <%!-- 3 big icons, 1-word labels — visual first --%>
        <div class="grid grid-cols-3 gap-4 sm:gap-8 mb-12 sm:mb-16 reveal-up">
          <%!-- Safe --%>
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

          <%!-- Fast --%>
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

          <%!-- Easy --%>
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

        <%!-- Divider --%>
        <div class="border-t border-[#E7E5E4] mb-10 sm:mb-14 reveal-up reveal-delay-1"></div>

        <%!-- Payment methods — big colorful pills --%>
        <div class="reveal-up reveal-delay-2">
          <p class="text-center text-xs font-semibold uppercase tracking-[0.2em] text-[#A8A29E] mb-6">
            We Accept
          </p>
          <div class="flex items-center justify-center gap-3 sm:gap-4 flex-wrap">
            <div class="flex items-center gap-2.5 bg-[#FBBF24]/10 border border-[#FBBF24]/25 rounded-full px-5 py-3 hover:bg-[#FBBF24]/15 hover:border-[#FBBF24]/40 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#FBBF24]"></div>
              <span class="text-sm font-bold text-[#92400E]">MTN MoMo</span>
            </div>
            <div class="flex items-center gap-2.5 bg-[#EF4444]/8 border border-[#EF4444]/20 rounded-full px-5 py-3 hover:bg-[#EF4444]/12 hover:border-[#EF4444]/35 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#EF4444]"></div>
              <span class="text-sm font-bold text-[#991B1B]">Telecel Cash</span>
            </div>
            <div class="flex items-center gap-2.5 bg-[#3B82F6]/8 border border-[#3B82F6]/20 rounded-full px-5 py-3 hover:bg-[#3B82F6]/12 hover:border-[#3B82F6]/35 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#3B82F6]"></div>
              <span class="text-sm font-bold text-[#1E40AF]">Visa</span>
            </div>
            <div class="flex items-center gap-2.5 bg-[#F97316]/8 border border-[#F97316]/20 rounded-full px-5 py-3 hover:bg-[#F97316]/12 hover:border-[#F97316]/35 hover:scale-105 transition-all duration-300 cursor-default">
              <div class="w-3 h-3 rounded-full bg-[#F97316]"></div>
              <span class="text-sm font-bold text-[#9A3412]">Mastercard</span>
            </div>
          </div>
        </div>
      </div>

      <style>
        .reveal-up {
          opacity: 0;
          transform: translateY(24px);
          transition: opacity 0.6s ease-out, transform 0.6s ease-out;
        }
        .reveal-up.revealed {
          opacity: 1;
          transform: translateY(0);
        }
        .reveal-delay-1 { transition-delay: 0.15s; }
        .reveal-delay-2 { transition-delay: 0.3s; }
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

    tokens = Map.get(assigns.theme, :design_tokens, %{})
    heading_font = DesignTokens.heading_font_family(tokens[:heading_font])
    heading_size = DesignTokens.heading_size(tokens[:typography_scale])
    btn_classes = DesignTokens.button_classes(tokens[:button_style])

    assigns =
      assigns
      |> assign(:nl_heading, nl_heading)
      |> assign(:nl_description, nl_description)
      |> assign(:nl_button_text, nl_button_text)
      |> assign(:nl_placeholder, nl_placeholder)
      |> assign(:nl_disclaimer, nl_disclaimer)
      |> assign(:heading_font, heading_font)
      |> assign(:heading_size, heading_size)
      |> assign(:btn_classes, btn_classes)

    ~H"""
    <section class="bg-white">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <div class="max-w-xl mx-auto text-center">
          <h2
            class={"#{@heading_size} font-black text-gray-900 mb-4"}
            style={"font-family: #{@heading_font};"}
          >
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
              class={"cursor-pointer px-8 py-3.5 text-sm font-bold uppercase tracking-wider #{@btn_classes} text-white transition-all duration-200 hover:opacity-90 whitespace-nowrap min-h-[48px]"}
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

  defp first_product_image(product) do
    Shared.first_image(product)
  end
end
