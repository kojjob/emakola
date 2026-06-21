defmodule Emakola.Themes.Starter.Home do
  @moduledoc """
  Starter theme home page -- clean, modern, minimal.

  Sections (gated by `@theme.sections.*` booleans):
  - Hero with indigo-to-slate gradient, large headline, CTA
  - Categories as horizontal scrollable pill chips
  - Featured products in a 2-col (mobile) / 4-col (desktop) grid
  - Trust section with three value propositions
  - Newsletter with simple email input in a light card
  - Footer via shared
  """
  use Phoenix.Component

  alias Emakola.Themes.Starter.Shared

  @doc """
  Renders the Starter theme home page.

  Expects assigns:
  - `@store` -- store map with `.name`, `.slug`, `.description`, `.whatsapp_number`
  - `@products` -- list of products with `.title`, `.slug`, `.min_price`, `.max_price`, `.images`
  - `@categories` -- list of categories with `.name`, `.slug`
  - `@theme` -- theme config map with `.sections` booleans
  - `@cart_count` -- integer cart item count
  """
  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <Shared.theme_styles theme={@theme} />
      <Shared.starter_nav store={@store} cart_count={@cart_count} />
      <%!-- Hero Section --%>
      <section
        :if={section_enabled?(@theme, :hero)}
        class="relative overflow-hidden"
      >
        <div class="bg-gradient-to-br from-[var(--theme-primary,#6366F1)] via-[#4F46E5] to-[var(--theme-accent,#1E293B)]">
          <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 lg:py-28">
            <div class="max-w-2xl">
              <h1
                class="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white leading-[1.1] mb-4 tracking-tight"
                style="font-family: 'Inter', sans-serif;"
              >
                {@theme.hero.title}
              </h1>
              <p
                class="text-lg sm:text-xl text-white/70 leading-relaxed mb-8 max-w-lg"
                style="font-family: 'Inter', sans-serif;"
              >
                {if @store.description,
                  do: @store.description,
                  else: @theme.hero.subtitle}
              </p>
              <div class="flex flex-wrap gap-3">
                <a
                  href={"/@#{@store.slug}/products"}
                  class="inline-flex items-center gap-2 px-8 py-4 bg-white text-[var(--theme-primary,#6366F1)] rounded-full text-base font-semibold hover:bg-gray-50 active:scale-[0.97] transition-all shadow-lg shadow-black/10"
                  style="font-family: 'Inter', sans-serif;"
                >
                  {@theme.hero.cta_text}
                  <svg
                    class="w-5 h-5"
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
                <a
                  :if={Map.get(@store, :whatsapp_number)}
                  href={"https://wa.me/#{String.replace(@store.whatsapp_number || "", "+", "")}"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-2 px-6 py-4 bg-white/10 text-white rounded-full text-base font-medium hover:bg-white/20 backdrop-blur-sm transition-all border border-white/20"
                  style="font-family: 'Inter', sans-serif;"
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

      <%!-- Category Pills (Horizontal Scroll) --%>
      <section
        :if={section_enabled?(@theme, :categories) and @categories != []}
        class="py-6 bg-white"
        aria-label="Product categories"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2
            class="text-lg font-semibold text-[#0F172A] mb-4"
            style="font-family: 'Inter', sans-serif;"
          >
            Shop by Category
          </h2>
          <div
            class="flex gap-3 overflow-x-auto pb-2 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
            role="list"
          >
            <Shared.category_pill
              :for={category <- @categories}
              category={category}
              store_slug={@store.slug}
            />
          </div>
        </div>
      </section>

      <%!-- Featured Products Grid --%>
      <section
        :if={section_enabled?(@theme, :featured) and @products != []}
        class="py-10 bg-white"
        aria-labelledby="starter-featured"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between mb-6">
            <h2
              id="starter-featured"
              class="text-2xl font-semibold text-[#0F172A]"
              style="font-family: 'Inter', sans-serif;"
            >
              Featured Products
            </h2>
            <a
              href={"/@#{@store.slug}/products"}
              class="text-sm font-medium text-[var(--theme-primary,#6366F1)] hover:text-[#4F46E5] transition-colors flex items-center gap-1"
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
            <Shared.product_card :for={product <- @products} product={product} store={@store} />
          </div>
        </div>
      </section>

      <%!-- Trust Section --%>
      <section
        :if={section_enabled?(@theme, :trust)}
        class="py-12 bg-[#F8FAFC]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2
            class="text-xl font-semibold text-[#0F172A] text-center mb-8"
            style="font-family: 'Inter', sans-serif;"
          >
            {@theme.trust.title}
          </h2>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
            <%!-- Secure Payment --%>
            <div class="text-center p-6">
              <div class="w-12 h-12 rounded-xl bg-[var(--theme-primary,#6366F1)]/10 mx-auto mb-4 flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-[var(--theme-primary,#6366F1)]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
                  />
                </svg>
              </div>
              <h3
                class="text-sm font-semibold text-[#0F172A] mb-1"
                style="font-family: 'Inter', sans-serif;"
              >
                Secure Payment
              </h3>
              <p class="text-xs text-[#64748B]" style="font-family: 'Inter', sans-serif;">
                Mobile money and card payments protected with encryption.
              </p>
            </div>

            <%!-- Fast Delivery --%>
            <div class="text-center p-6">
              <div class="w-12 h-12 rounded-xl bg-[var(--theme-primary,#6366F1)]/10 mx-auto mb-4 flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-[var(--theme-primary,#6366F1)]"
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
              </div>
              <h3
                class="text-sm font-semibold text-[#0F172A] mb-1"
                style="font-family: 'Inter', sans-serif;"
              >
                Fast Delivery
              </h3>
              <p class="text-xs text-[#64748B]" style="font-family: 'Inter', sans-serif;">
                Quick delivery within Accra and nationwide shipping available.
              </p>
            </div>

            <%!-- Easy Returns --%>
            <div class="text-center p-6">
              <div class="w-12 h-12 rounded-xl bg-[var(--theme-primary,#6366F1)]/10 mx-auto mb-4 flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-[var(--theme-primary,#6366F1)]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182"
                  />
                </svg>
              </div>
              <h3
                class="text-sm font-semibold text-[#0F172A] mb-1"
                style="font-family: 'Inter', sans-serif;"
              >
                Easy Returns
              </h3>
              <p class="text-xs text-[#64748B]" style="font-family: 'Inter', sans-serif;">
                Hassle-free returns within 7 days of delivery.
              </p>
            </div>
          </div>
        </div>
      </section>

      <%!-- Newsletter Section --%>
      <section
        :if={section_enabled?(@theme, :newsletter)}
        class="py-12"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="bg-[#F8FAFC] rounded-2xl p-8 sm:p-12 text-center">
            <h2
              class="text-2xl font-semibold text-[#0F172A] mb-2"
              style="font-family: 'Inter', sans-serif;"
            >
              {@theme.newsletter.title}
            </h2>
            <p
              class="text-[#64748B] text-sm mb-6 max-w-md mx-auto"
              style="font-family: 'Inter', sans-serif;"
            >
              {@theme.newsletter.subtitle}
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
                class="flex-1 px-5 py-3 rounded-full bg-white text-[#0F172A] placeholder:text-[#94A3B8] border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[var(--theme-primary,#6366F1)] focus:border-transparent text-sm"
                style="font-family: 'Inter', sans-serif;"
              />
              <button
                type="submit"
                class="px-8 py-3 bg-[var(--theme-primary,#6366F1)] text-white rounded-full text-sm font-semibold hover:bg-[#4F46E5] active:scale-[0.97] transition-all"
                style="font-family: 'Inter', sans-serif;"
              >
                {@theme.newsletter.button_text}
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
