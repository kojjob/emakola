defmodule Emakola.Themes.Market.ProductDetail do
  @moduledoc """
  Market theme — product detail page renderer.

  Renders the product detail view with image gallery, variant selectors,
  quantity stepper, add-to-cart, WhatsApp CTA, accordions, and related products.
  """
  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [image_placeholder: 1, bottom_nav: 1]

  alias EmakolaWeb.Helpers.Currency
  alias Emakola.Themes.Market.Shared

  def render(assigns) do
    ~H"""
    <div class="max-w-[560px] mx-auto bg-[#FAFAF9] sm:shadow-[0_0_40px_rgba(0,0,0,0.06)] min-h-screen pb-16 sm:pb-0">
      <%!-- Product images gallery --%>
      <section class="bg-white" aria-label="Product images">
        <div class="w-full aspect-[4/5] overflow-hidden bg-[#F1F5F9]">
          <%= if Shared.current_image(@product, @current_image_index) do %>
            <img
              src={Shared.current_image(@product, @current_image_index)}
              alt={"#{@product.title} — image #{@current_image_index + 1}"}
              class="w-full h-full object-cover"
            />
          <% else %>
            <div class="w-full h-full flex items-center justify-center">
              <.image_placeholder size="lg" />
            </div>
          <% end %>
        </div>
        <%!-- Dot indicators --%>
        <div
          :if={length(@product.images) > 1}
          class="flex items-center justify-center gap-2 py-3 px-4"
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
              "h-2 rounded-full border-none transition-all cursor-pointer",
              if(idx == @current_image_index,
                do: "w-6 bg-[#B45309]",
                else: "w-2 bg-[#E2E8F0] hover:bg-[#94A3B8]"
              )
            ]}
          />
        </div>
      </section>

      <%!-- Product info --%>
      <section class="px-4 py-5 bg-white border-b border-[#E2E8F0]">
        <span class="inline-block bg-[#FEF3C7] text-[#B45309] text-[0.6875rem] font-bold tracking-wider uppercase px-2.5 py-1 rounded-full mb-2">
          New Arrival
        </span>
        <h1 class="text-2xl font-bold text-[#0F172A] leading-tight mb-1">{@product.title}</h1>
        <p class="text-xl font-bold text-[#0F172A] mb-2.5">
          <%= if @selected_variant do %>
            {Currency.format_price(@selected_variant.price, @store.currency)}
          <% else %>
            {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
          <% end %>
        </p>
        <%!-- Stock status --%>
        <div class="mb-3.5">
          <.stock_badge variant={@selected_variant} />
        </div>
        <p :if={@product.description} class="text-[0.9375rem] text-[#475569] leading-relaxed">
          {@product.description}
        </p>
      </section>

      <%!-- Variant selectors --%>
      <section
        :if={@option_types != []}
        class="px-4 py-5 bg-white border-b border-[#E2E8F0] space-y-5"
        aria-label="Product options"
      >
        <div :for={ot <- @option_types}>
          <div class="text-[0.8125rem] font-semibold text-[#0F172A] mb-2.5 flex items-center justify-between">
            <span>{ot.name}</span>
          </div>
          <div class="flex gap-2 flex-wrap" role="radiogroup" aria-label={"Select #{ot.name}"}>
            <button
              :for={ov <- ot.option_values}
              phx-click="select_option"
              phx-value-option_type_id={ot.id}
              phx-value-value={ov.id}
              role="radio"
              aria-checked={Map.get(@selected_options, ot.id) == ov.id}
              class={[
                "min-w-[48px] h-11 px-4 rounded-full text-sm font-medium flex items-center justify-center transition-all cursor-pointer",
                if(Map.get(@selected_options, ot.id) == ov.id,
                  do: "bg-[#1C1917] text-white border-[1.5px] border-[#1C1917]",
                  else:
                    "bg-white text-[#0F172A] border-[1.5px] border-[#E2E8F0] hover:border-[#94A3B8]"
                )
              ]}
            >
              {ov.value}
            </button>
          </div>
        </div>
      </section>

      <%!-- Quantity + Add to Bag --%>
      <section class="px-4 py-5 bg-white border-b border-[#E2E8F0] space-y-3" aria-label="Add to bag">
        <%!-- Quantity stepper --%>
        <div class="flex items-center border-[1.5px] border-[#E2E8F0] rounded-xl w-fit overflow-hidden">
          <button
            phx-click="decrement_quantity"
            disabled={@quantity <= 1}
            class="w-11 h-11 flex items-center justify-center text-[#0F172A] hover:bg-[#F1F5F9] transition-colors disabled:text-[#94A3B8] disabled:cursor-not-allowed disabled:hover:bg-white"
            aria-label="Decrease quantity"
          >
            <svg
              class="w-[18px] h-[18px]"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
            >
              <path d="M4 9h10" />
            </svg>
          </button>
          <div class="w-12 h-11 flex items-center justify-center text-[0.9375rem] font-semibold text-[#0F172A] border-x-[1.5px] border-[#E2E8F0] select-none">
            {@quantity}
          </div>
          <button
            phx-click="increment_quantity"
            disabled={@quantity >= 10}
            class="w-11 h-11 flex items-center justify-center text-[#0F172A] hover:bg-[#F1F5F9] transition-colors disabled:text-[#94A3B8] disabled:cursor-not-allowed disabled:hover:bg-white"
            aria-label="Increase quantity"
          >
            <svg
              class="w-[18px] h-[18px]"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
            >
              <path d="M9 4v10M4 9h10" />
            </svg>
          </button>
        </div>

        <%!-- Add to Bag button --%>
        <button
          phx-click="add_to_cart"
          disabled={is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0}
          class={[
            "w-full h-[52px] rounded-[20px] text-base font-semibold flex items-center justify-center gap-2 transition-colors",
            if(is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0,
              do: "bg-[#E2E8F0] text-[#94A3B8] cursor-not-allowed",
              else: "bg-[#1C1917] text-white hover:bg-[#292524] cursor-pointer"
            )
          ]}
        >
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
            />
          </svg>
          <%= if is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0 do %>
            Out of Stock
          <% else %>
            Add to Bag
          <% end %>
        </button>

        <%!-- WhatsApp ask button --%>
        <a
          href={"https://wa.me/?text=Hi%2C%20I'm%20interested%20in%20#{URI.encode(@product.title)}%20from%20#{URI.encode(@store.name)}"}
          target="_blank"
          rel="noopener noreferrer"
          class="flex items-center justify-center gap-2 w-full h-12 border-[1.5px] border-[#E2E8F0] rounded-[20px] text-[0.9375rem] font-medium text-[#0F172A] hover:border-[#94A3B8] hover:bg-[#F8FAFC] transition-all"
        >
          <svg class="w-5 h-5 text-[#25D366]" viewBox="0 0 24 24" fill="currentColor">
            <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
          </svg>
          Ask on WhatsApp
        </a>

        <%!-- SKU --%>
        <p
          :if={@selected_variant && @selected_variant.sku}
          class="text-center text-xs text-[#94A3B8] pt-1"
        >
          SKU: {@selected_variant.sku}
        </p>
      </section>

      <%!-- Accordion sections --%>
      <div class="bg-white border-b border-[#E2E8F0]">
        <details>
          <summary class="px-4 py-4 text-[0.9375rem] font-semibold text-[#0F172A] cursor-pointer flex items-center justify-between hover:bg-[#FAFAF9] select-none list-none [&::-webkit-details-marker]:hidden">
            <span>Product Details</span>
            <svg
              class="w-5 h-5 text-[#94A3B8] transition-transform [[open]>&]:rotate-180"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
            </svg>
          </summary>
          <div class="px-4 pb-4 text-sm text-[#475569] leading-relaxed">
            <p :if={@product.description}>{@product.description}</p>
            <p :if={!@product.description}>No additional details available.</p>
          </div>
        </details>
        <details class="border-t border-[#E2E8F0]">
          <summary class="px-4 py-4 text-[0.9375rem] font-semibold text-[#0F172A] cursor-pointer flex items-center justify-between hover:bg-[#FAFAF9] select-none list-none [&::-webkit-details-marker]:hidden">
            <span>Shipping & Delivery</span>
            <svg
              class="w-5 h-5 text-[#94A3B8] transition-transform [[open]>&]:rotate-180"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
            </svg>
          </summary>
          <div class="px-4 pb-4 text-sm text-[#475569] leading-relaxed">
            <p>Delivery within Greater Accra: 1-2 business days.</p>
            <p class="mt-2">Nationwide delivery: 3-5 business days.</p>
          </div>
        </details>
        <details class="border-t border-[#E2E8F0]">
          <summary class="px-4 py-4 text-[0.9375rem] font-semibold text-[#0F172A] cursor-pointer flex items-center justify-between hover:bg-[#FAFAF9] select-none list-none [&::-webkit-details-marker]:hidden">
            <span>Returns & Exchange</span>
            <svg
              class="w-5 h-5 text-[#94A3B8] transition-transform [[open]>&]:rotate-180"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
            </svg>
          </summary>
          <div class="px-4 pb-4 text-sm text-[#475569] leading-relaxed">
            <p>
              Returns accepted within 7 days of delivery. Items must be unworn and in original packaging.
            </p>
          </div>
        </details>
      </div>

      <%!-- Related products --%>
      <section :if={@related_products != []} class="py-6 bg-[#FAFAF9]">
        <h2 class="text-[1.0625rem] font-bold text-[#0F172A] px-4 mb-3.5">You May Also Like</h2>
        <div class="flex gap-3 overflow-x-auto px-4 snap-x snap-mandatory [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          <a
            :for={rp <- @related_products}
            href={"/s/#{@store.slug}/products/#{rp.slug}"}
            class="flex-[0_0_140px] snap-start bg-white rounded-xl border border-[#E2E8F0] overflow-hidden hover:shadow-[0_2px_8px_rgba(0,0,0,0.06)] transition-shadow"
          >
            <div class="w-full aspect-square bg-[#F1F5F9] overflow-hidden">
              <%= if Shared.first_image(rp) do %>
                <img
                  src={Shared.first_image(rp)}
                  alt={rp.title}
                  loading="lazy"
                  class="w-full h-full object-cover"
                />
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <.image_placeholder />
                </div>
              <% end %>
            </div>
            <div class="p-2.5 py-2">
              <p class="text-[0.8125rem] font-medium text-[#0F172A] leading-tight mb-1 truncate">
                {rp.title}
              </p>
              <p class="text-[0.8125rem] font-bold text-[#0F172A]">
                {Currency.format_price_range(rp.min_price, rp.max_price, @store.currency)}
              </p>
            </div>
          </a>
        </div>
      </section>
    </div>

    <.bottom_nav store_slug={@store.slug} active_tab={:home} cart_count={@cart_count} />
    """
  end

  # -- Components --

  attr :variant, :map, default: nil

  defp stock_badge(assigns) do
    ~H"""
    <%= cond do %>
      <% is_nil(@variant) -> %>
        <span class="text-sm text-[#94A3B8]">Select options</span>
      <% @variant.stock_quantity <= 0 -> %>
        <span class="inline-flex items-center text-sm font-medium text-red-600">
          Out of Stock
        </span>
      <% @variant.stock_quantity < 5 -> %>
        <span class="inline-flex items-center text-sm font-medium text-amber-600">
          Low Stock ({@variant.stock_quantity} left)
        </span>
      <% true -> %>
        <span class="inline-flex items-center gap-1.5 text-sm font-medium text-[#059669]">
          <span class="w-1.5 h-1.5 rounded-full bg-[#059669]"></span> In Stock
        </span>
    <% end %>
    """
  end
end
