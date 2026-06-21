defmodule Emakola.Themes.Starter.Shared do
  @moduledoc """
  Shared components for the Starter theme.

  Clean, modern, minimal design with:
  - White (#FFFFFF) background
  - Indigo (#6366F1) primary / slate-dark (#1E293B) accent
  - Inter font throughout
  - Soft shadows, rounded-2xl cards, generous white space
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── Theme Styles ──

  @doc """
  Injects a <style> block that defines CSS custom properties for the Starter theme.
  Call once near the top of any page that uses Starter theme components.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#6366F1") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#1E293B") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#FFFFFF") %>;
      }
    </style>
    """
  end

  # ── Starter Nav Bar ──

  @doc """
  Clean, minimal top navigation. White background, store name left,
  search + cart icons right.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def starter_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-white border-b border-gray-100 shadow-sm">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-14 sm:h-16">
          <a href={"/@#{@store.slug}"} class="flex items-center gap-2.5 min-w-0">
            <span
              class="text-base sm:text-lg font-semibold text-[#0F172A] truncate"
              style="font-family: 'Inter', sans-serif;"
            >
              {@store.name}
            </span>
          </a>

          <div class="flex items-center gap-1">
            <a
              href={"/@#{@store.slug}/products"}
              class="p-2.5 rounded-xl hover:bg-gray-50 transition-colors"
              aria-label="Search products"
            >
              <svg
                class="w-5 h-5 text-[#64748B]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
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
              href={"/@#{@store.slug}/cart"}
              class="relative p-2.5 rounded-xl hover:bg-gray-50 transition-colors"
              aria-label={"Shopping cart, #{@cart_count} items"}
            >
              <svg
                class="w-5 h-5 text-[#64748B]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
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
                class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-[var(--theme-primary,#6366F1)] text-white text-[10px] font-bold rounded-full flex items-center justify-center px-1"
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

  # ── Product Card ──

  @doc """
  Minimal product card with white background, soft shadow, rounded-2xl.
  Subtle lift on hover.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <a href={"/@#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="relative rounded-2xl overflow-hidden mb-3 bg-gray-50 shadow-sm group-hover:shadow-md group-hover:-translate-y-0.5 transition-all duration-300">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          class="w-full aspect-[3/4] object-cover"
        />
        <div :if={!@image} class="w-full aspect-[3/4] flex items-center justify-center bg-gray-100">
          <svg class="w-12 h-12 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
        </div>
      </div>
      <p
        class="text-sm font-medium text-[#0F172A] leading-tight mb-1 truncate"
        style="font-family: 'Inter', sans-serif;"
      >
        {@product.title}
      </p>
      <p
        class="text-sm font-semibold text-[var(--theme-primary,#6366F1)]"
        style="font-family: 'Inter', sans-serif;"
      >
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>
    </a>
    """
  end

  # ── Category Pill ──

  @doc """
  Category as a pill/chip with rounded-full shape and soft background.
  """
  attr :category, :map, required: true
  attr :store_slug, :string, required: true
  attr :active, :boolean, default: false

  def category_pill(assigns) do
    ~H"""
    <a
      href={"/@#{@store_slug}/category/#{@category.slug}"}
      class={[
        "flex-shrink-0 px-4 py-2 rounded-full text-sm font-medium transition-all",
        if(@active,
          do: "bg-[var(--theme-primary,#6366F1)] text-white shadow-sm",
          else: "bg-gray-100 text-[#64748B] hover:bg-[var(--theme-primary,#6366F1)] hover:text-white"
        )
      ]}
      style="font-family: 'Inter', sans-serif;"
      role="listitem"
    >
      {@category.name}
    </a>
    """
  end

  # ── Footer ──

  @doc """
  Clean footer with store name, payment badges, and powered-by line.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer class="bg-[#F8FAFC] border-t border-gray-100">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8 mb-8">
          <%!-- Store Info --%>
          <div>
            <h3
              class="text-base font-semibold text-[#0F172A] mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              {@store.name}
            </h3>
            <p
              :if={@store.description}
              class="text-sm text-[#64748B] leading-relaxed max-w-xs"
              style="font-family: 'Inter', sans-serif;"
            >
              {@store.description}
            </p>
          </div>

          <%!-- Quick Links --%>
          <div>
            <h3
              class="text-sm font-semibold text-[#0F172A] uppercase tracking-wider mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              Shop
            </h3>
            <ul class="space-y-2">
              <li>
                <a
                  href={"/@#{@store.slug}/products"}
                  class="text-sm text-[#64748B] hover:text-[var(--theme-primary,#6366F1)] transition-colors"
                  style="font-family: 'Inter', sans-serif;"
                >
                  All Products
                </a>
              </li>
              <li :for={cat <- Enum.take(@categories, 4)}>
                <a
                  href={"/@#{@store.slug}/category/#{cat.slug}"}
                  class="text-sm text-[#64748B] hover:text-[var(--theme-primary,#6366F1)] transition-colors"
                  style="font-family: 'Inter', sans-serif;"
                >
                  {cat.name}
                </a>
              </li>
            </ul>
          </div>

          <%!-- Payment Methods --%>
          <div>
            <h3
              class="text-sm font-semibold text-[#0F172A] uppercase tracking-wider mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              We Accept
            </h3>
            <div class="flex items-center gap-3 flex-wrap">
              <span class="px-3 py-1.5 bg-white border border-gray-200 rounded-md text-xs font-medium text-[#64748B]">
                Mobile Money
              </span>
              <span class="px-3 py-1.5 bg-white border border-gray-200 rounded-md text-xs font-medium text-[#64748B]">
                Visa
              </span>
              <span class="px-3 py-1.5 bg-white border border-gray-200 rounded-md text-xs font-medium text-[#64748B]">
                Mastercard
              </span>
            </div>
          </div>
        </div>

        <%!-- Bottom bar --%>
        <div class="pt-6 border-t border-gray-200 flex flex-col sm:flex-row items-center justify-between gap-3">
          <p class="text-xs text-[#94A3B8]" style="font-family: 'Inter', sans-serif;">
            Powered by Makola
          </p>
          <p class="text-xs text-[#94A3B8]" style="font-family: 'Inter', sans-serif;">
            &copy; {DateTime.utc_now().year} {@store.name}. All rights reserved.
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
