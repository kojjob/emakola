defmodule Emakola.Themes.Heritage.Shared do
  @moduledoc """
  Shared components for the Heritage theme.

  Warm, story-driven, maker-forward design with:
  - Warm cream (#FFFBEB) background — feels like newsprint
  - Clay (#A0522D) primary / sage (#84A98C) accent
  - Lora humanist serif headlines + Inter body
  - Square craft cards with "Handmade in [city]" badges
  - Maker-name treated as a first-class data point on every card
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── Theme Styles ──

  @doc """
  Injects a <style> block with CSS custom properties for the Heritage theme.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#A0522D" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#84A98C" %>;
        --theme-highlight: <%= get_in(@theme, [:colors, :highlight]) || "#F4E4C1" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#FFFBEB" %>;
      }
    </style>
    """
  end

  # ── Heritage Nav Bar ──

  @doc """
  Warm, grounded top navigation. Wordmark with workshop subtitle, sage
  green accent line, minimal action icons.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def heritage_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50">
      <div class="h-px bg-gradient-to-r from-transparent via-[var(--theme-accent,#84A98C)] to-transparent">
      </div>
      <div class="bg-[#FFFBEB]/95 backdrop-blur-md border-b border-[#E7DDC7]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16 sm:h-20">
            <a href={"/s/#{@store.slug}"} class="flex items-center gap-3 min-w-0">
              <div class="w-11 h-11 rounded-full bg-[var(--theme-primary,#A0522D)] flex items-center justify-center flex-shrink-0">
                <span
                  class="text-base font-semibold text-white"
                  style="font-family: 'Lora', serif;"
                >
                  {String.first(@store.name)}
                </span>
              </div>
              <div class="min-w-0">
                <div
                  class="text-lg sm:text-xl text-[#1C1917] truncate leading-tight"
                  style="font-family: 'Lora', serif;"
                >
                  {@store.name}
                </div>
                <div class="text-[10px] tracking-[0.2em] uppercase text-[var(--theme-accent,#84A98C)]">
                  The workshop
                </div>
              </div>
            </a>

            <div class="flex items-center gap-1">
              <a
                href={"/s/#{@store.slug}/products"}
                class="hidden sm:inline-flex px-3 py-2 text-xs uppercase tracking-[0.2em] text-[#78716C] hover:text-[var(--theme-primary,#A0522D)] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                Shop
              </a>
              <a
                href={"/s/#{@store.slug}/about"}
                class="hidden sm:inline-flex px-3 py-2 text-xs uppercase tracking-[0.2em] text-[#78716C] hover:text-[var(--theme-primary,#A0522D)] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                Makers
              </a>
              <a
                href={"/s/#{@store.slug}/products"}
                class="p-2.5 text-[#78716C] hover:text-[var(--theme-primary,#A0522D)] transition-colors"
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
                class="relative p-2.5 text-[#78716C] hover:text-[var(--theme-primary,#A0522D)] transition-colors"
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
                  class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-[var(--theme-primary,#A0522D)] text-white text-[10px] font-medium rounded-full flex items-center justify-center px-1"
                  style="font-family: 'Inter', sans-serif;"
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

  # ── Craft Card ──

  @doc """
  Square craft card with maker name + city badge. Maker is treated as a
  first-class data point — every card tells you who made it and where.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :maker_name, :string, default: nil
  attr :maker_city, :string, default: nil

  def craft_card(assigns) do
    assigns =
      assigns
      |> assign(:image, first_image(assigns.product))
      |> assign(:resolved_maker, assigns.maker_name || assigns.store.name)
      |> assign(:resolved_city, assigns.maker_city || Map.get(assigns.store, :city))

    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="relative aspect-square overflow-hidden mb-3 bg-[#F4E4C1]/40 rounded-md">
        <%= if @image do %>
          <.optimized_image
            src={@image}
            alt={@product.title}
            class="w-full h-full object-cover group-hover:scale-[1.04] transition-transform duration-700"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center">
            <span class="material-symbols-outlined text-5xl text-[var(--theme-primary,#A0522D)]/50">
              chair
            </span>
          </div>
        <% end %>

        <span
          :if={@resolved_city}
          class="absolute top-3 left-3 inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-white/95 backdrop-blur-sm text-[10px] tracking-[0.1em] uppercase text-[var(--theme-primary,#A0522D)]"
          style="font-family: 'Inter', sans-serif;"
        >
          <span class="material-symbols-outlined text-[12px]">handyman</span> Made in {@resolved_city}
        </span>
      </div>

      <p
        class="text-base text-[#1C1917] mb-1 leading-tight"
        style="font-family: 'Lora', serif;"
      >
        {@product.title}
      </p>
      <p
        :if={@resolved_maker}
        class="text-xs text-[#78716C] mb-2"
        style="font-family: 'Inter', sans-serif;"
      >
        By {@resolved_maker}
      </p>
      <p
        class="text-sm font-medium text-[var(--theme-primary,#A0522D)] tabular-nums"
        style="font-family: 'Inter', sans-serif;"
      >
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>
    </a>
    """
  end

  # ── Footer ──

  @doc """
  Heritage footer with warm cream background, maker pledge, and grouped links.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer class="bg-[#F4E4C1]/40 border-t border-[#E7DDC7] mt-12">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8 lg:gap-10">
          <div class="lg:col-span-2">
            <p
              class="text-3xl sm:text-4xl text-[#1C1917] mb-4"
              style="font-family: 'Lora', serif;"
            >
              {@store.name}
            </p>
            <p
              :if={@store.description}
              class="text-sm text-[#78716C] leading-relaxed max-w-md"
              style="font-family: 'Inter', sans-serif;"
            >
              {String.slice(@store.description, 0, 200)}
            </p>
          </div>

          <div>
            <p
              class="text-[10px] font-medium tracking-[0.25em] uppercase text-[var(--theme-primary,#A0522D)] mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              The workshop
            </p>
            <ul
              class="space-y-2 text-sm text-[#57534E]"
              style="font-family: 'Inter', sans-serif;"
            >
              <li>
                <a href={"/s/#{@store.slug}/about"} class="hover:text-[#1C1917] transition-colors">
                  Our makers
                </a>
              </li>
              <li><a href="#" class="hover:text-[#1C1917] transition-colors">Behind the craft</a></li>
              <li><a href="#" class="hover:text-[#1C1917] transition-colors">Workshop visits</a></li>
            </ul>
          </div>

          <div>
            <p
              class="text-[10px] font-medium tracking-[0.25em] uppercase text-[var(--theme-primary,#A0522D)] mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              Care & service
            </p>
            <ul
              class="space-y-2 text-sm text-[#57534E]"
              style="font-family: 'Inter', sans-serif;"
            >
              <li><a href="#" class="hover:text-[#1C1917] transition-colors">Care guide</a></li>
              <li>
                <a href="#" class="hover:text-[#1C1917] transition-colors">Restoration & repair</a>
              </li>
              <li>
                <a href="#" class="hover:text-[#1C1917] transition-colors">Shipping & returns</a>
              </li>
              <li :if={Map.get(@store, :whatsapp_number)}>
                <a
                  href={"https://wa.me/#{normalise_whatsapp(@store.whatsapp_number)}"}
                  target="_blank"
                  rel="noopener"
                  class="hover:text-[#1C1917] transition-colors"
                >
                  Speak to a maker
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div class="mt-12 pt-6 border-t border-[#E7DDC7] flex flex-col sm:flex-row gap-3 sm:items-center sm:justify-between text-xs text-[#78716C]">
          <p style="font-family: 'Inter', sans-serif;">
            © {Date.utc_today().year} {@store.name}. Made by hand, kept for life.
          </p>
          <p style="font-family: 'Inter', sans-serif;">
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
  """
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  defp normalise_whatsapp(number) do
    number
    |> to_string()
    |> String.replace(~r/[^\d]/, "")
  end
end
