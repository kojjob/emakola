defmodule EmakolaWeb.StorefrontComponents do
  @moduledoc """
  Shared storefront UI components for the customer-facing shopping experience.

  Design language:
  - Background: #FAFAF9 (cream-50)
  - Accent: #B45309 (amber-700) for CTAs, prices, active states
  - Dark surfaces: #1C1917 (stone-900) for nav, featured cards
  - Typography: Inter for UI, Cormorant Garamond for display (via CSS class)
  - Radius: rounded-[20px] for cards, rounded-full for buttons/pills
  - Motion: hover scale 1.03-1.05 on cards/images
  """
  use Phoenix.Component

  alias EmakolaWeb.Helpers.Currency
  alias EmakolaWeb.SearchComponents

  # ── Navigation ──

  @doc """
  Dark stone nav bar with store avatar, name, open status, search/wishlist/cart icons.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :active_tab, :atom, default: :home

  def store_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-white border-b border-[#E2E8F0]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-14 sm:h-16">
          <a href={"/s/#{@store.slug}"} class="flex items-center gap-2.5 min-w-0">
            <div class="w-10 h-10 rounded-full bg-[#E2E8F0] flex items-center justify-center flex-shrink-0 border-2 border-[#E2E8F0] overflow-hidden">
              <span class="text-sm font-bold text-[#475569]">
                {String.first(@store.name)}
              </span>
            </div>
            <div class="min-w-0">
              <div class="text-[0.9375rem] font-semibold text-[#0F172A] truncate leading-tight">
                {@store.name}
              </div>
              <div class="flex items-center gap-1 text-xs text-[#94A3B8] leading-tight">
                <span class="w-1.5 h-1.5 rounded-full bg-[#059669] flex-shrink-0"></span>
                <span>Open</span>
              </div>
            </div>
          </a>

          <div class="flex items-center gap-1">
            <button
              type="button"
              phx-click={SearchComponents.show_search()}
              class="p-2.5 rounded-xl hover:bg-[#F1F5F9] transition-colors"
              aria-label="Search products"
            >
              <svg
                class="w-5 h-5 text-[#475569]"
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
            </button>
            <a
              href={"/s/#{@store.slug}/wishlist"}
              class="p-2.5 rounded-xl hover:bg-[#F1F5F9] transition-colors"
              aria-label="Wishlist"
            >
              <svg
                class="w-5 h-5 text-[#475569]"
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
              class="relative p-2.5 rounded-xl hover:bg-[#F1F5F9] transition-colors"
              aria-label={"Shopping cart, #{@cart_count} items"}
            >
              <svg
                class="w-5 h-5 text-[#475569]"
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
                class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-[#B45309] text-white text-[10px] font-bold rounded-full flex items-center justify-center px-1"
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

  # ── Category Circles ──

  @doc """
  Horizontal-scrolling story-style category circles.
  """
  attr :categories, :list, required: true
  attr :store_slug, :string, required: true
  attr :active_slug, :string, default: nil

  def category_circles(assigns) do
    ~H"""
    <nav
      :if={@categories != []}
      class="py-4 bg-white border-b border-[#E2E8F0]"
      aria-label="Product categories"
    >
      <div
        class="flex gap-4 px-4 sm:px-6 lg:px-8 lg:gap-6 overflow-x-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
        role="list"
      >
        <a
          :for={category <- @categories}
          href={"/s/#{@store_slug}/category/#{category.slug}"}
          class="flex flex-col items-center gap-1.5 flex-shrink-0 group"
          role="listitem"
        >
          <div class={"w-[68px] h-[68px] rounded-full p-[3px] group-hover:scale-105 transition-transform " <> if(@active_slug == category.slug, do: "bg-gradient-to-br from-[#B45309] to-[#F59E0B]", else: "bg-[#E2E8F0]")}>
            <div class="w-full h-full rounded-full bg-[#F1F5F9] border-2 border-white flex items-center justify-center">
              <span class="text-lg font-semibold text-[#94A3B8]">
                {String.first(category.name)}
              </span>
            </div>
          </div>
          <span class={"text-[0.6875rem] font-medium text-center whitespace-nowrap " <> if(@active_slug == category.slug, do: "text-[#B45309] font-semibold", else: "text-[#475569] group-hover:text-[#0F172A]")}>
            {category.name}
          </span>
        </a>
      </div>
    </nav>
    """
  end

  # ── Featured Product Card ──

  @doc """
  Large hero card for a featured product. Dark or light theme with "New Arrival" badge.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def featured_product_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="block bg-white rounded-[20px] overflow-hidden border border-[#E2E8F0] mb-8 hover:shadow-[0_4px_24px_rgba(0,0,0,0.06)] transition-shadow md:grid md:grid-cols-2"
      aria-label={"Featured product: #{@product.title}"}
    >
      <div class="w-full aspect-[16/10] md:aspect-auto md:h-full md:min-h-[320px] bg-[#F1F5F9] overflow-hidden">
        <img
          :if={@image}
          src={@image}
          alt={@product.title}
          class="w-full h-full object-cover"
          loading="eager"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <.image_placeholder size="lg" />
        </div>
      </div>
      <div class="p-5 sm:p-6 md:p-8 md:flex md:flex-col md:justify-center">
        <span class="inline-flex items-center px-2.5 py-1 text-[0.625rem] font-bold tracking-wider uppercase text-[#B45309] bg-[#FEF3C7] rounded-full mb-2.5">
          New Arrival
        </span>
        <h1 class="text-xl font-bold text-[#0F172A] mb-1.5 leading-tight">{@product.title}</h1>
        <p :if={@product.description} class="text-sm text-[#475569] leading-relaxed mb-4 line-clamp-2">
          {@product.description}
        </p>
        <p class="text-lg font-bold text-[#0F172A] mb-4">
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span class="flex items-center justify-center gap-2 w-full py-3.5 px-6 bg-[#1C1917] text-white rounded-full text-[0.9375rem] font-semibold hover:bg-[#292524] active:scale-[0.98] transition-all leading-none">
          <.bag_icon /> Add to Bag
        </span>
      </div>
    </a>
    """
  end

  # ── Product Card ──

  @doc """
  Standard product card for grids. 3:4 aspect ratio image, hover overlay, price.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :show_hover_overlay, :boolean, default: true

  def product_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="group block">
      <div class="relative rounded-[16px] overflow-hidden mb-3.5 bg-[#F1F5F9]">
        <img
          :if={@image}
          src={@image}
          alt={@product.title}
          loading="lazy"
          class="w-full aspect-[3/4] object-cover group-hover:scale-[1.04] transition-transform duration-500 ease-out"
        />
        <div :if={!@image} class="w-full aspect-[3/4] flex items-center justify-center">
          <.image_placeholder />
        </div>
        <div
          :if={@show_hover_overlay}
          class="absolute bottom-3 left-3 right-3 translate-y-3 opacity-0 group-hover:translate-y-0 group-hover:opacity-100 transition-all duration-300 ease-out flex justify-center"
        >
          <span class="w-full py-2.5 bg-white/95 backdrop-blur-md text-[#0F172A] text-xs font-bold tracking-wide uppercase rounded-xl shadow-[0_8px_16px_rgba(0,0,0,0.08)] flex items-center justify-center">
            Quick Add
          </span>
        </div>
      </div>
      <h3 class="text-[0.875rem] font-semibold text-[#0F172A] leading-snug mb-1 truncate group-hover:text-[#B45309] transition-colors">
        {@product.title}
      </h3>
      <p class="text-[0.8125rem] font-medium text-[#64748B]">
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>
    </a>
    """
  end

  # ── About Section ──

  @doc """
  Store about section with avatar, description, and WhatsApp CTA.
  """
  attr :store, :map, required: true

  def about_section(assigns) do
    ~H"""
    <section class="bg-white border border-[#E2E8F0] rounded-[20px] p-6 sm:p-8 mb-10 text-center">
      <h2 class="text-lg font-bold text-[#0F172A] mb-4">About the Shop</h2>
      <div class="w-20 h-20 rounded-full bg-[#FEF3C7] border-[3px] border-[#FEF3C7] mx-auto mb-3.5 flex items-center justify-center">
        <span class="text-2xl font-bold text-[#B45309]">{String.first(@store.name)}</span>
      </div>
      <p class="text-sm text-[#475569] leading-relaxed max-w-[480px] mx-auto mb-4">
        {if @store.description,
          do: @store.description,
          else:
            "Welcome to #{@store.name}. Browse our collection of quality products handpicked for you."}
      </p>
      <a
        :if={Map.get(@store, :whatsapp_number)}
        href={"https://wa.me/#{@store.whatsapp_number}"}
        target="_blank"
        class="inline-flex items-center gap-2 px-5 py-2.5 bg-[#25D366] text-white rounded-full text-sm font-semibold hover:bg-[#1FAF55] transition-colors"
      >
        <svg class="w-4.5 h-4.5" viewBox="0 0 24 24" fill="currentColor">
          <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
          <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
        </svg>
        Chat on WhatsApp
      </a>
    </section>
    """
  end

  # ── Bottom Navigation ──

  @doc """
  Mobile bottom tab bar with Home, Search, Saved, Cart.
  """
  attr :store_slug, :string, required: true
  attr :active_tab, :atom, default: :home
  attr :cart_count, :integer, default: 0

  def bottom_nav(assigns) do
    ~H"""
    <nav class="fixed bottom-0 inset-x-0 z-40 bg-white border-t border-[#E2E8F0] sm:hidden safe-area-inset-bottom">
      <div class="flex items-center justify-around h-14">
        <.bottom_nav_item
          href={"/s/#{@store_slug}"}
          icon="home"
          label="Home"
          active={@active_tab == :home}
        />
        <.bottom_nav_item
          href={"/s/#{@store_slug}/products"}
          icon="search"
          label="Search"
          active={@active_tab == :search}
        />
        <.bottom_nav_item
          href={"/s/#{@store_slug}/wishlist"}
          icon="heart"
          label="Saved"
          active={@active_tab == :saved}
        />
        <.bottom_nav_item
          href={"/s/#{@store_slug}/cart"}
          icon="bag"
          label="Cart"
          active={@active_tab == :cart}
          badge={@cart_count}
        />
      </div>
    </nav>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :badge, :integer, default: 0

  defp bottom_nav_item(assigns) do
    ~H"""
    <a
      href={@href}
      class={"flex flex-col items-center gap-0.5 px-3 py-1 relative " <> if(@active, do: "text-[#B45309]", else: "text-[#94A3B8]")}
    >
      <.nav_icon name={@icon} />
      <span class="text-[0.625rem] font-medium">{@label}</span>
      <span
        :if={@badge > 0}
        class="absolute -top-0.5 right-1 min-w-[14px] h-[14px] bg-[#B45309] text-white text-[8px] font-bold rounded-full flex items-center justify-center px-0.5"
      >
        {@badge}
      </span>
    </a>
    """
  end

  # ── Promo Banner ──

  @doc """
  Dark gradient promotional banner for collections or sales.
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :image_url, :string, default: nil
  attr :href, :string, default: "#"

  def promo_banner(assigns) do
    ~H"""
    <a
      href={@href}
      class="block relative rounded-[20px] overflow-hidden mb-6 bg-gradient-to-r from-[#1C1917] to-[#292524] min-h-[160px]"
    >
      <img
        :if={@image_url}
        src={@image_url}
        alt={@title}
        class="absolute inset-0 w-full h-full object-cover opacity-40 mix-blend-overlay"
        loading="lazy"
      />
      <div class="relative p-6 sm:p-8 flex flex-col justify-end min-h-[160px]">
        <p :if={@subtitle} class="text-xs font-semibold text-[#F59E0B] uppercase tracking-wider mb-1">
          {@subtitle}
        </p>
        <h3 class="text-xl font-bold text-white leading-tight">{@title}</h3>
        <span class="mt-3 inline-flex items-center gap-1.5 text-sm font-semibold text-white">
          Shop Now
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
            />
          </svg>
        </span>
      </div>
    </a>
    """
  end

  # ── Shared Helpers ──

  @doc """
  Placeholder icon for products without images.
  """
  attr :size, :string, default: "md"

  def image_placeholder(assigns) do
    size_class = if assigns.size == "lg", do: "w-16 h-16", else: "w-12 h-12"
    assigns = assign(assigns, :size_class, size_class)

    ~H"""
    <svg class={"#{@size_class} text-[#94A3B8]"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1"
        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
      />
    </svg>
    """
  end

  defp bag_icon(assigns) do
    ~H"""
    <svg
      class="w-[18px] h-[18px]"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="2"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
      />
    </svg>
    """
  end

  defp nav_icon(%{name: "home"} = assigns) do
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"
      />
    </svg>
    """
  end

  defp nav_icon(%{name: "search"} = assigns) do
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
      />
    </svg>
    """
  end

  defp nav_icon(%{name: "heart"} = assigns) do
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
      />
    </svg>
    """
  end

  defp nav_icon(%{name: "bag"} = assigns) do
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
      />
    </svg>
    """
  end

  defp nav_icon(assigns), do: ~H""

  @doc """
  Extract first image URL from a product's images association.
  Returns thumbnail_url if available, falls back to url, then nil.
  """
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end
end
