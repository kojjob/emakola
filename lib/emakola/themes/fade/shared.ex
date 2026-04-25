defmodule Emakola.Themes.Fade.Shared do
  @moduledoc """
  Shared components for the Fade theme.

  Drop-driven streetwear design with:
  - Near-black (#0A0A0A) background — full dark mode by default
  - Off-white (#FAFAFA) text and primary CTAs
  - Neon green (#00FF85) accent for drop counters and scarcity
  - Space Grotesk uppercase headlines + Inter body + JetBrains Mono numerals
  - drop_card with stock chip and sold-out state
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── Theme Styles ──

  @doc """
  Injects a <style> block with CSS custom properties for the Fade theme.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#FAFAFA" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#00FF85" %>;
        --theme-highlight: <%= get_in(@theme, [:colors, :highlight]) || "#1F1F1F" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#0A0A0A" %>;
      }
    </style>
    """
  end

  # ── Fade Nav Bar ──

  @doc """
  Hard-edged dark nav with all-caps wordmark and minimal action links.
  No accent stripe — pure black bar.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def fade_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-[#0A0A0A] border-b border-[#1F1F1F]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-14 sm:h-16">
          <a href={"/s/#{@store.slug}"} class="flex items-center min-w-0">
            <span
              class="text-base sm:text-lg font-bold text-white tracking-[0.05em] uppercase truncate"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              {@store.name}
            </span>
          </a>

          <div class="flex items-center gap-4 sm:gap-6">
            <a
              href={"/s/#{@store.slug}/products"}
              class="hidden sm:inline-flex text-[11px] font-semibold uppercase tracking-[0.2em] text-white hover:text-[var(--theme-accent,#00FF85)] transition-colors"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              Drops
            </a>
            <a
              href={"/s/#{@store.slug}/about"}
              class="hidden sm:inline-flex text-[11px] font-semibold uppercase tracking-[0.2em] text-white hover:text-[var(--theme-accent,#00FF85)] transition-colors"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              About
            </a>
            <a
              href={"/s/#{@store.slug}/cart"}
              class="relative inline-flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-[0.2em] text-white hover:text-[var(--theme-accent,#00FF85)] transition-colors"
              style="font-family: 'Space Grotesk', sans-serif;"
              aria-label={"Bag, #{@cart_count} items"}
            >
              Bag
              <span
                class="text-[10px] font-bold tabular-nums text-[var(--theme-accent,#00FF85)]"
                style="font-family: 'JetBrains Mono', monospace;"
              >
                [{@cart_count}]
              </span>
            </a>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ── Drop Card ──

  @doc """
  Square dark drop_card with stock chip overlay and sold-out state.
  Stock chip glows neon when low (≤ 5).
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :stock, :integer, default: nil
  attr :badge, :string, default: nil

  def drop_card(assigns) do
    assigns =
      assigns
      |> assign(:image, first_image(assigns.product))
      |> assign(:sold_out, assigns.stock != nil and assigns.stock <= 0)

    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="relative aspect-square overflow-hidden mb-3 bg-[#1F1F1F]">
        <%= if @image do %>
          <.optimized_image
            src={@image}
            alt={@product.title}
            class={"w-full h-full object-cover transition-transform duration-500 #{if @sold_out, do: "opacity-40 grayscale", else: "group-hover:scale-[1.04]"}"}
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center">
            <span class="material-symbols-outlined text-5xl text-[#404040]">checkroom</span>
          </div>
        <% end %>

        <%= cond do %>
          <% @sold_out -> %>
            <span
              class="absolute top-3 left-3 inline-flex items-center px-2.5 py-1 bg-[#FAFAFA] text-[#0A0A0A] text-[10px] font-bold uppercase tracking-[0.15em]"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              Sold out
            </span>
          <% is_integer(@stock) and @stock <= 5 -> %>
            <span
              class="absolute top-3 left-3 inline-flex items-center gap-1 px-2.5 py-1 bg-[var(--theme-accent,#00FF85)] text-[#0A0A0A] text-[10px] font-bold uppercase tracking-[0.15em]"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              <span style="font-family: 'JetBrains Mono', monospace;">{@stock}</span> left
            </span>
          <% @badge -> %>
            <span
              class="absolute top-3 left-3 inline-flex items-center px-2.5 py-1 bg-[#FAFAFA] text-[#0A0A0A] text-[10px] font-bold uppercase tracking-[0.15em]"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              {@badge}
            </span>
          <% true -> %>
            <span></span>
        <% end %>
      </div>

      <p
        class="text-sm font-bold text-white uppercase tracking-[0.05em] mb-1 truncate"
        style="font-family: 'Space Grotesk', sans-serif;"
      >
        {@product.title}
      </p>
      <p
        class={[
          "text-sm tabular-nums",
          if(@sold_out, do: "text-[#525252] line-through", else: "text-[var(--theme-accent,#00FF85)]")
        ]}
        style="font-family: 'JetBrains Mono', monospace;"
      >
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>
    </a>
    """
  end

  # ── Footer ──

  @doc """
  Minimal dark footer — drops calendar, returns, contact. Hard edges,
  no gradients, no warmth.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer class="bg-[#0A0A0A] border-t border-[#1F1F1F] mt-12">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8">
          <div class="lg:col-span-2">
            <p
              class="text-3xl text-white mb-4 uppercase tracking-[0.05em]"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              {@store.name}
            </p>
            <p
              :if={@store.description}
              class="text-sm text-[#A3A3A3] leading-relaxed max-w-md"
              style="font-family: 'Inter', sans-serif;"
            >
              {String.slice(@store.description, 0, 180)}
            </p>
          </div>

          <div>
            <p
              class="text-[10px] font-bold tracking-[0.25em] uppercase text-[var(--theme-accent,#00FF85)] mb-3"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              The shop
            </p>
            <ul class="space-y-2 text-sm text-[#A3A3A3]" style="font-family: 'Inter', sans-serif;">
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-white transition-colors">
                  Drops
                </a>
              </li>
              <li><a href="#" class="hover:text-white transition-colors">Drops calendar</a></li>
              <li><a href="#" class="hover:text-white transition-colors">Sizing guide</a></li>
            </ul>
          </div>

          <div>
            <p
              class="text-[10px] font-bold tracking-[0.25em] uppercase text-[var(--theme-accent,#00FF85)] mb-3"
              style="font-family: 'Space Grotesk', sans-serif;"
            >
              Help
            </p>
            <ul class="space-y-2 text-sm text-[#A3A3A3]" style="font-family: 'Inter', sans-serif;">
              <li><a href="#" class="hover:text-white transition-colors">Returns</a></li>
              <li><a href="#" class="hover:text-white transition-colors">Shipping</a></li>
              <li :if={Map.get(@store, :contact_email)}>
                <a
                  href={"mailto:#{@store.contact_email}"}
                  class="hover:text-white transition-colors"
                >
                  {@store.contact_email}
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div class="mt-12 pt-6 border-t border-[#1F1F1F] flex flex-col sm:flex-row gap-3 sm:items-center sm:justify-between text-[10px] uppercase tracking-[0.2em] text-[#525252]">
          <p style="font-family: 'Space Grotesk', sans-serif;">
            © {Date.utc_today().year} {@store.name}
          </p>
          <p style="font-family: 'Space Grotesk', sans-serif;">
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
end
