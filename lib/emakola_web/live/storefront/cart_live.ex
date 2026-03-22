defmodule EmakolaWeb.Storefront.CartLive do
  @moduledoc """
  Shopping cart page — displays cart items stored in LiveView assigns,
  supports quantity updates, item removal, and checkout via CheckoutService.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.{Currency, SEO, StoreResolver}

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug}, _session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:cart, [])
         |> assign(:cart_count, 0)
         |> assign(:cart_total, 0)
         |> assign(:checking_out, false)
         |> assign(:page_title, "Cart - #{store.name}")
         |> assign(:robots, SEO.robots_tag(false))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("update_quantity", %{"index" => index_str, "quantity" => qty_str}, socket) do
    index = String.to_integer(index_str)
    quantity = String.to_integer(qty_str)

    cart =
      if quantity <= 0 do
        List.delete_at(socket.assigns.cart, index)
      else
        List.update_at(socket.assigns.cart, index, fn item ->
          %{item | quantity: quantity}
        end)
      end

    {:noreply, recalculate_cart(socket, cart)}
  end

  @impl true
  def handle_event("remove_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    cart = List.delete_at(socket.assigns.cart, index)

    {:noreply, recalculate_cart(socket, cart)}
  end

  @impl true
  def handle_event("checkout", _params, socket) do
    cart = socket.assigns.cart

    if cart == [] do
      {:noreply, put_flash(socket, :error, "Your cart is empty")}
    else
      items =
        Enum.map(cart, fn item ->
          %{variant_id: item.variant_id, quantity: item.quantity}
        end)

      case Emakola.Orders.CheckoutService.checkout!(socket.assigns.store.id, items, []) do
        {:ok, order} ->
          {:noreply,
           socket
           |> assign(:cart, [])
           |> assign(:cart_count, 0)
           |> assign(:cart_total, 0)
           |> put_flash(:info, "Order #{order.order_number} placed successfully!")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, checkout_error_message(reason))}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 sm:px-6 py-6">
      <h1 class="text-2xl font-bold text-gray-900 mb-6">Shopping Cart</h1>

      <%= if @cart == [] do %>
        <div class="text-center py-16">
          <svg
            class="w-16 h-16 text-gray-300 mx-auto"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 100 4 2 2 0 000-4z"
            />
          </svg>
          <p class="mt-4 text-gray-500">Your cart is empty</p>
          <a
            href={"/s/#{@store.slug}/products"}
            class="mt-4 inline-block text-sm font-medium text-indigo-600 hover:text-indigo-700"
          >
            Continue shopping &rarr;
          </a>
        </div>
      <% else %>
        <!-- Cart items -->
        <div class="space-y-4">
          <div
            :for={{item, index} <- Enum.with_index(@cart)}
            class="flex items-center gap-4 p-4 bg-white border border-gray-200 rounded-lg"
          >
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-900 truncate">{item.product_title}</p>
              <p :if={item.variant_info} class="text-xs text-gray-500">{item.variant_info}</p>
              <p class="text-sm font-semibold text-gray-700 mt-1">
                {Currency.format_price(item.unit_price, @store.currency)}
              </p>
            </div>

            <div class="flex items-center gap-2">
              <select
                phx-change="update_quantity"
                phx-value-index={index}
                name="quantity"
                class="px-2 py-1 border border-gray-300 rounded text-sm"
              >
                <option
                  :for={qty <- 1..10}
                  value={qty}
                  selected={qty == item.quantity}
                >
                  {qty}
                </option>
              </select>
            </div>

            <p class="text-sm font-semibold text-gray-900 w-24 text-right">
              {Currency.format_price(item.unit_price * item.quantity, @store.currency)}
            </p>

            <button
              phx-click="remove_item"
              phx-value-index={index}
              class="text-gray-400 hover:text-red-500 transition-colors p-1"
              aria-label="Remove item"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
        </div>
        <!-- Cart summary -->
        <div class="mt-6 border-t border-gray-200 pt-6">
          <div class="flex justify-between items-center text-lg font-bold text-gray-900">
            <span>Total</span>
            <span>{Currency.format_price(@cart_total, @store.currency)}</span>
          </div>

          <button
            phx-click="checkout"
            disabled={@checking_out}
            class="mt-4 w-full py-3 px-6 bg-indigo-600 text-white rounded-lg text-sm font-semibold hover:bg-indigo-700 transition-colors disabled:bg-gray-300 disabled:cursor-not-allowed"
          >
            Proceed to Checkout
          </button>

          <a
            href={"/s/#{@store.slug}/products"}
            class="mt-3 block text-center text-sm text-indigo-600 hover:text-indigo-700 font-medium"
          >
            Continue shopping
          </a>
        </div>
      <% end %>
    </div>
    """
  end

  # -- Helpers --

  defp recalculate_cart(socket, cart) do
    cart_count = Enum.reduce(cart, 0, fn item, acc -> acc + item.quantity end)
    cart_total = Enum.reduce(cart, 0, fn item, acc -> acc + item.unit_price * item.quantity end)

    socket
    |> assign(:cart, cart)
    |> assign(:cart_count, cart_count)
    |> assign(:cart_total, cart_total)
  end

  defp checkout_error_message(reason) do
    messages = %{
      empty_cart: "Your cart is empty",
      variant_not_found: "Some items are no longer available",
      variant_not_in_store: "Some items are not from this store",
      insufficient_stock: "Some items are out of stock"
    }

    Map.get(messages, reason, "Something went wrong. Please try again.")
  end
end
