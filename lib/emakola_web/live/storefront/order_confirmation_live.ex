defmodule EmakolaWeb.Storefront.OrderConfirmationLive do
  @moduledoc """
  Order confirmation page with celebration design and delivery timeline.

  Displays:
  - Animated success checkmark
  - "You're all set!" heading with order number
  - "What happens next" vertical timeline
  - Compact order summary with expandable details
  - Continue shopping + WhatsApp contact CTAs
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug, "order_number" => order_number}, _session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        case load_order(store, order_number) do
          {:ok, order} ->
            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:order, order)
             |> assign(:cart, [])
             |> assign(:cart_count, 0)
             |> assign(:show_details, false)
             |> assign(:page_title, "Order #{order.order_number} - #{store.name}")}

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "Order not found")
             |> redirect(to: "/s/#{slug}")}
        end

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("toggle_details", _params, socket) do
    {:noreply, assign(socket, :show_details, !socket.assigns.show_details)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FAFAF9]">
      <div class="max-w-[640px] mx-auto px-4 py-10 sm:py-16">
        <%!-- Animated success checkmark --%>
        <div class="text-center mb-8">
          <div class="w-20 h-20 mx-auto mb-5 rounded-full bg-[#059669] flex items-center justify-center animate-[checkmark-pop_0.5s_ease-out_forwards]">
            <svg
              class="w-10 h-10 text-white"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2.5"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
            </svg>
          </div>
          <h1 class="text-2xl sm:text-3xl font-bold text-[#0F172A] mb-2">
            You're all set!
          </h1>
          <p class="text-sm text-[#475569]">
            Order <span class="font-semibold text-[#0F172A]">{@order.order_number}</span>
            has been placed successfully.
          </p>
        </div>

        <%!-- Payment status badge --%>
        <div class="flex justify-center mb-8">
          <.status_badge status={@order.status} />
        </div>

        <%!-- What happens next timeline --%>
        <div class="bg-white border border-[#E2E8F0] rounded-xl p-5 mb-6">
          <h3 class="text-sm font-semibold text-[#0F172A] mb-5">What happens next</h3>
          <div class="relative pl-8">
            <%!-- Timeline line --%>
            <div class="absolute left-[11px] top-1 bottom-1 w-px bg-[#E2E8F0]"></div>

            <%!-- Step 1: Order received (active) --%>
            <div class="relative pb-6">
              <div class="absolute left-[-21px] top-0.5 w-[22px] h-[22px] rounded-full bg-[#059669] flex items-center justify-center ring-4 ring-white">
                <svg
                  class="w-3 h-3 text-white"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="3"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                </svg>
              </div>
              <p class="text-sm font-semibold text-[#0F172A]">Order received</p>
              <p class="text-xs text-[#475569] mt-0.5">The seller has been notified</p>
            </div>

            <%!-- Step 2: Being prepared (grey) --%>
            <div class="relative pb-6">
              <div class="absolute left-[-21px] top-0.5 w-[22px] h-[22px] rounded-full bg-[#F1F5F9] border-2 border-[#CBD5E1] flex items-center justify-center ring-4 ring-white">
                <div class="w-2 h-2 rounded-full bg-[#CBD5E1]"></div>
              </div>
              <p class="text-sm font-medium text-[#64748B]">Being prepared</p>
              <p class="text-xs text-[#94A3B8] mt-0.5">We'll SMS you when it ships</p>
            </div>

            <%!-- Step 3: Delivered to you (grey) --%>
            <div class="relative">
              <div class="absolute left-[-21px] top-0.5 w-[22px] h-[22px] rounded-full bg-[#F1F5F9] border-2 border-[#CBD5E1] flex items-center justify-center ring-4 ring-white">
                <div class="w-2 h-2 rounded-full bg-[#CBD5E1]"></div>
              </div>
              <p class="text-sm font-medium text-[#64748B]">Delivered to you</p>
              <p class="text-xs text-[#94A3B8] mt-0.5">Estimated 2-5 business days</p>
            </div>
          </div>
        </div>

        <%!-- Compact order summary --%>
        <div class="bg-white border border-[#E2E8F0] rounded-xl overflow-hidden mb-6">
          <div class="p-5">
            <%!-- Product thumbnails row --%>
            <div class="flex items-center gap-2 mb-4">
              <div :for={item <- @order.line_items} class="relative flex-shrink-0">
                <div :if={line_item_image(item)} class="w-12 h-12 rounded-lg overflow-hidden">
                  <img
                    src={line_item_image(item)}
                    alt={item.product_title}
                    class="w-full h-full object-cover"
                    loading="lazy"
                  />
                </div>
                <div
                  :if={!line_item_image(item)}
                  class="w-12 h-12 bg-[#F1F5F9] rounded-lg flex items-center justify-center"
                >
                  <svg
                    class="w-4 h-4 text-[#94A3B8]"
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
                <span
                  :if={item.quantity > 1}
                  class="absolute -top-1 -right-1 w-5 h-5 bg-[#0F172A] text-white text-[10px] font-bold rounded-full flex items-center justify-center"
                >
                  {item.quantity}
                </span>
              </div>
              <span class="text-xs text-[#94A3B8] ml-1">
                {length(@order.line_items)} {if length(@order.line_items) == 1,
                  do: "item",
                  else: "items"}
              </span>
            </div>

            <%!-- Total paid --%>
            <div class="flex justify-between items-center">
              <span class="text-sm font-semibold text-[#0F172A]">Total paid</span>
              <span class="text-lg font-bold text-[#0F172A]">
                {Currency.format_price(@order.total, @store.currency)}
              </span>
            </div>

            <%!-- View details toggle --%>
            <button
              phx-click="toggle_details"
              class="mt-3 text-xs font-medium text-[#475569] hover:text-[#0F172A] transition-colors flex items-center gap-1"
            >
              {if @show_details, do: "Hide details", else: "View details"}
              <svg
                class={"w-3.5 h-3.5 transition-transform #{if @show_details, do: "rotate-180"}"}
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
              </svg>
            </button>
          </div>

          <%!-- Expandable details --%>
          <div :if={@show_details} class="border-t border-[#E2E8F0] px-5 py-4">
            <%!-- Line items --%>
            <div class="space-y-3 mb-4">
              <div :for={item <- @order.line_items} class="flex items-center gap-3">
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-[#0F172A] truncate">{item.product_title}</p>
                  <p class="text-xs text-[#94A3B8]">
                    Qty: {item.quantity}
                    <%= if item.variant_sku do %>
                      &middot; {item.variant_sku}
                    <% end %>
                  </p>
                </div>
                <span class="text-sm font-medium text-[#0F172A] flex-shrink-0">
                  {Currency.format_price(item.line_total, @store.currency)}
                </span>
              </div>
            </div>

            <%!-- Totals breakdown --%>
            <div class="space-y-2 text-sm border-t border-[#E2E8F0] pt-3">
              <div class="flex justify-between">
                <span class="text-[#475569]">Subtotal</span>
                <span class="text-[#0F172A]">
                  {Currency.format_price(@order.subtotal, @store.currency)}
                </span>
              </div>
              <div
                :if={order_has_field?(@order, :discount_amount) && @order.discount_amount > 0}
                class="flex justify-between"
              >
                <span class="text-[#475569]">Discount</span>
                <span class="text-[#059669]">
                  -{Currency.format_price(@order.discount_amount, @store.currency)}
                </span>
              </div>
              <div
                :if={order_has_field?(@order, :delivery_fee) && @order.delivery_fee > 0}
                class="flex justify-between"
              >
                <span class="text-[#475569]">Delivery</span>
                <span class="text-[#0F172A]">
                  {Currency.format_price(@order.delivery_fee, @store.currency)}
                </span>
              </div>
              <div class="flex justify-between text-base font-bold pt-2 border-t border-[#E2E8F0]">
                <span class="text-[#0F172A]">Total</span>
                <span class="text-[#0F172A]">
                  {Currency.format_price(@order.total, @store.currency)}
                </span>
              </div>
            </div>

            <%!-- Delivery details --%>
            <div :if={@order.shipping_address} class="border-t border-[#E2E8F0] pt-3 mt-3">
              <h4 class="text-xs font-semibold text-[#94A3B8] uppercase tracking-wider mb-2">
                Delivery
              </h4>
              <div class="text-sm text-[#475569] space-y-0.5">
                <p :if={@order.shipping_address["name"]} class="font-medium text-[#0F172A]">
                  {@order.shipping_address["name"]}
                </p>
                <p :if={@order.shipping_address["address"]}>
                  {@order.shipping_address["address"]}
                </p>
                <p :if={@order.shipping_address["region"]}>
                  {region_label(@order.shipping_address["region"])}
                </p>
              </div>
            </div>

            <%!-- Notes --%>
            <div :if={@order.notes && @order.notes != ""} class="border-t border-[#E2E8F0] pt-3 mt-3">
              <h4 class="text-xs font-semibold text-[#94A3B8] uppercase tracking-wider mb-2">
                Notes
              </h4>
              <p class="text-sm text-[#475569]">{@order.notes}</p>
            </div>
          </div>
        </div>

        <%!-- CTAs --%>
        <div class="space-y-3">
          <a
            href={"/s/#{@store.slug}"}
            class="w-full flex items-center justify-center gap-2 px-8 py-3.5 bg-[#1C1917] text-white text-sm font-semibold rounded-xl hover:bg-[#292524] transition-colors"
          >
            Continue Shopping
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3"
              />
            </svg>
          </a>

          <a
            :if={@store.whatsapp_number}
            href={"https://wa.me/#{clean_phone(@store.whatsapp_number)}?text=Hi! I just placed order #{@order.order_number}"}
            target="_blank"
            rel="noopener noreferrer"
            class="w-full flex items-center justify-center gap-2 px-8 py-3.5 bg-[#25D366] text-white text-sm font-semibold rounded-xl hover:bg-[#1fb855] transition-colors"
          >
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
            </svg>
            Contact seller on WhatsApp
          </a>
        </div>

        <%!-- SMS notification note --%>
        <p
          :if={customer_phone(@order)}
          class="text-center text-xs text-[#94A3B8] mt-4"
        >
          We'll text you at {mask_phone(customer_phone(@order))} with updates
        </p>
      </div>
    </div>

    <style>
      @keyframes checkmark-pop {
        0% { transform: scale(0); opacity: 0; }
        60% { transform: scale(1.2); }
        100% { transform: scale(1); opacity: 1; }
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

  # -- Data Loading --

  defp load_order(store, order_number) do
    case Emakola.Orders.Order
         |> Ash.Query.filter(store_id == ^store.id and order_number == ^order_number)
         |> Ash.Query.load(line_items: [variant: [product: [:images]]])
         |> Ash.read_one() do
      {:ok, nil} -> {:error, :not_found}
      {:ok, order} -> {:ok, order}
      {:error, _} -> {:error, :not_found}
    end
  end

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
end
