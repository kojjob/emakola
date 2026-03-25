defmodule Emakola.Themes.Atelier.Shared do
  @moduledoc """
  Shared UI components for the Atelier premium fashion theme.

  Design language:
  - Fonts: Cormorant (serif headings), Montserrat (sans body)
  - Colors: Gold (#CA8A04), Stone (#1C1917), Surface (#FAFAF9)
  - All colors use CSS variables for merchant overrides
  - Clean, minimal, editorial aesthetic
  """
  use Phoenix.Component

  alias EmakolaWeb.Helpers.Currency

  # ── CSS Variables ──

  @doc """
  Injects Atelier theme CSS custom properties and base styles.
  Place this in the root layout when the Atelier theme is active.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= Map.get(@theme, :primary_color, "#CA8A04") %>;
        --theme-primary-light: <%= Map.get(@theme, :primary_light, "#EAB308") %>;
        --theme-primary-dark: <%= Map.get(@theme, :primary_dark, "#A16207") %>;
        --theme-accent: <%= Map.get(@theme, :accent_color, "#1C1917") %>;
        --theme-accent-secondary: <%= Map.get(@theme, :accent_secondary, "#44403C") %>;
        --theme-surface: <%= Map.get(@theme, :surface_color, "#FAFAF9") %>;
        --theme-ink: <%= Map.get(@theme, :ink_color, "#0C0A09") %>;
        --theme-font-serif: '<%= Map.get(@theme, :serif_font, "Cormorant") %>', serif;
        --theme-font-sans: '<%= Map.get(@theme, :sans_font, "Montserrat") %>', system-ui, sans-serif;
      }
      .atelier-serif { font-family: var(--theme-font-serif); }
      .atelier-sans { font-family: var(--theme-font-sans); }
      .atelier-body { font-family: var(--theme-font-sans); color: var(--theme-ink); background: var(--theme-surface); -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; }
      .atelier-nav-scrolled { background: rgba(255,255,255,0.97); backdrop-filter: blur(12px); box-shadow: 0 1px 0 rgba(0,0,0,0.06); }
      .atelier-nav-scrolled .atelier-nav-link,
      .atelier-nav-scrolled .atelier-nav-icon { color: var(--theme-accent) !important; }
      .atelier-nav-scrolled .atelier-nav-logo { color: var(--theme-accent) !important; }
      .atelier-category-card:hover .atelier-category-overlay { opacity: 1; }
      .atelier-category-card:hover img { transform: scale(1.05); }
      .atelier-product-card:hover img { transform: scale(1.05); }
      .atelier-product-card:hover .atelier-heart-btn { opacity: 1; }
    </style>
    """
  end

  # ── Navigation ──

  @doc """
  Atelier transparent navigation bar that becomes white on scroll.
  Uses JS hook for scroll detection.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0
  attr :transparent, :boolean, default: true

  def navbar(assigns) do
    ~H"""
    <nav
      id="atelier-navbar"
      class={"fixed top-0 left-0 right-0 z-50 transition-all duration-500" <> unless(@transparent, do: " atelier-nav-scrolled", else: "")}
      phx-hook="ScrollGlass"
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-20">
          <%!-- Logo --%>
          <a
            href={"/s/#{@store.slug}"}
            class="atelier-nav-logo text-white transition-colors duration-500 atelier-serif text-2xl font-semibold tracking-[0.3em]"
          >
            {String.upcase(@store.name)}
          </a>

          <%!-- Center Links (Desktop) --%>
          <div class="hidden lg:flex items-center gap-8">
            <a
              :for={category <- Enum.take(@categories, 5)}
              href={"/s/#{@store.slug}/category/#{category.slug}"}
              class="atelier-nav-link text-white/90 hover:text-white text-xs font-medium uppercase tracking-widest transition-colors duration-300"
            >
              {category.name}
            </a>
          </div>

          <%!-- Right Icons --%>
          <div class="flex items-center gap-5">
            <%!-- Search --%>
            <a
              href={"/s/#{@store.slug}/products"}
              class="atelier-nav-icon text-white transition-colors duration-500"
              aria-label="Search"
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
            </a>

            <%!-- Wishlist --%>
            <a
              href={"/s/#{@store.slug}/wishlist"}
              class="atelier-nav-icon text-white transition-colors duration-500 hidden sm:block"
              aria-label="Wishlist"
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z" />
              </svg>
            </a>

            <%!-- Cart --%>
            <a
              href={"/s/#{@store.slug}/cart"}
              class="atelier-nav-icon text-white transition-colors duration-500 relative"
              aria-label={"Shopping cart, #{@cart_count} items"}
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z" />
                <line x1="3" y1="6" x2="21" y2="6" />
                <path d="M16 10a4 4 0 01-8 0" />
              </svg>
              <span
                :if={@cart_count > 0}
                class="absolute -top-1 -right-1 w-4 h-4 text-[10px] font-bold rounded-full flex items-center justify-center"
                style="background: var(--theme-primary); color: var(--theme-accent);"
              >
                {@cart_count}
              </span>
            </a>

            <%!-- Account --%>
            <a
              href={"/s/#{@store.slug}/account"}
              class="atelier-nav-icon text-white transition-colors duration-500 hidden sm:block"
              aria-label="Account"
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" /><circle cx="12" cy="7" r="4" />
              </svg>
            </a>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  # ── Product Card ──

  @doc """
  Atelier product card with 5:6 aspect ratio, hover heart, star ratings,
  and New/Sale badges.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    assigns =
      assigns
      |> assign(:image, first_image(assigns.product))
      |> assign(:badge, product_badge(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="atelier-product-card group block"
    >
      <div class="relative overflow-hidden bg-stone-100 aspect-[5/6] mb-3 sm:mb-4">
        <img
          :if={@image}
          src={@image}
          alt={@product.title}
          loading="lazy"
          class="w-full h-full object-cover transition-transform duration-700"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center bg-stone-100">
          <.image_placeholder />
        </div>

        <%!-- Badge --%>
        <span
          :if={@badge == :new}
          class="absolute top-3 left-3 text-white text-[10px] font-bold uppercase tracking-wider px-2.5 py-1"
          style="background: var(--theme-accent);"
        >
          New
        </span>
        <span
          :if={@badge == :sale}
          class="absolute top-3 left-3 text-[10px] font-bold uppercase tracking-wider px-2.5 py-1"
          style="background: var(--theme-primary); color: var(--theme-accent);"
        >
          Sale
        </span>

        <%!-- Heart button --%>
        <button
          class="atelier-heart-btn absolute top-3 right-3 w-9 h-9 bg-white/90 rounded-full flex items-center justify-center opacity-0 transition-opacity duration-300 hover:bg-white"
          aria-label="Add to wishlist"
          phx-click="toggle_wishlist"
          phx-value-product-id={@product.id}
        >
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke-width="1.5"
            style="stroke: var(--theme-accent);"
          >
            <path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z" />
          </svg>
        </button>
      </div>

      <div class="px-1">
        <h3 class="text-sm font-medium leading-snug mb-1" style="color: var(--theme-ink);">
          {@product.title}
        </h3>
        <.star_rating rating={4.5} />
        <.price_display product={@product} store={@store} />
      </div>
    </a>
    """
  end

  # ── Category Card ──

  @doc """
  Category card with image overlay and serif text for the masonry grid.
  """
  attr :category, :map, required: true
  attr :store, :map, required: true
  attr :class, :string, default: ""
  attr :image_url, :string, default: nil

  def category_card(assigns) do
    image = assigns.image_url || category_image(assigns.category)
    assigns = assign(assigns, :image, image)

    ~H"""
    <a
      href={"/s/#{@store.slug}/category/#{@category.slug}"}
      class={"atelier-category-card relative overflow-hidden group cursor-pointer " <> @class}
    >
      <img
        :if={@image}
        src={@image}
        alt={@category.name}
        class="absolute inset-0 w-full h-full object-cover transition-transform duration-700"
        loading="lazy"
      />
      <div :if={!@image} class="absolute inset-0 w-full h-full bg-stone-300"></div>
      <div class="atelier-category-overlay absolute inset-0 bg-black/40 opacity-0 transition-opacity duration-500">
      </div>
      <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent">
      </div>
      <div class="absolute bottom-0 left-0 p-5 sm:p-6">
        <h3 class="atelier-serif text-2xl sm:text-3xl text-white font-semibold mb-1">
          {@category.name}
        </h3>
        <span
          class="text-white/80 text-xs font-medium uppercase tracking-widest transition-colors"
          style="group-hover:color: var(--theme-primary);"
        >
          Explore
          <svg
            class="inline ml-1 w-3 h-3"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M5 12h14M12 5l7 7-7 7" />
          </svg>
        </span>
      </div>
    </a>
    """
  end

  # ── Star Rating ──

  attr :rating, :float, default: 0.0

  def star_rating(assigns) do
    full_stars = trunc(assigns.rating)
    has_half = assigns.rating - full_stars >= 0.5
    empty_stars = 5 - full_stars - if(has_half, do: 1, else: 0)

    assigns =
      assigns
      |> assign(:full_stars, full_stars)
      |> assign(:has_half, has_half)
      |> assign(:empty_stars, empty_stars)

    ~H"""
    <div class="flex items-center gap-1 mb-1.5">
      <div class="flex items-center" style="color: var(--theme-primary);">
        <svg :for={_ <- 1..@full_stars} width="12" height="12" viewBox="0 0 24 24" fill="currentColor">
          <polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26" />
        </svg>
        <svg
          :if={@has_half}
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="currentColor"
          opacity="0.6"
        >
          <polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26" />
        </svg>
        <svg
          :for={_ <- 1..max(@empty_stars, 0)}
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="currentColor"
          opacity="0.25"
        >
          <polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26" />
        </svg>
      </div>
      <span class="text-[10px]" style="color: var(--theme-accent-secondary, #44403C);">
        {Float.round(@rating, 1)}
      </span>
    </div>
    """
  end

  # ── Price Display ──

  attr :product, :map, required: true
  attr :store, :map, required: true

  def price_display(assigns) do
    has_sale =
      assigns.product.min_price && assigns.product.max_price &&
        assigns.product.min_price < assigns.product.max_price

    assigns = assign(assigns, :has_sale, has_sale)

    ~H"""
    <div class="flex items-center gap-2">
      <p class="text-sm font-semibold tabular-nums" style="color: var(--theme-ink);">
        {Currency.format_price(@product.min_price || 0, @store.currency)}
      </p>
      <p
        :if={@has_sale}
        class="text-xs line-through tabular-nums opacity-50"
        style="color: var(--theme-accent-secondary, #44403C);"
      >
        {Currency.format_price(@product.max_price, @store.currency)}
      </p>
    </div>
    """
  end

  # ── Footer ──

  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer style="background: var(--theme-accent); color: rgba(255,255,255,0.7);">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-14 sm:py-20">
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-10 sm:gap-8">
          <%!-- Brand --%>
          <div class="col-span-2 sm:col-span-1">
            <a
              href={"/s/#{@store.slug}"}
              class="inline-block atelier-serif text-xl font-semibold tracking-[0.3em] text-white mb-4"
            >
              {String.upcase(@store.name)}
            </a>
            <p class="text-white/50 text-xs leading-relaxed mb-6 max-w-xs">
              {if @store.description,
                do: @store.description,
                else: "Modern luxury fashion, crafted with intention."}
            </p>
          </div>

          <%!-- Shop --%>
          <div>
            <h4 class="text-white text-[11px] font-semibold uppercase tracking-widest mb-5">Shop</h4>
            <ul class="space-y-3">
              <li :for={category <- Enum.take(@categories, 5)}>
                <a
                  href={"/s/#{@store.slug}/category/#{category.slug}"}
                  class="text-white/50 hover:text-white text-xs transition-colors"
                >
                  {category.name}
                </a>
              </li>
            </ul>
          </div>

          <%!-- Help --%>
          <div>
            <h4 class="text-white text-[11px] font-semibold uppercase tracking-widest mb-5">Help</h4>
            <ul class="space-y-3">
              <li>
                <a
                  :if={Map.get(@store, :whatsapp_number)}
                  href={"https://wa.me/#{@store.whatsapp_number}"}
                  class="text-white/50 hover:text-white text-xs transition-colors"
                >
                  Contact Us
                </a>
              </li>
              <li><span class="text-white/50 text-xs">Shipping &amp; Returns</span></li>
              <li><span class="text-white/50 text-xs">Size Guide</span></li>
              <li><span class="text-white/50 text-xs">FAQ</span></li>
            </ul>
          </div>

          <%!-- About --%>
          <div>
            <h4 class="text-white text-[11px] font-semibold uppercase tracking-widest mb-5">About</h4>
            <ul class="space-y-3">
              <li><span class="text-white/50 text-xs">Our Story</span></li>
              <li><span class="text-white/50 text-xs">Sustainability</span></li>
            </ul>
          </div>
        </div>

        <%!-- Bottom --%>
        <div class="border-t border-white/10 mt-12 pt-8 flex flex-col sm:flex-row items-center justify-between gap-6">
          <p class="text-white/40 text-xs">
            &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
          <p class="text-white/30 text-[10px]">
            Powered by Emakola
          </p>
        </div>
      </div>
    </footer>
    """
  end

  # ── Image Placeholder ──

  def image_placeholder(assigns) do
    ~H"""
    <svg class="w-12 h-12 text-stone-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1"
        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
      />
    </svg>
    """
  end

  # ── Helpers ──

  @doc "Extract first image URL from a product's images association."
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  defp product_badge(product) do
    cond do
      Map.get(product, :status) == :new -> :new
      product.min_price && product.max_price && product.min_price < product.max_price -> :sale
      true -> nil
    end
  end

  defp category_image(category) do
    if Map.has_key?(category, :image_url), do: category.image_url, else: nil
  end
end
