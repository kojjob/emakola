defmodule Emakola.Themes.Luminous.Shared do
  @moduledoc """
  Shared components for the Luminous theme.

  Soft, aspirational, ingredient-honest design with:
  - Warm ivory (#FFFBF8) background — gentler than pure white
  - Rose primary (#DB2777) / champagne rose-gold (#E5B299) accents
  - Cormorant Garamond serif headings + Inter body
  - Square product cards with prominent product photography + swatch dots
  - "Best for" badges surfacing skin-type / concern fit
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── Theme Styles ──

  @doc """
  Injects a <style> block with CSS custom properties for the Luminous theme.
  Call once near the top of any page that uses Luminous components.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#DB2777" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#E5B299" %>;
        --theme-highlight: <%= get_in(@theme, [:colors, :highlight]) || "#FCE7F3" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#FFFBF8" %>;
      }
    </style>
    """
  end

  # ── Luminous Nav Bar ──

  @doc """
  Light, airy navigation bar with rose accent stripe and store branding.
  Skin-quiz CTA replaces the more transactional restaurant-style WhatsApp
  button — beauty buyers convert via discovery, not direct order.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def luminous_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50">
      <div class="h-px bg-gradient-to-r from-transparent via-[var(--theme-accent,#E5B299)] to-transparent">
      </div>
      <div class="bg-[#FFFBF8]/95 backdrop-blur-md border-b border-[#FBCFE8]/40">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-14 sm:h-16">
            <a href={"/s/#{@store.slug}"} class="flex items-center gap-3 min-w-0">
              <div class="w-10 h-10 rounded-full bg-gradient-to-br from-[var(--theme-primary,#DB2777)] to-[var(--theme-accent,#E5B299)] flex items-center justify-center flex-shrink-0 shadow-sm shadow-pink-200">
                <span
                  class="text-sm font-semibold text-white"
                  style="font-family: 'Cormorant Garamond', serif;"
                >
                  {String.first(@store.name)}
                </span>
              </div>
              <div class="min-w-0">
                <div
                  class="text-[1.0625rem] font-semibold text-[#1F1717] truncate leading-tight"
                  style="font-family: 'Cormorant Garamond', serif;"
                >
                  {@store.name}
                </div>
                <div class="flex items-center gap-1 text-[11px] text-[#78716C] leading-tight tracking-wide">
                  <span class="material-symbols-outlined text-[13px] text-[var(--theme-primary,#DB2777)]">
                    spa
                  </span>
                  <span>Honest beauty</span>
                </div>
              </div>
            </a>

            <div class="flex items-center gap-1">
              <a
                href={"/s/#{@store.slug}/products"}
                class="p-2.5 rounded-full hover:bg-[#FCE7F3] transition-colors"
                aria-label="Shop"
              >
                <svg
                  class="w-5 h-5 text-[#78716C]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.6"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
                  />
                </svg>
              </a>
              <a
                href={"/s/#{@store.slug}/wishlist"}
                class="p-2.5 rounded-full hover:bg-[#FCE7F3] transition-colors"
                aria-label="Wishlist"
              >
                <svg
                  class="w-5 h-5 text-[#78716C]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.6"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
                  />
                </svg>
              </a>
              <a
                href={"/s/#{@store.slug}/cart"}
                class="relative p-2.5 rounded-full hover:bg-[#FCE7F3] transition-colors"
                aria-label={"Bag, #{@cart_count} items"}
              >
                <svg
                  class="w-5 h-5 text-[#78716C]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.6"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
                  />
                </svg>
                <span
                  :if={@cart_count > 0}
                  class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-[var(--theme-primary,#DB2777)] text-white text-[10px] font-semibold rounded-full flex items-center justify-center px-1"
                >
                  {@cart_count}
                </span>
              </a>
            </div>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ── Beauty Product Card ──

  @doc """
  Square product card with rose-gold ring, optional swatch dots, and "Best
  for" badge. Tuned for skincare / cosmetics imagery.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :swatches, :list, default: [], doc: "List of hex colours for shade dots"
  attr :best_for, :string, default: nil, doc: "e.g. \"Oily skin\" or \"Dry skin\""

  def beauty_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="relative rounded-3xl overflow-hidden mb-3 bg-[#FCE7F3]/30 ring-1 ring-[#FBCFE8]/40 group-hover:ring-2 group-hover:ring-[var(--theme-accent,#E5B299)] transition-all duration-300">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          class="w-full aspect-square object-cover group-hover:scale-[1.04] transition-transform duration-500"
        />
        <div :if={!@image} class="w-full aspect-square flex items-center justify-center bg-[#FCE7F3]">
          <span class="material-symbols-outlined text-5xl text-[var(--theme-primary,#DB2777)]/60">
            spa
          </span>
        </div>

        <span
          :if={@best_for}
          class="absolute top-3 left-3 inline-flex items-center px-2.5 py-1 rounded-full bg-white/95 backdrop-blur-sm text-[10px] font-semibold tracking-[0.1em] uppercase text-[#78716C]"
        >
          For {@best_for}
        </span>

        <div class="absolute bottom-0 left-0 right-0 p-3 bg-gradient-to-t from-[#1F1717]/55 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex justify-center">
          <span
            class="text-xs font-semibold text-white tracking-[0.2em] uppercase"
            style="font-family: 'Inter', sans-serif;"
          >
            View product
          </span>
        </div>
      </div>

      <p
        class="text-sm font-medium text-[#1F1717] leading-tight mb-1 truncate"
        style="font-family: 'Inter', sans-serif;"
      >
        {@product.title}
      </p>
      <p class="text-sm font-semibold text-[var(--theme-primary,#DB2777)] mb-2 tabular-nums">
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>

      <div :if={@swatches != []} class="flex items-center gap-1.5">
        <span
          :for={hex <- Enum.take(@swatches, 5)}
          class="block w-3.5 h-3.5 rounded-full ring-1 ring-[#FBCFE8]"
          style={"background-color: #{hex};"}
          aria-hidden="true"
        >
        </span>
        <span :if={length(@swatches) > 5} class="text-[10px] text-[#78716C] ml-1">
          +{length(@swatches) - 5}
        </span>
      </div>
    </a>
    """
  end

  # ── Footer ──

  @doc """
  Beauty-brand footer with mission line, ingredient pledge, and minimal
  payment badges. Lighter than restaurant footer — beauty trades on
  brand voice rather than service breadth.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer class="bg-[#1F1717] text-[#FCE7F3] mt-12">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
          <div>
            <p
              class="text-3xl font-semibold text-white mb-3"
              style="font-family: 'Cormorant Garamond', serif;"
            >
              {@store.name}
            </p>
            <p
              :if={@store.description}
              class="text-sm text-[#FCE7F3]/70 leading-relaxed"
              style="font-family: 'Inter', sans-serif;"
            >
              {String.slice(@store.description, 0, 160)}
            </p>
          </div>

          <div>
            <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-accent,#E5B299)] mb-3">
              Our pledge
            </p>
            <ul
              class="space-y-1.5 text-sm text-[#FCE7F3]/85"
              style="font-family: 'Inter', sans-serif;"
            >
              <li class="flex items-start gap-2">
                <span class="material-symbols-outlined text-[16px] text-[var(--theme-accent,#E5B299)] mt-0.5">
                  spa
                </span>
                Clean ingredients, transparent sourcing
              </li>
              <li class="flex items-start gap-2">
                <span class="material-symbols-outlined text-[16px] text-[var(--theme-accent,#E5B299)] mt-0.5">
                  verified
                </span>
                Dermatologist-tested formulas
              </li>
              <li class="flex items-start gap-2">
                <span class="material-symbols-outlined text-[16px] text-[var(--theme-accent,#E5B299)] mt-0.5">
                  favorite
                </span>
                Made for African skin and weather
              </li>
            </ul>
          </div>

          <div>
            <p class="text-[10px] font-semibold tracking-[0.25em] uppercase text-[var(--theme-accent,#E5B299)] mb-3">
              Pay with
            </p>
            <div class="flex flex-wrap gap-2">
              <span class="inline-flex items-center px-2.5 py-1 rounded-full bg-[#FFC107] text-[#1F1717] text-[11px] font-semibold">
                MoMo
              </span>
              <span class="inline-flex items-center px-2.5 py-1 rounded-full bg-[#E60000] text-white text-[11px] font-semibold">
                Vodafone
              </span>
              <span class="inline-flex items-center px-2.5 py-1 rounded-full bg-white text-[#1F1717] text-[11px] font-semibold">
                Card
              </span>
            </div>
            <p class="mt-5 text-[11px] text-[#FCE7F3]/50" style="font-family: 'Inter', sans-serif;">
              Free shipping on orders over GH₵250.
            </p>
          </div>
        </div>

        <div class="mt-10 pt-6 border-t border-[#FCE7F3]/10 flex flex-col sm:flex-row gap-3 sm:items-center sm:justify-between text-xs text-[#FCE7F3]/50">
          <p style="font-family: 'Inter', sans-serif;">
            © {Date.utc_today().year} {@store.name}. Crafted with care.
          </p>
          <p style="font-family: 'Inter', sans-serif;">Powered by Emakola</p>
        </div>
      </div>
    </footer>
    """
  end

  # ── Helpers ──

  @doc """
  Extract first image URL from a product's images association.
  """
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end
end
