defmodule EmakolaWeb.Storefront.CartLive do
  @moduledoc """
  Shopping cart page — matches cart.html prototype.

  Features:
  - Page header with item count + continue shopping link
  - Cart items with product image, title, variant details, quantity stepper
  - Order summary panel (sticky on desktop)
  - Empty cart state with CTA
  - Responsive layout: stacked mobile, side-by-side desktop
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        cart_session_id = session["cart_session_id"]
        cart = if cart_session_id, do: CartStore.get_cart(cart_session_id), else: []

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart, cart)
         |> assign(:cart_count, cart_count(cart))
         |> assign(:cart_total, cart_total(cart))
         |> assign(:checking_out, false)
         |> assign(:page_title, "Shopping Bag - #{store.name}")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("update_quantity", %{"index" => index_str, "delta" => delta_str}, socket) do
    index = String.to_integer(index_str)
    delta = String.to_integer(delta_str)
    item = Enum.at(socket.assigns.cart, index)
    new_qty = item.quantity + delta

    if new_qty <= 0 do
      CartStore.remove_item(socket.assigns.cart_session_id, item.variant_id)
    else
      CartStore.update_quantity(socket.assigns.cart_session_id, item.variant_id, min(new_qty, 10))
    end

    {:noreply, reload_cart(socket)}
  end

  @impl true
  def handle_event("update_quantity", %{"index" => index_str, "quantity" => qty_str}, socket) do
    index = String.to_integer(index_str)
    quantity = String.to_integer(qty_str)
    item = Enum.at(socket.assigns.cart, index)

    if item do
      if quantity <= 0 do
        CartStore.remove_item(socket.assigns.cart_session_id, item.variant_id)
      else
        CartStore.update_quantity(socket.assigns.cart_session_id, item.variant_id, quantity)
      end
    end

    {:noreply, reload_cart(socket)}
  end

  @impl true
  def handle_event("remove_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    item = Enum.at(socket.assigns.cart, index)

    if item do
      CartStore.remove_item(socket.assigns.cart_session_id, item.variant_id)
    end

    {:noreply, reload_cart(socket)}
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
          CartStore.clear_cart(socket.assigns.cart_session_id)

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
    <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
      <%!-- Page header --%>
      <section class="pt-10 pb-6 sm:pt-14 sm:pb-8">
        <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
          <div>
            <h1 class="text-3xl sm:text-4xl font-bold text-[#0F172A]">Shopping Bag</h1>
            <p class="mt-1 text-sm text-[#94A3B8] font-light tracking-wide">
              {length(@cart)} {if length(@cart) == 1, do: "item", else: "items"}
            </p>
          </div>
          <a
            href={"/s/#{@store.slug}/products"}
            class="inline-flex items-center gap-2 text-sm font-medium text-[#475569] hover:text-[#B45309] transition-colors group"
          >
            <svg
              class="w-4 h-4 transition-transform group-hover:-translate-x-0.5"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18"
              />
            </svg>
            Continue Shopping
          </a>
        </div>
      </section>

      <%!-- Cart content --%>
      <section class="pb-16 sm:pb-20">
        <%= if @cart == [] do %>
          <%!-- Empty state --%>
          <div class="py-20 text-center">
            <svg
              class="w-16 h-16 mx-auto text-[#D6D3D1] mb-6"
              fill="none"
              stroke="currentColor"
              stroke-width="1"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007ZM8.625 10.5a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm7.5 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
              />
            </svg>
            <h2 class="text-2xl font-bold text-[#0F172A] mb-2">Your bag is empty</h2>
            <p class="text-sm text-[#94A3B8] mb-8">
              Discover our collection and find something you love.
            </p>
            <a
              href={"/s/#{@store.slug}/products"}
              class="inline-flex items-center gap-2 px-8 py-3 bg-[#1C1917] text-white text-sm font-semibold tracking-wider uppercase rounded-lg hover:bg-[#44403C] transition-colors"
            >
              Start Shopping
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
        <% else %>
          <div class="lg:grid lg:grid-cols-[1fr_380px] lg:gap-12 xl:gap-16">
            <%!-- Cart items --%>
            <div>
              <div
                :for={{item, index} <- Enum.with_index(@cart)}
                class="py-6 border-b border-[#E2E8F0] group"
              >
                <div class="flex gap-4 sm:gap-6">
                  <%!-- Product image placeholder --%>
                  <div class="flex-shrink-0 w-24 h-30 sm:w-32 sm:h-40 bg-[#F1F5F9] rounded-xl overflow-hidden">
                    <div class="w-full h-full flex items-center justify-center">
                      <svg
                        class="w-8 h-8 text-[#94A3B8]"
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
                  </div>

                  <div class="flex-1 min-w-0 flex flex-col sm:flex-row sm:justify-between gap-4">
                    <%!-- Item details --%>
                    <div class="flex-1 min-w-0">
                      <p class="text-lg sm:text-xl font-semibold text-[#0F172A] leading-tight truncate">
                        {item.product_title}
                      </p>
                      <div :if={item.variant_info} class="mt-2 space-y-0.5">
                        <p class="text-xs sm:text-sm text-[#94A3B8]">
                          Variant: <span class="text-[#475569] font-medium">{item.variant_info}</span>
                        </p>
                      </div>
                      <%!-- Mobile price + qty --%>
                      <p class="mt-2 text-base font-semibold text-[#0F172A] sm:hidden">
                        {Currency.format_price(item.unit_price, @store.currency)}
                      </p>
                      <div class="mt-3 flex items-center gap-4 sm:hidden">
                        <.quantity_stepper index={index} quantity={item.quantity} size="sm" />
                        <button
                          phx-click="remove_item"
                          phx-value-index={index}
                          class="text-[#94A3B8] hover:text-red-600 transition-colors p-1"
                          aria-label={"Remove #{item.product_title}"}
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
                              d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
                            />
                          </svg>
                        </button>
                      </div>
                    </div>

                    <%!-- Desktop price + qty + remove --%>
                    <div class="hidden sm:flex flex-col items-end justify-between flex-shrink-0 sm:min-w-[160px]">
                      <p class="text-base font-semibold text-[#0F172A]">
                        {Currency.format_price(item.unit_price, @store.currency)}
                      </p>
                      <.quantity_stepper index={index} quantity={item.quantity} size="md" />
                      <div class="flex items-center gap-1">
                        <span class="text-xs text-[#94A3B8]">Subtotal:</span>
                        <span class="text-sm font-semibold text-[#0F172A]">
                          {Currency.format_price(item.unit_price * item.quantity, @store.currency)}
                        </span>
                      </div>
                      <button
                        phx-click="remove_item"
                        phx-value-index={index}
                        class="inline-flex items-center gap-1.5 text-xs text-[#94A3B8] hover:text-red-600 transition-colors"
                        aria-label={"Remove #{item.product_title}"}
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
                            d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
                          />
                        </svg>
                        Remove
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Order summary --%>
            <div class="mt-8 lg:mt-0">
              <div class="lg:sticky lg:top-28">
                <div class="bg-white rounded-2xl border border-[#E2E8F0] p-6 sm:p-8 shadow-sm">
                  <h2 class="text-2xl font-bold text-[#0F172A] mb-6">Order Summary</h2>

                  <div class="space-y-3 text-sm">
                    <div class="flex justify-between">
                      <span class="text-[#94A3B8]">Subtotal</span>
                      <span class="font-medium text-[#0F172A]">
                        {Currency.format_price(@cart_total, @store.currency)}
                      </span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-[#94A3B8]">Shipping</span>
                      <span class="font-medium text-[#059669]">Calculated at checkout</span>
                    </div>
                  </div>

                  <div class="border-t border-[#E2E8F0] my-5"></div>

                  <div class="flex justify-between text-lg font-bold text-[#0F172A] mb-6">
                    <span>Total</span>
                    <span>{Currency.format_price(@cart_total, @store.currency)}</span>
                  </div>

                  <button
                    phx-click="checkout"
                    disabled={@checking_out || @cart == []}
                    class="w-full py-3.5 bg-[#1C1917] text-white text-sm font-semibold tracking-wider uppercase rounded-lg hover:bg-[#44403C] transition-colors disabled:bg-[#E2E8F0] disabled:text-[#94A3B8] disabled:cursor-not-allowed"
                  >
                    Proceed to Checkout
                  </button>

                  <%!-- Trust badges --%>
                  <div class="mt-5 flex items-center justify-center gap-4 text-xs text-[#94A3B8]">
                    <span class="flex items-center gap-1">
                      <svg
                        class="w-3.5 h-3.5"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z"
                        />
                      </svg>
                      Secure checkout
                    </span>
                    <span class="flex items-center gap-1">
                      <svg
                        class="w-3.5 h-3.5"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M8.25 18.75a1.5 1.5 0 0 1-3 0m3 0a1.5 1.5 0 0 0-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 0 1-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 0 1-3 0m3 0a1.5 1.5 0 0 0-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 0 0-3.213-9.193 2.056 2.056 0 0 0-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 0 0-10.026 0 1.106 1.106 0 0 0-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
                        />
                      </svg>
                      Free shipping over GH&#8373; 200
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </section>
    </div>
    """
  end

  # -- Components --

  attr :index, :integer, required: true
  attr :quantity, :integer, required: true
  attr :size, :string, default: "md"

  defp quantity_stepper(assigns) do
    btn_size = if assigns.size == "sm", do: "w-8 h-8", else: "w-9 h-9"
    input_size = if assigns.size == "sm", do: "w-10 h-8", else: "w-12 h-9"
    assigns = assign(assigns, btn_size: btn_size, input_size: input_size)

    ~H"""
    <div class="inline-flex items-center border border-[#E2E8F0] rounded-lg overflow-hidden">
      <button
        phx-click="update_quantity"
        phx-value-index={@index}
        phx-value-delta="-1"
        disabled={@quantity <= 1}
        class={"#{@btn_size} flex items-center justify-center text-[#475569] hover:text-[#0F172A] hover:bg-[#F1F5F9] transition-colors disabled:text-[#94A3B8] disabled:cursor-not-allowed"}
        aria-label="Decrease quantity"
      >
        <svg
          class="w-3.5 h-3.5"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          viewBox="0 0 24 24"
        >
          <path d="M5 12h14" stroke-linecap="round" />
        </svg>
      </button>
      <div class={"#{@input_size} flex items-center justify-center text-sm font-medium text-[#0F172A] border-x border-[#E2E8F0] select-none"}>
        {@quantity}
      </div>
      <button
        phx-click="update_quantity"
        phx-value-index={@index}
        phx-value-delta="1"
        disabled={@quantity >= 10}
        class={"#{@btn_size} flex items-center justify-center text-[#475569] hover:text-[#0F172A] hover:bg-[#F1F5F9] transition-colors disabled:text-[#94A3B8] disabled:cursor-not-allowed"}
        aria-label="Increase quantity"
      >
        <svg
          class="w-3.5 h-3.5"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          viewBox="0 0 24 24"
        >
          <path d="M12 5v14M5 12h14" stroke-linecap="round" />
        </svg>
      </button>
    </div>
    """
  end

  # -- Helpers --

  defp reload_cart(socket) do
    cart = CartStore.get_cart(socket.assigns.cart_session_id)

    socket
    |> assign(:cart, cart)
    |> assign(:cart_count, cart_count(cart))
    |> assign(:cart_total, cart_total(cart))
  end

  defp cart_count(cart) do
    Enum.reduce(cart, 0, fn item, acc -> acc + item.quantity end)
  end

  defp cart_total(cart) do
    Enum.reduce(cart, 0, fn item, acc -> acc + item.unit_price * item.quantity end)
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
