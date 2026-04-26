defmodule Emakola.Themes.DefaultRenderers.OrderConfirmation do
  @moduledoc """
  Default render for the storefront order confirmation page.

  Used by `EmakolaWeb.Storefront.OrderConfirmationLive` when no theme
  overrides `:render_order_confirmation`. Includes status badge,
  status colour helpers, and shipping/customer formatting helpers.

  See `docs/PATTERN-default-renderer-extraction.md`.
  """

  use Phoenix.Component

  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FAFAF9]">
      <%!-- ===== HERO CELEBRATION ===== --%>
      <section class="relative overflow-hidden bg-gradient-to-b from-[#1C1917] via-[#292524] to-[#1C1917] text-white">
        <%!-- Subtle radial glow --%>
        <div class="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_rgba(180,83,9,0.15)_0%,_transparent_70%)]">
        </div>

        <div class="relative max-w-[640px] mx-auto px-4 pt-12 pb-14 sm:pt-16 sm:pb-20 text-center">
          <%!-- Animated checkmark ring --%>
          <div class="relative w-24 h-24 mx-auto mb-6">
            <div class="absolute inset-0 rounded-full border-2 border-[#B45309]/30 animate-[ring-expand_1s_ease-out_forwards]">
            </div>
            <div class="absolute inset-0 rounded-full bg-gradient-to-br from-[#B45309] to-[#92400E] flex items-center justify-center animate-[checkmark-pop_0.5s_ease-out_forwards] shadow-lg shadow-[#B45309]/25">
              <svg
                class="w-11 h-11 text-white"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
              </svg>
            </div>
          </div>

          <h1 class="font-serif text-3xl sm:text-4xl font-semibold tracking-tight mb-2">
            Thank you for your order
          </h1>
          <p class="text-[#A8A29E] text-sm sm:text-base">
            Your order has been placed and is being processed
          </p>

          <%!-- Order number pill --%>
          <div class="mt-5 inline-flex items-center gap-2 bg-white/10 backdrop-blur-sm border border-white/10 rounded-full px-5 py-2">
            <span class="text-xs uppercase tracking-widest text-[#A8A29E]">Order</span>
            <span class="text-sm font-mono font-semibold text-white">{@order.order_number}</span>
          </div>
        </div>
      </section>

      <%!-- ===== MAIN CONTENT ===== --%>
      <div class="max-w-[640px] mx-auto px-4 -mt-6 sm:-mt-8 pb-12 relative z-10">
        <%!-- Status + Timeline Card --%>
        <div class="bg-white border border-[#E7E5E4] rounded-2xl shadow-sm overflow-hidden mb-5">
          <%!-- Status header bar --%>
          <div class="px-6 py-4 border-b border-[#F5F5F4] flex items-center justify-between">
            <span class="text-xs font-semibold uppercase tracking-widest text-[#78716C]">Status</span>
            <.status_badge status={@order.status} />
          </div>

          <%!-- Horizontal timeline --%>
          <div class="px-6 py-6">
            <div class="flex items-start">
              <%!-- Step 1 --%>
              <div class="flex-1 text-center">
                <div class="flex justify-center mb-3">
                  <div class="w-10 h-10 rounded-full bg-store-accent flex items-center justify-center shadow-md shadow-[#B45309]/20">
                    <svg
                      class="w-5 h-5 text-white"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2.5"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                    </svg>
                  </div>
                </div>
                <p class="text-xs font-semibold text-cta-dark">Received</p>
                <p class="text-[10px] text-[#A8A29E] mt-0.5">Seller notified</p>
              </div>

              <%!-- Connector --%>
              <div class="flex-shrink-0 w-16 sm:w-24 pt-5">
                <div class="h-px bg-gradient-to-r from-[#B45309] to-[#E7E5E4]"></div>
              </div>

              <%!-- Step 2 --%>
              <div class="flex-1 text-center">
                <div class="flex justify-center mb-3">
                  <div class="w-10 h-10 rounded-full bg-[#F5F5F4] border-2 border-[#D6D3D1] flex items-center justify-center">
                    <svg
                      class="w-5 h-5 text-[#A8A29E]"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="1.5"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"
                      />
                    </svg>
                  </div>
                </div>
                <p class="text-xs font-medium text-[#78716C]">Preparing</p>
                <p class="text-[10px] text-[#A8A29E] mt-0.5">SMS when shipped</p>
              </div>

              <%!-- Connector --%>
              <div class="flex-shrink-0 w-16 sm:w-24 pt-5">
                <div class="h-px bg-[#E7E5E4]"></div>
              </div>

              <%!-- Step 3 --%>
              <div class="flex-1 text-center">
                <div class="flex justify-center mb-3">
                  <div class="w-10 h-10 rounded-full bg-[#F5F5F4] border-2 border-[#D6D3D1] flex items-center justify-center">
                    <svg
                      class="w-5 h-5 text-[#A8A29E]"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="1.5"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
                      />
                    </svg>
                  </div>
                </div>
                <p class="text-xs font-medium text-[#78716C]">Delivered</p>
                <p class="text-[10px] text-[#A8A29E] mt-0.5">2-5 business days</p>
              </div>
            </div>
          </div>
        </div>

        <%!-- Order Summary Card --%>
        <div class="bg-white border border-[#E7E5E4] rounded-2xl shadow-sm overflow-hidden mb-5">
          <div class="px-6 py-4 border-b border-[#F5F5F4] flex items-center justify-between">
            <span class="text-xs font-semibold uppercase tracking-widest text-[#78716C]">
              Your Order
            </span>
            <span class="text-xs text-[#A8A29E]">
              {length(@order.line_items)} {if length(@order.line_items) == 1,
                do: "item",
                else: "items"}
            </span>
          </div>

          <%!-- Line items --%>
          <div class="divide-y divide-[#F5F5F4]">
            <div :for={item <- @order.line_items} class="px-6 py-4 flex items-center gap-4">
              <div class="relative flex-shrink-0">
                <div
                  :if={line_item_image(item)}
                  class="w-16 h-16 rounded-xl overflow-hidden bg-[#F5F5F4]"
                >
                  <img
                    src={line_item_image(item)}
                    alt={item.product_title}
                    class="w-full h-full object-cover"
                    loading="lazy"
                  />
                </div>
                <div
                  :if={!line_item_image(item)}
                  class="w-16 h-16 bg-[#F5F5F4] rounded-xl flex items-center justify-center"
                >
                  <svg
                    class="w-5 h-5 text-[#D6D3D1]"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5z"
                    />
                  </svg>
                </div>
                <span
                  :if={item.quantity > 1}
                  class="absolute -top-1.5 -right-1.5 w-5 h-5 bg-cta-dark text-white text-[10px] font-bold rounded-full flex items-center justify-center ring-2 ring-white"
                >
                  {item.quantity}
                </span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-cta-dark truncate">{item.product_title}</p>
                <p :if={item.variant_sku} class="text-xs text-[#A8A29E] mt-0.5">{item.variant_sku}</p>
              </div>
              <span class="text-sm font-semibold text-cta-dark tabular-nums flex-shrink-0">
                {Currency.format_price(item.line_total, @store.currency)}
              </span>
            </div>
          </div>

          <%!-- Totals --%>
          <div class="bg-[#FAFAF9] px-6 py-4 space-y-2">
            <div class="flex justify-between text-sm">
              <span class="text-[#78716C]">Subtotal</span>
              <span class="text-[#44403C] tabular-nums">
                {Currency.format_price(@order.subtotal, @store.currency)}
              </span>
            </div>
            <div
              :if={order_has_field?(@order, :discount_amount) && @order.discount_amount > 0}
              class="flex justify-between text-sm"
            >
              <span class="text-[#78716C]">Discount</span>
              <span class="text-[#059669] font-medium tabular-nums">
                -{Currency.format_price(@order.discount_amount, @store.currency)}
              </span>
            </div>
            <div
              :if={order_has_field?(@order, :delivery_fee) && @order.delivery_fee > 0}
              class="flex justify-between text-sm"
            >
              <span class="text-[#78716C]">Delivery</span>
              <span class="text-[#44403C] tabular-nums">
                {Currency.format_price(@order.delivery_fee, @store.currency)}
              </span>
            </div>
            <div class="flex justify-between items-baseline pt-3 border-t border-[#E7E5E4]">
              <span class="text-sm font-semibold text-cta-dark">Total</span>
              <span class="text-xl font-bold text-cta-dark tabular-nums">
                {Currency.format_price(@order.total, @store.currency)}
              </span>
            </div>
          </div>
        </div>

        <%!-- Delivery Details Card (collapsible) --%>
        <div
          :if={@order.shipping_address}
          class="bg-white border border-[#E7E5E4] rounded-2xl shadow-sm overflow-hidden mb-5"
        >
          <button
            phx-click="toggle_details"
            class="cursor-pointer w-full px-6 py-4 flex items-center justify-between hover:bg-[#FAFAF9] transition-colors"
          >
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-lg bg-[#F5F5F4] flex items-center justify-center">
                <svg
                  class="w-4 h-4 text-[#78716C]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z"
                  />
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z"
                  />
                </svg>
              </div>
              <span class="text-sm font-medium text-cta-dark">Delivery details</span>
            </div>
            <svg
              class={"w-4 h-4 text-[#A8A29E] transition-transform #{if @show_details, do: "rotate-180"}"}
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
            </svg>
          </button>
          <div :if={@show_details} class="px-6 pb-5 pt-0">
            <div class="ml-11 text-sm text-[#57534E] space-y-0.5">
              <p :if={@order.shipping_address["name"]} class="font-medium text-cta-dark">
                {@order.shipping_address["name"]}
              </p>
              <p :if={@order.shipping_address["address"]}>{@order.shipping_address["address"]}</p>
              <p :if={@order.shipping_address["region"]}>
                {region_label(@order.shipping_address["region"])}
              </p>
              <p :if={@order.shipping_address["phone"]} class="mt-2 text-xs text-[#A8A29E]">
                {@order.shipping_address["phone"]}
              </p>
            </div>
            <div
              :if={@order.notes && @order.notes != ""}
              class="ml-11 mt-3 pt-3 border-t border-[#F5F5F4]"
            >
              <p class="text-xs uppercase tracking-widest text-[#A8A29E] mb-1">Note</p>
              <p class="text-sm text-[#57534E]">{@order.notes}</p>
            </div>
          </div>
        </div>

        <%!-- CTAs --%>
        <div class="space-y-3 mb-6">
          <a
            href={"/s/#{@store.slug}"}
            class="group w-full flex items-center justify-center gap-2.5 px-8 py-4 bg-cta-dark text-white text-sm font-semibold tracking-wide rounded-2xl hover:bg-[#292524] transition-all hover:shadow-lg hover:shadow-stone-900/10"
          >
            Continue Shopping
            <svg
              class="w-4 h-4 transition-transform group-hover:translate-x-0.5"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
              />
            </svg>
          </a>

          <a
            :if={@store.whatsapp_number}
            href={"https://wa.me/#{clean_phone(@store.whatsapp_number)}?text=Hi! I just placed order #{@order.order_number}"}
            target="_blank"
            rel="noopener noreferrer"
            class="group w-full flex items-center justify-center gap-2.5 px-8 py-4 bg-white border border-[#E7E5E4] text-cta-dark text-sm font-semibold tracking-wide rounded-2xl hover:border-[#25D366] hover:text-[#25D366] transition-all"
          >
            <svg class="w-4.5 h-4.5 text-[#25D366]" fill="currentColor" viewBox="0 0 24 24">
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
            </svg>
            Contact seller on WhatsApp
          </a>
        </div>

        <%!-- SMS notification note --%>
        <p :if={customer_phone(@order)} class="text-center text-xs text-[#A8A29E]">
          We'll text you at {mask_phone(customer_phone(@order))} with updates
        </p>

        <%!-- Share strip — turn every buyer into a distribution node --%>
        <div class="mt-8 pt-8 border-t border-[#E7E5E4]">
          <EmakolaWeb.StorefrontComponents.share_strip
            url={share_url(@store, @order)}
            title={"I just shopped at #{@store.name}"}
            headline="Loved your order? Share it"
          />
        </div>
      </div>
    </div>

    <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />

    <style>
      @keyframes checkmark-pop {
        0% { transform: scale(0); opacity: 0; }
        60% { transform: scale(1.15); }
        100% { transform: scale(1); opacity: 1; }
      }
      @keyframes ring-expand {
        0% { transform: scale(0.8); opacity: 0; }
        50% { transform: scale(1.3); opacity: 0.5; }
        100% { transform: scale(1.5); opacity: 0; }
      }
    </style>
    """
  end

  # -- Components --

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    {bg, text, label} = status_colors(assigns.status)
    assigns = assign(assigns, bg: bg, text: text, label: label)

    ~H"""
    <span class={"inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full text-sm font-medium #{@bg} #{@text}"}>
      <span class={"w-2 h-2 rounded-full #{status_dot_color(@status)}"}></span>
      {@label}
    </span>
    """
  end

  defp status_colors(:pending), do: {"bg-amber-50", "text-amber-700", "Awaiting Payment"}
  defp status_colors(:confirmed), do: {"bg-green-50", "text-green-700", "Order Confirmed"}
  defp status_colors(:processing), do: {"bg-blue-50", "text-blue-700", "Processing"}
  defp status_colors(:shipped), do: {"bg-purple-50", "text-purple-700", "Shipped"}
  defp status_colors(:delivered), do: {"bg-green-50", "text-green-700", "Delivered"}
  defp status_colors(:cancelled), do: {"bg-red-50", "text-red-700", "Cancelled"}
  defp status_colors(_), do: {"bg-gray-50", "text-gray-700", "Unknown"}

  defp status_dot_color(:pending), do: "bg-amber-500"
  defp status_dot_color(:confirmed), do: "bg-green-500"
  defp status_dot_color(:processing), do: "bg-blue-500"
  defp status_dot_color(:shipped), do: "bg-purple-500"
  defp status_dot_color(:delivered), do: "bg-green-500"
  defp status_dot_color(:cancelled), do: "bg-red-500"
  defp status_dot_color(_), do: "bg-gray-500"

  # -- Helpers --

  defp line_item_image(line_item) do
    case line_item do
      %{variant: %{product: %{images: [img | _]}}} -> img.thumbnail_url || img.url
      _ -> nil
    end
  end

  defp order_has_field?(order, field) do
    Map.has_key?(order, field) && not is_nil(Map.get(order, field))
  end

  defp customer_phone(order) do
    cond do
      order.shipping_address && order.shipping_address["phone"] ->
        order.shipping_address["phone"]

      true ->
        nil
    end
  end

  defp mask_phone(nil), do: ""

  defp mask_phone(phone) when is_binary(phone) do
    cleaned = String.replace(phone, ~r/[^\d+]/, "")

    if String.length(cleaned) >= 6 do
      prefix = String.slice(cleaned, 0, 4)
      suffix = String.slice(cleaned, -4, 4)
      "#{prefix} XX #{suffix}"
    else
      phone
    end
  end

  defp clean_phone(phone) when is_binary(phone) do
    String.replace(phone, ~r/[^\d+]/, "")
  end

  defp clean_phone(_), do: ""

  defp region_label("greater_accra"), do: "Greater Accra"
  defp region_label("ashanti"), do: "Ashanti"
  defp region_label("central"), do: "Central"
  defp region_label("western"), do: "Western"
  defp region_label("eastern"), do: "Eastern"
  defp region_label("northern"), do: "Northern"
  defp region_label("volta"), do: "Volta"
  defp region_label(_), do: "Other"

  # Builds the share URL for the share_strip — points back to the merchant's
  # storefront home so social shares from the order confirmation drive new
  # traffic into the store. Uses host from EmakolaWeb.Endpoint config.
  defp share_url(store, _order) do
    base = EmakolaWeb.Endpoint.url()
    "#{base}/s/#{store.slug}"
  end
end
