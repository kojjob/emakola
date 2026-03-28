defmodule Emakola.Themes.Atelier.Home do
  @moduledoc """
  Atelier theme home page renderer — Stitch design reference.

  Sections (gated by `@theme.sections`):
  - Hero: Full-screen image bg, bold sans-serif heading, green CTAs
  - Categories: Horizontal scrolling circles
  - Products: Featured hero card + 2x2 smaller cards grid
  - Trending: New Arrivals flat 4-column grid
  - Trust: Secure commerce section with payment partners
  - Newsletter: "Stay Updated" email signup with benefits
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

      <%!-- New Arrivals --%>
      <.trending_section
        :if={section_enabled?(@theme, :featured_products) && length(@products) > 5}
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
    smaller_products = assigns.products |> Enum.drop(1) |> Enum.take(4)

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

      <%!-- Grid: Hero card on left, 4 smaller cards (2x2) on right --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Hero Product Card --%>
        <div :if={@hero_product}>
          <Shared.hero_product_card product={@hero_product} store={@store} />
        </div>

        <%!-- Four smaller cards in 2x2 grid, matching hero height --%>
        <div
          :if={@smaller_products != []}
          class="grid grid-cols-2 grid-rows-2 gap-4 sm:gap-6 h-full"
        >
          <Shared.product_card
            :for={product <- @smaller_products}
            product={product}
            store={@store}
          />
        </div>
      </div>
    </section>
    """
  end

  # ── Trust / Payment Section ──

  attr :store, :map, required: true
  attr :theme, :map, required: true

  defp trust_section(assigns) do
    trust_config = get_in(assigns.theme, [:trust]) || %{}

    trust_heading =
      Map.get(trust_config, :heading, "Seamless Trust. Secure Commerce.")

    trust_subtitle =
      Map.get(
        trust_config,
        :subtitle,
        "Shop with confidence using your preferred payment method."
      )

    cards = Map.get(trust_config, :cards, nil)

    default_cards = [
      %{
        title: "Encrypted Security",
        description:
          "Every transaction is protected with bank-level encryption. Your payment details are never stored on our servers.",
        icon: :shield
      },
      %{
        title: "Instant Settlement",
        description:
          "Payments are confirmed in real-time. No waiting, no uncertainty. Get instant order confirmation.",
        icon: :bolt
      },
      %{
        title: "Mobile Money Ready",
        description:
          "Pay with MTN Mobile Money, Telecel Cash, or your debit/credit card. Your choice, your convenience.",
        icon: :phone
      }
    ]

    trust_cards = cards || default_cards

    partners =
      Map.get(trust_config, :partners, ["MTN MoMo", "Telecel Cash", "Visa", "Mastercard"])

    assigns =
      assigns
      |> assign(:trust_heading, trust_heading)
      |> assign(:trust_subtitle, trust_subtitle)
      |> assign(:trust_cards, trust_cards)
      |> assign(:partners, partners)

    ~H"""
    <section class="py-16 sm:py-24" style="background: var(--theme-bg, #F0FDF4);">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <%!-- Heading --%>
        <div class="text-center mb-12 sm:mb-16">
          <h2 class="text-3xl sm:text-4xl lg:text-5xl font-black text-gray-900 mb-4">
            {@trust_heading}
          </h2>
          <p class="text-gray-600 text-base sm:text-lg max-w-2xl mx-auto">
            {@trust_subtitle}
          </p>
        </div>

        <%!-- Feature Cards --%>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-12">
          <div
            :for={{card, idx} <- Enum.with_index(@trust_cards)}
            class={[
              "bg-white rounded-xl p-6 sm:p-8 shadow-sm border border-gray-100 transition-shadow duration-200 hover:shadow-md",
              if(idx == 2, do: "md:col-span-2 lg:col-span-1", else: "")
            ]}
          >
            <div
              class="w-12 h-12 rounded-lg flex items-center justify-center mb-4"
              style="background: color-mix(in srgb, var(--theme-primary) 12%, white);"
            >
              <.trust_icon name={Map.get(card, :icon, :shield)} />
            </div>
            <h3 class="text-lg font-bold text-gray-900 mb-2">{Map.get(card, :title)}</h3>
            <p class="text-gray-600 text-sm leading-relaxed">
              {Map.get(card, :description)}
            </p>
          </div>
        </div>

        <%!-- Payment Partners --%>
        <div class="text-center">
          <p class="text-xs font-semibold uppercase tracking-widest text-gray-500 mb-6">
            Trusted Payment Partners
          </p>
          <div class="flex items-center justify-center gap-8 sm:gap-12 flex-wrap">
            <span
              :for={partner <- @partners}
              class="text-gray-400 font-bold text-sm sm:text-base"
            >
              {partner}
            </span>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp trust_icon(%{name: :shield} = assigns) do
    ~H"""
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
    """
  end

  defp trust_icon(%{name: :bolt} = assigns) do
    ~H"""
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
    """
  end

  defp trust_icon(%{name: :phone} = assigns) do
    ~H"""
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
    """
  end

  defp trust_icon(assigns) do
    ~H"""
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
    """
  end

  # ── Newsletter Section ──

  attr :store, :map, required: true
  attr :theme, :map, required: true

  defp newsletter_section(assigns) do
    newsletter_config = get_in(assigns[:theme], [:newsletter]) || %{}

    nl_heading =
      Map.get(newsletter_config, :heading, "Stay Updated")

    nl_description =
      Map.get(
        newsletter_config,
        :description,
        "Get the latest collections, exclusive offers, and order updates delivered to your inbox."
      )

    nl_button_text =
      Map.get(newsletter_config, :button_text, "Subscribe")

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
    <section class="bg-gradient-to-b from-[#F5F5F4] to-[#FAFAF9] border-t border-stone-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="max-w-xl mx-auto text-center">
          <%!-- Envelope Icon --%>
          <div class="flex justify-center mb-4">
            <div
              class="w-10 h-10 rounded-full flex items-center justify-center"
              style="background: color-mix(in srgb, var(--theme-primary) 12%, white);"
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke-width="2"
                style="stroke: var(--theme-primary);"
              >
                <rect x="2" y="4" width="20" height="16" rx="2" stroke="currentColor" />
                <path
                  d="M22 7l-10 7L2 7"
                  stroke="currentColor"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
            </div>
          </div>

          <h2 class="text-2xl sm:text-3xl font-black text-gray-900 mb-2">
            {@nl_heading}
          </h2>
          <p class="text-gray-600 text-sm sm:text-base leading-relaxed mb-6">
            {@nl_description}
          </p>

          <form class="flex flex-col sm:flex-row gap-3 mb-5" phx-submit="subscribe_newsletter">
            <label for="newsletter-email" class="sr-only">Email address</label>
            <input
              id="newsletter-email"
              type="email"
              name="email"
              placeholder={@nl_placeholder}
              required
              class="flex-1 px-5 py-3 bg-white rounded-lg text-sm text-gray-900 placeholder-gray-500 focus:outline-none focus:ring-2 transition-shadow duration-200 border border-stone-200 min-h-[48px]"
              style="--tw-ring-color: var(--theme-primary);"
            />
            <button
              type="submit"
              class="cursor-pointer px-8 py-3 text-sm font-bold uppercase tracking-wider rounded-lg text-white transition-all duration-200 hover:opacity-90 whitespace-nowrap min-h-[48px]"
              style="background: var(--theme-primary);"
            >
              {@nl_button_text}
            </button>
          </form>

          <%!-- Benefits --%>
          <div class="flex flex-wrap items-center justify-center gap-x-5 gap-y-1 mb-3">
            <span class="flex items-center gap-1.5 text-xs text-gray-500">
              <svg
                class="w-3.5 h-3.5 text-green-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
              </svg>
              New arrivals
            </span>
            <span class="flex items-center gap-1.5 text-xs text-gray-500">
              <svg
                class="w-3.5 h-3.5 text-green-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
              </svg>
              Exclusive deals
            </span>
            <span class="flex items-center gap-1.5 text-xs text-gray-500">
              <svg
                class="w-3.5 h-3.5 text-green-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
              </svg>
              Order updates
            </span>
          </div>

          <p class="text-xs text-gray-400">
            {@nl_disclaimer}
          </p>
        </div>
      </div>
    </section>
    """
  end

  # ── Trending / New Arrivals Section ──

  attr :store, :map, required: true
  attr :products, :list, required: true

  defp trending_section(assigns) do
    trending_products = assigns.products |> Enum.drop(5) |> Enum.take(4)

    assigns = assign(assigns, :trending_products, trending_products)

    ~H"""
    <section
      :if={@trending_products != []}
      class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24"
    >
      <%!-- Section Header --%>
      <div class="flex items-center justify-between mb-8 sm:mb-12">
        <h2 class="text-2xl sm:text-3xl lg:text-4xl font-black text-gray-900">
          New Arrivals
        </h2>
        <a
          href={"/s/#{@store.slug}/products"}
          class="text-sm font-semibold transition-colors hover:opacity-80"
          style="color: var(--theme-primary);"
        >
          View all &rarr;
        </a>
      </div>

      <%!-- Flat 4-column product grid --%>
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6">
        <Shared.product_card
          :for={product <- @trending_products}
          product={product}
          store={@store}
        />
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
