defmodule Emakola.Themes.Vibrant.Shared do
  @moduledoc """
  Shared components for the Vibrant theme.

  Bold, energetic, West African commerce-inspired design with:
  - Warm ivory (#FFFBEB) background
  - Red (#DC2626) primary / burnt orange (#7C2D12) accent
  - Playfair Display headings + DM Sans body
  - Large rounded cards with prominent shadows
  - Story-style category circles with gradient rings
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── Vibrant Nav Bar ──

  @doc """
  Bold top navigation bar with warm gradient accent stripe and store branding.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def vibrant_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50">
      <div class="h-1 bg-gradient-to-r from-[var(--theme-primary,#DC2626)] via-[var(--theme-accent,#7C2D12)] to-[var(--theme-primary,#DC2626)]">
      </div>
      <div class="bg-[#FFFBEB] border-b border-[#FDE68A]/60 shadow-sm">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-14 sm:h-16">
            <a href={"/s/#{@store.slug}"} class="flex items-center gap-3 min-w-0">
              <div class="w-10 h-10 rounded-full bg-gradient-to-br from-[var(--theme-primary,#DC2626)] to-[var(--theme-accent,#7C2D12)] flex items-center justify-center flex-shrink-0 shadow-md">
                <span class="text-sm font-bold text-white">
                  {String.first(@store.name)}
                </span>
              </div>
              <div class="min-w-0">
                <div
                  class="text-[0.9375rem] font-bold text-[#1C1917] truncate leading-tight"
                  style="font-family: 'Playfair Display', serif;"
                >
                  {@store.name}
                </div>
                <div class="flex items-center gap-1 text-xs text-[#92400E] leading-tight">
                  <span class="w-1.5 h-1.5 rounded-full bg-[#059669] flex-shrink-0"></span>
                  <span>Open</span>
                </div>
              </div>
            </a>

            <div class="flex items-center gap-1">
              <a
                href={"/s/#{@store.slug}/products"}
                class="p-2.5 rounded-xl hover:bg-[#FEF3C7] transition-colors"
                aria-label="Search products"
              >
                <svg
                  class="w-5 h-5 text-[#92400E]"
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
                href={"/s/#{@store.slug}/wishlist"}
                class="p-2.5 rounded-xl hover:bg-[#FEF3C7] transition-colors"
                aria-label="Wishlist"
              >
                <svg
                  class="w-5 h-5 text-[#92400E]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.8"
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
                class="relative p-2.5 rounded-xl hover:bg-[#FEF3C7] transition-colors"
                aria-label={"Shopping cart, #{@cart_count} items"}
              >
                <svg
                  class="w-5 h-5 text-[#92400E]"
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
                  class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-[var(--theme-primary,#DC2626)] text-white text-[10px] font-bold rounded-full flex items-center justify-center px-1"
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

  # ── Category Circle (Story-Style) ──

  @doc """
  Story-style category bubble with gradient ring border and bold label.
  Used in horizontal-scroll rows.
  """
  attr :category, :map, required: true
  attr :store_slug, :string, required: true
  attr :active, :boolean, default: false

  def category_circle(assigns) do
    ~H"""
    <a
      href={"/s/#{@store_slug}/category/#{@category.slug}"}
      class="flex flex-col items-center gap-2 flex-shrink-0 group"
      role="listitem"
    >
      <div class={[
        "w-[76px] h-[76px] rounded-full p-[3px] group-hover:scale-110 transition-transform duration-200",
        if(@active,
          do:
            "bg-gradient-to-br from-[var(--theme-primary,#DC2626)] to-[var(--theme-accent,#7C2D12)] shadow-lg shadow-red-200",
          else: "bg-gradient-to-br from-[#FDE68A] to-[#F59E0B]"
        )
      ]}>
        <%= if category_image(@category) do %>
          <.optimized_image
            src={category_image(@category)}
            alt={@category.name}
            priority={:low}
            class="w-full h-full rounded-full object-cover border-[3px] border-[#FFFBEB]"
            width={70}
            height={70}
          />
        <% else %>
          <div class="w-full h-full rounded-full bg-[#FFFBEB] border-[3px] border-[#FFFBEB] flex items-center justify-center">
            <span class="text-xl font-bold text-[var(--theme-accent,#7C2D12)]">
              {String.first(@category.name)}
            </span>
          </div>
        <% end %>
      </div>
      <span class={[
        "text-xs font-semibold text-center whitespace-nowrap max-w-[80px] truncate",
        if(@active,
          do: "text-[var(--theme-primary,#DC2626)]",
          else: "text-[#78350F] group-hover:text-[var(--theme-primary,#DC2626)]"
        )
      ]}>
        {@category.name}
      </span>
    </a>
    """
  end

  # ── Product Card (Vibrant) ──

  @doc """
  Large rounded product card with prominent shadow, warm tones, and bold price.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="relative rounded-2xl overflow-hidden mb-3 bg-[#FEF3C7]/40 shadow-md shadow-amber-100 group-hover:shadow-xl group-hover:shadow-amber-200/60 transition-all duration-300">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          class="w-full aspect-[3/4] object-cover group-hover:scale-[1.06] transition-transform duration-500"
        />
        <div :if={!@image} class="w-full aspect-[3/4] flex items-center justify-center bg-[#FEF3C7]">
          <svg class="w-12 h-12 text-[#D97706]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
        </div>
        <%!-- Hover overlay with warm gradient --%>
        <div class="absolute bottom-0 left-0 right-0 p-3 bg-gradient-to-t from-[var(--theme-accent,#7C2D12)]/70 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex justify-center">
          <span class="text-sm font-bold text-white tracking-wide">Shop Now</span>
        </div>
      </div>
      <p class="text-sm font-semibold text-[#1C1917] leading-tight mb-1 truncate">
        {@product.title}
      </p>
      <p class="text-sm font-bold text-[var(--theme-primary,#DC2626)]">
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>
    </a>
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

  defp category_image(category) do
    if Map.has_key?(category, :image_url), do: category.image_url, else: nil
  end
end
