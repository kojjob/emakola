defmodule Emakola.Themes.Starter.ProductDetail do
  @moduledoc """
  Starter theme product detail page (PDP).

  Features:
  - Breadcrumb navigation (Home > Products > Product Name)
  - Two-column layout: image gallery left, product info right
  - Variant selector pills
  - Quantity stepper
  - Add to Cart button (indigo, full-width)
  - WhatsApp button (green, secondary)
  - Collapsible accordion: Details, Shipping, Returns
  - Related products horizontal scroll
  """
  use Phoenix.Component

  alias Emakola.Themes.Starter.Shared
  alias EmakolaWeb.Helpers.Currency

  @doc """
  Renders the Starter theme product detail page.

  Expects assigns:
  - `@store` -- store map
  - `@product` -- product with `.title`, `.slug`, `.description`, `.images`, `.variants`
  - `@selected_variant` -- currently selected variant
  - `@selected_options` -- map of option_type_id => option_value_id
  - `@option_types` -- list of option types with `.option_values`
  - `@quantity` -- current quantity
  - `@current_image_index` -- index of displayed image
  - `@related_products` -- list of related products
  - `@categories` -- list of categories
  - `@theme` -- theme config map
  - `@cart_count` -- integer cart item count
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
    <div class="min-h-screen bg-white">
      <Shared.starter_nav store={@store} cart_count={@cart_count} />
      <%!-- Breadcrumb --%>
      <nav
        aria-label="Breadcrumb"
        class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-4"
      >
        <ol class="flex items-center gap-2 text-xs text-[#94A3B8]">
          <li>
            <a
              href={"/s/#{@store.slug}"}
              class="hover:text-[var(--theme-primary,#6366F1)] transition-colors"
              style="font-family: 'Inter', sans-serif;"
            >
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
              href={"/s/#{@store.slug}/products"}
              class="hover:text-[var(--theme-primary,#6366F1)] transition-colors"
              style="font-family: 'Inter', sans-serif;"
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
          <li class="text-[#0F172A] font-medium truncate max-w-[200px]">{@product.title}</li>
        </ol>
      </nav>

      <div class="max-w-[1280px] mx-auto lg:grid lg:grid-cols-2 lg:gap-12 lg:px-8 lg:pb-8">
        <%!-- Image Gallery --%>
        <section
          class="bg-[#F8FAFC] lg:rounded-2xl lg:overflow-hidden"
          aria-label="Product images"
        >
          <div class="w-full aspect-[4/5] lg:aspect-square overflow-hidden">
            <%= if current_image(@product, @current_image_index) do %>
              <img
                src={current_image(@product, @current_image_index)}
                alt={"#{@product.title} -- image #{@current_image_index + 1}"}
                class="w-full h-full object-cover"
              />
            <% else %>
              <div class="w-full h-full flex items-center justify-center bg-gray-100">
                <svg
                  class="w-16 h-16 text-gray-300"
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
          <%!-- Thumbnail Dots --%>
          <div
            :if={length(@product.images) > 1}
            class="flex items-center justify-center gap-2 py-4 px-4"
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
                "h-2.5 rounded-full transition-all cursor-pointer",
                if(idx == @current_image_index,
                  do: "w-8 bg-[var(--theme-primary,#6366F1)]",
                  else: "w-2.5 bg-gray-300 hover:bg-gray-400"
                )
              ]}
            />
          </div>
        </section>

        <%!-- Product Info Panel --%>
        <div class="lg:py-2">
          <%!-- Title, Price, Description --%>
          <section class="px-4 lg:px-0 py-6">
            <h1
              class="text-2xl sm:text-3xl font-semibold text-[#0F172A] leading-tight mb-3 tracking-tight"
              style="font-family: 'Inter', sans-serif;"
            >
              {@product.title}
            </h1>
            <p
              class="text-2xl font-semibold text-[var(--theme-primary,#6366F1)] mb-3"
              style="font-family: 'Inter', sans-serif;"
            >
              <%= if @selected_variant do %>
                {Currency.format_price(@selected_variant.price, @store.currency)}
              <% else %>
                {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
              <% end %>
            </p>
            <div class="mb-4">
              <.stock_badge variant={@selected_variant} />
            </div>
            <p
              :if={@product.description}
              class="text-sm text-[#64748B] leading-relaxed"
              style="font-family: 'Inter', sans-serif;"
            >
              {@product.description}
            </p>
          </section>

          <%!-- Variant Selectors --%>
          <section
            :if={@option_types != []}
            class="px-4 lg:px-0 py-5 space-y-5"
            aria-label="Product options"
          >
            <div :for={ot <- @option_types}>
              <div
                class="text-sm font-medium text-[#0F172A] mb-3"
                style="font-family: 'Inter', sans-serif;"
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
                    "min-w-[48px] h-11 px-5 rounded-full text-sm font-medium flex items-center justify-center transition-all cursor-pointer",
                    if(Map.get(@selected_options, ot.id) == ov.id,
                      do:
                        "bg-[var(--theme-primary,#6366F1)] text-white border-2 border-[var(--theme-primary,#6366F1)]",
                      else:
                        "bg-white text-[#64748B] border-2 border-gray-200 hover:border-[var(--theme-primary,#6366F1)] hover:text-[var(--theme-primary,#6366F1)]"
                    )
                  ]}
                  style="font-family: 'Inter', sans-serif;"
                >
                  {ov.value}
                </button>
              </div>
            </div>
          </section>

          <%!-- Quantity + Add to Cart --%>
          <section class="px-4 lg:px-0 py-5 space-y-4" aria-label="Add to cart">
            <%!-- Quantity stepper --%>
            <div class="flex items-center border border-gray-200 rounded-full w-fit overflow-hidden bg-white">
              <button
                phx-click="decrement_quantity"
                disabled={@quantity <= 1}
                class="w-12 h-12 flex items-center justify-center text-[#64748B] hover:bg-gray-50 transition-colors disabled:text-gray-200 disabled:cursor-not-allowed"
                aria-label="Decrease quantity"
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                >
                  <path d="M2 8h12" />
                </svg>
              </button>
              <div
                class="w-14 h-12 flex items-center justify-center text-sm font-semibold text-[#0F172A] border-x border-gray-200 select-none"
                style="font-family: 'Inter', sans-serif;"
              >
                {@quantity}
              </div>
              <button
                phx-click="increment_quantity"
                disabled={@quantity >= 10}
                class="w-12 h-12 flex items-center justify-center text-[#64748B] hover:bg-gray-50 transition-colors disabled:text-gray-200 disabled:cursor-not-allowed"
                aria-label="Increase quantity"
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                >
                  <path d="M8 2v12M2 8h12" />
                </svg>
              </button>
            </div>

            <%!-- Add to Cart CTA --%>
            <button
              phx-click="add_to_cart"
              disabled={is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0}
              class={[
                "w-full h-14 rounded-full text-base font-semibold flex items-center justify-center gap-2.5 transition-all",
                if(is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0,
                  do: "bg-gray-100 text-gray-400 cursor-not-allowed",
                  else:
                    "bg-[var(--theme-primary,#6366F1)] text-white hover:bg-[#4F46E5] active:scale-[0.97] cursor-pointer shadow-sm"
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
              <%= if is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0 do %>
                Out of Stock
              <% else %>
                Add to Cart
              <% end %>
            </button>

            <%!-- WhatsApp Button --%>
            <a
              href={"https://wa.me/#{String.replace(@store.whatsapp_number || "", "+", "")}?text=Hi%2C%20I'm%20interested%20in%20#{URI.encode(@product.title)}%20from%20#{URI.encode(@store.name)}"}
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center justify-center gap-2.5 w-full h-12 border-2 border-[#25D366] rounded-full text-sm font-semibold text-[#25D366] hover:bg-[#25D366]/5 transition-all"
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
              class="text-center text-xs text-[#94A3B8] pt-1"
              style="font-family: 'Inter', sans-serif;"
            >
              SKU: {@selected_variant.sku}
            </p>
          </section>

          <%!-- Accordion Sections --%>
          <div class="px-4 lg:px-0">
            <details class="bg-white rounded-xl border border-gray-200 mb-3 overflow-hidden">
              <summary
                class="px-5 py-4 text-sm font-medium text-[#0F172A] cursor-pointer flex items-center justify-between hover:bg-gray-50 select-none list-none [&::-webkit-details-marker]:hidden"
                style="font-family: 'Inter', sans-serif;"
              >
                <span>Product Details</span>
                <svg
                  class="w-5 h-5 text-[#94A3B8] transition-transform [[open]>&]:rotate-180"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
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
                class="px-5 pb-5 text-sm text-[#64748B] leading-relaxed"
                style="font-family: 'Inter', sans-serif;"
              >
                <p :if={@product.description}>{@product.description}</p>
                <p :if={!@product.description}>No additional details available.</p>
              </div>
            </details>
            <details class="bg-white rounded-xl border border-gray-200 mb-3 overflow-hidden">
              <summary
                class="px-5 py-4 text-sm font-medium text-[#0F172A] cursor-pointer flex items-center justify-between hover:bg-gray-50 select-none list-none [&::-webkit-details-marker]:hidden"
                style="font-family: 'Inter', sans-serif;"
              >
                <span>Shipping & Delivery</span>
                <svg
                  class="w-5 h-5 text-[#94A3B8] transition-transform [[open]>&]:rotate-180"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
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
                class="px-5 pb-5 text-sm text-[#64748B] leading-relaxed"
                style="font-family: 'Inter', sans-serif;"
              >
                <p>Delivery within Greater Accra: 1-2 business days.</p>
                <p class="mt-2">Nationwide delivery: 3-5 business days.</p>
              </div>
            </details>
            <details class="bg-white rounded-xl border border-gray-200 mb-3 overflow-hidden">
              <summary
                class="px-5 py-4 text-sm font-medium text-[#0F172A] cursor-pointer flex items-center justify-between hover:bg-gray-50 select-none list-none [&::-webkit-details-marker]:hidden"
                style="font-family: 'Inter', sans-serif;"
              >
                <span>Returns & Exchange</span>
                <svg
                  class="w-5 h-5 text-[#94A3B8] transition-transform [[open]>&]:rotate-180"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
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
                class="px-5 pb-5 text-sm text-[#64748B] leading-relaxed"
                style="font-family: 'Inter', sans-serif;"
              >
                <p>
                  Returns accepted within 7 days of delivery. Items must be unused and in original packaging.
                </p>
              </div>
            </details>
          </div>
        </div>
      </div>

      <%!-- Related Products Scroll --%>
      <section :if={@related_products != []} class="py-10 bg-white">
        <div class="max-w-[1280px] mx-auto">
          <h2
            class="text-xl font-semibold text-[#0F172A] px-4 sm:px-6 lg:px-8 mb-5"
            style="font-family: 'Inter', sans-serif;"
          >
            You May Also Like
          </h2>
          <div class="flex gap-4 overflow-x-auto px-4 sm:px-6 lg:px-8 pb-2 snap-x snap-mandatory [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            <a
              :for={rp <- @related_products}
              href={"/s/#{@store.slug}/products/#{rp.slug}"}
              class="flex-[0_0_160px] snap-start group"
            >
              <div class="rounded-2xl overflow-hidden bg-gray-50 shadow-sm group-hover:shadow-md group-hover:-translate-y-0.5 transition-all duration-300 mb-2.5">
                <div class="w-full aspect-square overflow-hidden">
                  <%= if Shared.first_image(rp) do %>
                    <img
                      src={Shared.first_image(rp)}
                      alt={rp.title}
                      loading="lazy"
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center bg-gray-100">
                      <svg
                        class="w-10 h-10 text-gray-300"
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
                class="text-sm font-medium text-[#0F172A] leading-tight mb-1 truncate"
                style="font-family: 'Inter', sans-serif;"
              >
                {rp.title}
              </p>
              <p
                class="text-sm font-semibold text-[var(--theme-primary,#6366F1)]"
                style="font-family: 'Inter', sans-serif;"
              >
                {Currency.format_price_range(rp.min_price, rp.max_price, @store.currency)}
              </p>
            </a>
          </div>
        </div>
      </section>

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
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-red-500">
          <span class="w-2 h-2 rounded-full bg-red-500"></span> Out of Stock
        </span>
      <% @variant.stock_quantity < 5 -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-amber-500">
          <span class="w-2 h-2 rounded-full bg-amber-500"></span>
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
