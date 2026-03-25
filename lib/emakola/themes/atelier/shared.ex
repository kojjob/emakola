defmodule Emakola.Themes.Atelier.Shared do
  @moduledoc """
  Shared UI components for the Atelier artisan craft theme.

  Design language (Stitch reference):
  - Fonts: System sans-serif (bold/black headings, regular body)
  - Colors: Green (#16A34A primary CTA, #166534 accent/brand), White surface
  - All colors use CSS variables for merchant overrides
  - Trust-forward, artisan aesthetic
  """
  use Phoenix.Component

  alias EmakolaWeb.Helpers.Currency

  # ── CSS Variables ──

  @doc """
  Injects Atelier theme CSS custom properties and base styles.
  Place this in the root layout when the Atelier theme is active.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#16A34A" %>;
        --theme-primary-light: #22C55E;
        --theme-primary-dark: <%= get_in(@theme, [:colors, :accent]) || "#166534" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#166534" %>;
        --theme-accent-secondary: #4B5563;
        --theme-surface: <%= get_in(@theme, [:colors, :background]) || "#FFFFFF" %>;
        --theme-ink: #1a1a1a;
        --theme-gold: #CA8A04;
        --theme-bg: var(--theme-surface);
      }
      .atelier-body {
        font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        color: var(--theme-ink);
        background: var(--theme-surface);
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
      }
      .atelier-product-card { cursor: pointer; }
      .atelier-product-card:hover img { transform: scale(1.05); }
      .atelier-product-card:hover .atelier-quick-add { opacity: 1; transform: translateY(0); }
      .atelier-quick-add { opacity: 0; transform: translateY(8px); transition: all 0.2s ease; }
      .atelier-category-circle { cursor: pointer; }
      .atelier-category-circle:hover img { transform: scale(1.1); }
      .atelier-category-circle:hover .atelier-cat-ring { border-color: var(--theme-primary); }
      .atelier-accordion-content { max-height: 0; overflow: hidden; transition: max-height 0.3s ease; }
      .atelier-accordion-toggle:checked ~ .atelier-accordion-content { max-height: 200px; }
      .atelier-accordion-toggle:checked ~ .atelier-accordion-header .atelier-accordion-icon { transform: rotate(180deg); }
    </style>
    """
  end

  # ── Navigation ──

  @doc """
  Atelier white navigation bar (Stitch design reference).

  - White background, sticky top, subtle bottom border
  - Left: Store name in bold accent color
  - Center: Nav links with active underline in theme primary
  - Right: Search pill, Cart icon (with badge), Account icon
  - Mobile: center links and search text hidden, icon-only
  """
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0
  attr :transparent, :boolean, default: false
  attr :active_path, :string, default: nil
  attr :search_placeholder, :string, default: nil

  def navbar(assigns) do
    search_text =
      assigns[:search_placeholder] ||
        get_in(assigns.store, [Access.key(:theme), Access.key(:search_placeholder)]) ||
        "Search products..."

    assigns = assign(assigns, :search_text, search_text)

    ~H"""
    <nav class="sticky top-0 left-0 right-0 z-50 bg-white border-b border-gray-100">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16 sm:h-20">
          <%!-- Left: Store name --%>
          <a
            href={"/s/#{@store.slug}"}
            class="text-xl sm:text-2xl font-black tracking-tight cursor-pointer transition-opacity duration-200 hover:opacity-80 min-h-[44px] flex items-center"
            style="color: var(--theme-accent);"
          >
            {@store.name}
          </a>

          <%!-- Center: Nav links (Desktop only) --%>
          <div class="hidden lg:flex items-center gap-8">
            <a
              href={"/s/#{@store.slug}/products"}
              class={[
                "relative text-sm font-medium cursor-pointer transition-colors duration-200 hover:text-gray-900 min-h-[44px] flex items-center",
                if(@active_path in ["/", "/products", nil] and @active_path != nil,
                  do: "text-gray-900",
                  else: "text-gray-600"
                )
              ]}
            >
              Shop
              <span
                :if={@active_path in ["/", "/products"]}
                class="absolute bottom-0 left-0 right-0 h-0.5"
                style="background: var(--theme-primary);"
              />
            </a>
            <a
              :for={category <- Enum.take(@categories, 3)}
              href={"/s/#{@store.slug}/category/#{category.slug}"}
              class={[
                "relative text-sm font-medium cursor-pointer transition-colors duration-200 hover:text-gray-900 min-h-[44px] flex items-center",
                if(@active_path == "/category/#{category.slug}",
                  do: "text-gray-900",
                  else: "text-gray-600"
                )
              ]}
            >
              {category.name}
              <span
                :if={@active_path == "/category/#{category.slug}"}
                class="absolute bottom-0 left-0 right-0 h-0.5"
                style="background: var(--theme-primary);"
              />
            </a>
          </div>

          <%!-- Right: Search + Icons --%>
          <div class="flex items-center gap-3 sm:gap-4">
            <%!-- Search Bar (Desktop pill) --%>
            <a
              href={"/s/#{@store.slug}/products"}
              class="hidden md:flex items-center gap-2 bg-gray-100 rounded-full px-4 py-2.5 text-sm text-gray-500 cursor-pointer transition-colors duration-200 hover:bg-gray-200 min-w-[220px] min-h-[44px]"
            >
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="flex-shrink-0"
              >
                <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
              <span class="truncate">{@search_text}</span>
            </a>

            <%!-- Search Icon (Mobile) --%>
            <a
              href={"/s/#{@store.slug}/products"}
              class="md:hidden flex items-center justify-center w-11 h-11 text-gray-700 cursor-pointer transition-colors duration-200 hover:text-gray-900 rounded-full hover:bg-gray-100"
              aria-label="Search"
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
            </a>

            <%!-- Cart --%>
            <a
              href={"/s/#{@store.slug}/cart"}
              class="relative flex items-center justify-center w-11 h-11 text-gray-700 cursor-pointer transition-colors duration-200 hover:text-gray-900 rounded-full hover:bg-gray-100"
              aria-label={"Shopping cart, #{@cart_count} items"}
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z" />
                <line x1="3" y1="6" x2="21" y2="6" />
                <path d="M16 10a4 4 0 01-8 0" />
              </svg>
              <span
                :if={@cart_count > 0}
                class="absolute top-0.5 right-0.5 w-5 h-5 text-[10px] font-bold rounded-full flex items-center justify-center text-white"
                style="background: var(--theme-primary);"
              >
                {@cart_count}
              </span>
            </a>

            <%!-- Account --%>
            <a
              href={"/s/#{@store.slug}/account"}
              class="hidden sm:flex items-center justify-center w-11 h-11 text-gray-700 cursor-pointer transition-colors duration-200 hover:text-gray-900 rounded-full hover:bg-gray-100"
              aria-label="Account"
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" /><circle cx="12" cy="7" r="4" />
              </svg>
            </a>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  # ── Product Card ──

  @doc """
  Atelier product card with image, quick-add overlay, title, and price.
  Stitch design: image + hover quick-add button + title + price below.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :show_add_button, :boolean, default: true

  def product_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <div class="atelier-product-card group">
      <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="block">
        <div class="relative overflow-hidden bg-gray-100 rounded-lg aspect-square mb-3">
          <img
            :if={@image}
            src={@image}
            alt={@product.title}
            loading="lazy"
            class="w-full h-full object-cover transition-transform duration-300"
          />
          <div :if={!@image} class="w-full h-full flex items-center justify-center bg-gray-100">
            <.image_placeholder />
          </div>

          <%!-- Quick Add overlay button --%>
          <div :if={@show_add_button} class="absolute bottom-3 left-3 right-3">
            <button
              class="atelier-quick-add w-full py-3 text-xs font-semibold uppercase tracking-wider rounded-lg text-white cursor-pointer transition-colors duration-200 min-h-[44px]"
              style="background: var(--theme-primary);"
              phx-click="add_to_cart"
              phx-value-product-id={@product.id}
            >
              Add to Cart
            </button>
          </div>
        </div>
      </a>

      <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="block">
        <h3 class="text-sm font-medium text-gray-900 leading-snug mb-1 line-clamp-2">
          {@product.title}
        </h3>
        <.price_display product={@product} store={@store} />
      </a>
    </div>
    """
  end

  # ── Hero Product Card ──

  @doc """
  Large hero-style product card for the featured section.
  Full-width image with title, price, and Details button overlaid at bottom.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true

  def hero_product_card(assigns) do
    assigns = assign(assigns, :image, first_image(assigns.product))

    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="group block relative overflow-hidden rounded-xl bg-gray-100 aspect-[4/5] sm:aspect-[3/4] cursor-pointer"
    >
      <img
        :if={@image}
        src={@image}
        alt={@product.title}
        loading="lazy"
        class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
      />
      <div :if={!@image} class="w-full h-full flex items-center justify-center">
        <.image_placeholder />
      </div>

      <%!-- Gradient overlay --%>
      <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-transparent"></div>

      <%!-- Content at bottom --%>
      <div class="absolute bottom-0 left-0 right-0 p-5 sm:p-6">
        <h3 class="text-lg sm:text-xl font-bold text-white mb-1">
          {@product.title}
        </h3>
        <p class="text-white/90 text-sm font-semibold mb-3 tabular-nums">
          {Currency.format_price(@product.min_price || 0, @store.currency)}
        </p>
        <span class="inline-block px-5 py-2.5 text-xs font-semibold uppercase tracking-wider rounded-lg text-white border border-white/40 hover:bg-white/20 transition-colors duration-200 cursor-pointer min-h-[44px] leading-[28px]">
          Details
        </span>
      </div>
    </a>
    """
  end

  # ── Category Circle ──

  @doc """
  Category circle for the horizontal scrolling section.
  Circular image with category name below.
  """
  attr :category, :map, required: true
  attr :store, :map, required: true

  def category_circle(assigns) do
    image = category_image(assigns.category)
    assigns = assign(assigns, :image, image)

    ~H"""
    <a
      href={"/s/#{@store.slug}/category/#{@category.slug}"}
      class="atelier-category-circle flex flex-col items-center gap-2 flex-shrink-0 group"
    >
      <div class="atelier-cat-ring w-20 h-20 sm:w-24 sm:h-24 rounded-full overflow-hidden bg-gray-100 border-2 border-gray-200 transition-colors duration-200">
        <img
          :if={@image}
          src={@image}
          alt={@category.name}
          class="w-full h-full object-cover transition-transform duration-300"
          loading="lazy"
        />
        <div :if={!@image} class="w-full h-full flex items-center justify-center bg-gray-200">
          <span class="text-lg font-bold text-gray-400">{String.first(@category.name)}</span>
        </div>
      </div>
      <span class="text-xs sm:text-sm font-medium text-gray-700 text-center whitespace-nowrap">
        {@category.name}
      </span>
    </a>
    """
  end

  # ── Star Rating ──

  attr :rating, :float, default: 0.0
  attr :review_count, :integer, default: 0

  def star_rating(assigns) do
    full_stars = trunc(assigns.rating)
    has_half = assigns.rating - full_stars >= 0.5
    empty_stars = 5 - full_stars - if(has_half, do: 1, else: 0)

    assigns =
      assigns
      |> assign(:full_stars, full_stars)
      |> assign(:has_half, has_half)
      |> assign(:empty_stars, empty_stars)

    ~H"""
    <div class="flex items-center gap-1.5">
      <div class="flex items-center" style="color: var(--theme-gold, #CA8A04);">
        <svg :for={_ <- 1..@full_stars} width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
          <polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26" />
        </svg>
        <svg
          :if={@has_half}
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="currentColor"
          opacity="0.6"
        >
          <polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26" />
        </svg>
        <svg
          :for={_ <- 1..max(@empty_stars, 0)}
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="currentColor"
          opacity="0.2"
        >
          <polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26" />
        </svg>
      </div>
      <span :if={@review_count > 0} class="text-xs text-gray-500">
        ({@review_count} Reviews)
      </span>
    </div>
    """
  end

  # ── Price Display ──

  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :size, :string, default: "sm"

  def price_display(assigns) do
    has_sale =
      assigns.product.min_price && assigns.product.max_price &&
        assigns.product.min_price < assigns.product.max_price

    assigns = assign(assigns, :has_sale, has_sale)

    ~H"""
    <div class="flex items-center gap-2">
      <p
        class={[
          "font-bold tabular-nums",
          if(@size == "lg", do: "text-2xl", else: "text-sm")
        ]}
        style="color: var(--theme-accent);"
      >
        {Currency.format_price(@product.min_price || 0, @store.currency)}
      </p>
      <p
        :if={@has_sale}
        class={[
          "line-through tabular-nums text-gray-400",
          if(@size == "lg", do: "text-base", else: "text-xs")
        ]}
      >
        {Currency.format_price(@product.max_price, @store.currency)}
      </p>
    </div>
    """
  end

  # ── Footer ──

  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :theme, :map, default: %{}

  def footer(assigns) do
    theme = assigns[:theme] || %{}
    footer_config = get_in(theme, [:footer]) || %{}

    brand_description =
      Map.get(
        footer_config,
        :description,
        if(assigns.store.description,
          do: assigns.store.description,
          else: "Curating excellence from West Africa's finest artisans."
        )
      )

    company_links =
      Map.get(footer_config, :company_links, [
        %{label: "Our Story", url: nil},
        %{label: "Shipping", url: nil},
        %{label: "Wholesale", url: nil},
        %{label: "Privacy Policy", url: nil}
      ])

    social_links =
      Map.get(footer_config, :social_links, %{
        instagram: nil,
        twitter: nil,
        facebook: nil
      })

    assigns =
      assigns
      |> assign(:brand_description, brand_description)
      |> assign(:company_links, company_links)
      |> assign(:social_links, social_links)

    ~H"""
    <footer class="bg-[#1a1a1a] text-white">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-14 sm:py-20">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-10 sm:gap-8">
          <%!-- Brand / Description --%>
          <div class="lg:col-span-1">
            <a
              href={"/s/#{@store.slug}"}
              class="inline-block text-xl font-black tracking-tight mb-4 cursor-pointer transition-opacity duration-200 hover:opacity-80 min-h-[44px] flex items-center"
              style="color: var(--theme-primary);"
            >
              {@store.name}
            </a>
            <p class="text-gray-400 text-sm leading-relaxed max-w-xs">
              {@brand_description}
            </p>
          </div>

          <%!-- Quick Links --%>
          <div>
            <h4 class="text-white text-xs font-semibold uppercase tracking-widest mb-5">
              Quick Links
            </h4>
            <ul class="space-y-3">
              <li>
                <a
                  href={"/s/#{@store.slug}/products"}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                >
                  Shop All
                </a>
              </li>
              <li :for={category <- Enum.take(@categories, 4)}>
                <a
                  href={"/s/#{@store.slug}/category/#{category.slug}"}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                >
                  {category.name}
                </a>
              </li>
            </ul>
          </div>

          <%!-- Company --%>
          <div>
            <h4 class="text-white text-xs font-semibold uppercase tracking-widest mb-5">Company</h4>
            <ul class="space-y-3">
              <li :for={link <- @company_links}>
                <%= if Map.get(link, :url) do %>
                  <a
                    href={Map.get(link, :url)}
                    class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                  >
                    {Map.get(link, :label)}
                  </a>
                <% else %>
                  <span class="text-gray-400 text-sm inline-flex items-center min-h-[44px]">
                    {Map.get(link, :label)}
                  </span>
                <% end %>
              </li>
            </ul>
          </div>

          <%!-- Contact / Social --%>
          <div>
            <h4 class="text-white text-xs font-semibold uppercase tracking-widest mb-5">Connect</h4>
            <ul class="space-y-3">
              <li :if={Map.get(@store, :whatsapp_number)}>
                <a
                  href={"https://wa.me/#{@store.whatsapp_number}"}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center gap-2 min-h-[44px]"
                  aria-label="WhatsApp"
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                    <path d="M12 0C5.373 0 0 5.373 0 12c0 2.625.846 5.059 2.284 7.034L.789 23.492a.5.5 0 00.613.613l4.458-1.495A11.952 11.952 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22c-2.24 0-4.31-.726-5.99-1.956l-.418-.312-2.65.888.888-2.65-.312-.418A9.935 9.935 0 012 12C2 6.477 6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z" />
                  </svg>
                  WhatsApp
                </a>
              </li>
              <li>
                <a
                  href={"/s/#{@store.slug}/contact"}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                >
                  Contact Us
                </a>
              </li>
            </ul>

            <%!-- Social Icons --%>
            <div class="flex items-center gap-3 mt-6">
              <%!-- Instagram --%>
              <.footer_social_icon
                url={Map.get(@social_links, :instagram)}
                label="Instagram"
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
                </svg>
              </.footer_social_icon>

              <%!-- Twitter / X --%>
              <.footer_social_icon
                url={Map.get(@social_links, :twitter)}
                label="Twitter"
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z" />
                </svg>
              </.footer_social_icon>

              <%!-- Facebook --%>
              <.footer_social_icon
                url={Map.get(@social_links, :facebook)}
                label="Facebook"
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
                </svg>
              </.footer_social_icon>
            </div>
          </div>
        </div>

        <%!-- Bottom bar --%>
        <div class="border-t border-gray-800 mt-12 pt-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p class="text-gray-500 text-xs">
            &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
          <p class="text-gray-600 text-[10px]">
            Powered by <span class="font-semibold" style="color: var(--theme-primary);">Emakola</span>
          </p>
        </div>
      </div>
    </footer>
    """
  end

  # ── Footer Social Icon ──

  attr :url, :string, default: nil
  attr :label, :string, required: true
  slot :inner_block, required: true

  defp footer_social_icon(assigns) do
    ~H"""
    <%= if @url do %>
      <a
        href={@url}
        class="flex items-center justify-center w-11 h-11 rounded-full text-gray-500 hover:text-white transition-colors duration-200 cursor-pointer hover:bg-white/10"
        aria-label={@label}
        target="_blank"
        rel="noopener noreferrer"
      >
        {render_slot(@inner_block)}
      </a>
    <% else %>
      <span
        class="flex items-center justify-center w-11 h-11 rounded-full text-gray-500 hover:text-white transition-colors duration-200 cursor-pointer hover:bg-white/10"
        aria-label={@label}
      >
        {render_slot(@inner_block)}
      </span>
    <% end %>
    """
  end

  # ── Image Placeholder ──

  def image_placeholder(assigns) do
    ~H"""
    <svg class="w-12 h-12 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1"
        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
      />
    </svg>
    """
  end

  # ── Helpers ──

  @doc "Extract first image URL from a product's images association."
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
