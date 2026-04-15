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
  import EmakolaWeb.StorefrontComponents

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        cart_session_id = session["cart_session_id"]
        cart = if cart_session_id, do: CartStore.get_cart(cart_session_id), else: []

        categories =
          try do
            Emakola.Catalog.list_root_categories!(store.id)
          rescue
            _ -> []
          end

        theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{})
        theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

        recommended_products =
          try do
            Emakola.Catalog.list_products_by_store_and_status!(store.id, :active)
            |> Enum.take(4)
          rescue
            _ -> []
          end

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:categories, categories)
         |> assign(:theme_module, theme_module)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart, cart)
         |> assign(:recommended_products, recommended_products)
         |> assign(:promo_code, nil)
         |> assign(:promo_error, nil)
         |> assign_totals(cart)
         |> assign(:checking_out, false)
         |> assign(:applied_coupon, nil)
         |> assign(:discount_amount, 0)
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
    if socket.assigns.cart == [] do
      {:noreply, put_flash(socket, :error, "Your cart is empty")}
    else
      {:noreply, push_navigate(socket, to: "/s/#{socket.assigns.store.slug}/checkout")}
    end
  end

  @impl true
  def handle_event("apply_promo", %{"promo" => promo}, socket) do
    promo = String.trim(promo) |> String.upcase()

    if promo == "WELCOME10" do
      {:noreply,
       socket
       |> assign(:promo_code, promo)
       |> assign(:promo_error, nil)
       |> assign_totals(socket.assigns.cart)}
    else
      {:noreply,
       socket
       |> assign(:promo_error, "Invalid promo code. Please try again.")}
    end
  end

  @impl true
  def handle_event("remove_promo", _params, socket) do
    {:noreply,
     socket
     |> assign(:promo_code, nil)
     |> assign(:promo_error, nil)
     |> assign_totals(socket.assigns.cart)}
  end

  @impl true
  def handle_event("update_promo_code", %{"promo_code" => code}, socket) do
    {:noreply, assign(socket, :promo_code, code)}
  end

  @impl true
  def handle_event("apply_coupon", _params, socket) do
    code = String.trim(socket.assigns.promo_code)
    store = socket.assigns.store

    if code == "" do
      {:noreply, assign(socket, :promo_error, "Please enter a coupon code")}
    else
      case Emakola.Orders.find_coupon_by_code(store.id, code) do
        {:ok, [coupon]} ->
          validate_and_apply_coupon(socket, coupon)

        {:ok, []} ->
          {:noreply, assign(socket, :promo_error, "Invalid coupon code")}

        {:error, _} ->
          {:noreply, assign(socket, :promo_error, "Invalid coupon code")}
      end
    end
  end

  @impl true
  def handle_event("remove_coupon", _params, socket) do
    {:noreply,
     socket
     |> assign(:applied_coupon, nil)
     |> assign(:discount_amount, 0)
     |> assign(:promo_code, "")
     |> assign(:promo_error, nil)}
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :cart) do
      {:ok, rendered} -> rendered
      :default -> render_default(assigns)
    end
  end

  defp render_default(assigns) do
    ~H"""
    <!-- PAGE HEADER -->
    <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-10 pb-6 sm:pt-14 sm:pb-8">
      <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
        <div>
          <h1 class="font-serif text-3xl sm:text-4xl font-semibold text-[#1C1917]">Shopping Bag</h1>
          <p id="item-count-text" class="mt-1 text-sm text-[#78716C] font-light tracking-wide">
            {@cart_count} {if @cart_count == 1, do: "item", else: "items"}
          </p>
        </div>
        <.link
          navigate={"/s/#{@store.slug}"}
          class="inline-flex items-center gap-2 text-sm font-medium text-[#44403C] hover:text-[#CA8A04] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded px-1 py-0.5 group"
        >
          <svg
            class="w-4 h-4 transition-transform group-hover:-translate-x-0.5"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            viewBox="0 0 24 24"
          >
            <path
              d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
          Continue Shopping
        </.link>
      </div>
    </section>

    <!-- CART LAYOUT -->
    <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16 sm:pb-20">
      <div class="lg:grid lg:grid-cols-[1fr_380px] lg:gap-12 xl:gap-16">
        <!-- ======= LEFT: Cart Items ======= -->
        <div id="cart-items">
          <%= if @cart == [] do %>
            <!-- Empty Cart State -->
            <div id="empty-cart" class="py-20 text-center">
              <svg
                class="w-16 h-16 mx-auto text-[#D6D3D1] mb-6"
                fill="none"
                stroke="currentColor"
                stroke-width="1"
                viewBox="0 0 24 24"
              >
                <path
                  d="M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007ZM8.625 10.5a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm7.5 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
              <h2 class="font-serif text-2xl font-semibold text-[#1C1917] mb-2">Your bag is empty</h2>
              <p class="text-sm text-[#78716C] mb-8">
                Discover our curated collection and find something you love.
              </p>
              <.link
                navigate={"/s/#{@store.slug}"}
                class="inline-flex items-center gap-2 px-8 py-3 bg-[#1C1917] text-white text-sm font-semibold tracking-wider uppercase rounded-lg hover:bg-[#44403C] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none"
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
                    d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                </svg>
              </.link>
            </div>
          <% else %>
            <!-- Cart Items -->
            <div
              :for={{item, index} <- Enum.with_index(@cart)}
              class="cart-item py-6 border-b border-[#E7E5E4] group"
            >
              <div class="flex gap-4 sm:gap-6">
                <.link
                  navigate={"/s/#{@store.slug}/products/#{item.variant_id}"}
                  class="flex-shrink-0 cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded-xl overflow-hidden"
                  aria-label={"View #{item.product_title}"}
                >
                  <%= if item[:image_url] do %>
                    <img
                      src={item[:image_url]}
                      alt={item.product_title}
                      class="w-24 h-30 sm:w-32 sm:h-40 object-cover rounded-xl transition-transform duration-300 group-hover:scale-[1.02]"
                      loading="lazy"
                      width="200"
                      height="250"
                    />
                  <% else %>
                    <div class="w-24 h-30 sm:w-32 sm:h-40 bg-neutral-100 rounded-xl flex items-center justify-center text-neutral-300">
                      <svg
                        class="w-8 h-8"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007ZM8.625 10.5a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm7.5 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
                        />
                      </svg>
                    </div>
                  <% end %>
                </.link>
                <div class="flex-1 min-w-0 flex flex-col sm:flex-row sm:justify-between gap-4">
                  <div class="flex-1 min-w-0">
                    <.link
                      navigate={"/s/#{@store.slug}/products/#{item.variant_id}"}
                      class="font-serif text-lg sm:text-xl font-semibold text-[#1C1917] hover:text-[#CA8A04] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded leading-tight"
                    >
                      {item.product_title}
                    </.link>
                    <div :if={item.variant_info} class="mt-2 space-y-0.5">
                      <p class="text-xs sm:text-sm text-[#78716C]">{item.variant_info}</p>
                    </div>
                    <p class="mt-2 text-base font-semibold text-[#1C1917] sm:hidden">
                      {Currency.format_price(item.unit_price * item.quantity, @store.currency)}
                    </p>
                    <div class="mt-3 flex items-center gap-4 sm:hidden">
                      <.quantity_stepper index={index} quantity={item.quantity} />
                      <button
                        phx-click="remove_item"
                        phx-value-index={index}
                        class="remove-btn text-[#78716C] hover:text-[#DC2626] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded p-1"
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
                            d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          />
                        </svg>
                      </button>
                    </div>
                    <button class="wishlist-btn mt-3 inline-flex items-center gap-1.5 text-xs text-[#78716C] hover:text-[#CA8A04] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded px-0.5 py-0.5">
                      <svg
                        class="w-3.5 h-3.5"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z"
                          stroke-linecap="round"
                          stroke-linejoin="round"
                        />
                      </svg>
                      Move to Wishlist
                    </button>
                  </div>
                  <div class="hidden sm:flex flex-col items-end justify-between flex-shrink-0 sm:min-w-[160px]">
                    <p class="text-base font-semibold text-[#1C1917]">
                      {Currency.format_price(item.unit_price, @store.currency)}
                    </p>
                    <.quantity_stepper index={index} quantity={item.quantity} />
                    <div class="flex items-center gap-1 mb-2 mt-2">
                      <span class="text-xs text-[#78716C]">Subtotal:</span>
                      <span class="item-subtotal text-sm font-semibold text-[#1C1917]">
                        {Currency.format_price(item.unit_price * item.quantity, @store.currency)}
                      </span>
                    </div>
                    <button
                      phx-click="remove_item"
                      phx-value-index={index}
                      class="remove-btn inline-flex items-center gap-1.5 text-xs text-[#78716C] hover:text-[#DC2626] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded px-0.5 py-0.5"
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
                          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
                          stroke-linecap="round"
                          stroke-linejoin="round"
                        />
                      </svg>
                      Remove
                    </button>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
        
    <!-- ======= RIGHT: Order Summary ======= -->
        <div :if={@cart != []} id="order-summary-wrapper" class="mt-8 lg:mt-0">
          <div class="lg:sticky lg:top-28">
            <div class="bg-white rounded-2xl border border-[#E7E5E4] p-6 sm:p-8 shadow-sm">
              <h2 class="font-serif text-2xl font-semibold text-[#1C1917] mb-6">Order Summary</h2>

              <div class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <span class="text-[#78716C]">Subtotal</span>
                  <span id="summary-subtotal" class="font-medium text-[#1C1917]">
                    {Currency.format_price(@cart_subtotal, @store.currency)}
                  </span>
                </div>
                <div class="flex justify-between">
                  <span class="text-[#78716C]">Shipping</span>
                  <span class="font-medium text-[#16A34A]">Free</span>
                </div>
                <p class="text-xs text-[#78716C]">Free shipping on orders over $200</p>
                <div class="flex justify-between">
                  <span class="text-[#78716C]">Estimated Tax</span>
                  <span id="summary-tax" class="font-medium text-[#1C1917]">
                    {Currency.format_price(@cart_tax, @store.currency)}
                  </span>
                </div>
              </div>

              <div class="border-t border-[#E7E5E4] my-5"></div>
              
    <!-- Promo Code -->
              <div id="promo-section">
                <label
                  for="promo-input"
                  class="block text-xs font-semibold tracking-wider uppercase text-[#44403C] mb-2"
                >
                  Promo Code
                </label>
                <form phx-submit="apply_promo" class="flex gap-2">
                  <input
                    id="promo-input"
                    name="promo"
                    type="text"
                    placeholder="Enter code"
                    disabled={@promo_code != nil}
                    class="flex-1 h-10 px-3 text-sm border border-[#E7E5E4] rounded-lg bg-transparent text-[#1C1917] placeholder:text-[#78716C]/60 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#CA8A04] transition-shadow disabled:opacity-50 disabled:cursor-not-allowed"
                    autocomplete="off"
                  />
                  <button
                    type="submit"
                    disabled={@promo_code != nil}
                    class="h-10 px-5 text-xs font-semibold tracking-wider uppercase bg-[#1C1917] text-white rounded-lg hover:bg-[#44403C] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Apply
                  </button>
                </form>
                <div :if={@promo_code} id="promo-success" class="mt-3 promo-success">
                  <div class="flex items-center gap-2 px-3 py-2 bg-green-50 border border-green-200 rounded-lg">
                    <svg
                      class="w-4 h-4 text-[#16A34A] flex-shrink-0"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                    >
                      <path
                        d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                    </svg>
                    <span class="text-xs font-medium text-green-800">
                      {@promo_code} applied &mdash; 10% off
                    </span>
                    <button
                      type="button"
                      phx-click="remove_promo"
                      class="ml-auto text-green-600 hover:text-green-800 transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded"
                      aria-label="Remove promo code"
                    >
                      <svg
                        class="w-3.5 h-3.5"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2"
                        viewBox="0 0 24 24"
                      >
                        <path d="M6 18 18 6M6 6l12 12" stroke-linecap="round" stroke-linejoin="round" />
                      </svg>
                    </button>
                  </div>
                </div>
                <div :if={@promo_error} id="promo-error" class="mt-2">
                  <p class="text-xs text-[#DC2626]">{@promo_error}</p>
                </div>
              </div>
              
    <!-- Discount line -->
              <div :if={@cart_discount > 0} id="discount-line" class="mt-4">
                <div class="flex justify-between text-sm">
                  <span class="text-[#16A34A] font-medium">Discount (10%)</span>
                  <span id="summary-discount" class="font-medium text-[#16A34A]">
                    -{Currency.format_price(@cart_discount, @store.currency)}
                  </span>
                </div>
              </div>

              <div class="border-t border-[#E7E5E4] my-5"></div>
              
    <!-- Total -->
              <div class="flex justify-between items-center mb-6">
                <span class="text-base font-semibold text-[#1C1917]">Total</span>
                <span id="summary-total" class="text-2xl font-bold text-[#1C1917] font-sans">
                  {Currency.format_price(@cart_total, @store.currency)}
                </span>
              </div>
              
    <!-- Checkout Button -->
              <.link
                navigate={"/s/#{@store.slug}/checkout"}
                id="checkout-btn"
                class="flex items-center justify-center gap-2 w-full h-14 bg-[#CA8A04] text-white text-sm font-semibold tracking-widest uppercase rounded-xl hover:bg-[#A16207] transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none shadow-lg shadow-[#CA8A04]/20"
              >
                <svg
                  class="w-5 h-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                </svg>
                Proceed to Checkout
              </.link>
              
    <!-- Trust Badges -->
              <div class="mt-5 flex items-center justify-center gap-6 text-[#78716C]">
                <div class="flex items-center gap-1.5">
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <path
                      d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>
                  <span class="text-xs font-medium">Secure Checkout</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <path
                      d="M9 15 3 9m0 0 6-6M3 9h12a6 6 0 0 1 0 12h-3"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>
                  <span class="text-xs font-medium">Free Returns</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ============================================ -->
    <!-- YOU MAY ALSO LIKE -->
    <!-- ============================================ -->
    <section
      :if={@recommended_products != []}
      class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-20 sm:pb-28"
    >
      <div class="text-center mb-10">
        <h2 class="font-serif text-2xl sm:text-3xl font-semibold text-[#1C1917]">
          You May Also Like
        </h2>
        <p class="mt-2 text-sm text-[#78716C]">Curated selections to complement your style</p>
      </div>

      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
        <a
          :for={product <- @recommended_products}
          href={"/s/#{@store.slug}/products/#{product.slug}"}
          class="group cursor-pointer focus-visible:ring-2 focus-visible:ring-[#CA8A04] focus-visible:outline-none rounded-xl"
        >
          <div class="relative overflow-hidden rounded-xl bg-white border border-[#E7E5E4] aspect-[3/4]">
            <%= if product.images != [] do %>
              <img
                src={List.first(product.images).url}
                alt={product.title}
                class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                loading="lazy"
              />
            <% else %>
              <div class="w-full h-full bg-neutral-100 flex items-center justify-center text-neutral-300">
                <svg
                  class="w-12 h-12"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007ZM8.625 10.5a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm7.5 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
                  />
                </svg>
              </div>
            <% end %>
            <div class="absolute inset-0 bg-gradient-to-t from-black/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300">
            </div>
          </div>
          <div class="mt-3 px-0.5">
            <h3 class="font-serif text-base sm:text-lg font-semibold text-[#1C1917] group-hover:text-[#CA8A04] transition-colors">
              {product.title}
            </h3>
            <p class="mt-0.5 text-sm font-medium text-[#44403C]">
              {Currency.format_price(product.min_price, @store.currency)}
            </p>
          </div>
        </a>
      </div>
    </section>

    <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
    <.bottom_nav store_slug={@store.slug} active_tab={:cart} cart_count={@cart_count} />
    """
  end

  # -- Components --

  attr :index, :integer, required: true
  attr :quantity, :integer, required: true

  defp quantity_stepper(assigns) do
    ~H"""
    <div class="inline-flex items-center overflow-hidden border rounded-lg border-[#E7E5E4]">
      <button
        disabled={@quantity <= 1}
        phx-click="update_quantity"
        phx-value-index={@index}
        phx-value-delta="-1"
        class="flex items-center justify-center w-8 h-8 sm:w-9 sm:h-9 text-[#44403C] hover:text-[#1C1917] hover:bg-gray-50 transition-colors cursor-pointer disabled:text-neutral-300 disabled:cursor-not-allowed"
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
      <div class="flex items-center justify-center w-10 text-sm font-medium bg-transparent border-x sm:w-12 h-8 sm:h-9 text-[#1C1917] border-[#E7E5E4]">
        {@quantity}
      </div>
      <button
        disabled={@quantity >= 10}
        phx-click="update_quantity"
        phx-value-index={@index}
        phx-value-delta="1"
        class="flex items-center justify-center w-8 h-8 sm:w-9 sm:h-9 text-[#44403C] hover:text-[#1C1917] hover:bg-gray-50 transition-colors cursor-pointer disabled:text-neutral-300 disabled:cursor-not-allowed"
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
    total = cart_total(cart)

    _discount =
      if socket.assigns[:applied_coupon] do
        calculate_discount(socket.assigns.applied_coupon, total)
      else
        0
      end

    socket
    |> assign(:cart, cart)
    |> assign_totals(cart)
  end

  defp assign_totals(socket, cart) do
    subtotal = cart_total(cart)

    discount =
      if socket.assigns[:promo_code] == "WELCOME10" do
        trunc(subtotal * 0.10)
      else
        0
      end

    taxable = max(0, subtotal - discount)
    tax = trunc(taxable * 0.08)
    total = taxable + tax

    socket
    |> assign(:cart_count, cart_count(cart))
    |> assign(:cart_subtotal, subtotal)
    |> assign(:cart_discount, discount)
    |> assign(:cart_tax, tax)
    |> assign(:cart_total, total)
  end

  defp cart_count(cart) do
    Enum.reduce(cart, 0, fn item, acc -> acc + item.quantity end)
  end

  defp cart_total(cart) do
    Enum.reduce(cart, 0, fn item, acc -> acc + item.unit_price * item.quantity end)
  end

  defp validate_and_apply_coupon(socket, coupon) do
    now = DateTime.utc_now()
    subtotal = socket.assigns.cart_subtotal

    cond do
      not coupon.active ->
        {:noreply, assign(socket, :promo_error, "This coupon is no longer active")}

      coupon.expires_at && DateTime.compare(now, coupon.expires_at) == :gt ->
        {:noreply, assign(socket, :promo_error, "This coupon has expired")}

      coupon.starts_at && DateTime.compare(now, coupon.starts_at) == :lt ->
        {:noreply, assign(socket, :promo_error, "This coupon is not yet valid")}

      coupon.max_uses && coupon.uses_count >= coupon.max_uses ->
        {:noreply, assign(socket, :promo_error, "This coupon has reached its usage limit")}

      coupon.minimum_order_amount && subtotal < coupon.minimum_order_amount ->
        {:noreply, assign(socket, :promo_error, "Order does not meet the minimum amount")}

      true ->
        discount = calculate_discount(coupon, subtotal)

        {:noreply,
         socket
         |> assign(:applied_coupon, coupon)
         |> assign(:discount_amount, discount)
         |> assign(:promo_error, nil)}
    end
  end

  defp calculate_discount(coupon, subtotal) do
    case coupon.discount_type do
      :percentage ->
        raw = div(subtotal * coupon.discount_value, 10_000)
        if coupon.max_discount_amount, do: min(raw, coupon.max_discount_amount), else: raw

      :fixed_amount ->
        min(coupon.discount_value, subtotal)

      :free_shipping ->
        0

      _ ->
        0
    end
  end
end
