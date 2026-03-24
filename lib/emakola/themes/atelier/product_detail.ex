defmodule Emakola.Themes.Atelier.ProductDetail do
  @moduledoc """
  Atelier theme product detail page (PDP) renderer.

  Features:
  - Image gallery with thumbnail navigation
  - Variant selectors (size, color, etc.)
  - Add to cart button with gold accent
  - Related products section
  - Editorial typography and clean layout
  """
  use Phoenix.Component

  alias Emakola.Themes.Atelier.Shared
  alias EmakolaWeb.Helpers.Currency

  @doc """
  Renders the Atelier product detail page.

  Required assigns:
  - `@store` - Store struct
  - `@theme` - Theme config map
  - `@product` - Product struct with images, variants loaded
  - `@related_products` - List of related products
  - `@categories` - List of categories for nav
  - `@cart_count` - Integer cart count
  - `@selected_variant` - Currently selected variant (or nil)
  """
  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :product, :map, required: true
  attr :related_products, :list, default: []
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0
  attr :selected_variant, :map, default: nil

  def render(assigns) do
    images = product_images(assigns.product)
    primary_image = List.first(images)

    assigns =
      assigns
      |> assign(:images, images)
      |> assign(:primary_image, primary_image)

    ~H"""
    <div class="atelier-body">
      <Shared.theme_styles theme={@theme} />
      <Shared.navbar
        store={@store}
        categories={@categories}
        cart_count={@cart_count}
        transparent={false}
      />

      <%!-- Product Detail --%>
      <div class="pt-24 sm:pt-28">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24">
          <%!-- Breadcrumb --%>
          <nav
            class="mb-8 text-xs"
            style="color: var(--theme-accent-secondary, #44403C);"
            aria-label="Breadcrumb"
          >
            <a href={"/s/#{@store.slug}"} class="hover:underline">{@store.name}</a>
            <span class="mx-2">/</span>
            <a href={"/s/#{@store.slug}/products"} class="hover:underline">Shop</a>
            <span class="mx-2">/</span>
            <span style="color: var(--theme-ink);">{@product.title}</span>
          </nav>

          <div class="lg:grid lg:grid-cols-2 lg:gap-16">
            <%!-- Image Gallery --%>
            <div>
              <%!-- Primary Image --%>
              <div class="aspect-[5/6] bg-stone-100 overflow-hidden mb-4">
                <img
                  :if={@primary_image}
                  src={@primary_image}
                  alt={@product.title}
                  class="w-full h-full object-cover"
                  id="atelier-primary-image"
                />
                <div :if={!@primary_image} class="w-full h-full flex items-center justify-center">
                  <Shared.image_placeholder />
                </div>
              </div>

              <%!-- Thumbnail Strip --%>
              <div :if={length(@images) > 1} class="grid grid-cols-4 gap-2">
                <button
                  :for={{img, idx} <- Enum.with_index(@images)}
                  class={"aspect-square bg-stone-100 overflow-hidden border-2 transition-colors " <>
                    if(idx == 0, do: "border-current", else: "border-transparent hover:border-stone-300")}
                  style={if(idx == 0, do: "border-color: var(--theme-primary);", else: "")}
                  phx-click="select_image"
                  phx-value-index={idx}
                  aria-label={"View image #{idx + 1}"}
                >
                  <img
                    src={img}
                    alt={"#{@product.title} - image #{idx + 1}"}
                    class="w-full h-full object-cover"
                    loading="lazy"
                  />
                </button>
              </div>
            </div>

            <%!-- Product Info --%>
            <div class="mt-8 lg:mt-0">
              <%!-- Title & Price --%>
              <h1
                class="atelier-serif text-3xl sm:text-4xl font-semibold mb-3 leading-tight"
                style="color: var(--theme-ink);"
              >
                {@product.title}
              </h1>

              <Shared.star_rating rating={4.5} />

              <p class="text-xl font-semibold mb-6 tabular-nums" style="color: var(--theme-ink);">
                {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
              </p>

              <%!-- Description --%>
              <p
                :if={@product.description}
                class="text-sm leading-relaxed mb-8"
                style="color: var(--theme-accent-secondary, #44403C);"
              >
                {@product.description}
              </p>

              <%!-- Variant Selectors --%>
              <.variant_selectors
                :if={has_variants?(@product)}
                product={@product}
                selected_variant={@selected_variant}
              />

              <%!-- Add to Cart --%>
              <div class="mt-8 space-y-3">
                <button
                  phx-click="add_to_cart"
                  phx-value-product-id={@product.id}
                  phx-value-variant-id={if @selected_variant, do: @selected_variant.id, else: ""}
                  class="w-full py-4 text-xs font-semibold uppercase tracking-widest transition-colors duration-300"
                  style="background: var(--theme-primary); color: var(--theme-accent);"
                >
                  Add to Cart
                </button>

                <button
                  phx-click="toggle_wishlist"
                  phx-value-product-id={@product.id}
                  class="w-full py-4 text-xs font-semibold uppercase tracking-widest border transition-colors duration-300 flex items-center justify-center gap-2"
                  style="border-color: var(--theme-ink); color: var(--theme-ink);"
                >
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                  >
                    <path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z" />
                  </svg>
                  Add to Wishlist
                </button>
              </div>

              <%!-- Product Details Accordion --%>
              <div class="mt-10 border-t" style="border-color: var(--theme-surface);">
                <.detail_row
                  title="Shipping"
                  text="Free delivery on orders over GHS 500. Standard delivery 3-5 business days."
                />
                <.detail_row title="Returns" text="Free returns within 30 days of purchase." />
              </div>
            </div>
          </div>

          <%!-- Related Products --%>
          <section :if={@related_products != []} class="mt-20 sm:mt-28">
            <h2
              class="atelier-serif text-2xl sm:text-3xl font-semibold text-center mb-10"
              style="color: var(--theme-ink);"
            >
              You May Also Like
            </h2>
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
              <Shared.product_card
                :for={product <- Enum.take(@related_products, 4)}
                product={product}
                store={@store}
              />
            </div>
          </section>
        </div>
      </div>

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Variant Selectors ──

  attr :product, :map, required: true
  attr :selected_variant, :map, default: nil

  defp variant_selectors(assigns) do
    # Group variants by option type (e.g., size, color)
    option_groups = group_variant_options(assigns.product.variants)
    assigns = assign(assigns, :option_groups, option_groups)

    ~H"""
    <div class="space-y-6">
      <div :for={{option_name, values} <- @option_groups}>
        <h3
          class="text-xs font-semibold uppercase tracking-widest mb-3"
          style="color: var(--theme-ink);"
        >
          {option_name}
        </h3>
        <div class="flex flex-wrap gap-2">
          <button
            :for={value <- values}
            phx-click="select_variant_option"
            phx-value-option={option_name}
            phx-value-value={value}
            class={"min-w-[48px] px-4 py-2.5 text-xs font-medium border transition-colors duration-200 " <>
              if(variant_selected?(value, option_name, @selected_variant),
                do: "border-current font-semibold",
                else: "border-stone-200 hover:border-stone-400"
              )}
            style={"color: " <> if(variant_selected?(value, option_name, @selected_variant), do: "var(--theme-ink)", else: "var(--theme-accent-secondary, #44403C)") <> ";"}
          >
            {value}
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ── Detail Row ──

  attr :title, :string, required: true
  attr :text, :string, required: true

  defp detail_row(assigns) do
    ~H"""
    <div class="py-4 border-b" style="border-color: var(--theme-surface);">
      <h4
        class="text-xs font-semibold uppercase tracking-widest mb-2"
        style="color: var(--theme-ink);"
      >
        {@title}
      </h4>
      <p class="text-sm leading-relaxed" style="color: var(--theme-accent-secondary, #44403C);">
        {@text}
      </p>
    </div>
    """
  end

  # ── Helpers ──

  defp product_images(product) do
    case product.images do
      images when is_list(images) and images != [] ->
        Enum.map(images, fn img ->
          cond do
            is_binary(Map.get(img, :url)) -> img.url
            is_binary(Map.get(img, :thumbnail_url)) -> img.thumbnail_url
            true -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp has_variants?(product) do
    case product.variants do
      variants when is_list(variants) and variants != [] -> true
      _ -> false
    end
  end

  defp group_variant_options(variants) when is_list(variants) do
    variants
    |> Enum.flat_map(fn variant ->
      case Map.get(variant, :options) do
        options when is_map(options) -> Map.to_list(options)
        _ -> []
      end
    end)
    |> Enum.group_by(fn {k, _v} -> k end, fn {_k, v} -> v end)
    |> Enum.map(fn {k, vs} -> {k, Enum.uniq(vs)} end)
  end

  defp group_variant_options(_), do: []

  defp variant_selected?(_value, _option_name, nil), do: false

  defp variant_selected?(value, option_name, selected_variant) do
    case Map.get(selected_variant, :options) do
      options when is_map(options) -> Map.get(options, option_name) == value
      _ -> false
    end
  end
end
