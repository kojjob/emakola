defmodule Emakola.Themes.Atelier.ProductDetail do
  @moduledoc """
  Atelier theme product detail page (PDP) renderer — Stitch design reference.

  Features:
  - Breadcrumb navigation
  - Image gallery with main image + thumbnails
  - Bold title with italic green accent
  - Star ratings with review count (only when the product has real reviews)
  - Price with strikethrough for sale items
  - Free delivery callout
  - Description card with specs
  - Add to Cart + WhatsApp purchase buttons
  - Accordion for care instructions + secure payment
  - Artisan story section
  - "Complete the Look" related products
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Atelier.Shared
  alias Emakola.Themes.Delivery
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
  - `@option_types` - List of option types for variant selection
  - `@selected_options` - Map of selected option values
  - `@quantity` - Current quantity
  - `@current_image_index` - Index of currently shown image
  """
  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :product, :map, required: true
  attr :related_products, :list, default: []
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0
  attr :selected_variant, :map, default: nil
  attr :option_types, :list, default: []
  attr :selected_options, :map, default: %{}
  attr :quantity, :integer, default: 1
  attr :current_image_index, :integer, default: 0

  def render(assigns) do
    images = product_images(assigns.product)
    current_idx = min(assigns.current_image_index, max(length(images) - 1, 0))
    primary_image = Enum.at(images, current_idx)

    assigns =
      assigns
      |> assign(:images, images)
      |> assign(:primary_image, primary_image)
      |> assign(:current_idx, current_idx)

    ~H"""
    <div class="atelier-body">
      <Shared.theme_styles theme={@theme} />
      <Shared.navbar
        store={@store}
        categories={@categories}
        cart_count={@cart_count}
      />

      <%!-- Product Detail --%>
      <div class="pt-4 sm:pt-8">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-24">
          <%!-- Breadcrumb --%>
          <nav
            class="mb-6 sm:mb-8 text-xs uppercase tracking-wider text-gray-400"
            aria-label="Breadcrumb"
          >
            <a href={store_path(@store.slug, "/")} class="hover:text-gray-900 transition-colors">
              Home
            </a>
            <span class="mx-2 text-gray-300">&rsaquo;</span>
            <a
              href={store_path(@store.slug, "/products")}
              class="hover:text-gray-900 transition-colors"
            >
              Shop
            </a>
            <span class="mx-2 text-gray-300">&rsaquo;</span>
            <span class="text-gray-900 font-semibold">{@product.title}</span>
          </nav>

          <div class="atelier-pdp-grid">
            <%!-- Image Gallery (left ~58%) --%>
            <div>
              <%!-- Main Image with navigation --%>
              <div class="relative aspect-[3/4] bg-gray-100 rounded-xl overflow-hidden mb-4 group">
                <.optimized_image
                  :if={@primary_image}
                  src={@primary_image}
                  alt={"#{@product.title} - image #{@current_idx + 1} of #{length(@images)}"}
                  priority={:high}
                  class="w-full h-full object-cover transition-opacity duration-300"
                  id="atelier-primary-image"
                />
                <div :if={!@primary_image} class="w-full h-full flex items-center justify-center">
                  <Shared.image_placeholder />
                </div>

                <%!-- Prev/Next arrows (visible on hover, always on mobile) --%>
                <div
                  :if={length(@images) > 1}
                  class="absolute inset-0 flex items-center justify-between px-3 pointer-events-none"
                >
                  <button
                    phx-click="prev_image"
                    class="pointer-events-auto w-10 h-10 sm:w-12 sm:h-12 rounded-full bg-white/80 hover:bg-white shadow-lg flex items-center justify-center text-gray-800 transition-all duration-200 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 cursor-pointer min-h-[44px]"
                    aria-label="Previous image"
                  >
                    <svg
                      width="20"
                      height="20"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                    >
                      <polyline points="15 18 9 12 15 6" />
                    </svg>
                  </button>
                  <button
                    phx-click="next_image"
                    class="pointer-events-auto w-10 h-10 sm:w-12 sm:h-12 rounded-full bg-white/80 hover:bg-white shadow-lg flex items-center justify-center text-gray-800 transition-all duration-200 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 cursor-pointer min-h-[44px]"
                    aria-label="Next image"
                  >
                    <svg
                      width="20"
                      height="20"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                    >
                      <polyline points="9 18 15 12 9 6" />
                    </svg>
                  </button>
                </div>

                <%!-- Image counter dots --%>
                <div
                  :if={length(@images) > 1}
                  class="absolute bottom-4 left-0 right-0 flex items-center justify-center gap-2"
                >
                  <button
                    :for={{_img, idx} <- Enum.with_index(@images)}
                    phx-click="select_image"
                    phx-value-index={idx}
                    class={"w-2.5 h-2.5 rounded-full transition-all duration-200 cursor-pointer " <>
                      if(idx == @current_idx, do: "bg-white scale-110 shadow", else: "bg-white/50 hover:bg-white/75")}
                    aria-label={"View image #{idx + 1}"}
                  />
                </div>
              </div>

              <%!-- Thumbnail Strip --%>
              <div :if={length(@images) > 1} class="grid grid-cols-4 sm:grid-cols-5 gap-2 sm:gap-3">
                <button
                  :for={{img, idx} <- Enum.with_index(@images)}
                  class={"aspect-square bg-gray-100 rounded-lg overflow-hidden border-2 transition-all " <>
                    if(idx == @current_idx, do: "border-green-600 ring-1 ring-green-600", else: "border-transparent hover:border-gray-300")}
                  phx-click="select_image"
                  phx-value-index={idx}
                  aria-label={"View image #{idx + 1}"}
                >
                  <.optimized_image
                    src={img}
                    alt={"#{@product.title} - image #{idx + 1}"}
                    priority={:low}
                    class="w-full h-full object-cover"
                  />
                </button>
              </div>
            </div>

            <%!-- Product Info (right ~42%) --%>
            <div class="mt-8">
              <%!-- Title --%>
              <h1 class="text-2xl sm:text-3xl font-black text-gray-900 leading-tight mb-3">
                {product_title_with_accent(@product.title)}
              </h1>

              <%!-- Rating (only when the product has real reviews) --%>
              <div
                :if={is_integer(Map.get(@product, :review_count)) && @product.review_count > 0}
                class="mb-4"
              >
                <Shared.star_rating
                  rating={rating_value(@product)}
                  review_count={@product.review_count}
                />
              </div>

              <%!-- Price --%>
              <div class="mb-4">
                <Shared.price_display product={@product} store={@store} size="lg" />
              </div>

              <%!-- Delivery callout. This used to read "Free Delivery within
                   Accra & Kumasi" on every Atelier product, for every store —
                   a promise no merchant made. It now states the store's own
                   delivery zones, and says nothing when it has configured
                   none. --%>
              <p
                :if={delivery_callout(assigns)}
                class="text-sm font-medium mb-6 flex items-center gap-2"
                style="color: var(--theme-accent);"
              >
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  aria-hidden="true"
                >
                  <path d="M1 3h15v13H1z" /><path d="M16 8h4l3 3v5h-7V8z" /><circle
                    cx="5.5"
                    cy="18.5"
                    r="2.5"
                  /><circle cx="18.5" cy="18.5" r="2.5" />
                </svg>
                {delivery_callout(assigns)}
              </p>

              <%!-- Description Card --%>
              <div :if={@product.description} class="bg-gray-50 rounded-xl p-5 sm:p-6 mb-6">
                <p class="text-sm text-gray-700 leading-relaxed mb-4">
                  {@product.description}
                </p>
                <%!-- Spec boxes --%>
                <div class="grid grid-cols-2 gap-3">
                  <div class="bg-white rounded-lg p-3 border border-gray-100">
                    <span class="block text-[10px] font-semibold uppercase tracking-widest text-gray-400 mb-1">
                      Dimensions
                    </span>
                    <span class="text-sm font-mono text-gray-800">
                      {product_spec(@product, :dimensions, "One Size")}
                    </span>
                  </div>
                  <div class="bg-white rounded-lg p-3 border border-gray-100">
                    <span class="block text-[10px] font-semibold uppercase tracking-widest text-gray-400 mb-1">
                      Material
                    </span>
                    <span class="text-sm font-mono text-gray-800">
                      {product_spec(@product, :material, "Handcrafted")}
                    </span>
                  </div>
                </div>
              </div>

              <%!-- Variant Selectors --%>
              <.variant_selectors
                :if={@option_types != []}
                option_types={@option_types}
                selected_options={@selected_options}
              />

              <%!-- Quantity Stepper --%>
              <div class="mb-6">
                <label class="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">
                  Quantity
                </label>
                <div class="inline-flex items-center border border-gray-200 rounded-lg overflow-hidden">
                  <button
                    phx-click="decrement_quantity"
                    class="w-11 h-11 flex items-center justify-center text-gray-600 hover:bg-gray-100 transition-colors"
                    aria-label="Decrease quantity"
                  >
                    <svg
                      width="16"
                      height="16"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <line x1="5" y1="12" x2="19" y2="12" />
                    </svg>
                  </button>
                  <span class="w-12 text-center text-sm font-semibold text-gray-900 tabular-nums">
                    {@quantity}
                  </span>
                  <button
                    phx-click="increment_quantity"
                    class="w-11 h-11 flex items-center justify-center text-gray-600 hover:bg-gray-100 transition-colors"
                    aria-label="Increase quantity"
                  >
                    <svg
                      width="16"
                      height="16"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
                    </svg>
                  </button>
                </div>
              </div>

              <%!-- Add to Cart --%>
              <div class="space-y-3 mb-8">
                <button
                  phx-click="add_to_cart"
                  phx-value-product-id={@product.id}
                  phx-value-variant-id={if @selected_variant, do: @selected_variant.id, else: ""}
                  class="w-full py-4 text-sm font-bold uppercase tracking-wider rounded-lg text-white transition-all duration-300 hover:opacity-90 min-h-[48px]"
                  style="background: var(--theme-accent, #166534);"
                >
                  ADD TO CART
                </button>

                <%!-- WhatsApp Purchase --%>
                <a
                  :if={Map.get(@store, :whatsapp_number)}
                  href={"https://wa.me/#{@store.whatsapp_number}?text=#{URI.encode("Hi! I'm interested in #{@product.title} (#{Currency.format_price(@product.min_price || 0, @store.currency)}). Is it available?")}"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="w-full py-4 text-sm font-bold uppercase tracking-wider rounded-lg border-2 border-green-600 text-green-700 hover:bg-green-50 transition-colors flex items-center justify-center gap-2 min-h-[48px]"
                >
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                    <path d="M12 0C5.373 0 0 5.373 0 12c0 2.625.846 5.059 2.284 7.034L.789 23.492a.5.5 0 00.613.613l4.458-1.495A11.952 11.952 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22c-2.24 0-4.31-.726-5.99-1.956l-.418-.312-2.65.888.888-2.65-.312-.418A9.935 9.935 0 012 12C2 6.477 6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z" />
                  </svg>
                  Purchase via WhatsApp
                </a>
              </div>

              <%!-- Accordion Sections --%>
              <div class="border-t border-gray-200">
                <.accordion_section title="CARE INSTRUCTIONS">
                  <p class="text-sm text-gray-600 leading-relaxed">
                    Handle with care. Clean with a soft dry cloth. Store in a cool, dry place away from direct sunlight. Avoid contact with water and chemicals.
                  </p>
                </.accordion_section>

                <.accordion_section title="SECURE PAYMENT">
                  <p class="text-sm text-gray-600 leading-relaxed">
                    All transactions are encrypted and secure. We accept MTN Mobile Money, Telecel Cash, Visa, and Mastercard. Your payment information is never stored on our servers.
                  </p>
                </.accordion_section>

                <.accordion_section title="SHIPPING &amp; RETURNS">
                  <p class="text-sm text-gray-600 leading-relaxed">
                    See our
                    <a
                      href={store_path(@store.slug, "/policies")}
                      class="underline hover:text-gray-900"
                    >
                      shipping and returns policy
                    </a>
                    for details.
                  </p>
                </.accordion_section>
              </div>
            </div>
          </div>

          <%!-- Artisan Story Section --%>
          <.artisan_story_section store={@store} />

          <%!-- Related Products: "Complete the Look" --%>
          <section :if={@related_products != []} class="mt-16 sm:mt-24">
            <h2 class="text-2xl sm:text-3xl font-black text-gray-900 mb-8">
              Complete the Look
            </h2>
            <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6">
              <Shared.product_card
                :for={product <- Enum.take(@related_products, 4)}
                product={product}
                store={@store}
              />
            </div>
          </section>
        </div>
      </div>

      <%!-- Customer Reviews --%>
      <EmakolaWeb.ReviewComponents.review_section
        store={@store}
        product={@product}
        reviews={@reviews}
        can_review={@can_review}
        already_reviewed={@already_reviewed}
        review_form_rating={@review_form_rating}
        review_form_title={@review_form_title}
        review_form_body={@review_form_body}
        review_submitting={@review_submitting}
        avg_rating={@product.avg_rating}
        review_count={@product.review_count}
        uploads={@uploads}
      />

      <Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Variant Selectors ──

  attr :option_types, :list, required: true
  attr :selected_options, :map, default: %{}

  defp variant_selectors(assigns) do
    ~H"""
    <div class="space-y-5 mb-6">
      <div :for={option_type <- @option_types}>
        <label class="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-2">
          {option_type.name}
        </label>
        <div class="flex flex-wrap gap-2">
          <button
            :for={option_value <- option_type.option_values || []}
            phx-click="select_option"
            phx-value-option_type_id={option_type.id}
            phx-value-value={option_value.id}
            class={"min-w-[48px] min-h-[44px] px-4 py-2.5 text-sm font-medium rounded-lg border-2 transition-all duration-200 " <>
              if(Map.get(@selected_options, option_type.id) == option_value.id,
                do: "border-green-600 bg-green-50 text-green-800 font-semibold",
                else: "border-gray-200 text-gray-700 hover:border-gray-400"
              )}
          >
            {option_value.value}
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ── Accordion Section ──

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp accordion_section(assigns) do
    accordion_id =
      "accordion-#{String.downcase(String.replace(assigns.title, ~r/[^a-zA-Z0-9]/, "-"))}"

    assigns = assign(assigns, :accordion_id, accordion_id)

    ~H"""
    <div id={@accordion_id} class="atelier-accordion border-b border-gray-200">
      <button
        type="button"
        phx-click={Phoenix.LiveView.JS.toggle_class("open", to: "##{@accordion_id}")}
        aria-controls={@accordion_id <> "-content"}
        class="atelier-accordion-header w-full flex items-center justify-between py-4 cursor-pointer group text-left"
      >
        <span class="text-xs font-bold uppercase tracking-widest text-gray-900">
          {@title}
        </span>
        <span class="atelier-accordion-icon text-gray-400 transition-transform duration-300">
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
          >
            <polyline points="6 9 12 15 18 9" />
          </svg>
        </span>
      </button>
      <div id={@accordion_id <> "-content"} class="atelier-accordion-content pb-4">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ── Artisan Story Section ──

  attr :store, :map, required: true

  defp artisan_story_section(assigns) do
    ~H"""
    <section class="mt-16 sm:mt-24 py-12 sm:py-16 bg-gray-50 -mx-4 sm:-mx-6 lg:-mx-8 px-4 sm:px-6 lg:px-8 rounded-2xl">
      <div class="max-w-6xl mx-auto">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-10 lg:gap-16 items-center">
          <%!-- Text side --%>
          <div>
            <span
              class="text-xs font-semibold uppercase tracking-widest mb-3 block"
              style="color: var(--theme-primary);"
            >
              The Artisan's Signature
            </span>
            <h2 class="text-2xl sm:text-3xl font-black text-gray-900 mb-4">
              {@store.name}
            </h2>
            <blockquote
              class="text-gray-600 italic text-base leading-relaxed mb-4 border-l-4 pl-4"
              style="border-color: var(--theme-primary);"
            >
              "Every piece tells a story of heritage, craftsmanship, and the human hands that shaped it."
            </blockquote>
            <p class="text-gray-600 text-sm leading-relaxed mb-6">
              {if @store.description,
                do: @store.description,
                else:
                  "Dedicated to preserving West African craft traditions while creating contemporary pieces for the modern world."}
            </p>
            <a
              href={store_path(@store.slug, "/about")}
              class="inline-flex items-center gap-2 text-sm font-bold transition-colors hover:opacity-80 min-h-[44px]"
              style="color: var(--theme-primary);"
            >
              Read Their Story
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              >
                <path d="M5 12h14M12 5l7 7-7 7" />
              </svg>
            </a>
          </div>

          <%!-- Image side --%>
          <div class="rounded-xl overflow-hidden bg-gray-200 aspect-[4/5]">
            <div class="w-full h-full flex items-center justify-center">
              <span class="text-6xl font-black text-gray-300">{String.first(@store.name)}</span>
            </div>
          </div>
        </div>
      </div>
    </section>
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

  defp rating_value(product) do
    case Map.get(product, :avg_rating) do
      %Decimal{} = r -> Decimal.to_float(r)
      r when is_number(r) -> r * 1.0
      _ -> 0.0
    end
  end

  defp product_spec(product, key, fallback) do
    metadata = Map.get(product, :metadata) || %{}

    cond do
      is_map(metadata) && Map.has_key?(metadata, key) ->
        Map.get(metadata, key)

      is_map(metadata) && Map.has_key?(metadata, Atom.to_string(key)) ->
        Map.get(metadata, Atom.to_string(key))

      true ->
        fallback
    end
  end

  defp product_title_with_accent(title) when is_binary(title) do
    words = String.split(title)

    if length(words) > 1 do
      {main_words, accent_words} = Enum.split(words, length(words) - 1)
      main = Enum.join(main_words, " ")
      accent = Enum.join(accent_words, " ")

      Phoenix.HTML.raw(
        "#{Phoenix.HTML.html_escape(main) |> Phoenix.HTML.safe_to_string()} " <>
          "<span class=\"italic\" style=\"color: var(--theme-accent);\">" <>
          "#{Phoenix.HTML.html_escape(accent) |> Phoenix.HTML.safe_to_string()}</span>"
      )
    else
      title
    end
  end

  defp product_title_with_accent(title), do: title

  defp delivery_callout(assigns), do: Delivery.callout(assigns)
end
