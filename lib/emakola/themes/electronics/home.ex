defmodule Emakola.Themes.Electronics.Home do
  @moduledoc """
  Electronics theme home — modern tech store mirroring the user-supplied
  Dribbble reference ("Upgrade Your Gear, Upgrade Yourself"):

  - Deep teal hero with vibrant product shot, orange CTA pill
  - Category pill strip (active = orange)
  - "Immersive Sound, Unmatched Comfort" — split: 2x2 product mini-grid
    on left + lifestyle image on right
  - Popular product grid (4-col) + featured deal split card
  - Trust statement banner (centered cream copy)
  - Best selling product grid (3-col)
  - Dark teal CTA band with star pattern + orange button
  - Newsletter on dark navy (footer-matched)
  """

  use Phoenix.Component

  alias Emakola.Themes.Electronics.Shared

  attr :store, :map, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:immersive_grid, fn -> Enum.take(assigns.products, 4) end)
      |> assign_new(:featured_products, fn -> Enum.take(assigns.products, 4) end)
      |> assign_new(:featured_deal, fn -> List.first(assigns.products) end)
      |> assign_new(:best_sellers, fn -> Enum.take(Enum.drop(assigns.products, 4), 3) end)

    ~H"""
    <div class="electronics-body min-h-screen">
      <Shared.theme_styles theme={@theme} />

      <%!-- HERO: split layout, deep teal left, vibrant product right --%>
      <section :if={section_enabled?(@theme, :hero)} class="bg-[#134E4A]">
        <Shared.electronics_nav store={@store} cart_count={@cart_count} on_dark={true} />

        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14 lg:py-20">
          <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
            <div class="text-white">
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#F97316]/20 text-[#F97316] text-[11px] font-bold uppercase tracking-[0.18em] mb-5">
                <span class="material-symbols-outlined" style="font-size: 14px;">flash_on</span>
                New Arrivals
              </span>
              <h1 class="electronics-heading text-4xl sm:text-5xl lg:text-6xl font-extrabold leading-[1.05] mb-3">
                {hero_title_first(@theme)}
              </h1>
              <p class="electronics-heading text-2xl sm:text-3xl lg:text-4xl text-[#F97316] font-bold mb-6">
                {hero_title_second(@theme)}
              </p>
              <p
                :if={@theme.hero.subtitle}
                class="text-base text-white/75 leading-relaxed mb-8 max-w-md"
              >
                {@theme.hero.subtitle}
              </p>
              <div class="flex flex-col sm:flex-row gap-3">
                <a
                  href={"/s/#{@store.slug}/products"}
                  class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full bg-[#F97316] text-white text-sm font-bold hover:bg-[#EA580C] transition-colors min-h-[48px]"
                >
                  {@theme.hero.cta_text || "Shop Now"}
                  <span class="material-symbols-outlined" style="font-size: 18px;">
                    arrow_forward
                  </span>
                </a>
                <a
                  href={"/s/#{@store.slug}/about"}
                  class="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-full border border-white/20 text-white text-sm font-semibold hover:bg-white/5 transition-colors min-h-[48px]"
                >
                  Learn more
                </a>
              </div>
            </div>

            <div class="relative">
              <div class="aspect-square rounded-3xl overflow-hidden bg-gradient-to-br from-[#1A6E69] to-[#0E3F3B] flex items-center justify-center">
                <%= if hero_image_url(assigns) do %>
                  <img
                    src={hero_image_url(assigns)}
                    alt="Electronics"
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <span class="material-symbols-outlined text-[#F97316]/40" style="font-size: 200px;">
                    headphones
                  </span>
                <% end %>
              </div>
              <%!-- Floating spec card --%>
              <div class="absolute bottom-6 left-6 sm:bottom-8 sm:left-8 bg-white rounded-2xl px-5 py-4 shadow-xl">
                <p class="text-[10px] uppercase tracking-wider text-[#6B7280] font-semibold mb-1">
                  Battery
                </p>
                <p class="electronics-mono text-base font-bold text-[#134E4A]">40hrs · BT 5.3</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- CATEGORY PILL STRIP --%>
      <section
        :if={section_enabled?(@theme, :categories)}
        class="bg-[#F5EFE5] border-b border-[#E5E7EB]"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-5">
          <div class="flex flex-wrap items-center gap-2 sm:gap-3">
            <a
              :for={item <- categories_strip_items(@theme)}
              href={"/s/#{@store.slug}/products"}
              class={"inline-flex items-center px-4 py-2 rounded-full text-sm font-semibold transition-colors min-h-[40px] " <>
                if(Map.get(item, :active), do: "bg-[#F97316] text-white", else: "bg-white border border-[#E5E7EB] text-[#1F2937] hover:border-[#F97316] hover:text-[#F97316]")}
            >
              {item.label}
            </a>
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center gap-1 ml-auto text-xs font-semibold text-[#134E4A] hover:gap-2 transition-all"
            >
              See all
              <span class="material-symbols-outlined" style="font-size: 14px;">arrow_forward</span>
            </a>
          </div>
        </div>
      </section>

      <%!-- IMMERSIVE: split grid + lifestyle --%>
      <section
        :if={section_enabled?(@theme, :immersive) && @immersive_grid != []}
        class="bg-[#F5EFE5] py-14 sm:py-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between mb-8">
            <h2 class="electronics-heading text-3xl sm:text-4xl font-extrabold text-[#134E4A]">
              Immersive Sound,<br />Unmatched Comfort
            </h2>
            <span class="hidden sm:inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white border border-[#E5E7EB] text-xs font-semibold text-[#134E4A]">
              <span class="material-symbols-outlined" style="font-size: 14px;">filter_list</span>
              Few products
            </span>
          </div>
          <div class="grid lg:grid-cols-2 gap-5">
            <div class="grid grid-cols-2 gap-4">
              <Shared.product_card
                :for={product <- @immersive_grid}
                product={product}
                store={@store}
              />
            </div>
            <div class="aspect-square lg:aspect-auto rounded-2xl overflow-hidden bg-gradient-to-br from-[#0F4A45] via-[#134E4A] to-[#0E3F3B] relative">
              <span class="absolute inset-0 flex items-center justify-center">
                <span class="material-symbols-outlined text-[#F97316]/30" style="font-size: 200px;">
                  headphones
                </span>
              </span>
              <div class="absolute bottom-6 left-6 right-6">
                <p class="electronics-heading text-2xl font-bold text-white mb-1">
                  Premium audio gear
                </p>
                <p class="text-sm text-white/70 mb-4">
                  Hand-picked for clarity, comfort, and battery life.
                </p>
                <a
                  href={"/s/#{@store.slug}/products"}
                  class="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-[#F97316] text-white text-xs font-bold hover:bg-[#EA580C] transition-colors"
                >
                  Learn More
                  <span class="material-symbols-outlined" style="font-size: 14px;">
                    arrow_forward
                  </span>
                </a>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- POPULAR PRODUCTS GRID + FEATURED DEAL --%>
      <section
        :if={section_enabled?(@theme, :featured_products) && @featured_products != []}
        class="bg-[#F5EFE5] pb-14 sm:pb-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between mb-8">
            <h2 class="electronics-heading text-3xl sm:text-4xl font-extrabold text-[#134E4A]">
              Popular product
            </h2>
            <a
              href={"/s/#{@store.slug}/products"}
              class="hidden sm:inline-flex items-center gap-1 text-sm font-semibold text-[#134E4A] hover:gap-2 transition-all"
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

          <%!-- Featured deal split card --%>
          <div
            :if={@featured_deal}
            class="mt-8 grid lg:grid-cols-2 gap-0 rounded-2xl overflow-hidden electronics-card"
          >
            <div class="aspect-square lg:aspect-auto bg-[#F3F4F6] flex items-center justify-center p-12">
              <%= if Shared.first_image(@featured_deal) do %>
                <img
                  src={Shared.first_image(@featured_deal)}
                  alt={@featured_deal.title}
                  class="max-w-full max-h-full object-contain"
                />
              <% else %>
                <span class="material-symbols-outlined text-[#134E4A]/30" style="font-size: 160px;">
                  headphones
                </span>
              <% end %>
            </div>
            <div class="p-8 sm:p-10 lg:p-12 flex flex-col justify-center">
              <h3 class="electronics-heading text-2xl sm:text-3xl font-bold text-[#1F2937] mb-3">
                {@featured_deal.title}
              </h3>
              <p
                :if={@featured_deal.description}
                class="text-sm text-[#4B5563] leading-relaxed mb-5 line-clamp-3"
              >
                {@featured_deal.description}
              </p>
              <%!-- Color swatches --%>
              <div class="flex items-center gap-2 mb-5">
                <span class="w-6 h-6 rounded-full bg-[#1F2937] ring-2 ring-[#F97316]"></span>
                <span class="w-6 h-6 rounded-full bg-[#F97316] ring-1 ring-black/10"></span>
                <span class="w-6 h-6 rounded-full bg-[#134E4A] ring-1 ring-black/10"></span>
                <span class="w-6 h-6 rounded-full bg-white ring-1 ring-[#E5E7EB]"></span>
              </div>
              <div class="flex items-center justify-between">
                <span class="electronics-mono text-2xl font-bold text-[#134E4A]">
                  {EmakolaWeb.Helpers.Currency.format_price(
                    @featured_deal.min_price || 0,
                    Map.get(@store, :currency, "GHS")
                  )}
                </span>
                <a
                  href={"/s/#{@store.slug}/products/#{@featured_deal.slug}"}
                  class="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-[#F97316] text-white text-sm font-bold hover:bg-[#EA580C] transition-colors"
                >
                  Add to Cart
                </a>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- TRUST STATEMENT --%>
      <section :if={section_enabled?(@theme, :trust)} class="bg-[#F5EFE5] py-14 sm:py-20">
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="electronics-heading text-2xl sm:text-3xl lg:text-4xl font-bold text-[#134E4A] leading-tight mb-3">
            {trust_title(@theme)}
          </h2>
          <p class="text-base text-[#4B5563] leading-relaxed">
            {trust_subtitle(@theme)}
          </p>
        </div>
      </section>

      <%!-- BEST SELLERS --%>
      <section
        :if={section_enabled?(@theme, :bestsellers) && @best_sellers != []}
        class="bg-[#F5EFE5] pb-14 sm:pb-20"
      >
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-end justify-between mb-8">
            <h2 class="electronics-heading text-3xl sm:text-4xl font-extrabold text-[#134E4A]">
              Best selling product
            </h2>
            <a
              href={"/s/#{@store.slug}/products"}
              class="hidden sm:inline-flex items-center gap-1 text-sm font-semibold text-[#134E4A] hover:gap-2 transition-all"
            >
              See all
              <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
            </a>
          </div>
          <div class="grid grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
            <Shared.product_card
              :for={product <- @best_sellers}
              product={product}
              store={@store}
            />
          </div>
        </div>
      </section>

      <%!-- DARK CTA BAND with star pattern --%>
      <section
        :if={section_enabled?(@theme, :cta_band)}
        class="bg-[#134E4A] py-14 sm:py-20 relative overflow-hidden"
      >
        <%!-- Star pattern background --%>
        <div class="absolute inset-0 opacity-10">
          <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <pattern
                id="electronics-stars"
                x="0"
                y="0"
                width="80"
                height="80"
                patternUnits="userSpaceOnUse"
              >
                <path
                  d="M40 10l4 12 12 1-9 8 3 12-10-7-10 7 3-12-9-8 12-1z"
                  fill="white"
                  fill-opacity="0.6"
                />
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#electronics-stars)" />
          </svg>
        </div>
        <div class="relative max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center text-white">
          <h2 class="electronics-heading text-3xl sm:text-4xl lg:text-5xl font-extrabold leading-tight mb-3">
            {cta_band_title(@theme)}
          </h2>
          <p class="text-base text-white/80 mb-7">{cta_band_subtitle(@theme)}</p>
          <a
            href={"/s/#{@store.slug}/products"}
            class="inline-flex items-center gap-2 px-8 py-4 rounded-full bg-[#F97316] text-white text-sm font-bold hover:bg-[#EA580C] transition-colors min-h-[48px]"
          >
            {cta_band_button(@theme)}
            <span class="material-symbols-outlined" style="font-size: 18px;">arrow_forward</span>
          </a>
        </div>
      </section>

      <%!-- NEWSLETTER --%>
      <section :if={section_enabled?(@theme, :newsletter)} class="bg-[#0A0F1F] py-14 sm:py-20">
        <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="electronics-heading text-3xl sm:text-4xl font-bold text-white mb-3">
            {newsletter_title(@theme)}
          </h2>
          <p class="text-sm text-white/70 mb-7">{newsletter_subtitle(@theme)}</p>
          <form class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto">
            <label for="electronics-newsletter-email" class="sr-only">Email</label>
            <input
              type="email"
              id="electronics-newsletter-email"
              placeholder="Enter your email"
              class="flex-1 px-5 py-3.5 rounded-full bg-white/10 border border-white/20 text-white placeholder:text-white/50 focus:outline-none focus:ring-2 focus:ring-[#F97316] text-sm"
            />
            <button
              type="submit"
              class="px-7 py-3.5 rounded-full bg-[#F97316] text-white text-sm font-bold hover:bg-[#EA580C] transition-colors min-h-[48px]"
            >
              {newsletter_button(@theme)}
            </button>
          </form>
        </div>
      </section>

      <Shared.electronics_footer store={@store} />
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

  # Splits hero title at first comma so headline can be "Upgrade Your Gear"
  # then orange "Upgrade Yourself" on a second line.
  defp hero_title_first(theme) do
    case get_in(theme, [:hero, :title]) do
      nil ->
        "Upgrade Your Gear"

      title when is_binary(title) ->
        case String.split(title, ",", parts: 2) do
          [first, _] -> String.trim(first)
          [single] -> single
        end
    end
  end

  defp hero_title_second(theme) do
    case get_in(theme, [:hero, :title]) do
      nil ->
        "Upgrade Yourself"

      title when is_binary(title) ->
        case String.split(title, ",", parts: 2) do
          [_, second] -> String.trim(second)
          _ -> "Upgrade Yourself"
        end
    end
  end

  defp categories_strip_items(theme) do
    case get_in(theme, [:categories_strip, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_categories_strip()
    end
  end

  defp default_categories_strip do
    [
      %{label: "Wireless", active: true},
      %{label: "Noise Cancellation"},
      %{label: "Sports & Active"},
      %{label: "Phones"}
    ]
  end

  defp trust_title(theme), do: get_in(theme, [:trust, :title]) || "Why thousands trust us"

  defp trust_subtitle(theme),
    do:
      get_in(theme, [:trust, :subtitle]) ||
        "Genuine products. 1-year warranty. Free shipping."

  defp cta_band_title(theme),
    do: get_in(theme, [:cta_band, :title]) || "Explore our latest collection"

  defp cta_band_subtitle(theme),
    do: get_in(theme, [:cta_band, :subtitle]) || "of electronics"

  defp cta_band_button(theme),
    do: get_in(theme, [:cta_band, :button_text]) || "Shop the Collection"

  defp newsletter_title(theme),
    do: get_in(theme, [:newsletter, :title]) || "Subscribe to our newsletter"

  defp newsletter_subtitle(theme),
    do: get_in(theme, [:newsletter, :subtitle]) || "New launches and exclusive offers."

  defp newsletter_button(theme),
    do: get_in(theme, [:newsletter, :button_text]) || "Subscribe"
end
