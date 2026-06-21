defmodule Emakola.Themes.Pharmacy.Home do
  @moduledoc """
  Pharmacy theme home page — premium wellness, trusted, accessibility-led.

  Mirrors the Dribbble reference (Pharmaicus / "Professional Pharmacy
  Services You Can Trust") with these gated sections (`@theme.sections.*`):
  - Forest-green photographic hero with serif headline + cream pill CTA
  - Stats strip (Years / Brands / Customers — 4 stat cards)
  - Highlight feature cards (3 pastel-bg blocks showcasing top products)
  - Trending products grid
  - Category pill strip
  - Trust badges (Licensed / Genuine / Discreet)
  - Brand story / Hospitals collaboration logos
  - Newsletter
  - Footer (matches hero forest-green)
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Pharmacy.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:featured_products, fn -> Enum.take(assigns.products, 4) end)
      |> assign_new(:highlight_products, fn -> Enum.take(assigns.products, 3) end)
      |> assign_new(:grid_products, fn -> Enum.drop(assigns.products, 4) end)

    ~H"""
    <div class="pharmacy-body min-h-screen">
      <Shared.theme_styles theme={@theme} />
      <Shared.pharmacy_nav store={@store} cart_count={@cart_count} />

      <%!-- HERO: forest green w/ photographic image, serif headline --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative overflow-hidden bg-[#14543E]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-14 sm:py-20 lg:py-24 relative">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
            <%!-- Left: copy --%>
            <div class="relative z-10 order-2 lg:order-1">
              <span class="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full bg-[#A7E5C5]/20 text-[#A7E5C5] text-xs font-semibold uppercase tracking-wider mb-6">
                <span class="material-symbols-outlined" style="font-size: 14px;">verified</span>
                Pharmacy you can trust
              </span>
              <h1 class="pharmacy-heading text-4xl sm:text-5xl lg:text-6xl font-medium text-white leading-[1.1] mb-6">
                {@theme.hero.title || "Professional Pharmacy Services You Can Trust"}
              </h1>
              <p class="text-base sm:text-lg text-[#F9F6F0]/80 leading-relaxed mb-8 max-w-xl">
                {@theme.hero.subtitle ||
                  @store.description ||
                  "Providing expert pharmacy care you can rely on. We are here to support your health every step of the way."}
              </p>
              <div class="flex flex-col sm:flex-row gap-3">
                <a
                  href={store_path(@store.slug, "/products")}
                  class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-white text-[#14543E] text-sm font-semibold hover:bg-[#A7E5C5] transition-colors min-h-[48px]"
                >
                  {@theme.hero.cta_text || "Explore Now"}
                  <span class="material-symbols-outlined" style="font-size: 18px;">
                    arrow_forward
                  </span>
                </a>
                <a
                  href={store_path(@store.slug, "/about")}
                  class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full border border-[#A7E5C5]/40 text-white text-sm font-semibold hover:bg-white/5 transition-colors min-h-[48px]"
                >
                  Learn more
                </a>
              </div>
            </div>

            <%!-- Right: photographic frame --%>
            <div class="relative order-1 lg:order-2">
              <div class="aspect-[4/3] rounded-3xl overflow-hidden bg-[#A7E5C5]/10 ring-1 ring-white/10">
                <%= if hero_image_url(assigns) do %>
                  <img
                    src={hero_image_url(assigns)}
                    alt="Pharmacy"
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <div class="w-full h-full bg-gradient-to-br from-[#1A6E4F] via-[#14543E] to-[#0F3F2E] flex items-center justify-center">
                    <span
                      class="material-symbols-outlined text-[#A7E5C5]/30"
                      style="font-size: 120px;"
                    >
                      local_pharmacy
                    </span>
                  </div>
                <% end %>
              </div>
              <%!-- floating trust card --%>
              <div class="absolute bottom-6 left-6 sm:bottom-8 sm:left-8 bg-white/95 backdrop-blur-md rounded-2xl px-5 py-4 shadow-xl">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 rounded-full bg-[#A7E5C5] flex items-center justify-center">
                    <span class="material-symbols-outlined text-[#14543E]" style="font-size: 22px;">
                      verified_user
                    </span>
                  </div>
                  <div>
                    <p class="text-xs uppercase tracking-wider text-[#6B7280] font-semibold">
                      Verified Pharmacy
                    </p>
                    <p class="text-sm font-bold text-[#14543E]">FDA Ghana approved</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- STATS STRIP --%>
      <section :if={section_enabled?(@theme, :stats)} class="bg-[#F9F6F0] py-14 sm:py-20">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid lg:grid-cols-2 gap-10 mb-12 items-end">
            <h2 class="pharmacy-heading text-3xl sm:text-4xl lg:text-5xl font-medium text-[#14543E] leading-tight">
              {stats_heading(@theme)}
              <span class="text-[#14543E]/60">Since {founded_year()}</span>
            </h2>
            <p class="text-base text-[#4B5563] leading-relaxed">
              {stats_subtitle(@theme)}
            </p>
          </div>

          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div
              :for={stat <- stats_items(@theme)}
              class="pharmacy-card p-6 sm:p-7 flex items-center gap-4"
            >
              <div class="w-12 h-12 rounded-full bg-[#A7E5C5] flex items-center justify-center flex-shrink-0">
                <span class="material-symbols-outlined text-[#14543E]" style="font-size: 22px;">
                  {stat.icon}
                </span>
              </div>
              <div>
                <p class="pharmacy-heading text-2xl sm:text-3xl font-semibold text-[#14543E]">
                  {stat.value}
                </p>
                <p class="text-xs text-[#4B5563] uppercase tracking-wider mt-0.5">
                  {stat.label}
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- TRENDING PRODUCTS --%>
      <section
        :if={section_enabled?(@theme, :featured_products) && @featured_products != []}
        class="bg-[#F9F6F0] pb-14 sm:pb-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between mb-8">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wider text-[#14543E]/70 mb-2">
                Trending now
              </p>
              <h2 class="pharmacy-heading text-3xl sm:text-4xl font-medium text-[#14543E]">
                Trending products for you
              </h2>
            </div>
            <a
              href={store_path(@store.slug, "/products")}
              class="hidden sm:inline-flex items-center gap-1 text-sm font-semibold text-[#14543E] hover:gap-2 transition-all"
            >
              See all
              <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
            </a>
          </div>

          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-5">
            <Shared.product_card
              :for={product <- @featured_products}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <%!-- HIGHLIGHT FEATURE CARDS — 3 pastel-bg blocks --%>
      <section
        :if={section_enabled?(@theme, :highlight_cards) && @highlight_products != []}
        class="bg-[#F9F6F0] pb-14 sm:pb-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-5">
            <.highlight_card
              :for={{product, idx} <- Enum.with_index(@highlight_products)}
              product={product}
              store={@store}
              palette={highlight_palette(idx)}
            />
          </div>
        </div>
      </section>

      <%!-- CATEGORY PILL STRIP --%>
      <section
        :if={section_enabled?(@theme, :categories) && @categories != []}
        class="bg-[#F9F6F0] pb-10"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex flex-wrap items-center gap-2 sm:gap-3">
            <a
              href={store_path(@store.slug, "/products")}
              class="inline-flex items-center px-4 py-2 rounded-full bg-[#14543E] text-white text-sm font-semibold"
            >
              All Products
            </a>
            <a
              :for={category <- Enum.take(@categories, 7)}
              href={store_path(@store.slug, "/category/#{category.slug}")}
              class="inline-flex items-center px-4 py-2 rounded-full bg-[#A7E5C5]/40 text-[#14543E] text-sm font-medium hover:bg-[#A7E5C5] transition-colors"
            >
              {category.name}
            </a>
          </div>
        </div>
      </section>

      <%!-- PRODUCT GRID (more) --%>
      <section
        :if={section_enabled?(@theme, :featured_products) && @grid_products != []}
        class="bg-[#F9F6F0] pb-14 sm:pb-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-5">
            <Shared.product_card
              :for={product <- Enum.take(@grid_products, 12)}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <%!-- TRUST STRIP --%>
      <section :if={section_enabled?(@theme, :trust)} class="bg-white py-14 sm:py-20">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-10">
            <h2 class="pharmacy-heading text-3xl sm:text-4xl font-medium text-[#14543E]">
              {trust_title(@theme)}
            </h2>
            <p class="text-sm text-[#4B5563] mt-3 max-w-xl mx-auto">
              {trust_subtitle(@theme)}
            </p>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
            <div
              :for={item <- trust_items(@theme)}
              class="flex flex-col items-center text-center px-6 py-8"
            >
              <div class="w-16 h-16 rounded-full bg-[#A7E5C5] flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-[#14543E]" style="font-size: 30px;">
                  {item.icon}
                </span>
              </div>
              <p class="text-base font-semibold text-[#14543E] mb-1">{item.label}</p>
              <p class="text-sm text-[#4B5563]">{item.subtitle}</p>
            </div>
          </div>
        </div>
      </section>

      <%!-- BRAND STORY / HOSPITALS strip --%>
      <section :if={section_enabled?(@theme, :brand_story)} class="bg-[#F9F6F0] py-14 sm:py-20">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="pharmacy-heading text-3xl sm:text-4xl font-medium text-[#14543E] mb-3">
            Trusted by hospitals across Ghana
          </h2>
          <p class="text-sm text-[#4B5563] mb-10 max-w-xl mx-auto">
            We collaborate with leading hospitals and clinics to deliver verified medication
            and wellness products to communities nationwide.
          </p>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-6 sm:gap-10 items-center opacity-70">
            <div :for={_ <- 1..4} class="h-10 sm:h-14 flex items-center justify-center">
              <span class="text-sm font-bold text-[#14543E]/40 tracking-wider uppercase">
                Hospital Logo
              </span>
            </div>
          </div>
        </div>
      </section>

      <%!-- NEWSLETTER --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="bg-[#14543E] py-14 sm:py-20">
        <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="pharmacy-heading text-3xl sm:text-4xl font-medium text-white mb-3">
            {newsletter_title(@theme)}
          </h2>
          <p class="text-sm text-[#F9F6F0]/80 mb-8">
            {newsletter_subtitle(@theme)}
          </p>
          <form class="flex flex-col sm:flex-row gap-3 max-w-lg mx-auto">
            <label for="pharmacy-newsletter-email" class="sr-only">Email</label>
            <input
              type="email"
              id="pharmacy-newsletter-email"
              placeholder="Enter your email"
              class="flex-1 px-5 py-3.5 rounded-full bg-white/10 border border-white/20 text-white placeholder:text-[#F9F6F0]/60 focus:outline-none focus:ring-2 focus:ring-[#A7E5C5] text-sm"
            />
            <button
              type="submit"
              class="px-7 py-3.5 rounded-full bg-[#A7E5C5] text-[#14543E] text-sm font-semibold hover:bg-white transition-colors min-h-[48px]"
            >
              {newsletter_button(@theme)}
            </button>
          </form>
        </div>
      </section>

      <Shared.pharmacy_footer store={@store} />
    </div>
    """
  end

  # ── Highlight feature card ──

  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :palette, :map, required: true

  defp highlight_card(assigns) do
    ~H"""
    <a
      href={store_path(@store.slug, "/products/#{@product.slug}")}
      class="relative block rounded-2xl p-6 sm:p-8 overflow-hidden group"
      style={"background-color: #{@palette.bg};"}
    >
      <div class="relative z-10 max-w-[55%]">
        <h3 class="pharmacy-heading text-xl sm:text-2xl font-semibold text-[#1F2937] leading-tight mb-2">
          {@product.title}
        </h3>
        <p class="text-base font-bold text-[#14543E] mb-4">
          {EmakolaWeb.Helpers.Currency.format_price(
            @product.min_price || 0,
            Map.get(@store, :currency, "GHS")
          )}
        </p>
        <span class="inline-flex items-center gap-1.5 text-sm font-semibold text-[#14543E]">
          Shop now
          <span class="material-symbols-outlined" style="font-size: 16px;">arrow_forward</span>
        </span>
      </div>
      <%= if Shared.first_image(@product) do %>
        <img
          src={Shared.first_image(@product)}
          alt={@product.title}
          class="absolute right-2 sm:right-4 bottom-2 sm:bottom-4 w-32 h-32 sm:w-44 sm:h-44 object-contain group-hover:scale-105 transition-transform"
        />
      <% else %>
        <div
          class="absolute right-2 sm:right-4 bottom-2 sm:bottom-4 w-32 h-32 sm:w-44 sm:h-44 flex items-center justify-center"
          style={"color: #{@palette.icon};"}
        >
          <span class="material-symbols-outlined" style="font-size: 100px;">medication</span>
        </div>
      <% end %>
    </a>
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

  defp stats_heading(theme), do: get_in(theme, [:stats, :heading]) || "Your Trusted Healthcare"

  defp stats_subtitle(theme),
    do:
      get_in(theme, [:stats, :subtitle]) ||
        "We believe in lasting relationships, not just transactions."

  defp stats_items(theme) do
    case get_in(theme, [:stats, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_stats()
    end
  end

  defp default_stats do
    [
      %{value: "20+", label: "Years of experience", icon: "verified"},
      %{value: "5k+", label: "Trusted brands", icon: "inventory_2"},
      %{value: "600+", label: "Global brands", icon: "public"},
      %{value: "1M", label: "Happy customers", icon: "favorite"}
    ]
  end

  defp trust_title(theme), do: get_in(theme, [:trust, :title]) || "Licensed & Trusted"

  defp trust_subtitle(theme),
    do:
      get_in(theme, [:trust, :subtitle]) ||
        "Verified pharmacy. Genuine medicines. Discreet delivery."

  defp trust_items(theme) do
    case get_in(theme, [:trust, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_trust_items()
    end
  end

  defp default_trust_items do
    [
      %{icon: "verified_user", label: "Licensed pharmacy", subtitle: "FDA Ghana approved"},
      %{icon: "local_pharmacy", label: "Genuine medicines", subtitle: "Trusted brands only"},
      %{icon: "local_shipping", label: "Discreet delivery", subtitle: "Across Ghana, fast"}
    ]
  end

  defp newsletter_title(theme),
    do: get_in(theme, [:newsletter, :title]) || "Stay healthy, stay informed"

  defp newsletter_subtitle(theme),
    do:
      get_in(theme, [:newsletter, :subtitle]) ||
        "Health tips, new launches, and offers from our pharmacists."

  defp newsletter_button(theme),
    do: get_in(theme, [:newsletter, :button_text]) || "Subscribe"

  defp founded_year, do: DateTime.utc_now().year - 17

  defp highlight_palette(0), do: %{bg: "#E8F5EE", icon: "#14543E"}
  defp highlight_palette(1), do: %{bg: "#FFF4E6", icon: "#92400E"}
  defp highlight_palette(2), do: %{bg: "#E0EAFB", icon: "#1E3A8A"}
  defp highlight_palette(_), do: %{bg: "#F3F4F6", icon: "#6B7280"}
end
