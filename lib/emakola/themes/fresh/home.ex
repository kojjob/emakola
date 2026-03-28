defmodule Emakola.Themes.Fresh.Home do
  @moduledoc """
  Fresh theme home page — warm, organic, appetizing.

  Sections (gated by `@theme.sections.*` booleans):
  - Hero with emerald-to-amber gradient, friendly headline, green CTA
  - Category circles with warm borders (horizontal scroll)
  - Featured "Today's Picks" section
  - Delivery banner with features
  - Product grid (2 col mobile, 3 col tablet, 4 col desktop)
  - Newsletter with weekly deals
  - Footer with delivery info
  """
  use Phoenix.Component

  alias Emakola.Themes.Fresh.Shared

  @doc """
  Renders the Fresh theme home page.

  Expects assigns:
  - `@store` — store map with `.name`, `.slug`, `.description`, `.whatsapp_number`
  - `@products` — list of products
  - `@categories` — list of categories
  - `@theme` — theme config map with `.sections` booleans
  - `@cart_count` — number of items in cart
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:featured_products, fn -> Enum.take(assigns.products, 4) end)
      |> assign_new(:grid_products, fn -> assigns.products end)

    ~H"""
    <div class="min-h-screen bg-[#FEFCE8]">
      <Shared.fresh_nav store={@store} cart_count={@cart_count} />
      <%!-- Hero Section --%>
      <section
        :if={section_enabled?(@theme, :hero)}
        class="relative overflow-hidden"
      >
        <div class="bg-gradient-to-br from-[#059669] via-[#047857] to-[#92400E]/30">
          <%!-- Organic leaf pattern overlay --%>
          <div class="absolute inset-0 opacity-[0.07]">
            <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <pattern
                  id="fresh-leaves"
                  x="0"
                  y="0"
                  width="60"
                  height="60"
                  patternUnits="userSpaceOnUse"
                >
                  <circle cx="15" cy="15" r="6" fill="white" fill-opacity="0.4" />
                  <circle cx="45" cy="45" r="4" fill="white" fill-opacity="0.3" />
                  <path
                    d="M30 5 Q35 15 30 25 Q25 15 30 5Z"
                    fill="white"
                    fill-opacity="0.2"
                  />
                </pattern>
              </defs>
              <rect width="100%" height="100%" fill="url(#fresh-leaves)" />
            </svg>
          </div>

          <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 lg:py-28">
            <div class="max-w-2xl">
              <span
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold tracking-widest uppercase text-[#D9F99D] bg-white/10 rounded-full mb-4 backdrop-blur-sm"
                style="font-family: 'Inter', sans-serif;"
              >
                <span
                  class="material-symbols-outlined"
                  style="font-size: 14px;"
                >
                  eco
                </span>
                {@store.name}
              </span>
              <h1
                class="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white leading-[1.1] mb-4"
                style="font-family: 'Nunito', sans-serif;"
              >
                {@theme.hero.title || "Fresh to Your Door"}
              </h1>
              <p
                class="text-lg sm:text-xl text-white/80 leading-relaxed mb-8 max-w-lg"
                style="font-family: 'Inter', sans-serif;"
              >
                {if @store.description,
                  do: @store.description,
                  else:
                    @theme.hero.subtitle ||
                      "Farm-fresh groceries delivered same day in Accra. Quality produce you can trust."}
              </p>
              <div class="flex flex-wrap gap-3">
                <a
                  href={"/s/#{@store.slug}/products"}
                  class="inline-flex items-center gap-2 px-8 py-4 bg-white text-[#059669] rounded-full text-base font-bold hover:bg-[#ECFDF5] active:scale-[0.97] transition-all shadow-lg shadow-black/20"
                  style="font-family: 'Inter', sans-serif;"
                >
                  {@theme.hero.cta_text || "Start Shopping"}
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
                  href={"https://wa.me/#{String.replace(@store.whatsapp_number || "", "+", "")}"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-2 px-6 py-4 bg-white/10 text-white rounded-full text-base font-semibold hover:bg-white/20 backdrop-blur-sm transition-all border border-white/20"
                  style="font-family: 'Inter', sans-serif;"
                >
                  <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                    <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
                  </svg>
                  Order via WhatsApp
                </a>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Category Circles (Horizontal Scroll) --%>
      <section
        :if={section_enabled?(@theme, :categories) and @categories != []}
        class="py-6 bg-[#FEFCE8]"
        aria-label="Product categories"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2
            class="text-lg font-bold text-[#1C1917] mb-4"
            style="font-family: 'Nunito', sans-serif;"
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

      <%!-- Today's Picks (Featured Products) --%>
      <section
        :if={section_enabled?(@theme, :featured) and @featured_products != []}
        class="py-8 bg-[#FEFCE8]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center gap-2.5">
              <span
                class="material-symbols-outlined text-[#059669]"
                style="font-size: 24px;"
              >
                local_fire_department
              </span>
              <h2
                class="text-2xl font-bold text-[#1C1917]"
                style="font-family: 'Nunito', sans-serif;"
              >
                Today's Picks
              </h2>
            </div>
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-sm font-semibold text-[#059669] hover:text-[#047857] transition-colors flex items-center gap-1"
              style="font-family: 'Inter', sans-serif;"
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
            <Shared.product_card
              :for={product <- @featured_products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <%!-- Delivery Banner --%>
      <section
        :if={section_enabled?(@theme, :promo)}
        class="py-8"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="relative rounded-3xl overflow-hidden bg-[#ECFDF5]">
            <div class="px-6 sm:px-10 py-10 sm:py-14">
              <div class="flex items-center gap-3 mb-4">
                <svg
                  class="w-8 h-8 text-[#059669]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
                  />
                </svg>
                <h3
                  class="text-2xl sm:text-3xl font-bold text-[#1C1917]"
                  style="font-family: 'Nunito', sans-serif;"
                >
                  Same-Day Delivery in Accra
                </h3>
              </div>
              <p
                class="text-[#78350F] text-base mb-8 max-w-lg"
                style="font-family: 'Inter', sans-serif;"
              >
                Order before noon and get your fresh produce delivered the same day. Quality guaranteed.
              </p>
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div class="flex items-center gap-3 bg-white rounded-2xl p-4 shadow-sm">
                  <div class="w-10 h-10 rounded-full bg-[#059669]/10 flex items-center justify-center flex-shrink-0">
                    <svg
                      class="w-5 h-5 text-[#059669]"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                  </div>
                  <div>
                    <p
                      class="text-sm font-bold text-[#1C1917]"
                      style="font-family: 'Nunito', sans-serif;"
                    >
                      Fresh Guarantee
                    </p>
                    <p class="text-xs text-[#78350F]" style="font-family: 'Inter', sans-serif;">
                      Quality checked produce
                    </p>
                  </div>
                </div>
                <div class="flex items-center gap-3 bg-white rounded-2xl p-4 shadow-sm">
                  <div class="w-10 h-10 rounded-full bg-[#059669]/10 flex items-center justify-center flex-shrink-0">
                    <svg
                      class="w-5 h-5 text-[#059669]"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                  </div>
                  <div>
                    <p
                      class="text-sm font-bold text-[#1C1917]"
                      style="font-family: 'Nunito', sans-serif;"
                    >
                      Same Day Delivery
                    </p>
                    <p class="text-xs text-[#78350F]" style="font-family: 'Inter', sans-serif;">
                      Order before 12pm
                    </p>
                  </div>
                </div>
                <div class="flex items-center gap-3 bg-white rounded-2xl p-4 shadow-sm">
                  <div class="w-10 h-10 rounded-full bg-[#059669]/10 flex items-center justify-center flex-shrink-0">
                    <svg
                      class="w-5 h-5 text-[#059669]"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M9 12.75L11.25 15 15 9.75m-6-7.19l-2.12 2.12a1.5 1.5 0 01-1.061.44H4.5A2.25 2.25 0 002.25 9v1.069c0 .398.158.78.44 1.06l2.12 2.122c.282.281.44.663.44 1.06V16.5a2.25 2.25 0 002.25 2.25h1.069c.397 0 .78.158 1.06.44l2.122 2.12a1.5 1.5 0 002.12 0l2.122-2.12a1.5 1.5 0 011.06-.44H18.75A2.25 2.25 0 0021 16.5v-1.069a1.5 1.5 0 01.44-1.06l2.12-2.122a1.5 1.5 0 000-2.12l-2.12-2.122a1.5 1.5 0 01-.44-1.06V4.5A2.25 2.25 0 0018.75 2.25h-1.069a1.5 1.5 0 01-1.06-.44l-2.122-2.12a1.5 1.5 0 00-2.12 0z"
                      />
                    </svg>
                  </div>
                  <div>
                    <p
                      class="text-sm font-bold text-[#1C1917]"
                      style="font-family: 'Nunito', sans-serif;"
                    >
                      Secure Payment
                    </p>
                    <p class="text-xs text-[#78350F]" style="font-family: 'Inter', sans-serif;">
                      MoMo, Card & Cash
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Shop All Products Grid --%>
      <section
        :if={section_enabled?(@theme, :products) and @grid_products != []}
        class="py-8 bg-[#FEFCE8]"
        aria-labelledby="fresh-shop-all"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center gap-2.5">
              <span
                class="material-symbols-outlined text-[#059669]"
                style="font-size: 24px;"
              >
                eco
              </span>
              <h2
                id="fresh-shop-all"
                class="text-2xl font-bold text-[#1C1917]"
                style="font-family: 'Nunito', sans-serif;"
              >
                Shop All Products
              </h2>
            </div>
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-sm font-semibold text-[#059669] hover:text-[#047857] transition-colors flex items-center gap-1"
              style="font-family: 'Inter', sans-serif;"
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

      <%!-- Newsletter Section --%>
      <section
        :if={section_enabled?(@theme, :newsletter)}
        class="py-10"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="bg-[#FEF9C3] rounded-3xl p-8 sm:p-12 text-center">
            <h2
              class="text-2xl sm:text-3xl font-bold text-[#1C1917] mb-3"
              style="font-family: 'Nunito', sans-serif;"
            >
              {@theme.newsletter.title || "Get Weekly Deals & Recipes"}
            </h2>
            <p
              class="text-[#78350F] text-base mb-6 max-w-md mx-auto"
              style="font-family: 'Inter', sans-serif;"
            >
              {@theme.newsletter.subtitle ||
                "Fresh picks, seasonal specials, and recipes delivered to your inbox."}
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
                class="flex-1 px-5 py-3.5 rounded-full bg-white text-[#1C1917] placeholder:text-[#92400E]/40 border border-[#D9F99D] focus:outline-none focus:ring-2 focus:ring-[#059669] focus:border-transparent text-sm shadow-sm"
                style="font-family: 'Inter', sans-serif;"
              />
              <button
                type="submit"
                class="px-8 py-3.5 bg-[#059669] text-white rounded-full text-sm font-bold hover:bg-[#047857] active:scale-[0.97] transition-all shadow-lg shadow-emerald-200"
                style="font-family: 'Inter', sans-serif;"
              >
                {@theme.newsletter.button_text || "Subscribe"}
              </button>
            </form>
          </div>
        </div>
      </section>

      <Shared.footer store={@store} categories={@categories} />
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
