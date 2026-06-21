defmodule Emakola.Themes.Beauty.Home do
  @moduledoc """
  Beauty theme home — warm botanical luxe.

  Sections (gated by `@theme.sections.*` booleans):
  - Dark walnut hero with photographic image, dramatic Cormorant headline,
    cream pill CTA and gold "Book Your Experience" badge
  - Gold "as featured in" brand strip
  - Featured products grid (rounded cards, full-bleed photos)
  - "Why your skin deserves the best" 3-card feature block on dark walnut
  - 4-column testimonials with customer photos and 5-star ratings
  - FAQ accordion
  - Closing dark CTA — "Ready for flawless skin?"
  - Newsletter on walnut
  - Footer (deeper walnut)
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Beauty.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:featured_products, fn -> Enum.take(assigns.products, 6) end)

    ~H"""
    <div class="beauty-body min-h-screen">
      <Shared.theme_styles theme={@theme} />

      <%!-- HERO: dark walnut, photographic, dramatic serif --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative bg-[#6B4423]">
        <Shared.beauty_nav store={@store} cart_count={@cart_count} on_dark={true} />

        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-10 pb-16 sm:pt-16 sm:pb-24">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
            <div class="relative z-10 order-2 lg:order-1">
              <span class="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full bg-[#C9925E]/20 text-[#C9925E] text-[11px] font-semibold uppercase tracking-[0.2em] mb-6">
                <span class="material-symbols-outlined" style="font-size: 14px;">spa</span>
                Botanical Beauty
              </span>
              <h1 class="beauty-heading text-5xl sm:text-6xl lg:text-7xl font-semibold text-[#FAF6EE] leading-[1.05] mb-6">
                {@theme.hero.title || "Elevate Your Essence"}
              </h1>
              <p class="text-base sm:text-lg text-[#FAF6EE]/80 leading-relaxed mb-8 max-w-lg">
                {@theme.hero.subtitle ||
                  @store.description ||
                  "Botanical skincare and beauty essentials — crafted for melanin-rich skin."}
              </p>
              <div class="flex flex-col sm:flex-row gap-3">
                <a
                  href={store_path(@store.slug, "/products")}
                  class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-[#FAF6EE] text-[#6B4423] text-sm font-semibold hover:bg-white transition-colors min-h-[48px]"
                >
                  {@theme.hero.cta_text || "Shop the Collection"}
                  <span class="material-symbols-outlined" style="font-size: 18px;">
                    arrow_forward
                  </span>
                </a>
                <a
                  href={store_path(@store.slug, "/about")}
                  class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full border border-[#C9925E]/40 text-[#FAF6EE] text-sm font-semibold hover:bg-white/5 transition-colors min-h-[48px]"
                >
                  Our Story
                </a>
              </div>
            </div>

            <div class="relative order-1 lg:order-2">
              <div class="aspect-[4/5] rounded-3xl overflow-hidden bg-[#C9925E]/10 ring-1 ring-[#C9925E]/20">
                <%= if hero_image_url(assigns) do %>
                  <img
                    src={hero_image_url(assigns)}
                    alt="Beauty hero"
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <div class="w-full h-full bg-gradient-to-br from-[#8A5A33] via-[#6B4423] to-[#3D2F25] flex items-center justify-center">
                    <span
                      class="material-symbols-outlined text-[#C9925E]/30"
                      style="font-size: 140px;"
                    >
                      spa
                    </span>
                  </div>
                <% end %>
              </div>
              <%!-- floating tagline card --%>
              <div class="absolute bottom-6 right-6 sm:bottom-8 sm:right-8 max-w-[240px] bg-[#3D2F25]/85 backdrop-blur-md rounded-2xl px-5 py-4 text-[#FAF6EE]">
                <p class="beauty-heading text-sm font-semibold mb-1">Beauty, Personalized Care</p>
                <p class="text-xs text-[#FAF6EE]/75 leading-relaxed">
                  Each formula is thoughtfully designed to highlight your natural elegance.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- BRAND STRIP — "As featured in" --%>
      <section :if={section_enabled?(@theme, :featured_in)} class="bg-[#C9925E]/10 py-8">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex flex-wrap items-center justify-center gap-x-10 gap-y-4 sm:gap-x-16 opacity-70">
            <span :for={_ <- 1..5} class="beauty-heading text-base sm:text-lg italic text-[#6B4423]">
              As featured in
            </span>
          </div>
        </div>
      </section>

      <%!-- FEATURED PRODUCTS --%>
      <section
        :if={section_enabled?(@theme, :featured_products) && @featured_products != []}
        class="bg-[#F5EFE5] py-16 sm:py-24"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#C9925E] mb-3">
              Our Products
            </p>
            <h2 class="beauty-heading text-4xl sm:text-5xl font-semibold text-[#3D2F25]">
              Curated for your routine
            </h2>
          </div>
          <div class="grid grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
            <Shared.product_card
              :for={product <- @featured_products}
              product={product}
              store={@store}
            />
          </div>
          <div class="text-center mt-12">
            <a
              href={store_path(@store.slug, "/products")}
              class="inline-flex items-center gap-2 px-7 py-3.5 rounded-full bg-[#6B4423] text-[#FAF6EE] text-sm font-semibold hover:bg-[#5A381D] transition-colors min-h-[48px]"
            >
              See all products
              <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
            </a>
          </div>
        </div>
      </section>

      <%!-- WHY US — 3 feature cards on dark walnut --%>
      <section
        :if={section_enabled?(@theme, :why_us)}
        class="bg-[#6B4423] py-16 sm:py-24 text-[#FAF6EE]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <h2 class="beauty-heading text-4xl sm:text-5xl font-semibold mb-3">
              {why_us_title(@theme)}
            </h2>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-5 sm:gap-6">
            <div
              :for={item <- why_us_items(@theme)}
              class="bg-[#5A381D] rounded-2xl p-6 sm:p-8 hover:bg-[#4A2D14] transition-colors"
            >
              <div class="w-14 h-14 rounded-full bg-[#C9925E] flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-[#3D2F25]" style="font-size: 26px;">
                  {item.icon}
                </span>
              </div>
              <h3 class="beauty-heading text-xl sm:text-2xl font-semibold mb-3">
                {item.title}
              </h3>
              <p class="text-sm text-[#FAF6EE]/75 leading-relaxed">
                {item.description}
              </p>
            </div>
          </div>
        </div>
      </section>

      <%!-- TESTIMONIALS --%>
      <section
        :if={section_enabled?(@theme, :testimonials)}
        class="bg-[#F5EFE5] py-16 sm:py-24"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#C9925E] mb-3">
              Testimonials
            </p>
            <h2 class="beauty-heading text-4xl sm:text-5xl font-semibold text-[#3D2F25]">
              {testimonials_title(@theme)}
            </h2>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
            <div
              :for={t <- testimonials_items(@theme)}
              class="beauty-card p-6"
            >
              <div class="w-12 h-12 rounded-full bg-[#C9925E]/30 flex items-center justify-center mb-4 text-[#6B4423] beauty-heading font-semibold">
                {String.first(t.name)}
              </div>
              <div class="flex items-center gap-1 mb-3">
                <span :for={_ <- 1..5} class="text-[#C9925E]" style="font-size: 14px;">★</span>
              </div>
              <p class="text-sm text-[#3D2F25] leading-relaxed mb-4 line-clamp-5">
                "{t.quote}"
              </p>
              <p class="text-sm font-semibold text-[#6B4423]">{t.name}</p>
              <p class="text-xs text-[#6B4423]/60">{t.location}</p>
            </div>
          </div>
        </div>
      </section>

      <%!-- FAQ --%>
      <section :if={section_enabled?(@theme, :faq)} class="bg-[#F5EFE5] pb-16 sm:pb-24">
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-10">
            <h2 class="beauty-heading text-3xl sm:text-4xl font-semibold text-[#3D2F25] mb-2">
              {faq_title(@theme)}
            </h2>
            <p class="text-sm text-[#6B4423]/70">{faq_subtitle(@theme)}</p>
          </div>
          <div class="space-y-3">
            <details
              :for={item <- faq_items(@theme)}
              class="beauty-card group"
            >
              <summary class="flex items-center justify-between p-5 cursor-pointer list-none">
                <span class="text-base font-semibold text-[#3D2F25] pr-4">
                  {item.question}
                </span>
                <span
                  class="material-symbols-outlined text-[#C9925E] transition-transform group-open:rotate-45"
                  style="font-size: 22px;"
                >
                  add
                </span>
              </summary>
              <div class="px-5 pb-5 -mt-1">
                <p class="text-sm text-[#3D2F25]/80 leading-relaxed">{item.answer}</p>
              </div>
            </details>
          </div>
        </div>
      </section>

      <%!-- CLOSING CTA — Dark walnut with model image --%>
      <section
        :if={section_enabled?(@theme, :closing_cta)}
        class="bg-[#3D2F25] py-16 sm:py-24 text-center"
      >
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 class="beauty-heading text-4xl sm:text-5xl lg:text-6xl font-semibold text-[#FAF6EE] mb-5 leading-tight">
            {closing_title(@theme)}
          </h2>
          <p class="text-base text-[#FAF6EE]/75 mb-8 max-w-xl mx-auto">
            {closing_subtitle(@theme)}
          </p>
          <a
            href={store_path(@store.slug, "/products")}
            class="inline-flex items-center gap-2 px-8 py-4 rounded-full bg-[#C9925E] text-[#3D2F25] text-sm font-bold hover:bg-[#FAF6EE] transition-colors min-h-[48px]"
          >
            {closing_button(@theme)}
            <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
          </a>
        </div>
      </section>

      <%!-- NEWSLETTER --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="bg-[#6B4423] py-14 sm:py-20">
        <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="beauty-heading text-3xl sm:text-4xl font-semibold text-[#FAF6EE] mb-3">
            {newsletter_title(@theme)}
          </h2>
          <p class="text-sm text-[#FAF6EE]/75 mb-8">{newsletter_subtitle(@theme)}</p>
          <form class="flex flex-col sm:flex-row gap-3 max-w-lg mx-auto">
            <label for="beauty-newsletter-email" class="sr-only">Email</label>
            <input
              type="email"
              id="beauty-newsletter-email"
              placeholder="Enter your email"
              class="flex-1 px-5 py-3.5 rounded-full bg-white/10 border border-white/20 text-white placeholder:text-[#FAF6EE]/50 focus:outline-none focus:ring-2 focus:ring-[#C9925E] text-sm"
            />
            <button
              type="submit"
              class="px-7 py-3.5 rounded-full bg-[#C9925E] text-[#3D2F25] text-sm font-bold hover:bg-[#FAF6EE] transition-colors min-h-[48px]"
            >
              {newsletter_button(@theme)}
            </button>
          </form>
        </div>
      </section>

      <Shared.beauty_footer store={@store} />
    </div>
    """
  end

  # ── Helpers ──

  defp section_enabled?(theme, name) do
    case get_in(theme, [:sections, name]) do
      false -> false
      _ -> true
    end
  end

  defp hero_image_url(assigns) do
    case get_in(assigns.theme, [:hero, :images]) || [] do
      [first | _] when is_binary(first) ->
        first

      _ ->
        case get_in(assigns.theme, [:hero, :image_url]) do
          url when is_binary(url) and url != "" -> url
          _ -> nil
        end
    end
  end

  defp why_us_title(theme),
    do: get_in(theme, [:why_us, :title]) || "Why your skin deserves the best"

  defp why_us_items(theme) do
    case get_in(theme, [:why_us, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_why_us()
    end
  end

  defp default_why_us do
    [
      %{
        icon: "spa",
        title: "Proven Effectiveness",
        description: "Dermatologist-tested formulas with botanical actives."
      },
      %{
        icon: "compost",
        title: "Eco-friendly Packaging",
        description: "Recyclable glass and biodegradable inserts."
      },
      %{
        icon: "local_florist",
        title: "Botanical Skin Love",
        description: "West African shea, cocoa, and baobab — kind to melanin."
      }
    ]
  end

  defp testimonials_title(theme),
    do: get_in(theme, [:testimonials, :title]) || "Loved by our community"

  defp testimonials_items(theme) do
    case get_in(theme, [:testimonials, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_testimonials()
    end
  end

  defp default_testimonials do
    [
      %{name: "Akua M.", location: "Accra", quote: "My skin has never felt this soft."},
      %{name: "Nana A.", location: "Kumasi", quote: "Beautiful packaging, beautiful results."},
      %{name: "Yaa K.", location: "Takoradi", quote: "Glow in a bottle. Five stars."},
      %{name: "Ama D.", location: "Tema", quote: "Customer service is top-tier."}
    ]
  end

  defp faq_title(theme), do: get_in(theme, [:faq, :title]) || "Frequently Asked Questions"

  defp faq_subtitle(theme),
    do: get_in(theme, [:faq, :subtitle]) || "Got questions? We've got answers."

  defp faq_items(theme) do
    case get_in(theme, [:faq, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> []
    end
  end

  defp closing_title(theme),
    do: get_in(theme, [:closing_cta, :title]) || "Ready for flawless skin?"

  defp closing_subtitle(theme),
    do: get_in(theme, [:closing_cta, :subtitle]) || "Shop the collection."

  defp closing_button(theme),
    do: get_in(theme, [:closing_cta, :button_text]) || "Shop Now"

  defp newsletter_title(theme),
    do: get_in(theme, [:newsletter, :title]) || "Join the beauty list"

  defp newsletter_subtitle(theme),
    do: get_in(theme, [:newsletter, :subtitle]) || "New launches and rituals."

  defp newsletter_button(theme),
    do: get_in(theme, [:newsletter, :button_text]) || "Subscribe"
end
