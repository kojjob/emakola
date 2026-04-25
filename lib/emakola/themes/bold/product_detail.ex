defmodule Emakola.Themes.Bold.ProductDetail do
  @moduledoc """
  Bold theme product detail page (PDP).

  Features:
  - Minimal breadcrumb ("Back to shop" link)
  - Two-column layout: massive image gallery (60%) + product info (40%)
  - Bold Outfit heading, amber accent price
  - Rectangular variant selectors with dark borders
  - Minimal inline quantity stepper
  - Full-width dark add-to-cart button (uppercase)
  - Green WhatsApp secondary button
  - Expandable product detail sections
  - Related products grid below
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Bold.Shared
  alias EmakolaWeb.Helpers.Currency

  @doc """
  Renders the Bold theme product detail page.

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
  - `@cart_count` — integer cart item count
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
    <div class="min-h-screen bg-[#F8FAFC]">
      <Shared.bold_nav store={@store} cart_count={@cart_count} />

      <%!-- Breadcrumb --%>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <a
          href={"/s/#{@store.slug}/products"}
          class="text-sm text-[#64748B] hover:text-[#0F172A] transition-colors inline-flex items-center gap-1.5"
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
              d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"
            />
          </svg>
          Back to shop
        </a>
      </div>

      <%!-- Main Product Layout — 60/40 split --%>
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 pb-12 lg:grid lg:grid-cols-5 lg:gap-12">
        <%!-- Image Gallery (3/5 = 60%) --%>
        <section class="lg:col-span-3" aria-label="Product images">
          <div class="w-full aspect-[3/4] lg:aspect-[4/5] overflow-hidden bg-[#F1F5F9]">
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
                  class="w-20 h-20 text-[#CBD5E1]"
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
          <%!-- Thumbnail strip --%>
          <div
            :if={length(@product.images) > 1}
            class="flex gap-2 mt-3 overflow-x-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
            role="tablist"
            aria-label="Product image thumbnails"
          >
            <button
              :for={{img, idx} <- Enum.with_index(@product.images)}
              phx-click="select_image"
              phx-value-index={idx}
              role="tab"
              aria-selected={idx == @current_image_index}
              aria-label={"Image #{idx + 1}"}
              class={[
                "flex-shrink-0 w-16 h-16 sm:w-20 sm:h-20 overflow-hidden transition-all",
                if(idx == @current_image_index,
                  do: "ring-2 ring-[#0F172A] ring-offset-2",
                  else: "opacity-60 hover:opacity-100"
                )
              ]}
            >
              <.optimized_image
                src={(img && (Map.get(img, :thumbnail_url) || Map.get(img, :url))) || ""}
                alt={"Thumbnail #{idx + 1}"}
                priority={:low}
                class="w-full h-full object-cover"
              />
            </button>
          </div>
        </section>

        <%!-- Product Info (2/5 = 40%) --%>
        <div class="lg:col-span-2 pt-6 lg:pt-0">
          <%!-- Title & Price --%>
          <section class="mb-6">
            <h1
              class="text-2xl sm:text-3xl lg:text-4xl font-black text-[#0F172A] leading-tight mb-3 tracking-tight"
              style="font-family: 'Outfit', sans-serif;"
            >
              {@product.title}
            </h1>
            <p
              class="text-xl sm:text-2xl font-bold text-[#F59E0B] mb-3"
              style="font-family: 'Outfit', sans-serif;"
            >
              <%= if @selected_variant do %>
                {Currency.format_price(@selected_variant.price, @store.currency)}
              <% else %>
                {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
              <% end %>
            </p>
            <.stock_badge variant={@selected_variant} />
          </section>

          <%!-- Description --%>
          <p
            :if={@product.description}
            class="text-sm text-[#64748B] leading-relaxed mb-8"
            style="font-family: 'Inter', sans-serif;"
          >
            {@product.description}
          </p>

          <%!-- Variant Selectors (Rectangular, Dark Borders) --%>
          <section
            :if={@option_types != []}
            class="space-y-6 mb-8"
            aria-label="Product options"
          >
            <div :for={ot <- @option_types}>
              <div
                class="text-xs font-bold tracking-[0.15em] uppercase text-[#64748B] mb-3"
                style="font-family: 'Inter', sans-serif;"
              >
                {ot.name}
              </div>
              <div class="flex gap-2 flex-wrap" role="radiogroup" aria-label={"Select #{ot.name}"}>
                <button
                  :for={ov <- ot.option_values}
                  phx-click="select_option"
                  phx-value-type={ot.name}
                  phx-value-value={ov.value}
                  role="radio"
                  aria-checked={Map.get(@selected_options, ot.id) == ov.id}
                  class={[
                    "min-w-[48px] h-11 px-5 text-sm font-medium flex items-center justify-center transition-all cursor-pointer border-2",
                    if(Map.get(@selected_options, ot.id) == ov.id,
                      do: "bg-[#0F172A] text-white border-[#0F172A]",
                      else: "bg-white text-[#0F172A] border-[#E2E8F0] hover:border-[#0F172A]"
                    )
                  ]}
                  style="font-family: 'Inter', sans-serif;"
                >
                  {ov.value}
                </button>
              </div>
            </div>
          </section>

          <%!-- Quantity Stepper (Minimal, Inline) --%>
          <div class="flex items-center gap-6 mb-6">
            <span
              class="text-xs font-bold tracking-[0.15em] uppercase text-[#64748B]"
              style="font-family: 'Inter', sans-serif;"
            >
              Qty
            </span>
            <div class="flex items-center border-2 border-[#E2E8F0]">
              <button
                phx-click="decrement_quantity"
                disabled={@quantity <= 1}
                class="w-10 h-10 flex items-center justify-center text-[#64748B] hover:text-[#0F172A] hover:bg-[#F1F5F9] transition-colors disabled:text-[#CBD5E1] disabled:cursor-not-allowed"
                aria-label="Decrease quantity"
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" d="M5 12h14" />
                </svg>
              </button>
              <div
                class="w-12 h-10 flex items-center justify-center text-sm font-bold text-[#0F172A] border-x-2 border-[#E2E8F0] select-none"
                style="font-family: 'Inter', sans-serif;"
              >
                {@quantity}
              </div>
              <button
                phx-click="increment_quantity"
                disabled={@quantity >= 10}
                class="w-10 h-10 flex items-center justify-center text-[#64748B] hover:text-[#0F172A] hover:bg-[#F1F5F9] transition-colors disabled:text-[#CBD5E1] disabled:cursor-not-allowed"
                aria-label="Increase quantity"
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" d="M12 5v14M5 12h14" />
                </svg>
              </button>
            </div>
          </div>

          <%!-- Add to Cart — Dark, Full Width, Uppercase --%>
          <button
            phx-click="add_to_cart"
            disabled={is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0}
            class={[
              "w-full h-14 text-sm font-bold tracking-[0.15em] uppercase flex items-center justify-center gap-3 transition-all",
              if(is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0,
                do: "bg-[#E2E8F0] text-[#94A3B8] cursor-not-allowed",
                else: "bg-[#0F172A] text-white hover:bg-[#1E293B] active:scale-[0.98] cursor-pointer"
              )
            ]}
            style="font-family: 'Inter', sans-serif;"
          >
            <svg
              class="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
              />
            </svg>
            <%= if is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0 do %>
              Out of Stock
            <% else %>
              Add to Cart
            <% end %>
          </button>

          <%!-- WhatsApp Button — Green, Secondary --%>
          <a
            href={"https://wa.me/#{String.replace(@store.whatsapp_number || "", "+", "")}?text=Hi%2C%20I'm%20interested%20in%20#{URI.encode(@product.title)}%20from%20#{URI.encode(@store.name)}"}
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center justify-center gap-2.5 w-full h-12 mt-3 border-2 border-[#25D366] text-[#25D366] text-sm font-semibold hover:bg-whatsapp hover:text-white transition-all"
            style="font-family: 'Inter', sans-serif;"
          >
            <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
            </svg>
            Ask on WhatsApp
          </a>

          <%!-- SKU --%>
          <p
            :if={@selected_variant && @selected_variant.sku}
            class="text-center text-xs text-[#94A3B8] mt-4"
            style="font-family: 'Inter', sans-serif;"
          >
            SKU: {@selected_variant.sku}
          </p>

          <%!-- Expandable Details --%>
          <div class="mt-10 space-y-0 border-t border-[#E2E8F0]">
            <details class="border-b border-[#E2E8F0]" open>
              <summary
                class="py-4 text-sm font-bold text-[#0F172A] cursor-pointer flex items-center justify-between select-none list-none [&::-webkit-details-marker]:hidden tracking-wide uppercase"
                style="font-family: 'Inter', sans-serif;"
              >
                <span>Product Details</span>
                <svg
                  class="w-4 h-4 text-[#94A3B8] transition-transform [[open]>&]:rotate-180"
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
                class="pb-5 text-sm text-[#64748B] leading-relaxed"
                style="font-family: 'Inter', sans-serif;"
              >
                <p :if={@product.description}>{@product.description}</p>
                <p :if={!@product.description}>No additional details available.</p>
              </div>
            </details>
            <details class="border-b border-[#E2E8F0]">
              <summary
                class="py-4 text-sm font-bold text-[#0F172A] cursor-pointer flex items-center justify-between select-none list-none [&::-webkit-details-marker]:hidden tracking-wide uppercase"
                style="font-family: 'Inter', sans-serif;"
              >
                <span>Shipping & Delivery</span>
                <svg
                  class="w-4 h-4 text-[#94A3B8] transition-transform [[open]>&]:rotate-180"
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
                class="pb-5 text-sm text-[#64748B] leading-relaxed"
                style="font-family: 'Inter', sans-serif;"
              >
                <p>Delivery within Greater Accra: 1-2 business days.</p>
                <p class="mt-2">Nationwide delivery: 3-5 business days.</p>
              </div>
            </details>
            <details class="border-b border-[#E2E8F0]">
              <summary
                class="py-4 text-sm font-bold text-[#0F172A] cursor-pointer flex items-center justify-between select-none list-none [&::-webkit-details-marker]:hidden tracking-wide uppercase"
                style="font-family: 'Inter', sans-serif;"
              >
                <span>Returns & Exchange</span>
                <svg
                  class="w-4 h-4 text-[#94A3B8] transition-transform [[open]>&]:rotate-180"
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
                class="pb-5 text-sm text-[#64748B] leading-relaxed"
                style="font-family: 'Inter', sans-serif;"
              >
                <p>
                  Returns accepted within 7 days of delivery. Items must be unworn and in original packaging.
                </p>
              </div>
            </details>
          </div>
        </div>
      </div>

      <%!-- Related Products --%>
      <section :if={@related_products != []} class="py-12 bg-[#F8FAFC] border-t border-[#E2E8F0]">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <h2
            class="text-xl sm:text-2xl font-bold text-[#0F172A] mb-8"
            style="font-family: 'Outfit', sans-serif;"
          >
            You May Also Like
          </h2>
          <div class="grid grid-cols-2 gap-6 sm:gap-8 lg:grid-cols-4 lg:gap-10">
            <Shared.product_card :for={rp <- @related_products} product={rp} store={@store} />
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
        <span class="text-sm text-[#94A3B8]" style="font-family: 'Inter', sans-serif;">
          Select options
        </span>
      <% @variant.stock_quantity <= 0 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-red-600">
          <span class="w-2 h-2 rounded-full bg-red-600"></span> Out of Stock
        </span>
      <% @variant.stock_quantity < 5 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-[#F59E0B]">
          <span class="w-2 h-2 rounded-full bg-[#F59E0B]"></span>
          Low Stock ({@variant.stock_quantity} left)
        </span>
      <% true -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-emerald-600">
          <span class="w-2 h-2 rounded-full bg-emerald-600"></span> In Stock
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
end
