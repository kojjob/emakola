defmodule Emakola.Themes.Fashion.Home do
  @moduledoc """
  Fashion theme home — editorial magazine.

  Sections (gated by `@theme.sections.*`):
  - Magazine-cover hero (full-bleed image, oversized Playfair title
    bottom-left, "Volume / Issue" marker top-right)
  - Editorial intro paragraph
  - 2x2 lookbook grid (1 hero left, 3 stacked right) with gold pills
  - Featured products grid (4-col)
  - "New Arrivals" gold-accented band
  - UGC strip ("Worn by you" placeholder)
  - Brand story split (image + Playfair headline + paragraph)
  - Newsletter on aubergine
  - Aubergine masthead footer
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fashion.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:lookbook_hero, fn -> List.first(assigns.products) end)
      |> assign_new(:lookbook_supporting, fn ->
        Enum.slice(assigns.products, 1, 3)
      end)
      |> assign_new(:featured_products, fn -> Enum.take(assigns.products, 8) end)
      |> assign_new(:new_arrivals, fn -> Enum.take(Enum.drop(assigns.products, 4), 4) end)

    ~H"""
    <div class="fashion-body min-h-screen">
      <Shared.theme_styles theme={@theme} />

      <%!-- HERO: magazine cover --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative">
        <Shared.fashion_nav store={@store} cart_count={@cart_count} on_dark={true} />

        <div class="relative -mt-20 h-[70vh] min-h-[560px] max-h-[820px] overflow-hidden">
          <%= if hero_image_url(assigns) do %>
            <img
              src={hero_image_url(assigns)}
              alt="Editorial cover"
              class="absolute inset-0 w-full h-full object-cover"
            />
          <% else %>
            <div class="absolute inset-0 bg-gradient-to-br from-[#5B21B6] via-[#3B0F7E] to-[#1F0750]">
            </div>
          <% end %>
          <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-black/40"></div>

          <%!-- Issue marker top-right --%>
          <div class="absolute top-24 right-4 sm:right-8 lg:right-12 text-white/80 text-right">
            <p class="text-[11px] uppercase tracking-[0.3em] mb-1">
              {issue_eyebrow(@theme)}
            </p>
            <p class="fashion-heading italic text-base">
              {issue_date()}
            </p>
          </div>

          <%!-- Headline bottom-left --%>
          <div class="absolute inset-x-0 bottom-0 px-4 sm:px-8 lg:px-16 pb-12 sm:pb-16 lg:pb-20">
            <div class="max-w-3xl">
              <p class="text-[11px] sm:text-xs uppercase tracking-[0.3em] text-[#D97706] mb-4 sm:mb-6">
                The Spring Edit
              </p>
              <h1 class="fashion-display text-5xl sm:text-7xl lg:text-8xl text-white leading-[0.95] mb-6 sm:mb-8 max-w-2xl">
                {@theme.hero.title || "Made by Tailors. Worn by You."}
              </h1>
              <p
                :if={@theme.hero.subtitle}
                class="text-base sm:text-lg text-white/85 leading-relaxed mb-8 max-w-md italic fashion-heading"
              >
                {@theme.hero.subtitle}
              </p>
              <a
                href={store_path(@store.slug, "/products")}
                class="inline-flex items-center gap-2 px-7 py-4 rounded-full bg-[#D97706] text-white text-sm font-bold uppercase tracking-wider hover:bg-[#B45309] transition-colors min-h-[48px]"
              >
                {@theme.hero.cta_text || "Shop the Drop"}
                <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
              </a>
            </div>
          </div>
        </div>
      </section>

      <%!-- EDITORIAL INTRO --%>
      <section :if={section_enabled?(@theme, :editorial_intro)} class="bg-[#FAF6EE] py-16 sm:py-24">
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p class="text-[11px] uppercase tracking-[0.3em] text-[#D97706] mb-4">
            {editorial_eyebrow(@theme)}
          </p>
          <h2 class="fashion-display text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] leading-tight mb-6">
            {editorial_title(@theme)}
          </h2>
          <p class="text-base sm:text-lg text-[#57534E] leading-relaxed">
            {editorial_body(@theme)}
          </p>
        </div>
      </section>

      <%!-- LOOKBOOK 2x2 grid --%>
      <section
        :if={section_enabled?(@theme, :lookbook) && @lookbook_hero}
        class="bg-[#FAF6EE] pb-14 sm:pb-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between mb-8">
            <div>
              <p class="text-[11px] uppercase tracking-[0.3em] text-[#D97706] mb-2">
                Lookbook
              </p>
              <h2 class="fashion-display text-3xl sm:text-4xl lg:text-5xl text-[#1C1917]">
                Editor's picks.
              </h2>
            </div>
            <a
              href={store_path(@store.slug, "/products")}
              class="hidden sm:inline-flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-[#5B21B6] hover:gap-3 transition-all"
            >
              See all
              <span class="material-symbols-outlined" style="font-size: 16px;">arrow_forward</span>
            </a>
          </div>

          <div class="grid lg:grid-cols-12 gap-4 sm:gap-6">
            <%!-- Hero product (left, 7 cols) --%>
            <a
              href={store_path(@store.slug, "/products/#{@lookbook_hero.slug}")}
              class="lg:col-span-7 relative aspect-[4/5] lg:aspect-auto rounded-lg overflow-hidden group bg-white"
            >
              <%= if Shared.first_image(@lookbook_hero) do %>
                <img
                  src={Shared.first_image(@lookbook_hero)}
                  alt={@lookbook_hero.title}
                  class="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
                />
              <% else %>
                <div class="absolute inset-0 bg-gradient-to-br from-[#5B21B6]/20 to-[#D97706]/15 flex items-center justify-center">
                  <span class="material-symbols-outlined text-[#5B21B6]/40" style="font-size: 120px;">
                    checkroom
                  </span>
                </div>
              <% end %>
              <span class="absolute top-4 left-4 px-3 py-1.5 rounded-full bg-[#D97706] text-white text-[10px] font-bold uppercase tracking-wider">
                Cover Look
              </span>
              <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-[#1C1917] to-transparent p-6 sm:p-8">
                <h3 class="fashion-heading text-2xl sm:text-3xl font-semibold text-white mb-1">
                  {@lookbook_hero.title}
                </h3>
                <p class="text-base font-bold text-[#D97706]">
                  {EmakolaWeb.Helpers.Currency.format_price(
                    @lookbook_hero.min_price || 0,
                    Map.get(@store, :currency, "GHS")
                  )}
                </p>
              </div>
            </a>

            <%!-- 3 stacked supporting (right, 5 cols) --%>
            <div class="lg:col-span-5 grid grid-cols-3 lg:grid-cols-1 gap-4 sm:gap-6">
              <Shared.product_card
                :for={product <- @lookbook_supporting}
                product={product}
                store={@store}
              />
            </div>
          </div>
        </div>
      </section>

      <%!-- FEATURED PRODUCTS --%>
      <section
        :if={section_enabled?(@theme, :featured_products) && @featured_products != []}
        class="bg-[#FAF6EE] pb-14 sm:pb-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between mb-8">
            <div>
              <p class="text-[11px] uppercase tracking-[0.3em] text-[#D97706] mb-2">
                The Edit
              </p>
              <h2 class="fashion-display text-3xl sm:text-4xl lg:text-5xl text-[#1C1917]">
                Just dropped.
              </h2>
            </div>
          </div>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
            <Shared.product_card
              :for={product <- @featured_products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <%!-- NEW ARRIVALS BAND — gold accented --%>
      <section
        :if={section_enabled?(@theme, :new_arrivals_band) && @new_arrivals != []}
        class="bg-[#5B21B6] py-14 sm:py-20 text-[#FAF6EE]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between mb-8 gap-4">
            <div>
              <p class="text-[11px] uppercase tracking-[0.3em] text-[#D97706] mb-2">
                Restocked
              </p>
              <h2 class="fashion-display text-3xl sm:text-4xl lg:text-5xl">
                Back in stock, briefly.
              </h2>
            </div>
            <a
              href={store_path(@store.slug, "/products")}
              class="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-[#D97706] text-white text-xs font-bold uppercase tracking-wider hover:bg-[#B45309] transition-colors self-start sm:self-end"
            >
              Shop the Restock
              <span class="material-symbols-outlined" style="font-size: 14px;">arrow_forward</span>
            </a>
          </div>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
            <a
              :for={product <- @new_arrivals}
              href={store_path(@store.slug, "/products/#{product.slug}")}
              class="group block"
            >
              <div class="aspect-[3/4] bg-white/5 ring-1 ring-white/10 overflow-hidden mb-3 rounded-lg">
                <%= if Shared.first_image(product) do %>
                  <img
                    src={Shared.first_image(product)}
                    alt={product.title}
                    class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
                  />
                <% else %>
                  <div class="w-full h-full flex items-center justify-center">
                    <span class="material-symbols-outlined text-[#D97706]/40" style="font-size: 56px;">
                      checkroom
                    </span>
                  </div>
                <% end %>
              </div>
              <h3 class="fashion-heading text-base font-semibold text-white mb-1 line-clamp-1">
                {product.title}
              </h3>
              <p class="text-sm text-[#D97706] font-bold">
                {EmakolaWeb.Helpers.Currency.format_price(
                  product.min_price || 0,
                  Map.get(@store, :currency, "GHS")
                )}
              </p>
            </a>
          </div>
        </div>
      </section>

      <%!-- UGC strip — "Worn by you" --%>
      <section :if={section_enabled?(@theme, :ugc)} class="bg-[#FAF6EE] py-14 sm:py-20">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p class="text-[11px] uppercase tracking-[0.3em] text-[#D97706] mb-3">
            Tag &commat;{String.downcase(String.replace(@store.name, " ", ""))}
          </p>
          <h2 class="fashion-display text-3xl sm:text-4xl lg:text-5xl text-[#1C1917] mb-10">
            Worn by you.
          </h2>
          <div class="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-2 sm:gap-3">
            <div
              :for={_ <- 1..6}
              class="aspect-square bg-gradient-to-br from-[#E7E5E4] to-[#D6D3D1] flex items-center justify-center"
            >
              <span class="material-symbols-outlined text-[#5B21B6]/30" style="font-size: 40px;">
                photo_camera
              </span>
            </div>
          </div>
        </div>
      </section>

      <%!-- BRAND STORY --%>
      <section :if={section_enabled?(@theme, :brand_story)} class="bg-white py-16 sm:py-24">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
            <div class="aspect-[3/4] bg-gradient-to-br from-[#5B21B6]/10 to-[#D97706]/10 flex items-center justify-center">
              <span class="material-symbols-outlined text-[#5B21B6]/40" style="font-size: 140px;">
                checkroom
              </span>
            </div>
            <div>
              <p class="text-[11px] uppercase tracking-[0.3em] text-[#D97706] mb-3">
                Our story
              </p>
              <h2 class="fashion-display text-4xl sm:text-5xl lg:text-6xl text-[#1C1917] leading-[1.05] mb-6">
                Sewn in Accra.<br />Worn worldwide.
              </h2>
              <p class="text-base text-[#57534E] leading-relaxed mb-3 italic fashion-heading">
                {@store.description ||
                  "We work with tailors and weavers across Ghana to bring you pieces that carry stories — Ankara prints, kente weaves, and modern silhouettes shaped by hand. Every piece is sewn in small batches; nothing mass-produced."}
              </p>
              <a
                href={store_path(@store.slug, "/about")}
                class="inline-flex items-center gap-2 mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-[#5B21B6] hover:gap-3 transition-all"
              >
                Read the journal
                <span class="material-symbols-outlined" style="font-size: 14px;">arrow_forward</span>
              </a>
            </div>
          </div>
        </div>
      </section>

      <%!-- NEWSLETTER --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="bg-[#5B21B6] py-14 sm:py-20">
        <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p class="text-[11px] uppercase tracking-[0.3em] text-[#D97706] mb-3">
            The List
          </p>
          <h2 class="fashion-display text-3xl sm:text-4xl lg:text-5xl text-white mb-3">
            {newsletter_title(@theme)}
          </h2>
          <p class="text-sm text-white/70 mb-8 italic fashion-heading">
            {newsletter_subtitle(@theme)}
          </p>
          <form class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto">
            <label for="fashion-newsletter-email" class="sr-only">Email</label>
            <input
              type="email"
              id="fashion-newsletter-email"
              placeholder="Enter your email"
              class="flex-1 px-5 py-3.5 rounded-full bg-white/10 border border-white/20 text-white placeholder:text-white/50 focus:outline-none focus:ring-2 focus:ring-[#D97706] text-sm"
            />
            <button
              type="submit"
              class="px-7 py-3.5 rounded-full bg-[#D97706] text-white text-xs font-bold uppercase tracking-wider hover:bg-[#B45309] transition-colors min-h-[48px]"
            >
              {newsletter_button(@theme)}
            </button>
          </form>
        </div>
      </section>

      <Shared.fashion_footer store={@store} />
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

  defp issue_eyebrow(theme),
    do: get_in(theme, [:editorial_intro, :eyebrow]) || "Volume IV · Drop No. 12"

  defp issue_date do
    Calendar.strftime(DateTime.utc_now(), "%B %Y")
  end

  defp editorial_eyebrow(theme),
    do: get_in(theme, [:editorial_intro, :eyebrow]) || "From the Editor"

  defp editorial_title(theme),
    do: get_in(theme, [:editorial_intro, :title]) || "Curated drops, made by hand."

  defp editorial_body(theme),
    do:
      get_in(theme, [:editorial_intro, :body]) ||
        "Each piece is sewn in small batches by tailors and artisans across Accra."

  defp newsletter_title(theme),
    do: get_in(theme, [:newsletter, :title]) || "First access. No noise."

  defp newsletter_subtitle(theme),
    do:
      get_in(theme, [:newsletter, :subtitle]) ||
        "Be the first to shop new drops, runway looks, and editor picks."

  defp newsletter_button(theme),
    do: get_in(theme, [:newsletter, :button_text]) || "Join the List"
end
