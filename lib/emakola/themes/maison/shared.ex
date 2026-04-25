defmodule Emakola.Themes.Maison.Shared do
  @moduledoc """
  Shared components for the Maison theme.

  Restrained, photography-first, museum-grade design with:
  - Stark white (#FFFFFF) background — image-first
  - Stone-900 (#1C1917) text and CTAs — minimal contrast variation
  - Warm gold (#D4A843) used sparingly for kickers and editorial flourish
  - Playfair Display heavy serif headlines + Inter 300/400 body
  - Tall portrait product cards, image dominates, name + price only
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── Theme Styles ──

  @doc """
  Injects a <style> block with CSS custom properties for the Maison theme.
  Call once near the top of any page that uses Maison components.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#1C1917" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#D4A843" %>;
        --theme-highlight: <%= get_in(@theme, [:colors, :highlight]) || "#F5F5F4" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#FFFFFF" %>;
      }
    </style>
    """
  end

  # ── Maison Nav Bar ──

  @doc """
  Spare, editorial top navigation. Wordmark left, minimal icons right.
  No accent stripe — relies on a thin border for separation.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def maison_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-white/95 backdrop-blur-md border-b border-[#E7E5E4]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16 sm:h-20">
          <a href={"/s/#{@store.slug}"} class="flex items-center min-w-0">
            <span
              class="text-xl sm:text-2xl text-[#1C1917] tracking-[0.04em] truncate"
              style="font-family: 'Playfair Display', serif;"
            >
              {@store.name}
            </span>
          </a>

          <div class="flex items-center gap-1">
            <a
              href={"/s/#{@store.slug}/products"}
              class="hidden sm:inline-flex px-3 py-2 text-xs uppercase tracking-[0.2em] text-[#1C1917] hover:text-[var(--theme-accent,#D4A843)] transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
              Shop
            </a>
            <a
              href={"/s/#{@store.slug}/about"}
              class="hidden sm:inline-flex px-3 py-2 text-xs uppercase tracking-[0.2em] text-[#1C1917] hover:text-[var(--theme-accent,#D4A843)] transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
              The maison
            </a>
            <a
              href={"/s/#{@store.slug}/products"}
              class="p-2.5 text-[#1C1917] hover:text-[var(--theme-accent,#D4A843)] transition-colors"
              aria-label="Search"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
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
              href={"/s/#{@store.slug}/cart"}
              class="relative p-2.5 text-[#1C1917] hover:text-[var(--theme-accent,#D4A843)] transition-colors"
              aria-label={"Bag, #{@cart_count} items"}
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
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
                class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-[#1C1917] text-white text-[10px] font-medium rounded-full flex items-center justify-center px-1"
                style="font-family: 'Inter', sans-serif;"
              >
                {@cart_count}
              </span>
            </a>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ── Portrait Product Card ──

  @doc """
  Tall portrait card — image dominates, name + price only. Hover crossfade
  between hero shot (first image) and detail shot (second image, if available).
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def portrait_card(assigns) do
    images = product_images(assigns.product)

    assigns =
      assigns
      |> assign(:hero_image, Enum.at(images, 0))
      |> assign(:detail_image, Enum.at(images, 1))

    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="relative aspect-[3/4] bg-[#F5F5F4] overflow-hidden mb-3">
        <%= if @hero_image do %>
          <.optimized_image
            src={@hero_image}
            alt={@product.title}
            class={"absolute inset-0 w-full h-full object-cover transition-opacity duration-700 #{if @detail_image, do: "group-hover:opacity-0", else: ""}"}
          />
          <.optimized_image
            :if={@detail_image}
            src={@detail_image}
            alt={"#{@product.title} detail"}
            priority={:low}
            class="absolute inset-0 w-full h-full object-cover opacity-0 group-hover:opacity-100 transition-opacity duration-700"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center">
            <span class="material-symbols-outlined text-5xl text-[#A8A29E]">apparel</span>
          </div>
        <% end %>
      </div>
      <p
        class="text-sm sm:text-base text-[#1C1917] mb-1 leading-tight"
        style="font-family: 'Playfair Display', serif;"
      >
        {@product.title}
      </p>
      <p
        class="text-xs sm:text-sm text-[#78716C] tabular-nums tracking-wide"
        style="font-family: 'Inter', sans-serif;"
      >
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>
    </a>
    """
  end

  # ── Footer ──

  @doc """
  Editorial footer — stockists, press, contact. Lower transactional friction,
  higher brand register. No service strip; payment badges in a single subtle
  line.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer class="bg-white border-t border-[#E7E5E4] mt-12">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8 lg:gap-10">
          <div class="lg:col-span-2">
            <p
              class="text-2xl sm:text-3xl text-[#1C1917] mb-4 tracking-[0.02em]"
              style="font-family: 'Playfair Display', serif;"
            >
              {@store.name}
            </p>
            <p
              :if={@store.description}
              class="text-sm text-[#78716C] leading-relaxed max-w-md"
              style="font-family: 'Inter', sans-serif;"
            >
              {String.slice(@store.description, 0, 180)}
            </p>
          </div>

          <div>
            <p
              class="text-[10px] font-medium tracking-[0.25em] uppercase text-[#1C1917] mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              The maison
            </p>
            <ul
              class="space-y-2 text-sm text-[#78716C]"
              style="font-family: 'Inter', sans-serif;"
            >
              <li>
                <a href={"/s/#{@store.slug}/about"} class="hover:text-[#1C1917] transition-colors">
                  Our story
                </a>
              </li>
              <li>
                <a href="#" class="hover:text-[#1C1917] transition-colors">Stockists</a>
              </li>
              <li>
                <a href="#" class="hover:text-[#1C1917] transition-colors">Press enquiries</a>
              </li>
              <li :if={Map.get(@store, :contact_email)}>
                <a
                  href={"mailto:#{@store.contact_email}"}
                  class="hover:text-[#1C1917] transition-colors"
                >
                  {@store.contact_email}
                </a>
              </li>
            </ul>
          </div>

          <div>
            <p
              class="text-[10px] font-medium tracking-[0.25em] uppercase text-[#1C1917] mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              Client services
            </p>
            <ul
              class="space-y-2 text-sm text-[#78716C]"
              style="font-family: 'Inter', sans-serif;"
            >
              <li>
                <a href="#" class="hover:text-[#1C1917] transition-colors">Shipping & returns</a>
              </li>
              <li>
                <a href="#" class="hover:text-[#1C1917] transition-colors">Care & restoration</a>
              </li>
              <li>
                <a href="#" class="hover:text-[#1C1917] transition-colors">Size guide</a>
              </li>
              <li :if={Map.get(@store, :whatsapp_number)}>
                <a
                  href={"https://wa.me/#{normalise_whatsapp(@store.whatsapp_number)}"}
                  target="_blank"
                  rel="noopener"
                  class="hover:text-[#1C1917] transition-colors"
                >
                  Concierge on WhatsApp
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div class="mt-12 pt-6 border-t border-[#E7E5E4] flex flex-col sm:flex-row gap-3 sm:items-center sm:justify-between text-xs text-[#A8A29E]">
          <p style="font-family: 'Inter', sans-serif;">
            © {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
          <p
            class="tracking-[0.15em] uppercase text-[10px]"
            style="font-family: 'Inter', sans-serif;"
          >
            MoMo · Vodafone · Card · Powered by Emakola
          </p>
        </div>
      </div>
    </footer>
    """
  end

  # ── Helpers ──

  @doc """
  Extract first image URL from a product's images association.
  Public helper used across Maison page modules.
  """
  def first_image(product) do
    case product_images(product) do
      [first | _] -> first
      _ -> nil
    end
  end

  defp product_images(product) do
    case product.images do
      images when is_list(images) ->
        images
        |> Enum.map(fn
          %{url: url} when is_binary(url) -> url
          %{thumbnail_url: url} when is_binary(url) -> url
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp normalise_whatsapp(number) do
    number
    |> to_string()
    |> String.replace(~r/[^\d]/, "")
  end
end
