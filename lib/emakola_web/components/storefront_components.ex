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

  # ── Optimized Image ──

  @doc """
  Performance-optimized `<img>` wrapper.

  This component centralises image best-practice attributes so the storefront
  renders fast on low-bandwidth mobile networks (the Emakola primary audience).
  Use it for **every** storefront `<img>` — plain `<img>` tags should be
  considered a lint violation in theme templates.

  ## Priority values

    * `:auto` (default) — lazy load, async decode. Use for everything below
      the fold and any repeat/gallery thumbnails.
    * `:high` — eager load, `fetchpriority="high"`, async decode. Use for
      the single most important image on each page: the home hero, the PDP
      main gallery image. These are the Largest Contentful Paint (LCP)
      candidates Google measures for Core Web Vitals.
    * `:low` — lazy load, `fetchpriority="low"`, async decode. Use for
      decorative, icon-sized, or far-below-fold images that should yield
      bandwidth to more important content.

  ## Dimensions

  Supplying `width` and `height` (or wrapping in an `aspect-ratio` container)
  prevents Cumulative Layout Shift (CLS) when the image loads. The Atelier
  theme uses `aspect-[...]` container classes, so `width`/`height` are
  optional on most call sites.

  ## Responsive images

  Pass `srcset` and `sizes` for responsive loading. For example:

      <.optimized_image
        src="/uploads/product-640.jpg"
        srcset="/uploads/product-320.jpg 320w, /uploads/product-640.jpg 640w, /uploads/product-1280.jpg 1280w"
        sizes="(max-width: 640px) 100vw, 50vw"
        alt="Product"
      />

  Responsive variants are not generated automatically — this is wiring for
  the ImageWorker to produce multiple sizes in a follow-up.

  ## Accessibility

  `alt` is required. Decorative images should pass `alt=""` explicitly to
  tell screen readers to skip them — never omit the attribute.
  """
  attr :src, :string, required: true
  attr :alt, :string, required: true

  attr :priority, :atom,
    values: [:auto, :high, :low],
    default: :auto,
    doc: ":high for LCP images, :low for decorative, :auto (default) elsewhere"

  attr :width, :integer, default: nil
  attr :height, :integer, default: nil
  attr :sizes, :string, default: nil
  attr :srcset, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  def optimized_image(assigns) do
    {loading, fetchpriority} =
      case assigns.priority do
        :high -> {"eager", "high"}
        :low -> {"lazy", "low"}
        :auto -> {"lazy", nil}
      end

    assigns =
      assigns
      |> assign(:loading, loading)
      |> assign(:fetchpriority, fetchpriority)

    ~H"""
    <img
      src={@src}
      alt={@alt}
      loading={@loading}
      decoding="async"
      fetchpriority={@fetchpriority}
      width={@width}
      height={@height}
      sizes={@sizes}
      srcset={@srcset}
      class={@class}
      {@rest}
    />
    """
  end

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
  attr :wishlisted, :boolean, default: false
  attr :show_wishlist_heart, :boolean, default: false

  def product_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <div class="group relative">
      <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="block">
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
      <div :if={@show_wishlist_heart} class="absolute top-3 right-3 z-10">
        <.wishlist_heart product_id={@product.id} wishlisted={@wishlisted} />
      </div>
    </div>
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

  # ── Wishlist Heart Toggle ──

  @doc """
  Heart icon button for wishlisting a product.

  Renders a filled amber heart when wishlisted, outline when not.
  Sends a "toggle_wishlist" event with the product_id value.
  Uses `Phoenix.LiveView.JS` for instant visual feedback before server round-trip.
  """
  attr :product_id, :string, required: true
  attr :wishlisted, :boolean, default: false

  def wishlist_heart(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={
        Phoenix.LiveView.JS.push("toggle_wishlist", value: %{product_id: @product_id})
        |> Phoenix.LiveView.JS.toggle_class("wishlist-heart-filled",
          to: "#wishlist-heart-#{@product_id}"
        )
      }
      id={"wishlist-heart-#{@product_id}"}
      class={"cursor-pointer w-9 h-9 rounded-full bg-white/90 backdrop-blur-sm flex items-center justify-center hover:bg-white transition-colors shadow-sm " <> if(@wishlisted, do: "wishlist-heart-filled", else: "")}
      aria-label={if @wishlisted, do: "Remove from wishlist", else: "Add to wishlist"}
    >
      <%!-- Outline heart (shown when not wishlisted) --%>
      <svg
        class={"w-5 h-5 transition-colors " <> if(@wishlisted, do: "hidden", else: "text-[#44403C]")}
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        viewBox="0 0 24 24"
        data-heart-outline
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
        />
      </svg>
      <%!-- Filled heart (shown when wishlisted) --%>
      <svg
        class={"w-5 h-5 transition-colors " <> if(@wishlisted, do: "text-[#B45309]", else: "hidden")}
        fill="currentColor"
        viewBox="0 0 24 24"
        data-heart-filled
      >
        <path d="M11.645 20.91l-.007-.003-.022-.012a15.247 15.247 0 01-.383-.218 25.18 25.18 0 01-4.244-3.17C4.688 15.36 2.25 12.174 2.25 8.25 2.25 5.322 4.714 3 7.688 3A5.5 5.5 0 0112 5.052 5.5 5.5 0 0116.313 3c2.973 0 5.437 2.322 5.437 5.25 0 3.925-2.438 7.111-4.739 9.256a25.175 25.175 0 01-4.244 3.17 15.247 15.247 0 01-.383.219l-.022.012-.007.004-.003.001a.752.752 0 01-.704 0l-.003-.001z" />
      </svg>
    </button>
    """
  end

  # ── Coupon Promotion Banner ──

  @doc """
  Slide-down banner showing active public coupons with a ticket-style visual.
  Only renders when the coupons list is non-empty.
  Dismissible via the close button.
  """
  attr :coupons, :list, required: true
  attr :store, :map, required: true

  def coupon_banner(assigns) do
    assigns = assign(assigns, :first_coupon, List.first(assigns.coupons))

    ~H"""
    <div
      :if={@first_coupon}
      id="coupon-promo-banner"
      class="relative bg-[#FFFBEB] border border-dashed border-[#F59E0B] rounded-xl px-4 py-3 sm:px-6 sm:py-3.5 mb-4"
    >
      <div class="flex items-center justify-between gap-3">
        <div class="flex items-center gap-2.5 min-w-0">
          <div class="flex-shrink-0 w-8 h-8 bg-[#FEF3C7] rounded-lg flex items-center justify-center">
            <svg
              class="w-4.5 h-4.5 text-[#B45309]"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z"
              />
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 6h.008v.008H6V6z" />
            </svg>
          </div>
          <p class="text-sm font-medium text-[#92400E] truncate">
            Use code
            <span class="font-bold font-mono bg-[#FEF3C7] px-1.5 py-0.5 rounded">
              {@first_coupon.code}
            </span>
            for {format_coupon_discount(@first_coupon, @store)}!
          </p>
        </div>
        <button
          phx-click={
            Phoenix.LiveView.JS.hide(
              to: "#coupon-promo-banner",
              transition:
                {"transition-all duration-300", "opacity-100 translate-y-0",
                 "opacity-0 -translate-y-2"}
            )
          }
          class="flex-shrink-0 w-7 h-7 flex items-center justify-center rounded-lg text-[#B45309] hover:bg-[#FEF3C7] transition-colors"
          aria-label="Dismiss promotion"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  defp format_coupon_discount(coupon, store) do
    case coupon.discount_type do
      :percentage ->
        pct = div(coupon.discount_value, 100)
        "#{pct}% off"

      :fixed_amount ->
        Currency.format_price(coupon.discount_value, store.currency) <> " off"

      :free_shipping ->
        "Free shipping"

      _ ->
        "a discount"
    end
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

  # ── Trust Badge ──

  @doc """
  Compact icon + label pill that signals provenance, scarcity, or social proof.

  Variants control color emphasis:
    * `:default` — neutral, low-contrast (most contexts)
    * `:scarcity` — amber, draws the eye ("Only 3 left", "Limited Edition")
    * `:provenance` — emerald, signals trust ("Made in Ghana", "Hand-woven")
  """
  attr :icon, :string,
    required: true,
    doc: "Material symbol name (e.g. \"verified\", \"location_on\")"

  attr :label, :string, required: true
  attr :variant, :atom, default: :default, values: [:default, :scarcity, :provenance]
  attr :class, :string, default: ""

  def trust_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold tracking-wide",
      badge_classes(@variant),
      @class
    ]}>
      <span class="material-symbols-outlined text-[14px] leading-none">{@icon}</span>
      {@label}
    </span>
    """
  end

  defp badge_classes(:default), do: "bg-[#F1F5F9] text-[#475569]"
  defp badge_classes(:scarcity), do: "bg-[#FEF3C7] text-[#92400E]"
  defp badge_classes(:provenance), do: "bg-[#D1FAE5] text-[#065F46]"

  # ── Trust Badges Strip ──

  @doc """
  Horizontal strip of trust_badge entries, used under hero or above fold.

  Each badge is a map: `%{icon: "verified", label: "Made in Ghana", variant: :provenance}`.
  `:variant` is optional and defaults to `:default`.
  """
  attr :badges, :list, required: true
  attr :class, :string, default: ""

  def trust_badges_strip(assigns) do
    ~H"""
    <div class={["flex flex-wrap gap-2", @class]} role="list">
      <.trust_badge
        :for={badge <- @badges}
        icon={badge.icon}
        label={badge.label}
        variant={Map.get(badge, :variant, :default)}
      />
    </div>
    """
  end

  # ── Occasion Collection Tile ──

  @doc """
  Large tile linking to a category, framed as an occasion ("For Celebrations").

  Renders a full-bleed image (or amber gradient fallback) with overlay title and
  chevron. Designed for narrative-first navigation per the storefront redesign —
  customers think in occasions, not product types.
  """
  attr :category, :map, required: true, doc: "Map with :name, :slug, optional :image_url"
  attr :store_slug, :string, required: true

  attr :occasion_label, :string,
    default: nil,
    doc: "Override display label (e.g. \"For Celebrations\")"

  def occasion_collection_tile(assigns) do
    assigns =
      assign_new(assigns, :display_label, fn ->
        assigns.occasion_label || assigns.category.name
      end)

    ~H"""
    <a
      href={"/s/#{@store_slug}/category/#{@category.slug}"}
      class="group relative block aspect-[4/5] sm:aspect-[5/6] rounded-[20px] overflow-hidden bg-[#1C1917] focus-visible:ring-2 focus-visible:ring-[#B45309] focus-visible:ring-offset-2"
    >
      <%= if Map.get(@category, :image_url) do %>
        <.optimized_image
          src={@category.image_url}
          alt={@category.name}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
        />
      <% else %>
        <div class="absolute inset-0 bg-gradient-to-br from-[#B45309] via-[#D97706] to-[#F59E0B]">
        </div>
      <% end %>
      <div class="absolute inset-0 bg-gradient-to-t from-black/75 via-black/25 to-transparent"></div>
      <div class="absolute inset-x-0 bottom-0 p-5 sm:p-6">
        <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-white/70 mb-1.5">
          Shop the edit
        </p>
        <h3 class="text-xl sm:text-2xl font-bold text-white leading-tight mb-3">
          {@display_label}
        </h3>
        <span class="inline-flex items-center gap-1 text-sm font-semibold text-white">
          Browse
          <span class="material-symbols-outlined text-base group-hover:translate-x-1 transition-transform">
            arrow_forward
          </span>
        </span>
      </div>
    </a>
    """
  end

  # ── Artisan Signature Card ──

  @doc """
  Maker bio card — surfaces the human behind the store.

  Renders avatar (store logo or initial), name, location, short bio, and an
  optional WhatsApp message link. Used for the "Artisan's Signature" section
  on the storefront home and PDP per the Stitch design system.
  """
  attr :store, :map,
    required: true,
    doc: "Store with :name, :description, :logo_url, :city, :region, :whatsapp_number"

  attr :headline, :string, default: "Meet the Artisan"
  attr :class, :string, default: ""

  def artisan_signature_card(assigns) do
    ~H"""
    <article class={[
      "relative rounded-[24px] bg-[#FAFAF9] border border-[#E7E5E4] overflow-hidden",
      "p-6 sm:p-8 lg:p-10",
      @class
    ]}>
      <p class="text-[11px] font-semibold tracking-[0.2em] uppercase text-[#B45309] mb-4">
        {@headline}
      </p>
      <div class="flex flex-col sm:flex-row gap-5 sm:gap-7 items-start">
        <div class="flex-shrink-0">
          <%= if @store.logo_url do %>
            <.optimized_image
              src={@store.logo_url}
              alt={"#{@store.name} portrait"}
              priority={:low}
              class="w-20 h-20 sm:w-28 sm:h-28 rounded-full object-cover ring-4 ring-[#FEF3C7]"
            />
          <% else %>
            <div class="w-20 h-20 sm:w-28 sm:h-28 rounded-full bg-gradient-to-br from-[#B45309] to-[#F59E0B] flex items-center justify-center ring-4 ring-[#FEF3C7]">
              <span class="text-2xl sm:text-3xl font-bold text-white">
                {String.first(@store.name)}
              </span>
            </div>
          <% end %>
        </div>
        <div class="flex-1 min-w-0">
          <h3 class="text-xl sm:text-2xl font-bold text-[#1C1917] leading-tight">
            {@store.name}
          </h3>
          <p
            :if={artisan_location(@store) != ""}
            class="mt-1 inline-flex items-center gap-1 text-sm text-[#78716C]"
          >
            <span class="material-symbols-outlined text-base">location_on</span>
            {artisan_location(@store)}
          </p>
          <p :if={@store.description} class="mt-4 text-[15px] leading-relaxed text-[#44403C]">
            {@store.description}
          </p>
          <a
            :if={Map.get(@store, :whatsapp_number)}
            href={"https://wa.me/#{normalise_whatsapp(@store.whatsapp_number)}"}
            target="_blank"
            rel="noopener"
            class="mt-5 inline-flex items-center gap-2 px-4 py-2 rounded-full bg-[#25D366] text-white text-sm font-semibold hover:bg-[#1FB855] transition-colors"
          >
            <span class="material-symbols-outlined text-[18px]">chat</span> Message on WhatsApp
          </a>
        </div>
      </div>
    </article>
    """
  end

  defp artisan_location(store) do
    [Map.get(store, :city), Map.get(store, :region)]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
  end

  defp normalise_whatsapp(number) do
    number
    |> to_string()
    |> String.replace(~r/[^\d]/, "")
  end

  # ── Pattern Divider ──

  @doc """
  Decorative section divider with a subtle culturally-inspired motif.

  Variants:
    * `:kente` — interlocking amber/gold zigzag (default)
    * `:ankara` — diamond + dot wax-print accent
    * `:none` — plain hairline rule with a single dot (use to soften without ornament)
  """
  attr :variant, :atom, default: :kente, values: [:kente, :ankara, :none]
  attr :class, :string, default: ""

  def pattern_divider(assigns) do
    ~H"""
    <div
      class={["w-full flex items-center justify-center py-6 sm:py-8", @class]}
      aria-hidden="true"
    >
      <div class="flex-1 h-px bg-gradient-to-r from-transparent via-[#E7E5E4] to-transparent"></div>
      <div class="px-4">
        <.divider_motif variant={@variant} />
      </div>
      <div class="flex-1 h-px bg-gradient-to-r from-[#E7E5E4] via-[#E7E5E4] to-transparent"></div>
    </div>
    """
  end

  attr :variant, :atom, required: true

  defp divider_motif(%{variant: :kente} = assigns) do
    ~H"""
    <svg
      width="48"
      height="14"
      viewBox="0 0 48 14"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M0 7 L8 0 L16 7 L24 0 L32 7 L40 0 L48 7" stroke="#B45309" stroke-width="2" />
      <path d="M0 7 L8 14 L16 7 L24 14 L32 7 L40 14 L48 7" stroke="#F59E0B" stroke-width="2" />
    </svg>
    """
  end

  defp divider_motif(%{variant: :ankara} = assigns) do
    ~H"""
    <svg
      width="48"
      height="14"
      viewBox="0 0 48 14"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <circle cx="6" cy="7" r="2" fill="#B45309" />
      <path d="M14 7 L20 1 L26 7 L20 13 Z" fill="none" stroke="#B45309" stroke-width="1.5" />
      <circle cx="34" cy="7" r="2" fill="#F59E0B" />
      <path d="M42 7 L48 1" stroke="#F59E0B" stroke-width="1.5" />
    </svg>
    """
  end

  defp divider_motif(%{variant: :none} = assigns) do
    ~H"""
    <span class="block w-1.5 h-1.5 rounded-full bg-[#E7E5E4]"></span>
    """
  end

  # ── Share Strip ──

  @doc """
  Horizontal row of social-share buttons. Used on the product detail page
  and the order confirmation page to turn every shopper into a distribution
  node.

  Each button opens a platform-specific share intent with the page URL and
  product/order title pre-filled. The Copy-link button uses a small JS
  hook (Phoenix.LiveView.JS) for clipboard write — no server round-trip.

  Phase 1 of the social-media integration plan. Phase 3 will increment a
  `share_count` per click; Phase 1 ships click-to-share without counting.

  ## Required attrs

    * `url` — the canonical absolute URL to share. Caller is responsible for
      ensuring this is the right URL (PDP canonical, order confirmation, etc).
    * `title` — the human-readable text included in share intents.

  ## Optional

    * `headline` — small heading rendered above the buttons (e.g. "Share
      this with friends"). Hidden if nil.
    * `class` — extra classes on the wrapper.

  ## Behaviour

  * **Additive only.** Inserted as a new section; doesn't replace any
    existing CTA.
  * **Always renders.** No conditional on having social handles set on the
    store — these buttons share the page itself, not link to merchant
    socials.
  """
  attr :url, :string, required: true
  attr :title, :string, required: true
  attr :headline, :string, default: nil
  attr :class, :string, default: ""
  # Optional LiveView event name to fire when any share button is tapped.
  # Phase 3: PDP passes "track_share" + phx-value-product-id to bump the
  # product's share_count. Other callers (order confirmation) leave it nil.
  attr :on_share, :string, default: nil
  attr :share_value, :string, default: nil

  def share_strip(assigns) do
    ~H"""
    <div class={["w-full", @class]}>
      <p
        :if={@headline}
        class="text-xs font-semibold tracking-[0.15em] uppercase text-[#78716C] mb-3"
      >
        {@headline}
      </p>
      <div class="flex flex-wrap gap-2">
        <a
          href={whatsapp_share_url(@url, @title)}
          target="_blank"
          rel="noopener noreferrer"
          phx-click={@on_share}
          phx-value-product-id={@share_value}
          phx-value-platform="whatsapp"
          class="inline-flex items-center gap-1.5 px-3 py-2 rounded-full bg-[#25D366] text-white text-xs font-semibold hover:bg-[#1FAF55] transition-colors"
          aria-label="Share on WhatsApp"
        >
          <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347" />
          </svg>
          WhatsApp
        </a>
        <a
          href={x_share_url(@url, @title)}
          target="_blank"
          rel="noopener noreferrer"
          phx-click={@on_share}
          phx-value-product-id={@share_value}
          phx-value-platform="x"
          class="inline-flex items-center gap-1.5 px-3 py-2 rounded-full bg-[#0F1419] text-white text-xs font-semibold hover:bg-black transition-colors"
          aria-label="Share on X"
        >
          <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
          </svg>
          X
        </a>
        <a
          href={facebook_share_url(@url)}
          target="_blank"
          rel="noopener noreferrer"
          phx-click={@on_share}
          phx-value-product-id={@share_value}
          phx-value-platform="facebook"
          class="inline-flex items-center gap-1.5 px-3 py-2 rounded-full bg-[#1877F2] text-white text-xs font-semibold hover:bg-[#0E62D0] transition-colors"
          aria-label="Share on Facebook"
        >
          <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M24 12.073c0-6.627-5.373-12-12-12S0 5.446 0 12.073c0 5.99 4.388 10.954 10.125 11.854V15.563H7.078v-3.49h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.49h-2.796v8.385C19.612 23.027 24 18.062 24 12.073" />
          </svg>
          Facebook
        </a>
        <button
          type="button"
          phx-click={Phoenix.LiveView.JS.dispatch("copy-to-clipboard", detail: %{text: @url})}
          class="inline-flex items-center gap-1.5 px-3 py-2 rounded-full bg-[#F1F5F9] text-[#1F1717] text-xs font-semibold hover:bg-[#E2E8F0] transition-colors"
          aria-label="Copy link to clipboard"
        >
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244"
            />
          </svg>
          Copy link
        </button>
      </div>
    </div>
    """
  end

  # ── Instagram / TikTok DM Helpers (Phase 3) ──

  @doc """
  Builds an Instagram DM link from the merchant's Instagram URL.
  Returns nil if no URL or unable to extract a handle.

  Input forms accepted:
    * "https://instagram.com/akosua_boutique"
    * "https://www.instagram.com/akosua_boutique/"
    * "https://instagram.com/akosua_boutique?hl=en"

  All resolve to "https://ig.me/m/akosua_boutique" — Instagram's
  universal DM deep link.
  """
  @spec instagram_dm_url(String.t() | nil) :: String.t() | nil
  def instagram_dm_url(nil), do: nil
  def instagram_dm_url(""), do: nil

  def instagram_dm_url(profile_url) when is_binary(profile_url) do
    case extract_handle(profile_url, "instagram.com") do
      nil -> nil
      handle -> "https://ig.me/m/#{handle}"
    end
  end

  def instagram_dm_url(_), do: nil

  @doc """
  Builds a TikTok message link from the merchant's TikTok URL.
  Returns nil if no URL or unable to extract a handle.

  TikTok's @-handle is part of the URL path. The DM deep link is:

      https://www.tiktok.com/@<handle>?lang=en

  Mobile devices intercept and open the app directly.
  """
  @spec tiktok_dm_url(String.t() | nil) :: String.t() | nil
  def tiktok_dm_url(nil), do: nil
  def tiktok_dm_url(""), do: nil

  def tiktok_dm_url(profile_url) when is_binary(profile_url) do
    case extract_handle(profile_url, "tiktok.com") do
      nil ->
        nil

      handle ->
        # TikTok handles in URLs commonly have @ prefix; strip then re-add
        clean = String.trim_leading(handle, "@")
        "https://www.tiktok.com/@#{clean}"
    end
  end

  def tiktok_dm_url(_), do: nil

  defp extract_handle(url, domain_fragment) do
    with %URI{host: host, path: path} when is_binary(host) and is_binary(path) <- URI.parse(url),
         true <- String.contains?(host, domain_fragment),
         [_, raw_handle | _] <- String.split(path, "/", trim: true) |> List.insert_at(0, "") do
      raw_handle
      |> String.trim()
      |> case do
        "" -> nil
        h -> h
      end
    else
      _ -> nil
    end
  end

  @doc """
  Renders a single click-to-DM button. Returns empty when `url` is nil so
  the caller doesn't have to wrap in `:if` — pass the `dm_url/1` result
  directly.

  Variants: `:instagram` (gradient pink-orange) | `:tiktok` (black) |
  `:whatsapp` (WhatsApp green — for symmetry alongside the other two).
  """
  attr :url, :any, required: true
  attr :variant, :atom, required: true, values: [:instagram, :tiktok, :whatsapp]
  attr :label, :string, default: nil

  def dm_button(%{url: nil} = assigns), do: ~H""
  def dm_button(%{url: ""} = assigns), do: ~H""

  def dm_button(assigns) do
    {classes, default_label, icon_path} = dm_button_style(assigns.variant)

    assigns =
      assigns
      |> assign(:classes, classes)
      |> assign(:label, assigns.label || default_label)
      |> assign(:icon_path, icon_path)

    ~H"""
    <a
      href={@url}
      target="_blank"
      rel="noopener noreferrer"
      class={[
        "inline-flex items-center gap-1.5 px-3 py-2 rounded-full text-white text-xs font-semibold transition-colors",
        @classes
      ]}
      aria-label={"Message on #{@label}"}
    >
      <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        <path d={@icon_path} />
      </svg>
      {@label}
    </a>
    """
  end

  # IG: gradient via inline style (Tailwind doesn't easily render IG's
  # signature radial gradient with a single utility).
  defp dm_button_style(:instagram),
    do:
      {"bg-gradient-to-tr from-[#F58529] via-[#DD2A7B] to-[#8134AF] hover:opacity-90",
       "Instagram DM",
       "M12 0C8.74 0 8.333.015 7.053.072 5.775.132 4.905.333 4.14.63c-.789.306-1.459.717-2.126 1.384S.935 3.35.63 4.14C.333 4.905.131 5.775.072 7.053.012 8.333 0 8.74 0 12s.015 3.667.072 4.947c.06 1.277.261 2.148.558 2.913.306.788.717 1.459 1.384 2.126.667.666 1.336 1.079 2.126 1.384.766.296 1.636.499 2.913.558C8.333 23.988 8.74 24 12 24s3.667-.015 4.947-.072c1.277-.06 2.148-.262 2.913-.558.788-.306 1.459-.718 2.126-1.384.666-.667 1.079-1.335 1.384-2.126.296-.765.499-1.636.558-2.913.06-1.28.072-1.687.072-4.947s-.015-3.667-.072-4.947c-.06-1.277-.262-2.149-.558-2.913-.306-.789-.718-1.459-1.384-2.126C21.319 1.347 20.651.935 19.86.63c-.765-.297-1.636-.499-2.913-.558C15.667.012 15.26 0 12 0zm0 2.16c3.203 0 3.585.016 4.85.071 1.17.055 1.805.249 2.227.415.562.217.96.477 1.382.896.419.42.679.819.896 1.381.164.422.36 1.057.413 2.227.057 1.266.07 1.646.07 4.85s-.015 3.585-.074 4.85c-.061 1.17-.256 1.805-.421 2.227-.224.562-.479.96-.897 1.382-.419.419-.824.679-1.38.896-.42.164-1.065.36-2.235.413-1.274.057-1.649.07-4.859.07-3.211 0-3.586-.015-4.859-.074-1.171-.061-1.816-.256-2.236-.421-.569-.224-.96-.479-1.379-.897-.421-.419-.69-.824-.9-1.38-.165-.42-.359-1.065-.42-2.235-.045-1.26-.061-1.649-.061-4.844 0-3.196.016-3.586.061-4.861.061-1.17.255-1.814.42-2.234.21-.57.479-.96.9-1.381.419-.419.81-.689 1.379-.898.42-.166 1.051-.361 2.221-.421 1.275-.045 1.65-.06 4.859-.06l.045.03zm0 3.678c-3.405 0-6.162 2.76-6.162 6.162 0 3.405 2.76 6.162 6.162 6.162 3.405 0 6.162-2.76 6.162-6.162 0-3.405-2.76-6.162-6.162-6.162zM12 16c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4zm7.846-10.405c0 .795-.646 1.44-1.44 1.44-.795 0-1.44-.646-1.44-1.44 0-.794.646-1.439 1.44-1.439.793-.001 1.44.645 1.44 1.439z"}

  defp dm_button_style(:tiktok),
    do:
      {"bg-[#000000] hover:bg-[#1F1F1F]", "TikTok",
       "M19.59 6.69a4.83 4.83 0 0 1-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 0 1-5.2 1.74 2.89 2.89 0 0 1 2.31-4.64 2.93 2.93 0 0 1 .88.13V9.4a6.84 6.84 0 0 0-1-.05A6.33 6.33 0 0 0 5.8 20.1a6.34 6.34 0 0 0 10.86-4.43v-7a8.16 8.16 0 0 0 4.77 1.52v-3.4a4.85 4.85 0 0 1-1.84-.1z"}

  defp dm_button_style(:whatsapp),
    do:
      {"bg-[#25D366] hover:bg-[#1FAF55]", "WhatsApp",
       "M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347"}

  @doc false
  def whatsapp_share_url(url, title) when is_binary(url) and is_binary(title) do
    text = URI.encode_www_form("#{title} — #{url}")
    "https://wa.me/?text=#{text}"
  end

  @doc false
  def x_share_url(url, title) when is_binary(url) and is_binary(title) do
    text = URI.encode_www_form(title)
    encoded_url = URI.encode_www_form(url)
    "https://twitter.com/intent/tweet?text=#{text}&url=#{encoded_url}"
  end

  @doc false
  def facebook_share_url(url) when is_binary(url) do
    "https://www.facebook.com/sharer/sharer.php?u=#{URI.encode_www_form(url)}"
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
