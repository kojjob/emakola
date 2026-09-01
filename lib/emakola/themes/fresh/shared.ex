defmodule Emakola.Themes.Fresh.Shared do
  @moduledoc """
  Shared components for the Fresh theme.

  Warm, organic, appetizing design for food and grocery stores:
  - Warm cream (#FEFCE8) background
  - Emerald green (#047857) primary / warm brown (#92400E) accent
  - Nunito headings + Inter body
  - Rounded-3xl cards with gentle shadows
  - Farmers market-style category circles
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias EmakolaWeb.Helpers.Currency

  # ── CSS Variable Injection ──

  @doc """
  Injects theme CSS custom properties into the page as a <style> block.
  Place this as the first element inside the outermost div of each page.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :primary]), "#047857") %>;
        --theme-accent: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :accent]), "#92400E") %>;
        --theme-bg: <%= EmakolaWeb.Helpers.CssColor.safe_css_color(get_in(@theme, [:colors, :background]), "#FEFCE8") %>;
      }
    </style>
    """
  end

  # ── Fresh Nav Bar ──

  @doc """
  White navigation bar with green accent. Store name with leaf icon.
  Rounded search bar. Cart with green badge.
  """
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0

  def fresh_nav(assigns) do
    ~H"""
    <header class="sticky top-0 z-50">
      <div class="bg-white border-b border-[#D9F99D]/60 shadow-sm">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-14 sm:h-16">
            <a href={store_path(@store.slug, "/")} class="flex items-center gap-2.5 min-w-0">
              <div class="w-10 h-10 rounded-full bg-gradient-to-br from-[#059669] to-[#047857] flex items-center justify-center flex-shrink-0 shadow-md">
                <span
                  class="material-symbols-outlined text-white"
                  style="font-size: 20px;"
                >
                  eco
                </span>
              </div>
              <div class="min-w-0">
                <div
                  class="text-[0.9375rem] font-bold text-cta-dark truncate leading-tight"
                  style="font-family: 'Nunito', sans-serif;"
                >
                  {@store.name}
                </div>
              </div>
            </a>

            <div class="flex items-center gap-1">
              <a
                href={store_path(@store.slug, "/products")}
                class="p-2.5 rounded-xl hover:bg-[#ECFDF5] transition-colors"
                aria-label="Search products"
              >
                <svg
                  class="w-5 h-5 text-[#92400E]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.8"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
                  />
                </svg>
              </a>
              <a
                href={store_path(@store.slug, "/cart")}
                class="relative p-2.5 rounded-xl hover:bg-[#ECFDF5] transition-colors"
                aria-label={"Shopping cart, #{Emakola.Plural.count(@cart_count, "item")}"}
              >
                <svg
                  class="w-5 h-5 text-[#92400E]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.8"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M2.25 3h1.386c.51 0 .955.343 1.087.835l.383 1.437M7.5 14.25a3 3 0 00-3 3h15.75m-12.75-3h11.218c1.121 0 2.002-.881 2.002-2.003V6.75m-14.22 0h14.22m-14.22 0L5.106 5.272M7.5 14.25L5.106 5.272m0 0a1.125 1.125 0 00-1.091-.852H2.25"
                  />
                </svg>
                <span
                  :if={@cart_count > 0}
                  class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-[#059669] text-white text-[10px] font-bold rounded-full flex items-center justify-center px-1"
                >
                  {@cart_count}
                </span>
              </a>
            </div>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ── Category Circle (Farmers Market Style) ──

  @doc """
  Circle with warm amber border, category image, and name below.
  Like a farmers market sign.

  Renders as a **link** when `href` is given — that is the home page, which has
  no product list to filter, so the shopper is going to the category's own page.
  Renders as a **filter button** otherwise: the product list narrows in place.

  Both were broken, and both crashed rather than doing nothing, because
  `handle_event/3` has no catch-all clause and an unmatched event raises:

    * On the home page it fired `filter_category` at `StoreLive`, which has no
      such handler at all. Every category on the Fresh home page killed the page.
    * On the product list it sent `phx-value-id`, but `ProductListLive` matches
      on `%{"category_id" => _}`, as the ten other themes send.
  """
  attr :category, :map, required: true
  attr :href, :string, default: nil
  attr :active, :boolean, default: false

  def category_circle(assigns) do
    ~H"""
    <a
      :if={@href}
      href={@href}
      class="flex flex-col items-center gap-2 flex-shrink-0 group cursor-pointer"
      role="listitem"
    >
      <.circle_face category={@category} active={@active} />
    </a>
    <button
      :if={!@href}
      phx-click="filter_category"
      phx-value-category_id={@category.id}
      class="flex flex-col items-center gap-2 flex-shrink-0 group cursor-pointer"
      role="listitem"
    >
      <.circle_face category={@category} active={@active} />
    </button>
    """
  end

  attr :category, :map, required: true
  attr :active, :boolean, required: true

  defp circle_face(assigns) do
    ~H"""
    <div class={[
      "w-[76px] h-[76px] rounded-full p-[3px] group-hover:scale-110 transition-transform duration-200",
      if(@active,
        do: "bg-gradient-to-br from-[#059669] to-[#047857] shadow-lg shadow-emerald-200",
        else: "bg-gradient-to-br from-[#92400E] to-[#B45309] shadow-sm"
      )
    ]}>
      <%= if category_image(@category) do %>
        <.optimized_image
          src={category_image(@category)}
          alt={@category.name}
          priority={:low}
          class="w-full h-full rounded-full object-cover border-[3px] border-[#FEFCE8]"
          width={70}
          height={70}
        />
      <% else %>
        <div class="w-full h-full rounded-full bg-[#FEFCE8] border-[3px] border-[#FEFCE8] flex items-center justify-center">
          <span class="text-xl font-bold text-[#92400E]">
            {String.first(@category.name)}
          </span>
        </div>
      <% end %>
    </div>
    <span class={[
      "text-xs font-semibold text-center whitespace-nowrap max-w-[80px] truncate",
      if(@active,
        do: "text-[#059669]",
        else: "text-[#78350F] group-hover:text-[#059669]"
      )
    ]}>
      {@category.name}
    </span>
    """
  end

  # ── Product Card (Fresh / Warm) ──

  @doc """
  Warm product card: cream background, rounded-3xl, large product image,
  Nunito title, green price, weight/size badge. Hover: gentle scale.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def product_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <a href={store_path(@store.slug, "/products/#{@product.slug}")} class="group block">
      <div class="relative rounded-3xl overflow-hidden mb-3 bg-[#FEF9C3]/30 shadow-sm group-hover:shadow-lg group-hover:shadow-emerald-100/60 transition-all duration-300">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@product.title}
          class="w-full aspect-square object-cover group-hover:scale-[1.04] transition-transform duration-500"
        />
        <div :if={!@image} class="w-full aspect-square flex items-center justify-center bg-[#ECFDF5]">
          <svg
            class="w-12 h-12 text-[#059669]/40"
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
        <%!-- Weight badge --%>
        <span
          :if={Map.get(@product, :weight)}
          class="absolute top-3 left-3 px-2.5 py-1 bg-white/90 backdrop-blur-sm text-[#92400E] text-xs font-semibold rounded-full"
        >
          {Map.get(@product, :weight)}
        </span>
      </div>
      <p
        class="text-sm font-bold text-cta-dark leading-tight mb-1 truncate"
        style="font-family: 'Nunito', sans-serif;"
      >
        {@product.title}
      </p>
      <p class="text-sm font-bold text-[var(--theme-primary,#047857)]">
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>
    </a>
    """
  end

  # ── Footer ──

  @doc """
  Cream background footer with green accents. "Farm fresh to your door" tagline.
  Payment badges and delivery info.
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    ~H"""
    <footer class="bg-[#FEFCE8] border-t border-[#D9F99D]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-8 mb-8">
          <%!-- Brand --%>
          <div>
            <div class="flex items-center gap-2.5 mb-3">
              <div class="w-9 h-9 rounded-full bg-gradient-to-br from-[#059669] to-[#047857] flex items-center justify-center">
                <span
                  class="material-symbols-outlined text-white"
                  style="font-size: 18px;"
                >
                  eco
                </span>
              </div>
              <span
                class="text-base font-bold text-cta-dark"
                style="font-family: 'Nunito', sans-serif;"
              >
                {@store.name}
              </span>
            </div>
            <%!-- The footer used to carry a "Fresh Guarantee" and a "Same Day
                 Delivery" badge on every page of every Fresh store. Neither was
                 the merchant's claim and neither had any data behind it, so both
                 are gone; the store's real delivery terms live on its policies
                 page and, when it has configured zones, in the home delivery
                 banner. --%>
            <p
              :if={@store.description not in [nil, ""]}
              class="text-sm text-[#78350F] leading-relaxed mb-4"
              style="font-family: 'Inter', sans-serif;"
            >
              {@store.description}
            </p>
          </div>

          <%!-- Explore --%>
          <div>
            <h3
              class="text-sm font-bold text-cta-dark mb-3 uppercase tracking-wider"
              style="font-family: 'Nunito', sans-serif;"
            >
              Explore
            </h3>
            <ul class="space-y-2 mb-4">
              <li>
                <a
                  href={store_path(@store.slug, "/blog")}
                  class="text-sm text-[#78350F] hover:text-[#059669] transition-colors"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Blog
                </a>
              </li>
              <li>
                <a
                  href={store_path(@store.slug, "/recipes")}
                  class="text-sm text-[#78350F] hover:text-[#059669] transition-colors"
                  style="font-family: 'Inter', sans-serif;"
                >
                  Recipes
                </a>
              </li>
              <li>
                <a
                  href={store_path(@store.slug, "/about")}
                  class="text-sm text-[#78350F] hover:text-[#059669] transition-colors"
                  style="font-family: 'Inter', sans-serif;"
                >
                  About Us
                </a>
              </li>
            </ul>
            <h3
              :if={@categories != []}
              class="text-sm font-bold text-cta-dark mb-3 uppercase tracking-wider"
              style="font-family: 'Nunito', sans-serif;"
            >
              Categories
            </h3>
            <ul class="space-y-2">
              <li :for={cat <- Enum.take(@categories, 6)}>
                <a
                  href={store_path(@store.slug, "/products?category=#{cat.slug}")}
                  class="text-sm text-[#78350F] hover:text-[#059669] transition-colors"
                  style="font-family: 'Inter', sans-serif;"
                >
                  {cat.name}
                </a>
              </li>
            </ul>
          </div>

          <%!-- Contact --%>
          <div>
            <h3
              class="text-sm font-bold text-cta-dark mb-3 uppercase tracking-wider"
              style="font-family: 'Nunito', sans-serif;"
            >
              Get in Touch
            </h3>
            <div class="space-y-3">
              <a
                :if={Map.get(@store, :whatsapp_number)}
                href={"https://wa.me/#{String.replace(@store.whatsapp_number || "", "+", "")}"}
                target="_blank"
                rel="noopener noreferrer"
                class="flex items-center gap-2 text-sm text-[#78350F] hover:text-whatsapp transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                  <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
                </svg>
                WhatsApp
              </a>
              <a
                href={store_path(@store.slug, "/products")}
                class="flex items-center gap-2 text-sm text-[#78350F] hover:text-[#059669] transition-colors"
                style="font-family: 'Inter', sans-serif;"
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.5 21v-7.5a.75.75 0 01.75-.75h3a.75.75 0 01.75.75V21m-4.5 0H2.36m11.14 0H18m0 0h3.64m-1.39 0V9.349m-16.5 11.65V9.35m0 0a3.001 3.001 0 003.75-.615A2.993 2.993 0 009.75 9.75c.896 0 1.7-.393 2.25-1.016a2.993 2.993 0 002.25 1.016c.896 0 1.7-.393 2.25-1.016a3.001 3.001 0 003.75.614m-16.5 0a3.004 3.004 0 01-.621-4.72L4.318 3.44A1.5 1.5 0 015.378 3h13.243a1.5 1.5 0 011.06.44l1.19 1.189a3 3 0 01-.621 4.72m-13.5 8.65h3.75a.75.75 0 00.75-.75V13.5a.75.75 0 00-.75-.75H6.75a.75.75 0 00-.75.75v3.15c0 .415.336.75.75.75z"
                  />
                </svg>
                Browse Products
              </a>
            </div>
          </div>
        </div>

        <%!-- Payment methods & copyright --%>
        <div class="border-t border-[#D9F99D] pt-6 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div class="flex items-center gap-3">
            <span class="px-2.5 py-1 bg-white border border-[#D9F99D] rounded text-xs font-semibold text-[#78350F]">
              MoMo
            </span>
            <span class="px-2.5 py-1 bg-white border border-[#D9F99D] rounded text-xs font-semibold text-[#78350F]">
              Telecel Cash
            </span>
            <span class="px-2.5 py-1 bg-white border border-[#D9F99D] rounded text-xs font-semibold text-[#78350F]">
              Card
            </span>
          </div>
          <p class="text-xs text-[#78350F]/60" style="font-family: 'Inter', sans-serif;">
            {@store.name} — Powered by Makola
          </p>
        </div>
      </div>
    </footer>
    """
  end

  # ── Helpers ──

  @doc """
  Whether a legacy `@theme.sections.<name>` toggle leaves a home block on.
  Lifted out of `Fresh.Home` so each extracted section keeps its own gate —
  stores that switched a block off the old way still see it off.
  """
  def section_enabled?(theme, section_name) do
    case theme do
      %{sections: sections} when is_map(sections) ->
        Map.get(sections, section_name, true)

      _ ->
        true
    end
  end

  @doc """
  Extract first image URL from a product's images association.
  """
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  defp category_image(category) do
    if Map.has_key?(category, :image_url), do: category.image_url, else: nil
  end
end
