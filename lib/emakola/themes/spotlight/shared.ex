defmodule Emakola.Themes.Spotlight.Shared do
  @moduledoc """
  Shared Spotlight components: theme_styles (CSS vars + .spot-* classes),
  nav, footer, product_card, image + WhatsApp helpers, section_enabled?.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#16130F") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#7C3AED") %>;
        --theme-accent-dark: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent_dark]), "#6D28D9") %>;
        --theme-accent-soft: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent_soft]), "#EDE7FB") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#FBF9F5") %>;
      }
      .spot-body { font-family: 'Inter', sans-serif; color: #16130F; background: var(--theme-bg); }
      .spot-display { font-family: 'Archivo', 'Inter', sans-serif; font-weight: 800; letter-spacing: -0.02em; line-height: 0.95; }
      .spot-heading { font-family: 'Archivo', 'Inter', sans-serif; font-weight: 700; letter-spacing: -0.01em; }
      .spot-cta { background: var(--theme-accent); color: #fff; }
      .spot-cta:hover { background: var(--theme-accent-dark); }
      .spot-blob { background: var(--theme-accent-soft); filter: blur(8px); }
    </style>
    """
  end

  # ── Nav ──
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-[#FBF9F5]/85 backdrop-blur border-b border-[#ECE7DE]">
      <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 flex items-center justify-between h-16">
        <a
          href={store_path(@store.slug, "/")}
          class="spot-heading text-lg font-extrabold tracking-tight"
        >
          {@store.name}
        </a>
        <nav class="hidden md:flex items-center gap-7 text-sm text-[#6B675F]">
          <a href={store_path(@store.slug, "/products")} class="hover:text-[#16130F]">Product</a>
          <a href={store_path(@store.slug, "/") <> "#benefits"} class="hover:text-[#16130F]">
            Benefits
          </a>
          <a href={store_path(@store.slug, "/") <> "#ingredients"} class="hover:text-[#16130F]">
            Ingredients
          </a>
          <a href={store_path(@store.slug, "/") <> "#testimonials"} class="hover:text-[#16130F]">
            Reviews
          </a>
        </nav>
        <a
          href={store_path(@store.slug, "/cart")}
          class="relative inline-flex items-center gap-2 spot-cta rounded-full px-4 py-2 text-sm font-semibold"
          aria-label={"Cart, #{Emakola.Plural.count(@cart_count, "item")}"}
        >
          Cart
          <span class="inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 rounded-full bg-white/25 text-[11px] font-bold">
            {@cart_count}
          </span>
        </a>
      </div>
    </header>
    """
  end

  # ── Footer ──
  attr :store, :map, required: true

  def footer(assigns) do
    ~H"""
    <footer class="bg-white border-t border-[#ECE7DE] mt-20">
      <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-12 grid grid-cols-2 md:grid-cols-4 gap-8">
        <div class="col-span-2">
          <div class="spot-heading text-xl font-extrabold">{@store.name}</div>
          <p class="text-sm text-[#6B675F] mt-3 max-w-sm leading-relaxed">
            {@store.description ||
              "One product, done properly — delivered to your door."}
          </p>
        </div>
        <div>
          <h4 class="text-xs font-semibold uppercase tracking-wider mb-3">Shop</h4>
          <ul class="space-y-2 text-sm text-[#6B675F]">
            <li>
              <a href={store_path(@store.slug, "/products")} class="hover:text-[#16130F]">
                The product
              </a>
            </li>
            <li><a href={store_path(@store.slug, "/cart")} class="hover:text-[#16130F]">Cart</a></li>
          </ul>
        </div>
        <div>
          <h4 class="text-xs font-semibold uppercase tracking-wider mb-3">More</h4>
          <ul class="space-y-2 text-sm text-[#6B675F]">
            <li>
              <a href={store_path(@store.slug, "/about")} class="hover:text-[#16130F]">About</a>
            </li>
            <li>
              <a href={store_path(@store.slug, "/account")} class="hover:text-[#16130F]">
                Track order
              </a>
            </li>
          </ul>
        </div>
      </div>
      <div class="border-t border-[#ECE7DE]">
        <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-5 text-xs text-[#7A7468]">
          &copy; {DateTime.utc_now().year} {@store.name}. All rights reserved.
        </div>
      </div>
    </footer>
    """
  end

  # ── Helpers ──
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  def current_image(product, index) do
    case Enum.at(product.images, index) do
      %{medium_url: url} when is_binary(url) -> url
      %{url: url} when is_binary(url) -> url
      _ -> first_image(product)
    end
  end

  def whatsapp_number(store) do
    case Map.get(store, :whatsapp_number) do
      n when is_binary(n) ->
        digits = String.replace(n, ~r/\D/, "")
        if digits == "", do: nil, else: digits

      _ ->
        nil
    end
  end

  def whatsapp_link(store, product_title) do
    case whatsapp_number(store) do
      nil ->
        nil

      digits ->
        "https://wa.me/#{digits}?text=#{URI.encode_www_form("Hi! I'd like to order: #{product_title}")}"
    end
  end

  @doc "Section toggle: nil/absent → enabled; explicit false → disabled."
  def section_enabled?(theme, key) do
    case get_in(theme, [:sections, key]) do
      false -> false
      _ -> true
    end
  end

  # ── Product card ──
  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    ~H"""
    <a href={store_path(@store.slug, "/products/#{@product.slug}")} class="group block">
      <div class="rounded-2xl overflow-hidden bg-white border border-[#ECE7DE] aspect-square relative">
        <.optimized_image
          :if={first_image(@product)}
          src={first_image(@product)}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-500"
        />
        <div
          :if={!first_image(@product)}
          class="w-full h-full flex items-center justify-center bg-[#F3EFE8]"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            class="w-12 h-12 text-[#d8d0c2]"
            fill="currentColor"
            aria-hidden="true"
          >
            <path d="M3.6 5.4a1 1 0 0 1 .9-.6h15a1 1 0 0 1 .9.6l1.6 3.6a1 1 0 0 1-.1.94 3.5 3.5 0 0 1-2.9 1.56V19a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7.5a3.5 3.5 0 0 1-2.9-1.56 1 1 0 0 1-.1-.94l1.6-3.6Zm5.4 8.6h6v4H9v-4Z" />
          </svg>
        </div>
      </div>
      <div class="pt-3">
        <h3 class="spot-heading text-sm font-semibold line-clamp-1">{@product.title}</h3>
        <span class="text-sm font-bold text-[var(--theme-accent,#7C3AED)] mt-1 block">
          {EmakolaWeb.Helpers.Currency.format_price(
            @product.min_price || 0,
            Map.get(@store, :currency, "GHS")
          )}
        </span>
      </div>
    </a>
    """
  end
end
