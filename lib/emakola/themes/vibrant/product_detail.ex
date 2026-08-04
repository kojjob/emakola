defmodule Emakola.Themes.Vibrant.ProductDetail do
  @moduledoc """
  Vibrant theme product detail page (PDP).

  Features:
  - Image gallery with rounded corners and warm background
  - Bold variant selectors as colorful pills
  - Prominent add-to-cart button in the theme's amber primary
  - WhatsApp inquiry button
  - Accordion details with warm styling
  - Related products horizontal scroll
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Vibrant.Shared
  alias EmakolaWeb.Helpers.Currency

  @doc """
  Renders the Vibrant theme product detail page.

  Expects assigns:
  - `@store` — store map
  - `@product` — product with `.title`, `.slug`, `.description`, `.images`, `.variants`
  - `@selected_variant` — currently selected variant
  - `@selected_options` — map of option_type_id => option_value_id
  - `@option_types` — list of option types with `.option_values`
  - `@quantity` — current quantity
  - `@current_image_index` — index of displayed image
  - `@related_products` — list of related products
  - `@theme` — theme config map
  """
  attr :store, :map, required: true
  attr :product, :map, required: true
  attr :selected_variant, :map, default: nil
  attr :selected_options, :map, default: %{}
  attr :option_types, :list, default: []
  attr :quantity, :integer, default: 1
  attr :current_image_index, :integer, default: 0
  attr :related_products, :list, default: []
  attr :categories, :list, default: []
  attr :theme, :map, required: true
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FFFBEB]">
      <Shared.vibrant_nav store={@store} cart_count={@cart_count} />
      <div class="max-w-[1280px] mx-auto lg:grid lg:grid-cols-2 lg:gap-10 lg:px-8 lg:py-8">
        <%!-- Image Gallery (rounded corners, warm bg) --%>
        <section
          class="bg-white lg:rounded-3xl lg:overflow-hidden lg:shadow-md lg:shadow-amber-100"
          aria-label="Product images"
        >
          <div class="w-full aspect-[4/5] lg:aspect-square overflow-hidden bg-store-accent-light/30">
            <%= if current_image(@product, @current_image_index) do %>
              <.optimized_image
                src={current_image(@product, @current_image_index)}
                alt={"#{@product.title} — image #{@current_image_index + 1}"}
                priority={:high}
                class="w-full h-full object-cover"
              />
            <% else %>
              <div class="w-full h-full flex items-center justify-center">
                <svg
                  class="w-16 h-16 text-[#D97706]"
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
            <% end %>
          </div>
          <%!-- Dot indicators with warm accent --%>
          <div
            :if={length(@product.images) > 1}
            class="flex items-center justify-center gap-2.5 py-4 px-4"
            role="tablist"
            aria-label="Product image thumbnails"
          >
            <button
              :for={{_img, idx} <- Enum.with_index(@product.images)}
              phx-click="select_image"
              phx-value-index={idx}
              role="tab"
              aria-selected={idx == @current_image_index}
              aria-label={"Image #{idx + 1}"}
              class={[
                "h-2.5 rounded-full border-none transition-all cursor-pointer",
                if(idx == @current_image_index,
                  do: "w-8 bg-[var(--theme-primary,#B45309)]",
                  else: "w-2.5 bg-[#FDE68A] hover:bg-[#F59E0B]"
                )
              ]}
            />
          </div>
        </section>

        <%!-- Product Info Panel --%>
        <div class="lg:py-4">
          <%!-- Product Info --%>
          <section class="px-4 lg:px-0 py-6 bg-[#FFFBEB]">
            <span
              :if={new_arrival?(@product)}
              class="inline-block bg-[#FEF3C7] text-[var(--theme-primary,#B45309)] text-[0.6875rem] font-bold tracking-wider uppercase px-3 py-1.5 rounded-full mb-3"
            >
              New Arrival
            </span>
            <h1
              class="text-3xl font-bold text-cta-dark leading-tight mb-2"
              style="font-family: 'Manrope', sans-serif;"
            >
              {@product.title}
            </h1>
            <p class="text-2xl font-bold text-[var(--theme-primary,#B45309)] mb-3">
              <%= if @selected_variant do %>
                {Currency.format_price(@selected_variant.price, @store.currency)}
              <% else %>
                {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
              <% end %>
            </p>
            <%!-- Stock status --%>
            <div class="mb-4">
              <.stock_badge variant={@selected_variant} />
            </div>
            <p
              :if={@product.description}
              class="text-base text-[#78350F] leading-relaxed"
              style="font-family: 'Inter', sans-serif;"
            >
              {@product.description}
            </p>
          </section>

          <%!-- Variant Selectors (Bold Pills) --%>
          <section
            :if={@option_types != []}
            class="px-4 lg:px-0 py-5 space-y-5"
            aria-label="Product options"
          >
            <div :for={ot <- @option_types}>
              <div
                class="text-sm font-bold text-cta-dark mb-3"
                style="font-family: 'Inter', sans-serif;"
              >
                {ot.name}
              </div>
              <div class="flex gap-2.5 flex-wrap" role="radiogroup" aria-label={"Select #{ot.name}"}>
                <button
                  :for={ov <- ot.option_values}
                  phx-click="select_option"
                  phx-value-option_type_id={ot.id}
                  phx-value-option_value_id={ov.id}
                  role="radio"
                  aria-checked={Map.get(@selected_options, ot.id) == ov.id}
                  class={[
                    "min-w-[52px] h-12 px-5 rounded-full text-sm font-bold flex items-center justify-center transition-all cursor-pointer",
                    if(Map.get(@selected_options, ot.id) == ov.id,
                      do:
                        "bg-[var(--theme-primary,#B45309)] text-white border-2 border-[var(--theme-primary,#B45309)] shadow-md shadow-amber-200/60",
                      else:
                        "bg-white text-[#78350F] border-2 border-[#FDE68A] hover:border-[var(--theme-primary,#B45309)] hover:text-[var(--theme-primary,#B45309)]"
                    )
                  ]}
                >
                  {ov.value}
                </button>
              </div>
            </div>
          </section>

          <%!-- Quantity + Add to Bag --%>
          <section class="px-4 lg:px-0 py-5 space-y-4" aria-label="Add to bag">
            <%!-- Quantity stepper --%>
            <div class="flex items-center border-2 border-[#FDE68A] rounded-full w-fit overflow-hidden bg-white">
              <button
                phx-click="decrement_quantity"
                disabled={@quantity <= 1}
                class="w-12 h-12 flex items-center justify-center text-[#78350F] hover:bg-store-accent-light transition-colors disabled:text-[#FDE68A] disabled:cursor-not-allowed"
                aria-label="Decrease quantity"
              >
                <svg
                  class="w-5 h-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2.5"
                  stroke-linecap="round"
                >
                  <path d="M4 9h10" />
                </svg>
              </button>
              <div
                class="w-14 h-12 flex items-center justify-center text-base font-bold text-cta-dark border-x-2 border-[#FDE68A] select-none"
                style="font-family: 'Inter', sans-serif;"
              >
                {@quantity}
              </div>
              <button
                phx-click="increment_quantity"
                disabled={@quantity >= 10}
                class="w-12 h-12 flex items-center justify-center text-[#78350F] hover:bg-store-accent-light transition-colors disabled:text-[#FDE68A] disabled:cursor-not-allowed"
                aria-label="Increase quantity"
              >
                <svg
                  class="w-5 h-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2.5"
                  stroke-linecap="round"
                >
                  <path d="M9 4v10M4 9h10" />
                </svg>
              </button>
            </div>

            <%!-- Add to Bag CTA --%>
            <%!-- Built from the store's own delivery zones; renders nothing when it
                 has configured none. Never a theme default — a hardcoded "free
                 delivery in Accra" would be a promise the merchant never made. --%>
            <p
              :if={Emakola.Themes.Delivery.callout(assigns)}
              class="mb-3 flex items-center gap-2 text-sm font-medium"
            >
              <span
                aria-hidden="true"
                class="inline-block h-1.5 w-1.5 rounded-full bg-current opacity-60"
              />
              {Emakola.Themes.Delivery.callout(assigns)}
            </p>
            <button
              phx-click="add_to_cart"
              disabled={
                is_nil(@selected_variant) || not Emakola.Catalog.Variant.in_stock?(@selected_variant)
              }
              class={[
                "w-full h-14 rounded-full text-base font-bold flex items-center justify-center gap-2.5 transition-all",
                if(
                  is_nil(@selected_variant) ||
                    not Emakola.Catalog.Variant.in_stock?(@selected_variant),
                  do: "bg-[#FDE68A]/50 text-[#D97706]/50 cursor-not-allowed",
                  else:
                    "bg-[var(--theme-primary,#B45309)] text-white hover:bg-[#B91C1C] active:scale-[0.97] cursor-pointer shadow-lg shadow-amber-200/60"
                )
              ]}
              style="font-family: 'Inter', sans-serif;"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="2"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
                />
              </svg>
              <%= if is_nil(@selected_variant) || not Emakola.Catalog.Variant.in_stock?(@selected_variant) do %>
                Out of Stock
              <% else %>
                Add to Bag
              <% end %>
            </button>

            <%!-- WhatsApp Ask --%>
            <a
              href={"https://wa.me/?text=Hi%2C%20I'm%20interested%20in%20#{URI.encode(@product.title)}%20from%20#{URI.encode(@store.name)}"}
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center justify-center gap-2.5 w-full h-12 border-2 border-whatsapp rounded-full text-base font-semibold text-whatsapp hover:bg-whatsapp/5 transition-all"
              style="font-family: 'Inter', sans-serif;"
            >
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
              </svg>
              Ask on WhatsApp
            </a>

            <%!-- Share Strip — fires share-product event for atomic count tracking --%>
            <EmakolaWeb.StorefrontComponents.share_strip
              url={@canonical_url || "/s/#{@store.slug}/products/#{@product.slug}"}
              title={@product.title}
              on_share="share-product"
              share_value={@product.id}
              class="pt-2"
            />

            <%!-- SKU --%>
            <p
              :if={@selected_variant && @selected_variant.sku}
              class="text-center text-xs text-[#D97706]/60 pt-1"
              style="font-family: 'Inter', sans-serif;"
            >
              SKU: {@selected_variant.sku}
            </p>
          </section>

          <%!-- Accordion Sections --%>
          <div class="px-4 lg:px-0">
            <details class="bg-white rounded-2xl border border-[#FDE68A]/60 mb-3 overflow-hidden">
              <summary
                class="px-5 py-4 text-base font-bold text-cta-dark cursor-pointer flex items-center justify-between hover:bg-store-accent-light/30 select-none list-none [&::-webkit-details-marker]:hidden"
                style="font-family: 'Inter', sans-serif;"
              >
                <span>Product Details</span>
                <svg
                  class="w-5 h-5 text-[#D97706] transition-transform [[open]>&]:rotate-180"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="2"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                  />
                </svg>
              </summary>
              <div
                class="px-5 pb-5 text-sm text-[#78350F] leading-relaxed"
                style="font-family: 'Inter', sans-serif;"
              >
                <p :if={@product.description}>{@product.description}</p>
                <p :if={!@product.description}>No additional details available.</p>
              </div>
            </details>
            <details class="bg-white rounded-2xl border border-[#FDE68A]/60 mb-3 overflow-hidden">
              <summary
                class="px-5 py-4 text-base font-bold text-cta-dark cursor-pointer flex items-center justify-between hover:bg-store-accent-light/30 select-none list-none [&::-webkit-details-marker]:hidden"
                style="font-family: 'Inter', sans-serif;"
              >
                <span>Shipping & Delivery</span>
                <svg
                  class="w-5 h-5 text-[#D97706] transition-transform [[open]>&]:rotate-180"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="2"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                  />
                </svg>
              </summary>
              <div
                class="px-5 pb-5 text-sm text-[#78350F] leading-relaxed"
                style="font-family: 'Inter', sans-serif;"
              >
                <p>
                  See our
                  <a
                    href={store_path(@store.slug, "/policies")}
                    class="underline hover:text-cta-dark transition-colors"
                  >
                    delivery information
                  </a>
                  on the policies page.
                </p>
              </div>
            </details>
            <details class="bg-white rounded-2xl border border-[#FDE68A]/60 mb-3 overflow-hidden">
              <summary
                class="px-5 py-4 text-base font-bold text-cta-dark cursor-pointer flex items-center justify-between hover:bg-store-accent-light/30 select-none list-none [&::-webkit-details-marker]:hidden"
                style="font-family: 'Inter', sans-serif;"
              >
                <span>Returns & Exchange</span>
                <svg
                  class="w-5 h-5 text-[#D97706] transition-transform [[open]>&]:rotate-180"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="2"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                  />
                </svg>
              </summary>
              <div
                class="px-5 pb-5 text-sm text-[#78350F] leading-relaxed"
                style="font-family: 'Inter', sans-serif;"
              >
                <p>
                  See our
                  <a
                    href={store_path(@store.slug, "/policies")}
                    class="underline hover:text-cta-dark transition-colors"
                  >
                    returns policy
                  </a>
                  on the policies page.
                </p>
              </div>
            </details>
          </div>
        </div>
      </div>

      <%!-- Related Products Scroll --%>
      <section :if={@related_products != []} class="py-8 bg-[#FFFBEB]">
        <div class="max-w-[1280px] mx-auto">
          <h2
            class="text-xl font-bold text-cta-dark px-4 sm:px-6 lg:px-8 mb-5"
            style="font-family: 'Manrope', sans-serif;"
          >
            You May Also Like
          </h2>
          <div class="flex gap-4 overflow-x-auto px-4 sm:px-6 lg:px-8 pb-2 snap-x snap-mandatory [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            <a
              :for={rp <- @related_products}
              href={store_path(@store.slug, "/products/#{rp.slug}")}
              class="flex-[0_0_160px] snap-start group"
            >
              <div class="rounded-2xl overflow-hidden bg-store-accent-light/30 shadow-md shadow-amber-100 group-hover:shadow-xl group-hover:shadow-amber-200/60 transition-all duration-300 mb-2.5">
                <div class="w-full aspect-square overflow-hidden">
                  <%= if Shared.first_image(rp) do %>
                    <.optimized_image
                      src={Shared.first_image(rp)}
                      alt={rp.title}
                      class="w-full h-full object-cover group-hover:scale-[1.06] transition-transform duration-500"
                    />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center bg-store-accent-light">
                      <svg
                        class="w-10 h-10 text-[#D97706]"
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
                  <% end %>
                </div>
              </div>
              <p class="text-sm font-semibold text-cta-dark leading-tight mb-1 truncate">
                {rp.title}
              </p>
              <p class="text-sm font-bold text-[var(--theme-primary,#B45309)]">
                {Currency.format_price_range(rp.min_price, rp.max_price, @store.currency)}
              </p>
            </a>
          </div>
        </div>
      </section>

      <%!-- Customer Reviews --%>
      <EmakolaWeb.ReviewComponents.review_section
        store={@store}
        product={@product}
        reviews={@reviews}
        can_review={@can_review}
        already_reviewed={@already_reviewed}
        review_form={assigns[:review_form]}
        review_form_rating={@review_form_rating}
        review_form_title={@review_form_title}
        review_form_body={@review_form_body}
        review_submitting={@review_submitting}
        avg_rating={@product.avg_rating}
        review_count={@product.review_count}
        uploads={@uploads}
      />

      <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
    </div>
    """
  end

  # ── Components ──

  defp stock_badge(assigns) do
    ~H"""
    <%= cond do %>
      <% is_nil(@variant) -> %>
        <span class="text-sm text-[#D97706]" style="font-family: 'Inter', sans-serif;">
          Select options
        </span>
      <% @variant.track_inventory and @variant.stock_quantity <= 0 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-bold text-[var(--theme-primary,#B45309)]">
          <span class="w-2 h-2 rounded-full bg-[var(--theme-primary,#B45309)]"></span> Out of Stock
        </span>
      <% @variant.track_inventory and @variant.stock_quantity < 5 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-bold text-[#D97706]">
          <span class="w-2 h-2 rounded-full bg-[#D97706]"></span>
          Low Stock ({@variant.stock_quantity} left)
        </span>
      <% true -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-bold text-[#059669]">
          <span class="w-2 h-2 rounded-full bg-[#059669]"></span> In Stock
        </span>
    <% end %>
    """
  end

  # ── Helpers ──

  defp current_image(product, index) do
    case Enum.at(product.images, index) do
      %{medium_url: url} when is_binary(url) -> url
      %{url: url} when is_binary(url) -> url
      _ -> Shared.first_image(product)
    end
  end

  @new_arrival_window_seconds 14 * 24 * 60 * 60

  defp new_arrival?(product) do
    case Map.get(product, :inserted_at) do
      %DateTime{} = dt ->
        DateTime.diff(DateTime.utc_now(), dt) <= @new_arrival_window_seconds

      %NaiveDateTime{} = dt ->
        NaiveDateTime.diff(NaiveDateTime.utc_now(), dt) <= @new_arrival_window_seconds

      _ ->
        false
    end
  end
end
