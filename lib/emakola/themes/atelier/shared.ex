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

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.DesignTokens
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
      @media (prefers-reduced-motion: reduce) {
        .atelier-hero-img { animation: none !important; opacity: 1 !important; }
        .atelier-hero-img ~ .atelier-hero-img { opacity: 0 !important; }
      }
      /* Transparent navbar (blends into hero) */
      .atelier-nav-transparent {
        background: transparent !important;
        border-bottom-color: transparent !important;
        position: absolute !important;
        transition: background 0.3s ease, border-color 0.3s ease, box-shadow 0.3s ease;
      }
      .atelier-nav-transparent .atelier-nav-brand { color: #fff !important; }
      .atelier-nav-transparent .atelier-nav-link { color: rgba(255,255,255,0.85) !important; }
      .atelier-nav-transparent .atelier-nav-link:hover { color: #fff !important; }
      .atelier-nav-transparent .atelier-nav-icon { color: #fff !important; }
      .atelier-nav-transparent .atelier-nav-search {
        background: rgba(255,255,255,0.15) !important;
        color: rgba(255,255,255,0.8) !important;
      }
      .atelier-nav-transparent .atelier-nav-search:hover { background: rgba(255,255,255,0.25) !important; }

      /* Scrolled state: back to solid */
      .atelier-nav-transparent.scrolled {
        position: sticky !important;
        background: #fff !important;
        border-bottom-color: rgb(243 244 246) !important;
        box-shadow: 0 1px 3px rgba(0,0,0,0.05);
      }
      .atelier-nav-transparent.scrolled .atelier-nav-brand { color: var(--theme-accent) !important; }
      .atelier-nav-transparent.scrolled .atelier-nav-link { color: rgb(75 85 99) !important; }
      .atelier-nav-transparent.scrolled .atelier-nav-link:hover { color: rgb(17 24 39) !important; }
      .atelier-nav-transparent.scrolled .atelier-nav-icon { color: rgb(55 65 81) !important; }
      .atelier-nav-transparent.scrolled .atelier-nav-search {
        background: rgb(243 244 246) !important;
        color: rgb(107 114 128) !important;
      }

      /* Mobile menu drawer — JS-driven via Phoenix.LiveView.JS commands
         in atelier/nav.ex (show_mobile_menu/0 and hide_mobile_menu/0).
         The old .atelier-mobile-toggle:checked sibling pattern was removed
         because LiveView's DOM diff loses native checkbox state across
         re-renders. */

      /* Accordion — toggled by `.open` class via Phoenix.LiveView.JS.toggle_class
         in atelier/product_detail.ex. Same checkbox-pattern fix as the mobile
         menu. */
      .atelier-accordion-content { max-height: 0 !important; overflow: hidden !important; opacity: 0; transition: max-height 0.3s ease, opacity 0.2s ease; }
      .atelier-accordion.open .atelier-accordion-content { max-height: 300px !important; opacity: 1; }
      .atelier-accordion.open .atelier-accordion-icon { transform: rotate(180deg); }

      /* About page layouts */
      .atelier-about-2col { display: grid; gap: 3rem; }
      .atelier-about-3col { display: grid; gap: 2rem; }
      .atelier-about-4col { display: grid; grid-template-columns: repeat(2, 1fr); gap: 1.5rem; }
      @media (min-width: 768px) {
        .atelier-about-2col { grid-template-columns: 1fr 1fr; align-items: center; }
        .atelier-about-3col { grid-template-columns: repeat(3, 1fr); gap: 3rem; }
        .atelier-about-4col { grid-template-columns: repeat(4, 1fr); gap: 2rem; }
      }

      /* PDP two-column layout */
      @media (min-width: 1024px) {
        .atelier-pdp-grid {
          display: grid;
          grid-template-columns: 7fr 5fr;
          gap: 3rem;
        }
        .atelier-pdp-grid > :nth-child(2) {
          margin-top: 0 !important;
        }
      }
    </style>
    """
  end

  # ── Navigation (delegated) ──

  defdelegate navbar(assigns), to: Emakola.Themes.Atelier.Nav
  defdelegate show_search(), to: Emakola.Themes.Atelier.Nav
  defdelegate hide_search(), to: Emakola.Themes.Atelier.Nav

  # ── Product Card ──

  @doc """
  Atelier product card with image, quick-add overlay, title, and price.
  Stitch design: image + hover quick-add button + title + price below.
  """
  attr :product, :map, required: true
  attr :store, :map, required: true
  attr :show_add_button, :boolean, default: true

  def product_card(assigns) do
    tokens = get_design_tokens(assigns)
    btn_classes = DesignTokens.button_classes(tokens[:button_style])

    assigns =
      assigns
      |> assign(:image, first_image(assigns.product))
      |> assign(:btn_classes, btn_classes)

    ~H"""
    <div class="atelier-product-card group">
      <a href={"/s/#{@store.slug}/products/#{@product.slug}"} class="block">
        <div class="relative overflow-hidden bg-gray-100 rounded-lg aspect-square mb-3">
          <.optimized_image
            :if={@image}
            src={@image}
            alt={@product.title}
            class="w-full h-full object-cover transition-transform duration-300"
          />
          <div :if={!@image} class="w-full h-full flex items-center justify-center bg-gray-100">
            <.image_placeholder />
          </div>

          <%!-- Quick View icon button (top-right, visible on hover) --%>
          <a
            href={"/s/#{@store.slug}/products/#{@product.slug}"}
            class="absolute top-2 right-2 w-8 h-8 flex items-center justify-center bg-white rounded-full shadow-md opacity-0 group-hover:opacity-100 transition-opacity duration-200 hover:bg-gray-50"
            aria-label={"View #{@product.title}"}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4 text-gray-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
              />
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
              />
            </svg>
          </a>

          <%!-- Quick Add overlay button --%>
          <div :if={@show_add_button} class="absolute bottom-3 left-3 right-3">
            <button
              class={"atelier-quick-add w-full py-3 text-xs font-semibold uppercase tracking-wider #{@btn_classes} text-white cursor-pointer transition-colors duration-200 min-h-[44px]"}
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
        <.product_card_stars
          :if={is_integer(Map.get(@product, :review_count)) && @product.review_count > 0}
          avg_rating={@product.avg_rating || 0}
          review_count={@product.review_count}
        />
        <.price_display product={@product} store={@store} />
      </a>

      <%!-- Variant indicator dots --%>
      <.variant_dots count={Map.get(@product, :variant_count)} />
    </div>
    """
  end

  defp product_card_stars(assigns) do
    assigns = assign(assigns, :rating, assigns.avg_rating || 0)

    ~H"""
    <div class="flex items-center gap-1 mb-1">
      <div class="flex items-center">
        <%= for i <- 1..5 do %>
          <svg
            class={"w-3.5 h-3.5 #{if i <= round(@rating), do: "text-amber-400", else: "text-gray-300"}"}
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
          </svg>
        <% end %>
      </div>
      <span class="text-xs text-gray-500">({@review_count})</span>
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
      <.optimized_image
        :if={@image}
        src={@image}
        alt={@product.title}
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
    product_count = Map.get(assigns.category, :product_count, nil)
    assigns = assigns |> assign(:image, image) |> assign(:product_count, product_count)

    ~H"""
    <a
      href={"/s/#{@store.slug}/category/#{@category.slug}"}
      class="atelier-category-circle flex flex-col items-center gap-2.5 flex-shrink-0 group"
    >
      <div class="atelier-cat-ring w-24 h-24 sm:w-28 sm:h-28 rounded-full overflow-hidden border-2 border-gray-200 transition-colors duration-200">
        <.optimized_image
          :if={@image}
          src={@image}
          alt={@category.name}
          priority={:low}
          class="w-full h-full object-cover transition-transform duration-300"
        />
        <div
          :if={!@image}
          class="w-full h-full flex items-center justify-center"
          style="background: linear-gradient(135deg, color-mix(in srgb, var(--theme-primary) 15%, white), color-mix(in srgb, var(--theme-primary) 30%, white));"
        >
          <span
            class="text-2xl sm:text-3xl font-black"
            style="color: var(--theme-primary);"
          >
            {String.first(@category.name)}
          </span>
        </div>
      </div>
      <div class="flex flex-col items-center gap-0.5">
        <span class="text-xs sm:text-sm font-semibold text-gray-800 text-center whitespace-nowrap">
          {@category.name}
        </span>
        <span :if={@product_count} class="text-[11px] text-gray-500">
          {@product_count} {if @product_count == 1, do: "item", else: "items"}
        </span>
      </div>
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

  # ── Variant Dots ──

  @doc """
  Small indicator dots showing the number of available variants.
  Only renders when a product has more than one variant.
  """
  attr :count, :integer, default: nil

  def variant_dots(assigns) do
    count =
      case assigns[:count] do
        n when is_integer(n) -> n
        _ -> 0
      end

    dot_count = min(count, 5)
    assigns = assign(assigns, count: count, dot_count: dot_count)

    ~H"""
    <div :if={@count > 1} class="flex items-center gap-1 mt-1">
      <span :for={_i <- 1..@dot_count} class="w-1.5 h-1.5 rounded-full bg-gray-300"></span>
      <span class="text-[10px] text-gray-400 ml-0.5">{@count} options</span>
    </div>
    """
  end

  # ── Footer (delegated) ──

  defdelegate footer(assigns), to: Emakola.Themes.Atelier.Footer

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

  # Extracts design tokens from assigns, checking @theme first, then @store.theme.
  defp get_design_tokens(assigns) do
    cond do
      assigns[:theme] && is_map(assigns.theme) ->
        Map.get(assigns.theme, :design_tokens, %{})

      assigns[:store] && is_map(assigns.store) ->
        assigns.store
        |> Map.get(:theme, %{})
        |> Map.get(:design_tokens, %{})

      true ->
        %{}
    end
  end

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
