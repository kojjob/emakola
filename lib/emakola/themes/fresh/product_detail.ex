defmodule Emakola.Themes.Fresh.ProductDetail do
  @moduledoc """
  Fresh theme product detail page (PDP).

  Features:
  - Breadcrumb with green text links
  - Two-column layout: large rounded image gallery, product info
  - Nunito headings, green price
  - Fresh/Organic/Local badges based on product tags
  - Rounded pill variant selectors with green active state
  - Quantity stepper with green buttons
  - Add to Cart (green, rounded-2xl, full-width)
  - WhatsApp order button
  - Delivery info card
  - Related products horizontal scroll
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Fresh.Shared
  alias Emakola.Themes.Terms
  alias EmakolaWeb.Helpers.Currency

  @doc """
  Renders the Fresh theme product detail page.

  Expects assigns:
  - `@store` — store map
  - `@product` — product with `.title`, `.slug`, `.description`, `.images`, `.variants`
  - `@selected_variant` — currently selected variant
  - `@selected_options` — map of option_type_id => option_value_id
  - `@option_types` — list of option types with `.option_values`
  - `@quantity` — current quantity
  - `@current_image_index` — index of displayed image
  - `@related_products` — list of related products
  - `@categories` — list of categories
  - `@theme` — theme config map
  - `@cart_count` — number of items in cart
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
    <div class="min-h-screen bg-[#FEFCE8]">
      <Shared.fresh_nav store={@store} cart_count={@cart_count} />
      <%!-- Breadcrumb --%>
      <nav
        aria-label="Breadcrumb"
        class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-4"
      >
        <ol class="flex items-center gap-2 text-xs text-[#78350F]/60">
          <li>
            <a href={store_path(@store.slug, "/")} class="hover:text-[#059669] transition-colors">
              Home
            </a>
          </li>
          <li>
            <svg
              class="w-3 h-3 inline"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="m9 5 7 7-7 7" />
            </svg>
          </li>
          <li>
            <a
              href={store_path(@store.slug, "/products")}
              class="hover:text-[#059669] transition-colors"
            >
              Products
            </a>
          </li>
          <li>
            <svg
              class="w-3 h-3 inline"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="m9 5 7 7-7 7" />
            </svg>
          </li>
          <li class="text-cta-dark font-medium truncate max-w-[200px]">{@product.title}</li>
        </ol>
      </nav>

      <div class="max-w-[1280px] mx-auto lg:grid lg:grid-cols-2 lg:gap-10 lg:px-8 lg:pb-8">
        <%!-- Image Gallery --%>
        <section
          class="bg-white lg:rounded-3xl lg:overflow-hidden lg:shadow-md lg:shadow-emerald-50"
          aria-label="Product images"
        >
          <div class="w-full aspect-[4/5] lg:aspect-square overflow-hidden bg-[#ECFDF5]/30">
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
                  class="w-16 h-16 text-[#059669]/30"
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
          <%!-- Dot indicators --%>
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
                  do: "w-8 bg-[#059669]",
                  else: "w-2.5 bg-[#D9F99D] hover:bg-[#A3E635]"
                )
              ]}
            />
          </div>
        </section>

        <%!-- Product Info Panel --%>
        <div class="lg:py-4">
          <section class="px-4 lg:px-0 py-6 bg-[#FEFCE8]">
            <%!-- Fresh / Organic / Local badges --%>
            <div class="flex flex-wrap gap-2 mb-3">
              <span
                :for={tag <- fresh_tags(@product)}
                class="inline-flex items-center gap-1 px-3 py-1.5 text-[0.6875rem] font-bold tracking-wider uppercase bg-[#ECFDF5] text-[#059669] rounded-full"
              >
                <span
                  class="material-symbols-outlined"
                  style="font-size: 12px;"
                >
                  eco
                </span>
                {tag}
              </span>
            </div>

            <h1
              class="text-3xl font-bold text-cta-dark leading-tight mb-2"
              style="font-family: 'Nunito', sans-serif;"
            >
              {@product.title}
            </h1>
            <p class="text-2xl font-bold text-[var(--theme-primary,#047857)] mb-3">
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

          <%!-- Variant Selectors (Rounded Pills) --%>
          <section
            :if={@option_types != []}
            class="px-4 lg:px-0 py-5 space-y-5"
            aria-label="Product options"
          >
            <div :for={ot <- @option_types}>
              <div
                class="text-sm font-bold text-cta-dark mb-3"
                style="font-family: 'Nunito', sans-serif;"
              >
                {ot.name}
              </div>
              <div class="flex gap-2.5 flex-wrap" role="radiogroup" aria-label={"Select #{ot.name}"}>
                <button
                  :for={ov <- ot.option_values}
                  phx-click="select_option"
                  phx-value-option_type_id={ot.id}
                  phx-value-value={ov.id}
                  role="radio"
                  aria-checked={Map.get(@selected_options, ot.id) == ov.id}
                  class={[
                    "min-w-[52px] h-12 px-5 rounded-full text-sm font-bold flex items-center justify-center transition-all cursor-pointer",
                    if(Map.get(@selected_options, ot.id) == ov.id,
                      do:
                        "bg-[#059669] text-white border-2 border-[#059669] shadow-md shadow-emerald-200",
                      else:
                        "bg-white text-[#78350F] border-2 border-[#D9F99D] hover:border-[#059669] hover:text-[#059669]"
                    )
                  ]}
                >
                  {ov.value}
                </button>
              </div>
            </div>
          </section>

          <%!-- Quantity + Add to Cart --%>
          <section class="px-4 lg:px-0 py-5 space-y-4" aria-label="Add to cart">
            <%!-- Quantity stepper --%>
            <div class="flex items-center border-2 border-[#D9F99D] rounded-full w-fit overflow-hidden bg-white">
              <button
                phx-click="decrement_quantity"
                disabled={@quantity <= 1}
                class="w-12 h-12 flex items-center justify-center text-[#78350F] hover:bg-[#ECFDF5] transition-colors disabled:text-[#D9F99D] disabled:cursor-not-allowed"
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
                class="w-14 h-12 flex items-center justify-center text-base font-bold text-cta-dark border-x-2 border-[#D9F99D] select-none"
                style="font-family: 'Inter', sans-serif;"
              >
                {@quantity}
              </div>
              <button
                phx-click="increment_quantity"
                disabled={@quantity >= 10}
                class="w-12 h-12 flex items-center justify-center text-[#78350F] hover:bg-[#ECFDF5] transition-colors disabled:text-[#D9F99D] disabled:cursor-not-allowed"
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

            <%!-- Add to Cart CTA --%>
            <button
              phx-click="add_to_cart"
              disabled={
                is_nil(@selected_variant) ||
                  not Emakola.Catalog.Variant.in_stock?(@selected_variant)
              }
              class={[
                "w-full h-14 rounded-2xl text-base font-bold flex items-center justify-center gap-2.5 transition-all",
                if(
                  is_nil(@selected_variant) ||
                    not Emakola.Catalog.Variant.in_stock?(@selected_variant),
                  do: "bg-[#D9F99D]/50 text-[#059669]/40 cursor-not-allowed",
                  else:
                    "bg-[var(--theme-primary,#047857)] text-white hover:opacity-90 active:scale-[0.97] cursor-pointer shadow-lg shadow-emerald-200"
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
                  d="M2.25 3h1.386c.51 0 .955.343 1.087.835l.383 1.437M7.5 14.25a3 3 0 00-3 3h15.75m-12.75-3h11.218c1.121 0 2.002-.881 2.002-2.003V6.75m-14.22 0h14.22m-14.22 0L5.106 5.272M7.5 14.25L5.106 5.272m0 0a1.125 1.125 0 00-1.091-.852H2.25"
                />
              </svg>
              <%= if is_nil(@selected_variant) || not Emakola.Catalog.Variant.in_stock?(@selected_variant) do %>
                Out of Stock
              <% else %>
                Add to Cart
              <% end %>
            </button>

            <%!-- WhatsApp Order --%>
            <a
              href={"https://wa.me/#{String.replace(@store.whatsapp_number || "", "+", "")}?text=Hi%2C%20I'd%20like%20to%20order%20#{URI.encode(@product.title)}%20from%20#{URI.encode(@store.name)}"}
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center justify-center gap-2.5 w-full h-12 border-2 border-whatsapp rounded-2xl text-base font-semibold text-whatsapp hover:bg-whatsapp/5 transition-all"
              style="font-family: 'Inter', sans-serif;"
            >
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
              </svg>
              Order via WhatsApp
            </a>

            <%!-- SKU --%>
            <p
              :if={@selected_variant && @selected_variant.sku}
              class="text-center text-xs text-[#059669]/50 pt-1"
              style="font-family: 'Inter', sans-serif;"
            >
              SKU: {@selected_variant.sku}
            </p>
          </section>

          <%!-- Delivery Info Card --%>
          <div class="px-4 lg:px-0 mb-4">
            <div class="bg-[#ECFDF5] rounded-2xl p-5 border border-[#D9F99D]/60">
              <div class="flex items-center gap-2.5 mb-2">
                <svg
                  class="w-5 h-5 text-[#059669]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
                  />
                </svg>
                <p class="text-sm font-bold text-cta-dark" style="font-family: 'Nunito', sans-serif;">
                  Delivery information
                </p>
              </div>
              <p
                class="text-xs text-[#78350F] leading-relaxed"
                style="font-family: 'Inter', sans-serif;"
              >
                See
                <a
                  href={store_path(@store.slug, "/policies")}
                  class="underline hover:text-cta-dark transition-colors"
                >
                  our policies page
                </a>
                for delivery times and coverage.
              </p>
            </div>
          </div>

          <%!-- Accordion Sections --%>
          <div class="px-4 lg:px-0">
            <details class="bg-white rounded-2xl border border-[#D9F99D]/60 mb-3 overflow-hidden">
              <summary
                class="px-5 py-4 text-base font-bold text-cta-dark cursor-pointer flex items-center justify-between hover:bg-[#ECFDF5]/30 select-none list-none [&::-webkit-details-marker]:hidden"
                style="font-family: 'Nunito', sans-serif;"
              >
                <span>Product Details</span>
                <svg
                  class="w-5 h-5 text-[#059669] transition-transform [[open]>&]:rotate-180"
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
            <details class="bg-white rounded-2xl border border-[#D9F99D]/60 mb-3 overflow-hidden">
              <summary
                class="px-5 py-4 text-base font-bold text-cta-dark cursor-pointer flex items-center justify-between hover:bg-[#ECFDF5]/30 select-none list-none [&::-webkit-details-marker]:hidden"
                style="font-family: 'Nunito', sans-serif;"
              >
                <span>Delivery Information</span>
                <svg
                  class="w-5 h-5 text-[#059669] transition-transform [[open]>&]:rotate-180"
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
            <details class="bg-white rounded-2xl border border-[#D9F99D]/60 mb-3 overflow-hidden">
              <summary
                class="px-5 py-4 text-base font-bold text-cta-dark cursor-pointer flex items-center justify-between hover:bg-[#ECFDF5]/30 select-none list-none [&::-webkit-details-marker]:hidden"
                style="font-family: 'Nunito', sans-serif;"
              >
                <span>Freshness Guarantee</span>
                <svg
                  class="w-5 h-5 text-[#059669] transition-transform [[open]>&]:rotate-180"
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
                <p :if={Terms.badges(assigns) != []} class="mb-1 font-bold text-cta-dark">
                  {Enum.join(Terms.badges(assigns), " · ")}
                </p>
                <p>
                  Not happy with freshness? See our
                  <a
                    href={store_path(@store.slug, "/policies")}
                    class="underline hover:text-cta-dark transition-colors"
                  >
                    returns policy
                  </a>
                  for how to request a replacement or refund.
                </p>
              </div>
            </details>
          </div>
        </div>
      </div>

      <%!-- Related Products Scroll --%>
      <section :if={@related_products != []} class="py-8 bg-[#FEFCE8]">
        <div class="max-w-[1280px] mx-auto">
          <h2
            class="text-xl font-bold text-cta-dark px-4 sm:px-6 lg:px-8 mb-5"
            style="font-family: 'Nunito', sans-serif;"
          >
            You Might Also Like
          </h2>
          <div class="flex gap-4 overflow-x-auto px-4 sm:px-6 lg:px-8 pb-2 snap-x snap-mandatory [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            <a
              :for={rp <- @related_products}
              href={store_path(@store.slug, "/products/#{rp.slug}")}
              class="flex-[0_0_160px] snap-start group"
            >
              <div class="rounded-2xl overflow-hidden bg-[#ECFDF5]/30 shadow-sm group-hover:shadow-lg group-hover:shadow-emerald-100/60 transition-all duration-300 mb-2.5">
                <div class="w-full aspect-square overflow-hidden">
                  <%= if Shared.first_image(rp) do %>
                    <.optimized_image
                      src={Shared.first_image(rp)}
                      alt={rp.title}
                      class="w-full h-full object-cover group-hover:scale-[1.04] transition-transform duration-500"
                    />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center bg-[#ECFDF5]">
                      <svg
                        class="w-10 h-10 text-[#059669]/30"
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
              <p
                class="text-sm font-bold text-cta-dark leading-tight mb-1 truncate"
                style="font-family: 'Nunito', sans-serif;"
              >
                {rp.title}
              </p>
              <p class="text-sm font-bold text-[var(--theme-primary,#047857)]">
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

  # ── Components ──

  defp stock_badge(assigns) do
    ~H"""
    <%= cond do %>
      <% is_nil(@variant) -> %>
        <span class="text-sm text-[#92400E]" style="font-family: 'Inter', sans-serif;">
          Select options
        </span>
      <% @variant.track_inventory and @variant.stock_quantity <= 0 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-bold text-[#DC2626]">
          <span class="w-2 h-2 rounded-full bg-[#DC2626]"></span> Out of Stock
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

  @fresh_keywords ~w(fresh organic local farm natural)

  defp fresh_tags(product) do
    tags =
      case Map.get(product, :tags) do
        tags when is_list(tags) -> tags
        _ -> []
      end

    tags
    |> Enum.filter(fn tag ->
      tag_lower = String.downcase(to_string(tag))
      Enum.any?(@fresh_keywords, &String.contains?(tag_lower, &1))
    end)
    |> Enum.take(3)
    |> case do
      [] -> []
      found -> found
    end
  end
end
