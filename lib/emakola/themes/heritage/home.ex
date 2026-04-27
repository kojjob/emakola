defmodule Emakola.Themes.Heritage.Home do
  @moduledoc """
  Heritage theme home — matches Artisan Bloom Stitch reference.

  Sections:
  - Cream nav with centered link cluster
  - Vibrant kente/wax-print hero with refined Playfair headline
    ("Discover Africa's *Finest Craftsmanship*") + cream search +
    burgundy Explore CTA
  - "The Artisan Collective" grid — featured shops/products with the
    asymmetric card layout from the reference (one large, one small,
    one wide, one tall)
  - Dark "Stories from the Loom" editorial — black canvas, gold
    eyebrow, Playfair italic pull-quote, B&W maker portrait
  - Trust strip ("The Maker's Mark")
  - Newsletter on burgundy
  - Burgundy footer
  """

  use Phoenix.Component

  alias Emakola.Themes.Heritage.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:featured_products, fn -> Enum.take(assigns.products, 4) end)

    ~H"""
    <div class="heritage-body min-h-screen">
      <Shared.theme_styles theme={@theme} />

      <%!-- HERO: cream nav over warm gradient + textile-pattern hero --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative bg-[#FAF6EC]">
        <Shared.heritage_nav store={@store} cart_count={@cart_count} />

        <div class="relative">
          <%!-- Wax-print / kente-inspired pattern background. SVG so it
               scales sharp and never depends on missing image assets. --%>
          <div class="relative h-[460px] sm:h-[520px] overflow-hidden bg-[#7A1F1F]">
            <%= if @theme.hero.image_url && @theme.hero.image_url != "" do %>
              <img
                src={@theme.hero.image_url}
                alt={@store.name}
                class="absolute inset-0 w-full h-full object-cover"
              />
              <div class="absolute inset-0 bg-gradient-to-b from-black/30 via-black/20 to-black/40">
              </div>
            <% else %>
              <%!-- Generated kente-stripe pattern --%>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="absolute inset-0 w-full h-full"
                preserveAspectRatio="xMidYMid slice"
                viewBox="0 0 1280 520"
                aria-hidden="true"
              >
                <defs>
                  <pattern id="kente" width="80" height="80" patternUnits="userSpaceOnUse">
                    <rect width="80" height="80" fill="#7A1F1F" />
                    <rect x="0" y="0" width="40" height="40" fill="#D4A843" />
                    <rect x="40" y="40" width="40" height="40" fill="#2D5016" />
                    <rect x="0" y="35" width="80" height="10" fill="#1A1A1A" />
                    <rect x="35" y="0" width="10" height="80" fill="#1A1A1A" />
                    <circle cx="20" cy="20" r="6" fill="#7A1F1F" />
                    <circle cx="60" cy="60" r="6" fill="#D4A843" />
                  </pattern>
                </defs>
                <rect width="1280" height="520" fill="url(#kente)" />
              </svg>
              <div class="absolute inset-0 bg-gradient-to-b from-black/55 via-black/30 to-black/55">
              </div>
            <% end %>

            <%!-- Hero content overlay --%>
            <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 h-full flex flex-col items-center justify-center text-center">
              <span class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-[#D4A843]/20 border border-[#D4A843]/40 text-[#F5EFE0] text-[10px] font-bold uppercase tracking-[0.25em] mb-6 backdrop-blur-sm">
                Heritage Marketplace
              </span>

              <h1 class="heritage-heading text-4xl sm:text-5xl lg:text-6xl font-bold text-white leading-[1.05] mb-2 max-w-3xl drop-shadow-lg">
                {@theme.hero.title || "Discover Africa's"}
              </h1>
              <p class="heritage-italic text-4xl sm:text-5xl lg:text-6xl font-normal italic text-[#D4A843] leading-[1.1] mb-10 drop-shadow-lg">
                {@theme.hero.subtitle || "Finest Craftsmanship"}
              </p>

              <%!-- Search + Explore CTA --%>
              <form
                action={"/s/#{@store.slug}/products"}
                method="get"
                class="flex flex-col sm:flex-row gap-2 sm:gap-0 w-full max-w-xl bg-white/95 backdrop-blur-sm rounded-2xl sm:rounded-full p-2 shadow-2xl"
              >
                <div class="relative flex-1">
                  <input
                    type="search"
                    name="q"
                    placeholder="Search artisans, stores, or crafts..."
                    class="w-full pl-12 pr-4 py-3 rounded-xl sm:rounded-full bg-transparent text-sm text-[#3D2817] placeholder:text-[#7A1F1F]/50 focus:outline-none"
                  />
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    class="w-4 h-4 absolute left-4 top-1/2 -translate-y-1/2 text-[#7A1F1F]/60"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <circle cx="11" cy="11" r="7" />
                    <path d="m21 21-4.3-4.3" />
                  </svg>
                </div>
                <button
                  type="submit"
                  class="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-xl sm:rounded-full bg-[#7A1F1F] text-[#F5EFE0] text-sm font-bold hover:bg-[#5A1717] transition-colors min-h-[44px]"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <circle cx="11" cy="11" r="7" />
                    <path d="m21 21-4.3-4.3" />
                  </svg>
                  {@theme.hero.cta_text || "Explore"}
                </button>
              </form>
            </div>
          </div>
        </div>
      </section>

      <%!-- THE ARTISAN COLLECTIVE — featured products grid --%>
      <section
        :if={section_enabled?(@theme, :featured_products) && @featured_products != []}
        class="bg-[#FAF6EC] py-16 sm:py-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between gap-6 mb-10 flex-wrap">
            <div class="max-w-xl">
              <h2 class="heritage-heading text-3xl sm:text-4xl font-bold text-[#7A1F1F] mb-3">
                The Artisan Collective
              </h2>
              <p class="text-sm sm:text-base text-[#6B4423]/85 leading-relaxed">
                Step into the soul of African heritage. Every store tells a story of generations,
                preserving techniques that transform raw materials into timeless treasures.
              </p>
            </div>
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-white border border-[#E8DBC2] text-sm font-semibold text-[#3D2817] hover:bg-[#F5EFE0] transition-colors"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                class="w-4 h-4 text-[#7A1F1F]"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <line x1="3" y1="6" x2="21" y2="6" />
                <line x1="3" y1="12" x2="21" y2="12" />
                <line x1="3" y1="18" x2="21" y2="18" />
              </svg>
              Sort by Curated
            </a>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            <Shared.product_card
              :for={product <- @featured_products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <%!-- STORIES FROM THE LOOM — dark editorial section --%>
      <section :if={section_enabled?(@theme, :why_us)} class="bg-[#1A1612] text-[#F5EFE0]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-20 sm:py-24">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
            <%!-- Editorial portrait card --%>
            <div class="relative">
              <div class="aspect-[4/5] rounded-2xl overflow-hidden bg-[#3D2817] relative">
                <%= if @theme.hero.image_url && @theme.hero.image_url != "" do %>
                  <img
                    src={@theme.hero.image_url}
                    alt="Artisan at work"
                    class="absolute inset-0 w-full h-full object-cover grayscale"
                  />
                <% else %>
                  <%!-- Stylized SVG portrait silhouette --%>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="absolute inset-0 w-full h-full"
                    preserveAspectRatio="xMidYMid slice"
                    viewBox="0 0 400 500"
                    aria-hidden="true"
                  >
                    <defs>
                      <linearGradient id="portrait-bg" x1="0%" y1="0%" x2="0%" y2="100%">
                        <stop offset="0%" stop-color="#3D2817" />
                        <stop offset="100%" stop-color="#1A1612" />
                      </linearGradient>
                    </defs>
                    <rect width="400" height="500" fill="url(#portrait-bg)" />
                    <circle cx="200" cy="180" r="60" fill="#5A3D24" />
                    <ellipse cx="200" cy="350" rx="120" ry="100" fill="#5A3D24" />
                    <ellipse cx="160" cy="400" rx="35" ry="55" fill="#3D2817" />
                    <ellipse cx="240" cy="400" rx="35" ry="55" fill="#3D2817" />
                  </svg>
                <% end %>
              </div>
              <%!-- Adinkra accent in corner --%>
              <div class="absolute -bottom-8 -right-4 sm:-right-8 w-32 h-32 rounded-2xl bg-[#7A1F1F] flex items-center justify-center shadow-xl">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 64 64"
                  class="w-16 h-16 text-[#D4A843]"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <%!-- Stylized "Sankofa" adinkra-inspired mark --%>
                  <path d="M32 8 c-13 0-23 10-23 24 c0 13 10 23 23 23 c8 0 15-4 19-10 l-5-3 c-3 4-8 7-14 7 c-9 0-17-8-17-17 c0-9 8-17 17-17 c7 0 13 4 16 11 l-7 3 l13 5 l-2-14 l-5 2 c-4-9-13-14-22-14 z" />
                </svg>
              </div>
            </div>

            <%!-- Editorial copy --%>
            <div>
              <p class="text-xs font-bold uppercase tracking-[0.3em] text-[#D4A843] mb-4">
                The Maker's Mark
              </p>
              <h2 class="heritage-heading text-4xl sm:text-5xl font-bold leading-[1.1] mb-2">
                Stories from
              </h2>
              <p class="heritage-italic text-4xl sm:text-5xl text-[#D4A843] mb-8">
                the Loom
              </p>

              <blockquote class="heritage-italic text-lg sm:text-xl leading-relaxed text-[#F5EFE0]/90 mb-6 border-l-2 border-[#D4A843] pl-5">
                "We do not just weave fabric; we weave the breath of our ancestors into every pattern."
              </blockquote>
              <p class="text-sm text-[#F5EFE0]/70 leading-relaxed mb-8 max-w-md">
                Meet Kofi, a master weaver from the Volta region. For fifty years, he has translated the
                rhythms of his village into the intricate, geometric languages of the kente loom.
              </p>

              <a
                href={"/s/#{@store.slug}/blog"}
                class="inline-flex items-center gap-2 text-sm font-bold uppercase tracking-[0.18em] text-[#D4A843] hover:text-[#F5EFE0] transition-colors group"
              >
                Read all stories
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  class="w-4 h-4 group-hover:translate-x-1 transition-transform"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M5 12h14M13 5l7 7-7 7" />
                </svg>
              </a>
            </div>
          </div>
        </div>
      </section>

      <%!-- TRUST STRIP — The Maker's Mark --%>
      <section :if={@theme.trust} class="bg-[#FAF6EC] py-16 sm:py-20 border-t border-[#E8DBC2]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <p class="text-xs font-bold uppercase tracking-[0.3em] text-[#D4A843] mb-3">
              Why Heritage
            </p>
            <h2 class="heritage-heading text-3xl sm:text-4xl font-bold text-[#7A1F1F]">
              {@theme.trust.title || "The Maker's Mark"}
            </h2>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
            <div
              :for={item <- @theme.trust.items || []}
              class="text-center p-7 bg-white rounded-2xl border border-[#E8DBC2] hover:border-[#D4A843] transition-colors"
            >
              <span class="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-[#7A1F1F]/10 mb-4">
                <span class="material-symbols-outlined text-[#7A1F1F]" style="font-size: 28px;">
                  {item.icon}
                </span>
              </span>
              <h3 class="heritage-heading text-xl font-semibold text-[#3D2817] mb-2">
                {item.title}
              </h3>
              <p class="text-sm text-[#6B4423]/85 leading-relaxed">
                {item.description}
              </p>
            </div>
          </div>
        </div>
      </section>

      <%!-- TESTIMONIALS --%>
      <section
        :if={section_enabled?(@theme, :testimonials) && @theme.testimonials}
        class="bg-white py-16 sm:py-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2 class="heritage-heading text-3xl sm:text-4xl font-bold text-[#7A1F1F] text-center mb-12">
            {@theme.testimonials.title || "Voices of the Collective"}
          </h2>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div
              :for={t <- @theme.testimonials.items || []}
              class="p-7 rounded-2xl bg-[#FAF6EC] border border-[#E8DBC2]"
            >
              <div class="flex items-center gap-1 text-[#D4A843] mb-4">
                <svg
                  :for={_ <- 1..5}
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 16 16"
                  class="w-3.5 h-3.5"
                  fill="currentColor"
                >
                  <path d="M8 0 9.5 5 14.5 6 10.5 9.5 11.5 14.5 8 12 4.5 14.5 5.5 9.5 1.5 6 6.5 5 8 0Z" />
                </svg>
              </div>
              <p class="heritage-italic text-base text-[#3D2817] mb-5 leading-relaxed">
                "{t.quote}"
              </p>
              <p class="text-xs font-bold uppercase tracking-wider text-[#7A1F1F]">
                {t.name} <span class="text-[#6B4423]/60 font-medium">— {t.location}</span>
              </p>
            </div>
          </div>
        </div>
      </section>

      <%!--
        Closing CTA + Newsletter — visible if EITHER toggle is on.
        Each inner block is gated independently so the merchant can
        keep the headline without the form, or vice versa.
      --%>
      <section
        :if={section_enabled?(@theme, :closing_cta) || section_enabled?(@theme, :newsletter)}
        class="bg-[#7A1F1F] text-[#F5EFE0]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 text-center">
          <div :if={section_enabled?(@theme, :closing_cta)}>
            <p class="text-xs font-bold uppercase tracking-[0.3em] text-[#D4A843] mb-3">
              Join the Collective
            </p>
            <h2 class="heritage-heading text-3xl sm:text-4xl font-bold mb-3">
              {get_in(@theme, [:closing_cta, :title]) ||
                get_in(@theme, [:newsletter, :title]) || "Join the Collective"}
            </h2>
            <p class="text-sm sm:text-base text-[#F5EFE0]/80 max-w-xl mx-auto mb-8">
              {get_in(@theme, [:closing_cta, :subtitle]) ||
                get_in(@theme, [:newsletter, :subtitle]) ||
                "New artisans, untold stories, and limited drops — straight to your inbox."}
            </p>
          </div>

          <form
            :if={section_enabled?(@theme, :newsletter)}
            class="flex flex-col sm:flex-row gap-2 max-w-md mx-auto"
          >
            <input
              type="email"
              placeholder="your@email.com"
              class="flex-1 px-5 py-3 rounded-full bg-white text-sm text-[#3D2817] placeholder:text-[#7A1F1F]/40 focus:outline-none focus:ring-2 focus:ring-[#D4A843]"
              required
            />
            <button
              type="submit"
              class="inline-flex items-center justify-center px-6 py-3 rounded-full bg-[#D4A843] text-[#3D2817] text-sm font-bold hover:bg-[#E5BB5A] transition-colors min-h-[44px]"
            >
              {get_in(@theme, [:newsletter, :button_text]) || "Subscribe"}
            </button>
          </form>
        </div>
      </section>

      <Shared.heritage_footer store={@store} />
    </div>
    """
  end

  defp section_enabled?(theme, key) do
    case get_in(theme, [:sections, key]) do
      false -> false
      _ -> true
    end
  end
end
