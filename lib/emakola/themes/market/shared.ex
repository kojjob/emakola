defmodule Emakola.Themes.Market.Shared do
  @moduledoc """
  Shared helper functions for the Market theme.

  Provides image extraction and other utilities used across
  the home, product list, and product detail renderers.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  # ── Footer (delegated) ──

  defdelegate footer(assigns), to: Emakola.Themes.Market.Footer

  # ── Top Navigation ──

  @doc """
  Market's own banner header — warm stone chrome for the Stall elevation.

  Store identity linking home, desktop category links, search (a plain link
  to the products page — no client event to crash on), and the cart link
  carrying the live item count. Sticky so the cart stays one tap away while
  scrolling a long grid on a phone.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def market_nav(assigns) do
    ~H"""
    <header
      role="banner"
      class="sticky top-0 z-50 border-b border-stone-200 bg-white/95 backdrop-blur"
    >
      <div class="mx-auto max-w-[1280px] px-4 sm:px-6 lg:px-8">
        <div class="flex h-14 items-center justify-between gap-3 sm:h-16">
          <a
            href={store_path(@store.slug, "/")}
            class="flex min-w-0 items-center gap-2.5 rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2"
          >
            <span
              class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-stone-100 to-stone-200 text-sm font-bold text-stone-600 [font-family:var(--dt-heading-font,inherit)]"
              aria-hidden="true"
            >
              {String.first(@store.name)}
            </span>
            <span class="truncate text-base font-bold tracking-tight text-stone-900 [font-family:var(--dt-heading-font,inherit)] sm:text-lg">
              {@store.name}
            </span>
          </a>

          <nav
            :if={@categories != []}
            class="hidden min-w-0 flex-1 items-center justify-center gap-6 md:flex"
            aria-label="Categories"
          >
            <a
              :for={category <- Enum.take(@categories, 5)}
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class="whitespace-nowrap rounded text-sm font-medium text-stone-600 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 focus-visible:ring-offset-2 motion-safe:transition-colors"
            >
              {category.name}
            </a>
          </nav>

          <div class="flex flex-shrink-0 items-center gap-0.5">
            <a
              href={store_path(@store.slug, "/products")}
              aria-label="Search products"
              class="flex h-11 w-11 items-center justify-center rounded-full text-stone-600 hover:bg-stone-100 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 motion-safe:transition-colors"
            >
              <svg
                class="h-[22px] w-[22px]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.8"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
                />
              </svg>
            </a>
            <a
              href={store_path(@store.slug, "/cart")}
              aria-label={"Shopping cart, #{@cart_count} items"}
              class="relative flex h-11 w-11 items-center justify-center rounded-full text-stone-600 hover:bg-stone-100 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900 motion-safe:transition-colors"
            >
              <svg
                class="h-[22px] w-[22px]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.8"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
                />
              </svg>
              <span
                :if={@cart_count > 0}
                class="absolute right-0.5 top-0.5 flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-stone-900 px-1 text-[10px] font-bold leading-none text-white"
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

  # ── Mobile Bottom Navigation ──

  @doc """
  Market-owned mobile tab bar — Home, Search, Saved, Cart in the warm
  stone palette. Home chrome, so the Home tab is always current.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def market_bottom_nav(assigns) do
    ~H"""
    <nav
      class="safe-area-inset-bottom fixed inset-x-0 bottom-0 z-40 border-t border-stone-200 bg-white sm:hidden"
      aria-label="Store"
    >
      <div class="flex h-14 items-center justify-around">
        <a
          href={store_path(@store.slug, "/")}
          aria-current="page"
          class="flex flex-col items-center gap-0.5 rounded px-3 py-1 text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900"
        >
          <svg
            class="h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"
            />
          </svg>
          <span class="text-[0.625rem] font-semibold">Home</span>
        </a>
        <a
          href={store_path(@store.slug, "/products")}
          class="flex flex-col items-center gap-0.5 rounded px-3 py-1 text-stone-400 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900"
        >
          <svg
            class="h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
            />
          </svg>
          <span class="text-[0.625rem] font-medium">Search</span>
        </a>
        <a
          href={store_path(@store.slug, "/wishlist")}
          class="flex flex-col items-center gap-0.5 rounded px-3 py-1 text-stone-400 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900"
        >
          <svg
            class="h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
            />
          </svg>
          <span class="text-[0.625rem] font-medium">Saved</span>
        </a>
        <a
          href={store_path(@store.slug, "/cart")}
          class="relative flex flex-col items-center gap-0.5 rounded px-3 py-1 text-stone-400 hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-900"
          aria-label={"Cart, #{@cart_count} items"}
        >
          <span class="relative">
            <svg
              class="h-6 w-6"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.5"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
              />
            </svg>
            <span
              :if={@cart_count > 0}
              class="absolute -right-1.5 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-stone-900 px-0.5 text-[0.5rem] font-bold leading-none text-white"
            >
              {@cart_count}
            </span>
          </span>
          <span class="text-[0.625rem] font-medium">Cart</span>
        </a>
      </div>
    </nav>
    """
  end

  # ── CSS Variable Injection ──

  @doc """
  Injects theme CSS custom properties into the page as a <style> block.
  Place this as the first element inside the outermost div of each page.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#1C1917") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#B45309") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#FAFAF9") %>;
      }
    </style>
    """
  end

  @doc """
  Extract the first image URL from a product's images association.
  Returns thumbnail_url if available, falls back to url, then nil.
  """
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  @doc """
  Get the image at a specific index from a product's images.
  Falls back to medium_url, then url, then first_image.
  """
  def current_image(product, index) do
    case Enum.at(product.images, index) do
      %{medium_url: url} when is_binary(url) -> url
      %{url: url} when is_binary(url) -> url
      _ -> first_image(product)
    end
  end

  @doc """
  Extract image URL from a category, if available.
  """
  def category_image(category) do
    if Map.has_key?(category, :image_url) do
      category.image_url
    else
      nil
    end
  end

  @doc """
  wa.me link to the store's WhatsApp number prefilled with the product
  title, or nil when the store has no number.
  """
  def whatsapp_link(store, product_title) do
    case Map.get(store, :whatsapp_number) do
      number when is_binary(number) ->
        digits = String.replace(number, ~r/\D/, "")

        if digits == "" do
          nil
        else
          message = "Hi, I'm interested in #{product_title} from #{Map.get(store, :name)}"
          "https://wa.me/#{digits}?text=#{URI.encode_www_form(message)}"
        end

      _ ->
        nil
    end
  end
end
