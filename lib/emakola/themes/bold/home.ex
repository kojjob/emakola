defmodule Emakola.Themes.Bold.Home do
  @moduledoc """
  Bold theme home page — editorial, magazine-style layout.

  Sections (gated by `@theme.sections.*` booleans):
  - Full-bleed dark hero with massive headline
  - Text-based category links separated by vertical bars
  - Asymmetric bento grid for featured products
  - Full-width amber editorial banner
  - Clean 3-column product grid
  - Dark newsletter section with amber CTA
  - Dark editorial footer
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Bold.Shared
  alias EmakolaWeb.Helpers.Currency

  @doc """
  Renders the Bold theme home page.

  Expects assigns:
  - `@store` — store map with `.name`, `.slug`, `.description`, `.whatsapp_number`
  - `@products` — list of products with `.title`, `.slug`, `.min_price`, `.max_price`, `.images`
  - `@categories` — list of categories with `.name`, `.slug`
  - `@theme` — theme config map with `.sections` booleans
  - `@cart_count` — integer cart item count
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:featured_products, fn ->
        Enum.take(assigns.products, 3)
      end)
      |> assign_new(:grid_products, fn -> assigns.products end)

    ~H"""
    <div class="min-h-screen bg-[#F8FAFC]">
      <Shared.bold_nav store={@store} cart_count={@cart_count} />

      <%!-- Full-Bleed Dark Hero --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative overflow-hidden">
        <%= if @theme.hero.image_url && @theme.hero.image_url != "" do %>
          <div class="relative min-h-[70vh] sm:min-h-[80vh] flex items-center">
            <.optimized_image
              src={@theme.hero.image_url}
              alt=""
              priority={:high}
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-[#0F172A]/70"></div>
            <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-20 sm:py-28 lg:py-36 w-full">
              <.hero_content store={@store} theme={@theme} />
            </div>
          </div>
        <% else %>
          <div class="relative min-h-[70vh] sm:min-h-[80vh] flex items-center bg-gradient-to-br from-[#0F172A] via-[#1E293B] to-[#0F172A]">
            <div class="absolute inset-0 opacity-[0.03]">
              <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern
                    id="bold-grid"
                    x="0"
                    y="0"
                    width="60"
                    height="60"
                    patternUnits="userSpaceOnUse"
                  >
                    <path
                      d="M60 0 L0 0 L0 60"
                      fill="none"
                      stroke="white"
                      stroke-width="0.5"
                    />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#bold-grid)" />
              </svg>
            </div>
            <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-20 sm:py-28 lg:py-36 w-full">
              <.hero_content store={@store} theme={@theme} />
            </div>
          </div>
        <% end %>
      </section>

      <%!-- Category Text Links (Editorial Navigation) --%>
      <section
        :if={section_enabled?(@theme, :categories) and @categories != []}
        class="py-8 bg-[#F8FAFC] border-b border-[#E2E8F0]"
        aria-label="Product categories"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-center gap-4 sm:gap-6 flex-wrap">
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-xs sm:text-sm font-semibold tracking-[0.15em] uppercase text-[#0F172A] hover:text-[#F59E0B] transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
              All
            </a>
            <span
              :for={cat <- @categories}
              class="flex items-center gap-4 sm:gap-6"
            >
              <span class="text-[#CBD5E1]" aria-hidden="true">|</span>
              <a
                href={"/s/#{@store.slug}/category/#{cat.slug}"}
                class="text-xs sm:text-sm font-semibold tracking-[0.15em] uppercase text-[#64748B] hover:text-[#0F172A] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                {cat.name}
              </a>
            </span>
          </div>
        </div>
      </section>

      <%!-- Featured Products — Asymmetric Bento Grid --%>
      <section
        :if={section_enabled?(@theme, :featured) and @featured_products != []}
        class="py-12 sm:py-16 bg-[#F8FAFC]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2
            class="text-xs font-bold tracking-[0.2em] uppercase text-[#64748B] mb-8"
            style="font-family: 'Outfit', sans-serif;"
          >
            Featured
          </h2>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-6">
            <%!-- Large hero card --%>
            <%= if Enum.at(@featured_products, 0) do %>
              <% product = Enum.at(@featured_products, 0) %>
              <a
                href={"/s/#{@store.slug}/products/#{product.slug}"}
                class="group block md:row-span-2"
              >
                <div class="relative overflow-hidden bg-[#F1F5F9] h-full min-h-[400px] md:min-h-0">
                  <.optimized_image
                    :if={Shared.first_image(product)}
                    src={Shared.first_image(product)}
                    alt={product.title}
                    priority={:high}
                    class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
                  />
                  <div
                    :if={!Shared.first_image(product)}
                    class="w-full h-full flex items-center justify-center min-h-[400px]"
                  >
                    <svg
                      class="w-16 h-16 text-[#94A3B8]"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="1"
                        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                      />
                    </svg>
                  </div>
                  <div class="absolute bottom-0 left-0 right-0 p-6 sm:p-8 bg-gradient-to-t from-[#0F172A]/80 via-[#0F172A]/40 to-transparent">
                    <h3
                      class="text-xl sm:text-2xl font-bold text-white mb-1"
                      style="font-family: 'Outfit', sans-serif;"
                    >
                      {product.title}
                    </h3>
                    <p class="text-sm text-white/70" style="font-family: 'Inter', sans-serif;">
                      {Currency.format_price_range(
                        product.min_price,
                        product.max_price,
                        @store.currency
                      )}
                    </p>
                  </div>
                </div>
              </a>
            <% end %>
            <%!-- Two smaller cards stacked --%>
            <%= for product <- Enum.slice(@featured_products, 1, 2) do %>
              <a
                href={"/s/#{@store.slug}/products/#{product.slug}"}
                class="group block"
              >
                <div class="relative overflow-hidden bg-[#F1F5F9]">
                  <.optimized_image
                    :if={Shared.first_image(product)}
                    src={Shared.first_image(product)}
                    alt={product.title}
                    class="w-full aspect-[4/3] object-cover group-hover:scale-105 transition-transform duration-700"
                  />
                  <div
                    :if={!Shared.first_image(product)}
                    class="w-full aspect-[4/3] flex items-center justify-center"
                  >
                    <svg
                      class="w-12 h-12 text-[#94A3B8]"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="1"
                        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                      />
                    </svg>
                  </div>
                  <div class="absolute bottom-0 left-0 right-0 p-5 bg-gradient-to-t from-[#0F172A]/70 to-transparent">
                    <h3
                      class="text-lg font-bold text-white mb-0.5"
                      style="font-family: 'Outfit', sans-serif;"
                    >
                      {product.title}
                    </h3>
                    <p class="text-sm text-white/70" style="font-family: 'Inter', sans-serif;">
                      {Currency.format_price_range(
                        product.min_price,
                        product.max_price,
                        @store.currency
                      )}
                    </p>
                  </div>
                </div>
              </a>
            <% end %>
          </div>
        </div>
      </section>

      <%!-- Editorial Banner — Full-Width Amber Accent Bar --%>
      <section
        :if={section_enabled?(@theme, :editorial_banner)}
        class="bg-[#F59E0B]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14 text-center">
          <p
            class="text-2xl sm:text-3xl lg:text-4xl font-bold italic text-[#0F172A] leading-snug max-w-3xl mx-auto"
            style="font-family: 'Outfit', sans-serif;"
          >
            {if @store.description,
              do: @store.description,
              else: "Curated for those who appreciate the art of well-made things."}
          </p>
        </div>
      </section>

      <%!-- Products Grid (Clean 3-Column) --%>
      <section
        :if={section_enabled?(@theme, :products) and @grid_products != []}
        class="py-12 sm:py-16 bg-[#F8FAFC]"
        aria-labelledby="bold-shop-all"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between mb-10">
            <h2
              id="bold-shop-all"
              class="text-2xl sm:text-3xl font-bold text-[#0F172A]"
              style="font-family: 'Outfit', sans-serif;"
            >
              The Collection
            </h2>
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-sm font-medium text-[#64748B] hover:text-[#0F172A] transition-colors border-b border-[#64748B] hover:border-[#0F172A] pb-0.5"
              style="font-family: 'Inter', sans-serif;"
            >
              View All
            </a>
          </div>
          <div class="grid grid-cols-2 gap-6 sm:gap-8 lg:grid-cols-3 lg:gap-10">
            <Shared.product_card :for={product <- @grid_products} product={product} store={@store} />
          </div>
        </div>
      </section>

      <%!-- Newsletter (Dark BG, Amber CTA) --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="py-16 sm:py-20">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="bg-[#0F172A] px-6 sm:px-12 lg:px-20 py-14 sm:py-20 text-center">
            <h2
              class="text-2xl sm:text-3xl lg:text-4xl font-bold text-white mb-4"
              style="font-family: 'Outfit', sans-serif;"
            >
              Stay in the Know
            </h2>
            <p
              class="text-slate-400 text-base mb-8 max-w-md mx-auto"
              style="font-family: 'Inter', sans-serif;"
            >
              New drops, editorial picks, and exclusive access delivered to your inbox.
            </p>
            <form
              class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto"
              phx-submit="subscribe_newsletter"
            >
              <input
                type="email"
                name="email"
                placeholder="Your email address"
                required
                class="flex-1 px-5 py-3.5 bg-slate-800 text-white placeholder:text-slate-500 border border-slate-700 text-sm focus:outline-none focus:border-[#F59E0B] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              />
              <button
                type="submit"
                class="px-8 py-3.5 bg-[#F59E0B] text-[#0F172A] text-sm font-bold hover:bg-[#D97706] active:scale-[0.97] transition-all tracking-wide uppercase"
                style="font-family: 'Inter', sans-serif;"
              >
                Subscribe
              </button>
            </form>
          </div>
        </div>
      </section>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Hero Content Component ──

  defp hero_content(assigns) do
    ~H"""
    <div class="max-w-3xl">
      <p
        class="text-xs sm:text-sm font-semibold tracking-[0.3em] uppercase text-[#F59E0B] mb-6"
        style="font-family: 'Inter', sans-serif;"
      >
        {@store.name}
      </p>
      <h1
        class="text-5xl sm:text-6xl lg:text-7xl xl:text-8xl font-black text-white leading-[0.95] mb-6 tracking-tight"
        style="font-family: 'Outfit', sans-serif;"
      >
        {@theme.hero.title || "The Edit"}
      </h1>
      <p
        class="text-lg sm:text-xl text-slate-300 leading-relaxed mb-10 max-w-lg font-light"
        style="font-family: 'Inter', sans-serif;"
      >
        {@theme.hero.subtitle || "Curated goods for the discerning eye"}
      </p>
      <a
        href={"/s/#{@store.slug}/products"}
        class="inline-flex items-center gap-3 px-8 py-4 bg-[#F59E0B] text-[#0F172A] text-sm font-bold tracking-wide uppercase hover:bg-[#D97706] active:scale-[0.97] transition-all"
        style="font-family: 'Inter', sans-serif;"
      >
        {@theme.hero.cta_text || "Shop the Collection"}
        <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
          />
        </svg>
      </a>
    </div>
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
