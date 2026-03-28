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
            <img
              :for={{url, idx} <- Enum.with_index(@valid_images)}
              src={url}
              alt={"#{@store.name} collection #{idx + 1}"}
              class="atelier-hero-img absolute inset-0 w-full h-full object-cover object-center"
              style={"animation-delay: #{Float.round(idx * @total_duration / @image_count - (if idx > 0, do: @total_duration * overlap / 100, else: 0), 1)}s; opacity: #{if idx == 0, do: 1, else: 0};"}
            />
          <% else %>
            <%!-- Single image: gentle Ken Burns drift --%>
            <img
              src={List.first(@valid_images)}
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

  defp categories_section(assigns) do
    ~H"""
    <section class="py-12 sm:py-16">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <%!-- Section heading --%>
        <h2 class="text-2xl sm:text-3xl font-black text-gray-900 text-center mb-8 sm:mb-10">
          Shop by Category
        </h2>
        <%!-- Horizontal scrolling category circles --%>
        <div class="flex gap-8 sm:gap-10 overflow-x-auto pb-4 scrollbar-hide -mx-4 px-4 sm:mx-0 sm:px-0 sm:justify-center sm:flex-wrap">
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
    theme = assigns.theme
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
