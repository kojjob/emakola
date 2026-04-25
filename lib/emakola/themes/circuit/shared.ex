defmodule Emakola.Themes.Circuit.Shared do
  @moduledoc """
  Shared components for the Circuit theme.

  Minimal tech retail design with:
  - Dark blue-tinted near-black (#0F0F12) background
  - White text + electric blue accent for spec moments
  - Inter throughout, JetBrains Mono for spec values
  - device_card with tech badges and "Notify me" sold-out state
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── Theme Styles ──

  @doc """
  Injects a <style> block with CSS custom properties for the Circuit theme.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#FFFFFF" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#3B82F6" %>;
        --theme-highlight: <%= get_in(@theme, [:colors, :highlight]) || "#1A1A1F" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#0F0F12" %>;
      }
    </style>
    """
  end

  # ── Circuit Nav Bar ──

  @doc """
  Apple-style minimal nav. Wordmark left, ghost links centred, action icons right.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def circuit_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-[#0F0F12]/95 backdrop-blur-md border-b border-[#27272A]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-14 sm:h-16">
          <a href={"/s/#{@store.slug}"} class="flex items-center min-w-0">
            <span
              class="text-base font-semibold text-white tracking-tight truncate"
              style="font-family: 'Inter', sans-serif;"
            >
              {@store.name}
            </span>
          </a>

          <nav class="hidden md:flex items-center gap-7" aria-label="Primary">
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-sm text-[#9CA3AF] hover:text-white transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
              All devices
            </a>
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-sm text-[#9CA3AF] hover:text-white transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
              Compare
            </a>
            <a
              href={"/s/#{@store.slug}/about"}
              class="text-sm text-[#9CA3AF] hover:text-white transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
              Support
            </a>
          </nav>

          <div class="flex items-center gap-1">
            <a
              href={"/s/#{@store.slug}/products"}
              class="p-2.5 text-[#9CA3AF] hover:text-white transition-colors"
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
              class="relative p-2.5 text-[#9CA3AF] hover:text-white transition-colors"
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
                class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-[var(--theme-accent,#3B82F6)] text-white text-[10px] font-semibold rounded-full flex items-center justify-center px-1"
                style="font-family: 'JetBrains Mono', monospace;"
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

  # ── Device Card ──

  @doc """
  Square device card with light frame for product photography, optional
  spec preview line, and tech badges (5G, USB-C, etc.). Renders a
  "Notify me" CTA when stock is 0.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :spec_preview, :string, default: nil
  attr :badges, :list, default: []
  attr :stock, :integer, default: nil

  def device_card(assigns) do
    assigns =
      assigns
      |> assign(:image, first_image(assigns.product))
      |> assign(:sold_out, assigns.stock != nil and assigns.stock <= 0)

    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="relative aspect-square overflow-hidden mb-4 bg-[#1A1A1F] rounded-2xl">
        <%= if @image do %>
          <.optimized_image
            src={@image}
            alt={@product.title}
            class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-[1.03]"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center">
            <span class="material-symbols-outlined text-5xl text-[#3F3F46]">smartphone</span>
          </div>
        <% end %>

        <div :if={@badges != []} class="absolute top-3 left-3 flex flex-wrap gap-1.5">
          <span
            :for={badge <- Enum.take(@badges, 3)}
            class="inline-flex items-center px-2 py-0.5 rounded-md bg-[#0F0F12]/80 backdrop-blur-sm text-[10px] font-medium text-white tracking-wide"
            style="font-family: 'JetBrains Mono', monospace;"
          >
            {badge}
          </span>
        </div>
      </div>

      <p
        class="text-sm font-semibold text-white mb-1 truncate"
        style="font-family: 'Inter', sans-serif;"
      >
        {@product.title}
      </p>
      <p
        :if={@spec_preview}
        class="text-xs text-[#9CA3AF] mb-2 truncate"
        style="font-family: 'Inter', sans-serif;"
      >
        {@spec_preview}
      </p>
      <div class="flex items-center justify-between">
        <p
          class="text-sm font-semibold text-white tabular-nums"
          style="font-family: 'JetBrains Mono', monospace;"
        >
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span
          :if={@sold_out}
          class="text-[10px] uppercase tracking-[0.15em] text-[var(--theme-accent,#3B82F6)]"
          style="font-family: 'Inter', sans-serif;"
        >
          Notify me →
        </span>
      </div>
    </a>
    """
  end

  # ── Footer ──

  @doc """
  Minimal dark Apple-style footer — links grouped, quiet copyright.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer class="bg-[#0F0F12] border-t border-[#27272A] mt-12">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-8">
          <div>
            <p
              class="text-xs font-semibold tracking-wide uppercase text-white mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              Shop
            </p>
            <ul class="space-y-2 text-sm text-[#9CA3AF]" style="font-family: 'Inter', sans-serif;">
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  All devices
                </a>
              </li>
              <li><a href="#" class="hover:text-white transition-colors">Compare</a></li>
              <li><a href="#" class="hover:text-white transition-colors">Accessories</a></li>
            </ul>
          </div>

          <div>
            <p
              class="text-xs font-semibold tracking-wide uppercase text-white mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              Support
            </p>
            <ul class="space-y-2 text-sm text-[#9CA3AF]" style="font-family: 'Inter', sans-serif;">
              <li><a href="#" class="hover:text-white transition-colors">Setup guide</a></li>
              <li><a href="#" class="hover:text-white transition-colors">Warranty</a></li>
              <li><a href="#" class="hover:text-white transition-colors">Returns</a></li>
              <li :if={Map.get(@store, :whatsapp_number)}>
                <a
                  href={"https://wa.me/#{normalise_whatsapp(@store.whatsapp_number)}"}
                  target="_blank"
                  rel="noopener"
                  class="hover:text-white transition-colors"
                >
                  Tech support
                </a>
              </li>
            </ul>
          </div>

          <div>
            <p
              class="text-xs font-semibold tracking-wide uppercase text-white mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              About
            </p>
            <ul class="space-y-2 text-sm text-[#9CA3AF]" style="font-family: 'Inter', sans-serif;">
              <li>
                <a href={"/s/#{@store.slug}/about"} class="hover:text-white transition-colors">
                  About us
                </a>
              </li>
              <li><a href="#" class="hover:text-white transition-colors">Authenticity</a></li>
              <li :if={Map.get(@store, :contact_email)}>
                <a
                  href={"mailto:#{@store.contact_email}"}
                  class="hover:text-white transition-colors"
                >
                  Contact
                </a>
              </li>
            </ul>
          </div>

          <div>
            <p
              class="text-xs font-semibold tracking-wide uppercase text-white mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              Pay with
            </p>
            <div class="flex flex-wrap gap-1.5">
              <span class="inline-flex items-center px-2 py-1 rounded bg-[#FFC107] text-[#0F0F12] text-[10px] font-bold">
                MoMo
              </span>
              <span class="inline-flex items-center px-2 py-1 rounded bg-[#E60000] text-white text-[10px] font-bold">
                Vodafone
              </span>
              <span class="inline-flex items-center px-2 py-1 rounded bg-white text-[#0F0F12] text-[10px] font-bold">
                Card
              </span>
            </div>
          </div>
        </div>

        <div
          class="mt-12 pt-6 border-t border-[#27272A] text-xs text-[#52525B]"
          style="font-family: 'Inter', sans-serif;"
        >
          © {Date.utc_today().year} {@store.name}. Powered by Emakola.
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
