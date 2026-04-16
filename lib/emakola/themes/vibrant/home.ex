defmodule Emakola.Themes.Vibrant.Home do
  @moduledoc """
  Vibrant theme home page — bold, energetic, West African commerce-inspired.

  Sections (gated by `@theme.sections.*` booleans):
  - Bold hero with warm gradient background and large CTA
  - Story-style category circles (horizontal scroll)
  - Featured product highlight (large card)
  - Product grid (2 col mobile, 3 col tablet, 4 col desktop)
  - About/story section with warm tones
  - Newsletter with vibrant CTA
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Vibrant.Shared
  alias EmakolaWeb.Helpers.Currency

  @doc """
  Renders the Vibrant theme home page.

  Expects assigns:
  - `@store` — store map with `.name`, `.slug`, `.description`, `.whatsapp_number`
  - `@products` — list of products with `.title`, `.slug`, `.min_price`, `.max_price`, `.images`
  - `@categories` — list of categories with `.name`, `.slug`, `.description`
  - `@theme` — theme config map with `.sections` booleans
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:featured_product, fn -> List.first(assigns.products) end)
      |> assign_new(:grid_products, fn -> assigns.products end)

    ~H"""
    <div class="min-h-screen bg-[#FFFBEB]">
      <Shared.theme_styles theme={@theme} />
      <%!-- Bold Hero Section --%>
      <section
        :if={section_enabled?(@theme, :hero)}
        class="relative overflow-hidden"
      >
        <div class="bg-gradient-to-br from-[var(--theme-primary,#DC2626)] via-[#B91C1C] to-[var(--theme-accent,#7C2D12)]">
          <%!-- Pattern-like texture overlay --%>
          <div class="absolute inset-0 opacity-10">
            <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <pattern
                  id="vibrant-pattern"
                  x="0"
                  y="0"
                  width="40"
                  height="40"
                  patternUnits="userSpaceOnUse"
                >
                  <circle cx="20" cy="20" r="8" fill="white" fill-opacity="0.3" />
                  <path
                    d="M0 20 L40 20 M20 0 L20 40"
                    stroke="white"
                    stroke-width="0.5"
                    stroke-opacity="0.2"
                  />
                </pattern>
              </defs>
              <rect width="100%" height="100%" fill="url(#vibrant-pattern)" />
            </svg>
          </div>

          <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 lg:py-28">
            <div class="max-w-2xl">
              <span class="inline-flex items-center px-3 py-1.5 text-xs font-bold tracking-widest uppercase text-[#FDE68A] bg-white/10 rounded-full mb-4 backdrop-blur-sm">
                {@store.name}
              </span>
              <h1
                class="text-4xl sm:text-5xl lg:text-6xl font-bold text-white leading-[1.1] mb-4"
                style="font-family: 'Playfair Display', serif;"
              >
                Discover Bold, Beautiful Products
              </h1>
              <p
                class="text-lg sm:text-xl text-white/80 leading-relaxed mb-8 max-w-lg"
                style="font-family: 'DM Sans', sans-serif;"
              >
                {if @store.description,
                  do: @store.description,
                  else: "Explore our curated collection of quality products, handpicked for you."}
              </p>
              <div class="flex flex-wrap gap-3">
                <a
                  href={"/s/#{@store.slug}/products"}
                  class="inline-flex items-center gap-2 px-8 py-4 bg-white text-[var(--theme-primary,#DC2626)] rounded-full text-base font-bold hover:bg-[#FEF3C7] active:scale-[0.97] transition-all shadow-lg shadow-black/20"
                  style="font-family: 'DM Sans', sans-serif;"
                >
                  Shop Now
                  <svg
                    class="w-5 h-5"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.5"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                    />
                  </svg>
                </a>
                <a
                  :if={Map.get(@store, :whatsapp_number)}
                  href={"https://wa.me/#{@store.whatsapp_number}"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-2 px-6 py-4 bg-white/10 text-white rounded-full text-base font-semibold hover:bg-white/20 backdrop-blur-sm transition-all border border-white/20"
                  style="font-family: 'DM Sans', sans-serif;"
                >
                  <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
                  </svg>
                  Chat with Us
                </a>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Category Circles (Story-Style Horizontal Scroll) --%>
      <section
        :if={section_enabled?(@theme, :categories) and @categories != []}
        class="py-6 bg-[#FFFBEB]"
        aria-label="Product categories"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2
            class="text-lg font-bold text-[#1C1917] mb-4"
            style="font-family: 'Playfair Display', serif;"
          >
            Shop by Category
          </h2>
          <div
            class="flex gap-5 overflow-x-auto pb-2 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
            role="list"
          >
            <Shared.category_circle
              :for={category <- @categories}
              category={category}
              store_slug={@store.slug}
            />
          </div>
        </div>
      </section>

      <%!-- Featured Product Highlight --%>
      <section
        :if={section_enabled?(@theme, :featured) and @featured_product}
        class="py-8 bg-[#FFFBEB]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <.featured_card product={@featured_product} store={@store} />
        </div>
      </section>

      <%!-- Product Grid --%>
      <section
        :if={section_enabled?(@theme, :products) and @grid_products != []}
        class="py-8 bg-[#FFFBEB]"
        aria-labelledby="vibrant-shop-all"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between mb-6">
            <h2
              id="vibrant-shop-all"
              class="text-2xl font-bold text-[#1C1917]"
              style="font-family: 'Playfair Display', serif;"
            >
              Shop All
            </h2>
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-sm font-semibold text-[var(--theme-primary,#DC2626)] hover:text-[var(--theme-accent,#7C2D12)] transition-colors flex items-center gap-1"
            >
              View All
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </a>
          </div>
          <div class="grid grid-cols-2 gap-4 md:grid-cols-3 md:gap-5 lg:grid-cols-4 lg:gap-6">
            <Shared.product_card :for={product <- @grid_products} product={product} store={@store} />
          </div>
        </div>
      </section>

      <%!-- Colorful Accent Section / Promo Banner --%>
      <section
        :if={section_enabled?(@theme, :promo)}
        class="py-8"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="relative rounded-3xl overflow-hidden bg-gradient-to-r from-[var(--theme-accent,#7C2D12)] to-[var(--theme-primary,#DC2626)]">
            <%!-- Decorative pattern --%>
            <div class="absolute inset-0 opacity-10">
              <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern
                    id="promo-dots"
                    x="0"
                    y="0"
                    width="24"
                    height="24"
                    patternUnits="userSpaceOnUse"
                  >
                    <circle cx="12" cy="12" r="2" fill="white" />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#promo-dots)" />
              </svg>
            </div>
            <div class="relative px-6 sm:px-10 py-12 sm:py-16 text-center">
              <h3
                class="text-2xl sm:text-3xl font-bold text-white mb-3"
                style="font-family: 'Playfair Display', serif;"
              >
                New Arrivals Every Week
              </h3>
              <p
                class="text-white/80 text-base mb-6 max-w-md mx-auto"
                style="font-family: 'DM Sans', sans-serif;"
              >
                Be the first to discover our latest collection of handpicked products.
              </p>
              <a
                href={"/s/#{@store.slug}/products"}
                class="inline-flex items-center gap-2 px-8 py-3.5 bg-white text-[var(--theme-accent,#7C2D12)] rounded-full text-sm font-bold hover:bg-[#FEF3C7] active:scale-[0.97] transition-all shadow-lg"
              >
                Explore Collection
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                  />
                </svg>
              </a>
            </div>
          </div>
        </div>
      </section>

      <%!-- About / Story Section --%>
      <section
        :if={section_enabled?(@theme, :about)}
        class="py-10 bg-[#FFFBEB]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="bg-white rounded-3xl border border-[#FDE68A]/60 p-8 sm:p-12 text-center shadow-sm">
            <h2
              class="text-2xl font-bold text-[#1C1917] mb-5"
              style="font-family: 'Playfair Display', serif;"
            >
              Our Story
            </h2>
            <div class="w-24 h-24 rounded-full bg-gradient-to-br from-[var(--theme-primary,#DC2626)] to-[var(--theme-accent,#7C2D12)] mx-auto mb-5 flex items-center justify-center shadow-lg shadow-red-200">
              <span
                class="text-3xl font-bold text-white"
                style="font-family: 'Playfair Display', serif;"
              >
                {String.first(@store.name)}
              </span>
            </div>
            <p
              class="text-base text-[#78350F] leading-relaxed max-w-[520px] mx-auto mb-6"
              style="font-family: 'DM Sans', sans-serif;"
            >
              {if @store.description,
                do: @store.description,
                else:
                  "Welcome to #{@store.name}. We bring you quality products with the warmth and vibrancy of West African commerce."}
            </p>
            <a
              :if={Map.get(@store, :whatsapp_number)}
              href={"https://wa.me/#{@store.whatsapp_number}"}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-2 px-6 py-3 bg-[#25D366] text-white rounded-full text-sm font-bold hover:bg-[#1FAF55] transition-colors shadow-md"
            >
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
              </svg>
              Chat on WhatsApp
            </a>
          </div>
        </div>
      </section>

      <%!-- Newsletter Section --%>
      <section
        :if={section_enabled?(@theme, :newsletter)}
        class="py-10"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="bg-gradient-to-br from-[#1C1917] to-[#292524] rounded-3xl p-8 sm:p-12 text-center">
            <h2
              class="text-2xl sm:text-3xl font-bold text-white mb-3"
              style="font-family: 'Playfair Display', serif;"
            >
              Stay in the Loop
            </h2>
            <p
              class="text-white/70 text-base mb-6 max-w-md mx-auto"
              style="font-family: 'DM Sans', sans-serif;"
            >
              Get notified about new arrivals, special offers, and exclusive deals.
            </p>
            <form
              class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto"
              phx-submit="subscribe_newsletter"
            >
              <input
                type="email"
                name="email"
                placeholder="Enter your email"
                required
                class="flex-1 px-5 py-3.5 rounded-full bg-white/10 text-white placeholder:text-white/40 border border-white/20 focus:outline-none focus:ring-2 focus:ring-[var(--theme-primary,#DC2626)] focus:border-transparent text-sm"
                style="font-family: 'DM Sans', sans-serif;"
              />
              <button
                type="submit"
                class="px-8 py-3.5 bg-[var(--theme-primary,#DC2626)] text-white rounded-full text-sm font-bold hover:bg-[#B91C1C] active:scale-[0.97] transition-all shadow-lg shadow-red-900/30"
                style="font-family: 'DM Sans', sans-serif;"
              >
                Subscribe
              </button>
            </form>
          </div>
        </div>
      </section>

      <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Featured Card ──

  defp featured_card(assigns) do
    assigns = assign(assigns, :image, Shared.first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="block bg-white rounded-3xl overflow-hidden border border-[#FDE68A]/60 mb-2 hover:shadow-2xl hover:shadow-amber-200/40 transition-all duration-300 md:grid md:grid-cols-2"
      aria-label={"Featured product: #{@product.title}"}
    >
      <div class="w-full aspect-[16/10] md:aspect-auto md:h-full md:min-h-[360px] bg-[#FEF3C7]/30 overflow-hidden">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          priority={:high}
          class="w-full h-full object-cover"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center">
          <svg class="w-16 h-16 text-[#D97706]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
        </div>
      </div>
      <div class="p-6 sm:p-8 md:p-10 md:flex md:flex-col md:justify-center">
        <span class="inline-flex items-center px-3 py-1.5 text-[0.6875rem] font-bold tracking-wider uppercase text-[var(--theme-primary,#DC2626)] bg-red-50 rounded-full mb-3 w-fit">
          Featured
        </span>
        <h2
          class="text-2xl sm:text-3xl font-bold text-[#1C1917] mb-2 leading-tight"
          style="font-family: 'Playfair Display', serif;"
        >
          {@product.title}
        </h2>
        <p
          :if={@product.description}
          class="text-base text-[#78350F] leading-relaxed mb-5 line-clamp-2"
          style="font-family: 'DM Sans', sans-serif;"
        >
          {@product.description}
        </p>
        <p class="text-xl font-bold text-[var(--theme-primary,#DC2626)] mb-5">
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span class="flex items-center justify-center gap-2 w-full py-4 px-6 bg-[var(--theme-primary,#DC2626)] text-white rounded-full text-base font-bold hover:bg-[#B91C1C] active:scale-[0.97] transition-all shadow-lg shadow-red-200 leading-none">
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
            />
          </svg>
          Add to Bag
        </span>
      </div>
    </a>
    """
  end

  # ── Section Gating Helper ──

  defp section_enabled?(theme, section_name) do
    case theme do
      %{sections: sections} when is_map(sections) ->
        Map.get(sections, section_name, true)

      _ ->
        true
    end
  end
end
