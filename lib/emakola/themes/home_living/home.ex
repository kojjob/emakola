defmodule Emakola.Themes.HomeLiving.Home do
  @moduledoc """
  Home Living theme home — modern furniture/lifestyle store.

  Combines two user-supplied references:
  - Furniora: dark charcoal hero with bold uppercase headline,
    floating feature-tile overlays, lime-green active nav
  - Lovely Home: rooms grid, sale band with 4 features, popular
    products, deal-of-the-day, customer testimonials

  Sections (gated by `@theme.sections.*`):
  - Hero (charcoal, photographic, bold uppercase headline + 2 floating
    feature tiles overlaid bottom-right)
  - "Shop by categories" stat bar (200+ Unique products)
  - 4-tile "Shop by room" categories
  - 4-feature sale band (Free Delivery / Safe Pay / Curation / Customers)
  - Featured products grid
  - Editor's pick / Deal of the day on terracotta
  - Trust strip
  - Brand story split
  - Newsletter
  - Footer
  """

  use Phoenix.Component

  alias Emakola.Themes.HomeLiving.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:featured_products, fn -> Enum.take(assigns.products, 8) end)
      |> assign_new(:editor_pick, fn -> List.first(assigns.products) end)
      |> assign_new(:tile_products, fn -> Enum.take(assigns.products, 2) end)

    ~H"""
    <div class="home-living-body min-h-screen">
      <Shared.theme_styles theme={@theme} />

      <%!-- HERO: dark charcoal, photographic, BOLD UPPERCASE headline (Furniora) --%>
      <section :if={section_enabled?(@theme, :hero)} class="relative bg-[#1F2937] overflow-hidden">
        <Shared.home_living_nav
          store={@store}
          cart_count={@cart_count}
          on_dark={true}
          active_path="/"
        />

        <%!-- Background photographic layer --%>
        <%= if hero_image_url(assigns) do %>
          <img
            src={hero_image_url(assigns)}
            alt="Home interior"
            class="absolute inset-0 w-full h-full object-cover opacity-60"
          />
          <div class="absolute inset-0 bg-gradient-to-br from-[#1F2937]/90 via-[#1F2937]/60 to-transparent">
          </div>
        <% else %>
          <div class="absolute inset-0 bg-gradient-to-br from-[#1F2937] via-[#374151] to-[#1F2937]">
          </div>
        <% end %>

        <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pt-10 pb-20 sm:pt-16 sm:pb-32 lg:pb-40">
          <div class="max-w-2xl">
            <h1 class="home-living-display text-4xl sm:text-6xl lg:text-7xl text-white mb-6">
              {@theme.hero.title || "Masterpieces Crafted From Solid Wood"}
            </h1>
            <p
              :if={@theme.hero.subtitle}
              class="text-base sm:text-lg text-white/75 leading-relaxed mb-8 max-w-lg"
            >
              {@theme.hero.subtitle}
            </p>
            <a
              href={"/@#{@store.slug}/products"}
              class="inline-flex items-center gap-2 px-7 py-4 rounded-full bg-[#1F2937] text-white text-sm font-semibold border border-white/20 hover:bg-white hover:text-[#1F2937] transition-colors min-h-[48px]"
            >
              {@theme.hero.cta_text || "Explore More"}
              <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
            </a>
          </div>

          <%!-- Floating feature tiles overlay (bottom-right) — Furniora --%>
          <div
            :if={@tile_products != []}
            class="hidden md:flex absolute bottom-8 right-8 lg:bottom-12 lg:right-12 gap-3"
          >
            <a
              :for={{product, idx} <- Enum.with_index(@tile_products)}
              href={"/@#{@store.slug}/products/#{product.slug}"}
              class="block w-40 h-40 rounded-2xl overflow-hidden bg-white/10 backdrop-blur-md ring-1 ring-white/20 group hover:ring-[#84CC16] transition-all"
            >
              <div class="relative w-full h-full">
                <img
                  :if={Shared.first_image(product)}
                  src={Shared.first_image(product)}
                  alt={product.title}
                  class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                />
                <div
                  :if={!Shared.first_image(product)}
                  class="w-full h-full flex items-center justify-center bg-[#374151]"
                >
                  <span class="material-symbols-outlined text-white/40" style="font-size: 56px;">
                    {tile_icon(idx)}
                  </span>
                </div>
                <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-[#1F2937] to-transparent p-3">
                  <p class="text-xs font-semibold text-white truncate">
                    {product.title}
                  </p>
                  <span class="material-symbols-outlined text-[#84CC16]" style="font-size: 14px;">
                    arrow_outward
                  </span>
                </div>
              </div>
            </a>
          </div>
        </div>
      </section>

      <%!-- SHOP BY CATEGORIES strip (Furniora "200+ Unique products") --%>
      <section class="bg-white py-10 sm:py-12 border-b border-[#E5E7EB]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-end">
            <div class="lg:col-span-3">
              <h2 class="home-living-heading text-3xl sm:text-4xl font-bold text-[#1F2937] leading-tight">
                Shop<br />by categories
              </h2>
              <div class="flex items-center gap-2 mt-3">
                <span class="material-symbols-outlined text-[#84CC16]" style="font-size: 22px;">
                  inventory_2
                </span>
                <p class="text-sm text-[#4B5563]">
                  <span class="font-bold text-[#1F2937]">200+</span> unique products
                </p>
              </div>
            </div>
            <div class="lg:col-span-9 grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4">
              <a
                :for={room <- rooms_items(@theme)}
                href={"/@#{@store.slug}/products"}
                class="group bg-[#F3F4F6] rounded-2xl p-4 sm:p-5 hover:bg-[#1F2937] hover:text-white transition-colors min-h-[120px] flex flex-col justify-between"
              >
                <span
                  class="material-symbols-outlined text-[#1F2937] group-hover:text-[#84CC16] transition-colors"
                  style="font-size: 28px;"
                >
                  {room.icon}
                </span>
                <p class="text-sm font-semibold mt-3">
                  {room.name}
                </p>
              </a>
            </div>
          </div>
        </div>
      </section>

      <%!-- SALE BAND — 4 features (Lovely Home red bar) --%>
      <section :if={section_enabled?(@theme, :sale_band)} class="bg-[#C2410C] py-6 sm:py-8 text-white">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 sm:gap-6">
            <div
              :for={item <- sale_band_items(@theme)}
              class="flex items-center gap-3"
            >
              <span class="material-symbols-outlined text-[#84CC16]" style="font-size: 32px;">
                {item.icon}
              </span>
              <div>
                <p class="text-sm font-bold leading-tight">{item.title}</p>
                <p class="text-[11px] text-white/75 leading-tight">{item.subtitle}</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- FEATURED PRODUCTS GRID --%>
      <section
        :if={section_enabled?(@theme, :featured_products) && @featured_products != []}
        class="bg-[#FAF7F2] py-14 sm:py-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between mb-8">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#84CC16] mb-2">
                Bestsellers
              </p>
              <h2 class="home-living-heading text-3xl sm:text-4xl font-bold text-[#1F2937]">
                Popular products
              </h2>
            </div>
            <a
              href={"/@#{@store.slug}/products"}
              class="hidden sm:inline-flex items-center gap-1 text-sm font-semibold text-[#1F2937] hover:gap-2 transition-all"
            >
              View all
              <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
            </a>
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

      <%!-- DEAL OF THE DAY / Editor's Pick (terracotta secondary) --%>
      <section
        :if={section_enabled?(@theme, :editor_pick) && @editor_pick}
        class="bg-[#FAF7F2] pb-14 sm:pb-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid lg:grid-cols-2 gap-0 rounded-3xl overflow-hidden bg-[#1F2937]">
            <div class="p-8 sm:p-12 lg:p-16 text-white order-2 lg:order-1 flex flex-col justify-center">
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#84CC16] text-[#1F2937] text-[11px] font-bold uppercase tracking-wider mb-5 self-start">
                <span class="material-symbols-outlined" style="font-size: 12px;">flash_on</span>
                Deal of the Day
              </span>
              <h2 class="home-living-heading text-3xl sm:text-4xl lg:text-5xl font-bold leading-tight mb-5">
                {@editor_pick.title}
              </h2>
              <p
                :if={@editor_pick.description}
                class="text-base text-white/75 leading-relaxed mb-7 max-w-md line-clamp-3"
              >
                {@editor_pick.description}
              </p>
              <div class="flex flex-wrap items-center gap-4 mb-7">
                <span class="home-living-heading text-3xl font-bold text-[#84CC16]">
                  {EmakolaWeb.Helpers.Currency.format_price(
                    @editor_pick.min_price || 0,
                    Map.get(@store, :currency, "GHS")
                  )}
                </span>
                <span class="text-sm text-white/50 line-through">
                  20% off
                </span>
              </div>
              <a
                href={"/@#{@store.slug}/products/#{@editor_pick.slug}"}
                class="inline-flex items-center gap-2 px-7 py-4 rounded-full bg-[#84CC16] text-[#1F2937] text-sm font-bold hover:bg-white transition-colors min-h-[48px] self-start"
              >
                Shop now
                <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
              </a>
            </div>
            <div class="aspect-square lg:aspect-auto order-1 lg:order-2 bg-[#374151]">
              <img
                :if={Shared.first_image(@editor_pick)}
                src={Shared.first_image(@editor_pick)}
                alt={@editor_pick.title}
                class="w-full h-full object-cover"
              />
              <div
                :if={!Shared.first_image(@editor_pick)}
                class="w-full h-full flex items-center justify-center"
              >
                <span class="material-symbols-outlined text-white/30" style="font-size: 140px;">
                  chair
                </span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- TRUST STRIP --%>
      <section :if={section_enabled?(@theme, :trust)} class="bg-white py-12 sm:py-16">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
            <div
              :for={item <- trust_items(@theme)}
              class="flex items-center gap-4"
            >
              <div class="w-14 h-14 rounded-2xl bg-[#84CC16]/15 flex items-center justify-center flex-shrink-0">
                <span class="material-symbols-outlined text-[#1F2937]" style="font-size: 26px;">
                  {item.icon}
                </span>
              </div>
              <div>
                <p class="text-base font-semibold text-[#1F2937] mb-0.5">{item.label}</p>
                <p class="text-xs text-[#4B5563]">{item.subtitle}</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- BRAND STORY --%>
      <section :if={section_enabled?(@theme, :brand_story)} class="bg-[#FAF7F2] py-16 sm:py-24">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
            <div class="aspect-[4/3] rounded-3xl bg-gradient-to-br from-[#374151] to-[#1F2937] flex items-center justify-center overflow-hidden">
              <span class="material-symbols-outlined text-[#84CC16]/40" style="font-size: 140px;">
                home
              </span>
            </div>
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#84CC16] mb-3">
                Our story
              </p>
              <h2 class="home-living-heading text-3xl sm:text-4xl font-bold text-[#1F2937] mb-5 leading-tight">
                Built in Ghana, made for life.
              </h2>
              <p class="text-base text-[#4B5563] leading-relaxed mb-3">
                {@store.description ||
                  "We work with local craftspeople to bring you furniture that lasts. Solid wood, natural fibres, no fast-furniture shortcuts. Delivered across all 16 regions of Ghana."}
              </p>
              <a
                href={"/@#{@store.slug}/about"}
                class="inline-flex items-center gap-1 mt-4 text-sm font-semibold text-[#1F2937] hover:gap-2 transition-all"
              >
                Read more
                <span class="material-symbols-outlined" style="font-size: 16px;">arrow_forward</span>
              </a>
            </div>
          </div>
        </div>
      </section>

      <%!-- NEWSLETTER --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="bg-[#1F2937] py-14 sm:py-20">
        <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="home-living-heading text-3xl sm:text-4xl font-bold text-white mb-3">
            {newsletter_title(@theme)}
          </h2>
          <p class="text-sm text-white/70 mb-7">{newsletter_subtitle(@theme)}</p>
          <form class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto">
            <label for="home-living-newsletter-email" class="sr-only">Email</label>
            <input
              type="email"
              id="home-living-newsletter-email"
              placeholder="Enter your email"
              class="flex-1 px-5 py-3.5 rounded-full bg-white/10 border border-white/20 text-white placeholder:text-white/50 focus:outline-none focus:ring-2 focus:ring-[#84CC16] text-sm"
            />
            <button
              type="submit"
              class="px-7 py-3.5 rounded-full bg-[#84CC16] text-[#1F2937] text-sm font-bold hover:bg-white transition-colors min-h-[48px]"
            >
              {newsletter_button(@theme)}
            </button>
          </form>
        </div>
      </section>

      <Shared.home_living_footer store={@store} />
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

  defp rooms_items(theme) do
    case get_in(theme, [:rooms, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_rooms()
    end
  end

  defp default_rooms do
    [
      %{name: "Living Room", icon: "weekend", slug: "living"},
      %{name: "Bedroom", icon: "bed", slug: "bedroom"},
      %{name: "Kitchen", icon: "blender", slug: "kitchen"},
      %{name: "Bathroom", icon: "bathtub", slug: "bath"}
    ]
  end

  defp sale_band_items(theme) do
    case get_in(theme, [:sale_band, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_sale_band()
    end
  end

  defp default_sale_band do
    [
      %{icon: "local_shipping", title: "Free Delivery", subtitle: "Orders GHS 500+"},
      %{icon: "verified_user", title: "Safe Payment", subtitle: "MoMo & cards"},
      %{icon: "schedule", title: "Daily Curation", subtitle: "Hand-picked"},
      %{icon: "favorite", title: "Happy Customers", subtitle: "10k+ in Ghana"}
    ]
  end

  defp trust_items(theme) do
    case get_in(theme, [:trust, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_trust()
    end
  end

  defp default_trust do
    [
      %{icon: "category", label: "Quality materials", subtitle: "Solid wood, natural fibres"},
      %{icon: "local_shipping", label: "Ships in 5 days", subtitle: "Across Ghana"},
      %{icon: "swap_horiz", label: "30-day returns", subtitle: "No questions asked"}
    ]
  end

  defp newsletter_title(theme),
    do: get_in(theme, [:newsletter, :title]) || "New pieces, in your inbox"

  defp newsletter_subtitle(theme),
    do: get_in(theme, [:newsletter, :subtitle]) || "Restocks and seasonal releases."

  defp newsletter_button(theme), do: get_in(theme, [:newsletter, :button_text]) || "Subscribe"

  defp tile_icon(0), do: "lightbulb"
  defp tile_icon(_), do: "weekend"
end
