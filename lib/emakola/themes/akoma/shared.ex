defmodule Emakola.Themes.Akoma.Shared do
  @moduledoc """
  Shared components for the Akoma theme: theme_styles (CSS vars + base classes),
  akoma_nav (minimal sticky header), akoma_footer, image helpers, product_card,
  and WhatsApp ordering helpers.
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#1A1A1A" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#2F5D50" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#F8F9F7" %>;
      }
      .akoma-body { font-family: 'Inter', sans-serif; color: #1A1A1A; background: var(--theme-bg); }
      .akoma-heading { font-family: 'Manrope', 'Inter', sans-serif; letter-spacing: -0.015em; }
      .akoma-card { background: #FFFFFF; border: 1px solid #E8EAE7; border-radius: 8px; }
    </style>
    """
  end

  # ── Nav ──

  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def akoma_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-white/90 backdrop-blur border-b border-[#E8EAE7]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <nav class="hidden md:flex items-center gap-6 text-sm text-[#6B7280] flex-1">
            <a href={"/s/#{@store.slug}/products"} class="hover:text-[#1A1A1A]">Shop</a>
            <a href={"/s/#{@store.slug}/products"} class="hover:text-[#1A1A1A]">New</a>
            <a href={"/s/#{@store.slug}/about"} class="hover:text-[#1A1A1A]">About</a>
          </nav>
          <a
            href={"/s/#{@store.slug}"}
            class="akoma-heading text-lg sm:text-xl font-extrabold tracking-[0.15em] uppercase text-[#1A1A1A] flex-1 text-center"
          >
            {@store.name}
          </a>
          <div class="flex items-center justify-end gap-3 flex-1">
            <a
              href={"/s/#{@store.slug}/account"}
              class="w-9 h-9 rounded-full hover:bg-[#F0F1EF] flex items-center justify-center"
              aria-label="Account"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                class="w-5 h-5 text-[#1A1A1A]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <circle cx="12" cy="8" r="4" /><path d="M4 21a8 8 0 0 1 16 0" />
              </svg>
            </a>
            <a
              href={"/s/#{@store.slug}/cart"}
              class="relative w-9 h-9 rounded-full hover:bg-[#F0F1EF] flex items-center justify-center"
              aria-label={"Cart, #{@cart_count} items"}
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                class="w-5 h-5 text-[#1A1A1A]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z" /><path d="M3 6h18M16 10a4 4 0 0 1-8 0" />
              </svg>
              <span
                :if={@cart_count > 0}
                class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 rounded-full bg-[#2F5D50] text-white text-[10px] font-bold flex items-center justify-center"
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

  # ── Footer ──

  attr :store, :map, required: true

  def akoma_footer(assigns) do
    ~H"""
    <footer class="bg-white border-t border-[#E8EAE7] mt-16">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-8">
          <div class="col-span-2">
            <div class="akoma-heading text-xl font-extrabold tracking-[0.12em] uppercase">
              {@store.name}
            </div>
            <p class="text-sm text-[#6B7280] leading-relaxed mt-3 max-w-sm">
              {@store.description ||
                "Thoughtfully made products, fairly priced — delivered across Ghana."}
            </p>
          </div>
          <div>
            <h4 class="text-xs font-semibold uppercase tracking-wider text-[#1A1A1A] mb-3">
              Shop
            </h4>
            <ul class="space-y-2 text-sm text-[#6B7280]">
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-[#1A1A1A]">
                  All products
                </a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/products"} class="hover:text-[#1A1A1A]">
                  New arrivals
                </a>
              </li>
            </ul>
          </div>
          <div>
            <h4 class="text-xs font-semibold uppercase tracking-wider text-[#1A1A1A] mb-3">
              Help
            </h4>
            <ul class="space-y-2 text-sm text-[#6B7280]">
              <li>
                <a href={"/s/#{@store.slug}/about"} class="hover:text-[#1A1A1A]">About</a>
              </li>
              <li>
                <a href={"/s/#{@store.slug}/track"} class="hover:text-[#1A1A1A]">
                  Track order
                </a>
              </li>
            </ul>
          </div>
        </div>
        <div class="border-t border-[#E8EAE7] mt-10 pt-6 text-xs text-[#9CA3AF]">
          &copy; {DateTime.utc_now().year} {@store.name}. All rights reserved.
        </div>
      </div>
    </footer>
    """
  end

  # ── Image helpers ──

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

  # ── WhatsApp ordering ──

  @doc "Digits-only phone or nil."
  def whatsapp_number(store) do
    case Map.get(store, :whatsapp_number) do
      n when is_binary(n) ->
        digits = String.replace(n, ~r/\D/, "")
        if digits == "", do: nil, else: digits

      _ ->
        nil
    end
  end

  @doc "wa.me link prefilled with the product title, or nil when the store has no number."
  def whatsapp_link(store, product_title) do
    case whatsapp_number(store) do
      nil ->
        nil

      digits ->
        "https://wa.me/#{digits}?text=#{URI.encode("Hi! I'd like to order: #{product_title}")}"
    end
  end

  # ── Product card ──

  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="akoma-card aspect-[3/4] overflow-hidden relative">
        <.optimized_image
          :if={first_image(@product)}
          src={first_image(@product)}
          alt={@product.title}
          class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-500"
        />
        <div
          :if={!first_image(@product)}
          class="w-full h-full flex items-center justify-center bg-[#F0F1EF]"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            class="w-12 h-12 text-[#CBD5C7]"
            fill="currentColor"
            aria-hidden="true"
          >
            <path d="M3.6 5.4a1 1 0 0 1 .9-.6h15a1 1 0 0 1 .9.6l1.6 3.6a1 1 0 0 1-.1.94 3.5 3.5 0 0 1-2.9 1.56V19a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7.5a3.5 3.5 0 0 1-2.9-1.56 1 1 0 0 1-.1-.94l1.6-3.6Zm5.4 8.6h6v4H9v-4Z" />
          </svg>
        </div>
      </div>
      <div class="pt-3">
        <h3 class="text-sm font-medium text-[#1A1A1A] line-clamp-1">{@product.title}</h3>
        <span class="text-sm font-semibold text-[#2F5D50] mt-1 block">
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
