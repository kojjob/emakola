defmodule EmakolaWeb.Storefront.OrderConfirmationLive do
  @moduledoc """
  Order confirmation page — shows order details after successful checkout.

  Displays:
  - Order number and status
  - Ordered items with prices
  - Payment status (paid, pending, COD)
  - Delivery details
  - Continue shopping link
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
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FAFAF9]">
      <div class="max-w-[640px] mx-auto px-4 py-10 sm:py-16">
        <%!-- Success icon --%>
        <div class="text-center mb-8">
          <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-[#059669] flex items-center justify-center">
            <svg
              class="w-8 h-8 text-white"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2.5"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
            </svg>
          </div>
          <h1 class="text-2xl sm:text-3xl font-bold text-[#0F172A] mb-2">
            Thank you for your order!
          </h1>
          <p class="text-sm text-[#475569]">
            Order <span class="font-semibold text-[#0F172A]">{@order.order_number}</span>
            has been placed.
          </p>
        </div>

        <%!-- Payment status badge --%>
        <div class="flex justify-center mb-8">
          <.status_badge status={@order.status} />
        </div>

        <%!-- Order details card --%>
        <div class="bg-white border border-[#E2E8F0] rounded-xl overflow-hidden mb-6">
          <%!-- Order items --%>
          <div class="p-5">
            <h3 class="text-sm font-semibold text-[#0F172A] mb-4">Order Items</h3>
            <div class="space-y-3">
              <div :for={item <- @order.line_items} class="flex items-center gap-3">
                <div class="w-12 h-12 bg-[#F1F5F9] rounded-lg flex items-center justify-center flex-shrink-0">
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
          </div>

          <%!-- Totals --%>
          <div class="border-t border-[#E2E8F0] px-5 py-4">
            <div class="space-y-2 text-sm">
              <div class="flex justify-between">
                <span class="text-[#475569]">Subtotal</span>
                <span class="text-[#0F172A]">
                  {Currency.format_price(@order.subtotal, @store.currency)}
                </span>
              </div>
              <div class="flex justify-between text-base font-bold pt-2 border-t border-[#E2E8F0]">
                <span class="text-[#0F172A]">Total</span>
                <span class="text-[#0F172A]">
                  {Currency.format_price(@order.total, @store.currency)}
                </span>
              </div>
            </div>
          </div>
        </div>

        <%!-- Delivery details --%>
        <div
          :if={@order.shipping_address}
          class="bg-white border border-[#E2E8F0] rounded-xl p-5 mb-6"
        >
          <h3 class="text-sm font-semibold text-[#0F172A] mb-3">Delivery Details</h3>
          <div class="text-sm text-[#475569] space-y-1">
            <p :if={@order.shipping_address["name"]} class="font-medium text-[#0F172A]">
              {@order.shipping_address["name"]}
            </p>
            <p :if={@order.shipping_address["address"]}>
              {@order.shipping_address["address"]}
            </p>
            <p :if={@order.shipping_address["phone"]}>
              {@order.shipping_address["phone"]}
            </p>
            <p :if={@order.shipping_address["region"]}>
              {region_label(@order.shipping_address["region"])}
            </p>
          </div>
        </div>

        <%!-- Notes --%>
        <div
          :if={@order.notes && @order.notes != ""}
          class="bg-white border border-[#E2E8F0] rounded-xl p-5 mb-8"
        >
          <h3 class="text-sm font-semibold text-[#0F172A] mb-2">Order Notes</h3>
          <p class="text-sm text-[#475569]">{@order.notes}</p>
        </div>

        <%!-- Actions --%>
        <div class="text-center space-y-3">
          <a
            href={"/s/#{@store.slug}"}
            class="inline-flex items-center gap-2 px-8 py-3 bg-[#1C1917] text-white text-sm font-semibold rounded-xl hover:bg-[#292524] transition-colors"
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
        </div>
      </div>
    </div>
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
         |> Ash.Query.load([:line_items, :customer])
         |> Ash.read_one() do
      {:ok, nil} -> {:error, :not_found}
      {:ok, order} -> {:ok, order}
      {:error, _} -> {:error, :not_found}
    end
  end

  # -- Helpers --

  defp region_label("greater_accra"), do: "Greater Accra"
  defp region_label("ashanti"), do: "Ashanti"
  defp region_label("central"), do: "Central"
  defp region_label("western"), do: "Western"
  defp region_label("eastern"), do: "Eastern"
  defp region_label("northern"), do: "Northern"
  defp region_label("volta"), do: "Volta"
  defp region_label(_), do: "Other"
end
