defmodule EmakolaWeb.Storefront.CheckoutLive do
  @moduledoc """
  Checkout page — accordion multi-step checkout flow with coupon support
  and rich MoMo waiting state.

  Steps:
    1. Contact & Delivery
    2. Payment Method
    3. Review & Pay
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias Emakola.Orders.CheckoutService
  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

  require Ash.Query

  @payment_poll_interval_ms 3_000
  @payment_poll_max_attempts 60

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        cart_session_id = session["cart_session_id"]
        cart = if cart_session_id, do: CartStore.get_cart(cart_session_id), else: []

        cart_total =
          Enum.reduce(cart, 0, fn item, acc -> acc + item.unit_price * item.quantity end)

        cart_count = Enum.reduce(cart, 0, fn item, acc -> acc + item.quantity end)

        categories =
          try do
            Emakola.Catalog.list_root_categories!(store.id)
          rescue
            _ -> []
          end

        theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{})
        theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:categories, categories)
         |> assign(:theme_module, theme_module)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart, cart)
         |> assign(:cart_count, cart_count)
         |> assign(:cart_total, cart_total)
         |> assign(:step, 1)
         |> assign(:payment_method, "momo")
         |> assign(:phone, "")
         |> assign(:fullname, "")
         |> assign(:address, "")
         |> assign(:region, "greater_accra")
         |> assign(:delivery_fee, 1500)
         |> assign(:notes, "")
         |> assign(:processing, false)
         |> assign(:order, nil)
         |> assign(:checkout_error, nil)
         |> assign(:payment_status, nil)
         |> assign(:poll_attempts, 0)
         |> assign(:gateway_reference, nil)
         |> assign(:coupon_code, "")
         |> assign(:coupon, nil)
         |> assign(:discount_amount, 0)
         |> assign(:coupon_error, nil)
         |> assign(:show_mobile_summary, false)
         |> assign(:form_errors, %{})
         |> assign(:timer_seconds, 180)
         |> assign(:page_title, "Checkout - #{store.name}")}

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Store not found") |> redirect(to: "/")}
    end
  end

  # -- Event Handlers -------------------------------------------------------

  @impl true
  def handle_event("select_payment", %{"method" => method}, socket),
    do: {:noreply, assign(socket, :payment_method, method)}

  @impl true
  def handle_event("go_to_step", %{"step" => step_str}, socket),
    do: {:noreply, assign(socket, :step, String.to_integer(step_str))}

  @impl true
  def handle_event("toggle_mobile_summary", _params, socket),
    do: {:noreply, assign(socket, :show_mobile_summary, !socket.assigns.show_mobile_summary)}

  @impl true
  def handle_event("update_details", params, socket) do
    {:noreply,
     socket
     |> assign(:phone, Map.get(params, "phone", socket.assigns.phone))
     |> assign(:fullname, Map.get(params, "fullname", socket.assigns.fullname))
     |> assign(:address, Map.get(params, "address", socket.assigns.address))
     |> assign(:region, Map.get(params, "region", socket.assigns.region))
     |> assign(:notes, Map.get(params, "notes", socket.assigns.notes))
     |> assign(:coupon_code, Map.get(params, "coupon_code", socket.assigns.coupon_code))
     |> assign(:form_errors, %{})
     |> update_delivery_fee()}
  end

  @impl true
  def handle_event("submit_details", params, socket) do
    socket =
      socket
      |> assign(:phone, Map.get(params, "phone", ""))
      |> assign(:fullname, Map.get(params, "fullname", ""))
      |> assign(:address, Map.get(params, "address", ""))
      |> assign(:region, Map.get(params, "region", "greater_accra"))
      |> assign(:notes, Map.get(params, "notes", ""))
      |> update_delivery_fee()

    errors = validate_contact_fields(socket.assigns)

    if errors == %{} do
      {:noreply, socket |> assign(:form_errors, %{}) |> assign(:step, 2)}
    else
      {:noreply, assign(socket, :form_errors, errors)}
    end
  end

  @impl true
  def handle_event("apply_coupon", %{"coupon_code" => code}, socket) do
    case CheckoutService.validate_coupon(
           socket.assigns.store.id,
           code,
           socket.assigns.cart_total
         ) do
      {:ok, coupon} ->
        discount =
          CheckoutService.calculate_discount(
            coupon,
            socket.assigns.cart_total,
            socket.assigns.delivery_fee
          )

        {:noreply,
         socket
         |> assign(
           coupon: coupon,
           coupon_code: code,
           discount_amount: discount,
           coupon_error: nil
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(
           coupon_error: coupon_error_message(reason),
           coupon: nil,
           discount_amount: 0
         )}
    end
  end

  @impl true
  def handle_event("remove_coupon", _params, socket) do
    {:noreply,
     socket |> assign(coupon: nil, coupon_code: "", discount_amount: 0, coupon_error: nil)}
  end

  @impl true
  def handle_event("place_order", params, socket) do
    # Update fields from form params
    socket =
      socket
      |> assign(:phone, Map.get(params, "phone", socket.assigns.phone))
      |> assign(:fullname, Map.get(params, "fullname", socket.assigns.fullname))
      |> assign(:address, Map.get(params, "address", socket.assigns.address))
      |> assign(:region, Map.get(params, "region", socket.assigns.region))
      |> assign(:notes, Map.get(params, "notes", socket.assigns.notes))
      |> update_delivery_fee()

    errors = validate_contact_fields(socket.assigns)

    cond do
      errors != %{} ->
        {:noreply, assign(socket, :form_errors, errors)}

      socket.assigns.cart == [] ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, "Your cart is empty -- please add items before checking out")}

      true ->
        socket = assign(socket, processing: true, form_errors: %{})

        case create_order(socket) do
          {:ok, order} ->
            socket = assign(socket, :order, order)
            handle_payment(socket, order)

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:processing, false)
             |> put_flash(:error, checkout_error_message(reason))}
        end
    end
  end

  @impl true
  def handle_event("retry_payment", _params, socket) do
    if socket.assigns.order do
      handle_payment(
        assign(socket, processing: true, checkout_error: nil, timer_seconds: 180),
        socket.assigns.order
      )
    else
      {:noreply, put_flash(socket, :error, "No order to retry payment for")}
    end
  end

  # -- Info Handlers --------------------------------------------------------

  @impl true
  def handle_info(:poll_payment_status, socket) do
    order = socket.assigns.order
    poll_attempts = socket.assigns.poll_attempts

    if poll_attempts >= @payment_poll_max_attempts do
      {:noreply,
       socket
       |> assign(:processing, false)
       |> assign(:payment_status, :timeout)
       |> put_flash(:error, "Payment verification timed out.")}
    else
      case verify_payment_status(socket) do
        :success ->
          if socket.assigns[:cart_session_id],
            do: CartStore.clear_cart(socket.assigns.cart_session_id)

          {:noreply,
           socket
           |> assign(:processing, false)
           |> redirect(
             to: "/s/#{socket.assigns.store.slug}/orders/#{order.order_number}/confirmation"
           )}

        :failed ->
          {:noreply,
           socket
           |> assign(:processing, false)
           |> assign(:payment_status, :failed)
           |> put_flash(:error, "Payment failed. Please try again.")}

        :pending ->
          Process.send_after(self(), :poll_payment_status, @payment_poll_interval_ms)
          {:noreply, assign(socket, :poll_attempts, poll_attempts + 1)}
      end
    end
  end

  @impl true
  def handle_info(:tick_timer, socket) do
    if socket.assigns.timer_seconds > 0 and socket.assigns.payment_status == :awaiting_payment do
      Process.send_after(self(), :tick_timer, 1000)
      {:noreply, assign(socket, :timer_seconds, socket.assigns.timer_seconds - 1)}
    else
      {:noreply, socket}
    end
  end

  # -- Render ---------------------------------------------------------------

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:order_total, calculate_order_total(assigns))
      |> assign(:effective_delivery_fee, effective_delivery_fee(assigns))

    ~H"""
    <div class="min-h-screen flex flex-col bg-stone-50 font-[Montserrat,system-ui,sans-serif] text-stone-950 antialiased">
      <%!-- Minimal Navigation --%>
      <header class="border-b border-stone-200 bg-white/80 backdrop-blur-md sticky top-0 z-50">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <a
              href={"/s/#{@store.slug}/cart"}
              class="cursor-pointer flex items-center gap-2 text-stone-600 hover:text-stone-900 transition-colors text-sm font-medium rounded-lg px-2 py-1 -ml-2"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
              </svg>
              Back to Bag
            </a>
            <span class="absolute left-1/2 -translate-x-1/2 font-[Cormorant,Georgia,serif] text-2xl sm:text-3xl font-semibold tracking-[0.15em] text-stone-900">
              {String.upcase(@store.name)}
            </span>
            <div class="flex items-center gap-2 text-stone-600 text-sm font-medium">
              <svg class="w-4 h-4 text-amber-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                <path d="M7 11V7a5 5 0 0 1 10 0v4" />
              </svg>
              <span class="hidden sm:inline">Secure Checkout</span>
            </div>
          </div>
        </div>
      </header>

      <%!-- Checkout Progress Stepper --%>
      <div class="bg-white border-b border-stone-100">
        <div class="max-w-2xl mx-auto px-4 sm:px-6 py-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-full bg-amber-600 text-white flex items-center justify-center text-xs font-semibold shadow-sm shadow-amber-600/20">1</div>
              <span class="text-sm font-semibold text-stone-900 hidden sm:inline">Information</span>
            </div>
            <div class="h-0.5 flex-1 bg-stone-200 mx-3 sm:mx-4 rounded-full"></div>
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-full border-2 border-stone-300 text-stone-400 flex items-center justify-center text-xs font-semibold">2</div>
              <span class="text-sm font-medium text-stone-400 hidden sm:inline">Shipping</span>
            </div>
            <div class="h-0.5 flex-1 bg-stone-200 mx-3 sm:mx-4 rounded-full"></div>
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-full border-2 border-stone-300 text-stone-400 flex items-center justify-center text-xs font-semibold">3</div>
              <span class="text-sm font-medium text-stone-400 hidden sm:inline">Payment</span>
            </div>
          </div>
        </div>
      </div>

      <main class="flex-1 py-8 sm:py-12">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <%!-- MoMo Waiting State --%>
          <div :if={@payment_status == :awaiting_payment} class="max-w-lg mx-auto">
            <.momo_waiting_state
              payment_method={@payment_method}
              order={@order}
              phone={@phone}
              timer_seconds={@timer_seconds}
            />
          </div>

          <%!-- Payment Failed State --%>
          <div :if={@payment_status == :failed} class="max-w-lg mx-auto mb-6">
            <div class="bg-red-50 border border-red-200 rounded-xl p-6 text-center">
              <div class="w-12 h-12 mx-auto mb-3 bg-red-100 rounded-full flex items-center justify-center">
                <svg class="w-6 h-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
              <h3 class="font-[Cormorant,Georgia,serif] text-2xl font-semibold text-red-900 mb-1">Payment failed</h3>
              <p class="text-sm text-red-700 mb-4">The payment was not completed. Please try again.</p>
              <button phx-click="retry_payment" class="cursor-pointer inline-flex items-center px-8 py-3.5 bg-amber-600 text-white rounded-xl text-sm font-semibold hover:bg-amber-700 transition-colors">
                Retry Payment
              </button>
            </div>
          </div>

          <%!-- Payment Timeout State --%>
          <div :if={@payment_status == :timeout} class="max-w-lg mx-auto mb-6">
            <div class="bg-amber-50 border border-amber-200 rounded-xl p-6 text-center">
              <div class="w-12 h-12 mx-auto mb-3 bg-amber-100 rounded-full flex items-center justify-center">
                <svg class="w-6 h-6 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                </svg>
              </div>
              <h3 class="font-[Cormorant,Georgia,serif] text-2xl font-semibold text-amber-900 mb-1">Payment timed out</h3>
              <p class="text-sm text-amber-700 mb-4">We didn't receive a response in time. You can try again.</p>
              <button phx-click="retry_payment" class="cursor-pointer inline-flex items-center px-8 py-3.5 bg-amber-600 text-white rounded-xl text-sm font-semibold hover:bg-amber-700 transition-colors">
                Retry Payment
              </button>
            </div>
          </div>

          <%!-- Main Checkout Content: Two-Column Layout --%>
          <div :if={@payment_status not in [:awaiting_payment, :failed, :timeout]} class="lg:grid lg:grid-cols-5 lg:gap-12 xl:gap-16">

            <%!-- LEFT COLUMN: Checkout Form (60%) --%>
            <div class="lg:col-span-3">
              <form phx-submit="place_order" phx-change="update_details" novalidate class="space-y-10">

                <%!-- SECTION 1: Contact Information --%>
                <section>
                  <h2 class="font-[Cormorant,Georgia,serif] text-2xl sm:text-3xl font-semibold text-stone-900 mb-6">Contact</h2>
                  <div class="space-y-4">
                    <div>
                      <label for="phone" class="block text-sm font-medium text-stone-900 mb-1.5">
                        Phone number <span class="text-amber-600">*</span>
                      </label>
                      <div class="relative">
                        <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                          <svg class="w-4 h-4 text-stone-400" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 4.5v2.25z" />
                          </svg>
                        </div>
                        <input
                          type="tel"
                          id="phone"
                          name="phone"
                          value={@phone}
                          placeholder="+233 24 123 4567"
                          class={"w-full bg-white border rounded-xl pl-11 pr-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-amber-600/30 focus:border-amber-600 transition-all #{if @form_errors[:phone], do: "border-red-400 bg-red-50", else: "border-stone-200"}"}
                        />
                      </div>
                      <p :if={@form_errors[:phone]} class="text-xs text-red-600 mt-1">{@form_errors[:phone]}</p>
                    </div>

                    <div>
                      <label for="fullname" class="block text-sm font-medium text-stone-900 mb-1.5">
                        Full name <span class="text-amber-600">*</span>
                      </label>
                      <input
                        type="text"
                        id="fullname"
                        name="fullname"
                        value={@fullname}
                        placeholder="Ama Mensah"
                        class={"w-full bg-white border rounded-xl px-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-amber-600/30 focus:border-amber-600 transition-all #{if @form_errors[:fullname], do: "border-red-400 bg-red-50", else: "border-stone-200"}"}
                      />
                      <p :if={@form_errors[:fullname]} class="text-xs text-red-600 mt-1">{@form_errors[:fullname]}</p>
                    </div>
                  </div>
                </section>

                <div class="border-t border-stone-200"></div>

                <%!-- SECTION 2: Shipping Address --%>
                <section>
                  <h2 class="font-[Cormorant,Georgia,serif] text-2xl sm:text-3xl font-semibold text-stone-900 mb-6">Shipping Address</h2>
                  <div class="space-y-4">
                    <div>
                      <label for="address" class="block text-sm font-medium text-stone-900 mb-1.5">
                        Address <span class="text-amber-600">*</span>
                      </label>
                      <input
                        type="text"
                        id="address"
                        name="address"
                        value={@address}
                        placeholder="House 14, Osu Badu Street"
                        class={"w-full bg-white border rounded-xl px-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-amber-600/30 focus:border-amber-600 transition-all #{if @form_errors[:address], do: "border-red-400 bg-red-50", else: "border-stone-200"}"}
                      />
                      <p :if={@form_errors[:address]} class="text-xs text-red-600 mt-1">{@form_errors[:address]}</p>
                    </div>

                    <div>
                      <label for="region" class="block text-sm font-medium text-stone-900 mb-1.5">
                        Region <span class="text-amber-600">*</span>
                      </label>
                      <div class="relative">
                        <select
                          id="region"
                          name="region"
                          class="cursor-pointer w-full bg-white border border-stone-200 rounded-xl px-4 py-3.5 text-sm text-stone-900 appearance-none focus:ring-2 focus:ring-amber-600/30 focus:border-amber-600 transition-all"
                        >
                          <option value="greater_accra" selected={@region == "greater_accra"}>Greater Accra</option>
                          <option value="ashanti" selected={@region == "ashanti"}>Ashanti</option>
                          <option value="central" selected={@region == "central"}>Central</option>
                          <option value="western" selected={@region == "western"}>Western</option>
                          <option value="eastern" selected={@region == "eastern"}>Eastern</option>
                          <option value="northern" selected={@region == "northern"}>Northern</option>
                          <option value="volta" selected={@region == "volta"}>Volta</option>
                          <option value="other" selected={@region == "other"}>Other</option>
                        </select>
                        <div class="absolute inset-y-0 right-0 pr-4 flex items-center pointer-events-none">
                          <svg class="w-4 h-4 text-stone-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
                          </svg>
                        </div>
                      </div>
                    </div>

                    <div>
                      <label for="notes" class="block text-sm font-medium text-stone-900 mb-1.5">
                        Delivery notes <span class="text-stone-400 font-normal">(optional)</span>
                      </label>
                      <input
                        type="text"
                        id="notes"
                        name="notes"
                        value={@notes}
                        placeholder="Landmark, special instructions, etc."
                        class="w-full bg-white border border-stone-200 rounded-xl px-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-amber-600/30 focus:border-amber-600 transition-all"
                      />
                    </div>
                  </div>
                </section>

                <div class="border-t border-stone-200"></div>

                <%!-- SECTION 3: Delivery Method --%>
                <section>
                  <h2 class="font-[Cormorant,Georgia,serif] text-2xl sm:text-3xl font-semibold text-stone-900 mb-6">Delivery Method</h2>
                  <div class="space-y-3">
                    <%!-- Standard Delivery (selected based on region) --%>
                    <div class="flex items-center justify-between p-4 sm:p-5 bg-white border-2 border-amber-600 bg-amber-50/40 rounded-xl">
                      <div class="flex items-center gap-4">
                        <div class="w-5 h-5 rounded-full border-2 border-amber-600 flex items-center justify-center shrink-0">
                          <div class="w-2.5 h-2.5 rounded-full bg-amber-600"></div>
                        </div>
                        <div>
                          <p class="text-sm font-semibold text-stone-900">Standard Delivery</p>
                          <p class="text-xs text-stone-600 mt-0.5">{delivery_estimate(@region)}</p>
                        </div>
                      </div>
                      <span class="text-sm font-semibold text-stone-900">
                        {Currency.format_price(@delivery_fee, @store.currency)}
                      </span>
                    </div>

                    <%!-- Express Delivery --%>
                    <div class="flex items-center justify-between p-4 sm:p-5 bg-white border-2 border-stone-200 rounded-xl opacity-50">
                      <div class="flex items-center gap-4">
                        <div class="w-5 h-5 rounded-full border-2 border-stone-300 flex items-center justify-center shrink-0"></div>
                        <div>
                          <p class="text-sm font-semibold text-stone-900">Express Delivery</p>
                          <p class="text-xs text-stone-600 mt-0.5">Next business day</p>
                        </div>
                      </div>
                      <span class="text-xs font-medium text-stone-400">Coming soon</span>
                    </div>
                  </div>
                </section>

                <div class="border-t border-stone-200"></div>

                <%!-- SECTION 4: Payment Method --%>
                <section>
                  <h2 class="font-[Cormorant,Georgia,serif] text-2xl sm:text-3xl font-semibold text-stone-900 mb-6">Payment</h2>
                  <%!-- Payment Method Tabs --%>
                  <div class="flex border-b border-stone-200 mb-6" role="tablist">
                    <button
                      :for={
                        {method, label, icon_path} <- [
                          {"momo", "Mobile Money", "M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"},
                          {"card", "Card", "M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v10.5a2.25 2.25 0 002.25 2.25z"},
                          {"cod", "Cash on Delivery", "M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z"}
                        ]
                      }
                      type="button"
                      phx-click="select_payment"
                      phx-value-method={method}
                      role="tab"
                      aria-selected={@payment_method == method}
                      class={"cursor-pointer flex items-center gap-2 px-4 sm:px-5 py-3 text-sm font-medium transition-colors border-b-2 -mb-px #{if @payment_method == method, do: "border-stone-900 text-stone-900", else: "border-transparent text-stone-400 hover:text-stone-600"}"}
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d={icon_path} />
                      </svg>
                      {label}
                    </button>
                  </div>

                  <%!-- Mobile Money Fields --%>
                  <div :if={@payment_method == "momo"} class="space-y-4">
                    <p class="text-sm text-stone-600">
                      You will receive a payment prompt on your phone. Approve it to complete the purchase.
                    </p>
                    <div class="flex items-start gap-3 pt-1">
                      <svg class="w-5 h-5 text-amber-600 mt-0.5 shrink-0" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
                      </svg>
                      <span class="text-sm text-stone-600">Secured by Paystack. Your phone number will be used to send the payment prompt.</span>
                    </div>
                  </div>

                  <%!-- Card Payment Info --%>
                  <div :if={@payment_method == "card"} class="space-y-4">
                    <p class="text-sm text-stone-600">
                      You will be securely redirected to Paystack to complete your card payment.
                    </p>
                    <div class="flex items-start gap-3 pt-1">
                      <svg class="w-5 h-5 text-amber-600 mt-0.5 shrink-0" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
                      </svg>
                      <span class="text-sm text-stone-600">Visa, Mastercard, and Verve accepted. Secured by Paystack.</span>
                    </div>
                  </div>

                  <%!-- Cash on Delivery Info --%>
                  <div :if={@payment_method == "cod"} class="space-y-4">
                    <p class="text-sm text-stone-600">
                      Pay with cash or mobile money when your order is delivered.
                    </p>
                    <div class="flex items-start gap-3 pt-1">
                      <svg class="w-5 h-5 text-amber-600 mt-0.5 shrink-0" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" />
                      </svg>
                      <span class="text-sm text-stone-600">Please have the exact amount ready. Our delivery agent will confirm your order on arrival.</span>
                    </div>
                  </div>

                  <%!-- Coupon Code --%>
                  <div class="mt-6 pt-6 border-t border-stone-200">
                    <label class="block text-sm font-medium text-stone-900 mb-1.5">Promo code</label>
                    <div class="flex gap-2">
                      <input
                        type="text"
                        name="coupon_code"
                        value={@coupon_code}
                        placeholder="Enter code"
                        disabled={@coupon != nil}
                        phx-keydown=""
                        class={"flex-1 bg-white border rounded-xl px-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-amber-600/30 focus:border-amber-600 transition-all #{if @coupon_error, do: "border-red-400", else: "border-stone-200"} disabled:bg-stone-50 disabled:text-stone-400"}
                      />
                      <button
                        :if={@coupon == nil}
                        type="button"
                        phx-click="apply_coupon"
                        phx-value-coupon_code={@coupon_code}
                        class="cursor-pointer px-5 py-3.5 border border-stone-200 rounded-xl text-sm font-medium text-stone-600 hover:bg-stone-50 transition-colors"
                      >
                        Apply
                      </button>
                      <button
                        :if={@coupon != nil}
                        type="button"
                        phx-click="remove_coupon"
                        class="cursor-pointer px-5 py-3.5 border border-red-200 rounded-xl text-sm font-medium text-red-600 hover:bg-red-50 transition-colors"
                      >
                        Remove
                      </button>
                    </div>
                    <p :if={@coupon_error} class="text-xs text-red-600 mt-1">{@coupon_error}</p>
                    <p :if={@coupon} class="text-xs text-emerald-600 mt-1">
                      Coupon applied: -{Currency.format_price(@discount_amount, @store.currency)} off
                    </p>
                  </div>
                </section>

                <%!-- Place Order Button --%>
                <div>
                  <div :if={@checkout_error} class="mb-4 bg-red-50 border border-red-200 rounded-xl p-4">
                    <p class="text-sm text-red-700">{@checkout_error}</p>
                  </div>

                  <button
                    type="submit"
                    disabled={@processing}
                    class="cursor-pointer w-full bg-amber-600 text-white py-4 rounded-xl text-sm font-semibold hover:bg-amber-700 disabled:bg-stone-200 disabled:text-stone-400 transition-colors shadow-sm shadow-amber-600/20"
                  >
                    <%= if @processing do %>
                      <span class="inline-flex items-center gap-2">
                        <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                        </svg>
                        Processing...
                      </span>
                    <% else %>
                      Place Order -- {Currency.format_price(@order_total, @store.currency)}
                    <% end %>
                  </button>

                  <div class="flex items-center justify-center gap-2 mt-4 text-xs text-stone-400">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                      <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                    </svg>
                    Your payment information is encrypted and secure
                  </div>
                </div>
              </form>
            </div>

            <%!-- RIGHT COLUMN: Order Summary Sidebar (40%) --%>
            <div class="lg:col-span-2 mt-10 lg:mt-0">
              <div class="sticky top-24">
                <div class="bg-white border border-stone-200 rounded-2xl p-6 shadow-sm">
                  <%!-- Header --%>
                  <div class="flex items-center justify-between mb-5">
                    <h2 class="font-[Cormorant,Georgia,serif] text-xl font-semibold text-stone-900">Order Summary</h2>
                    <a href={"/s/#{@store.slug}/cart"} class="text-sm font-medium text-amber-600 hover:text-amber-700 transition-colors">Edit</a>
                  </div>

                  <%!-- Cart Items --%>
                  <div class="space-y-4 mb-6">
                    <div :for={item <- @cart} class="flex gap-3.5">
                      <div class="w-16 h-16 bg-stone-100 rounded-xl flex-shrink-0 overflow-hidden">
                        <img
                          :if={item[:image_url]}
                          src={item[:image_url]}
                          alt={item.product_title}
                          class="w-full h-full object-cover"
                        />
                        <div :if={!item[:image_url]} class="w-full h-full flex items-center justify-center">
                          <svg class="w-6 h-6 text-stone-300" fill="none" stroke="currentColor" stroke-width="1" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                        </div>
                      </div>
                      <div class="flex-1 min-w-0">
                        <h3 class="text-sm font-semibold text-stone-900 truncate">{item.product_title}</h3>
                        <p :if={item[:variant_info]} class="text-xs text-stone-500 mt-0.5">{item[:variant_info]}</p>
                        <p class="text-xs text-stone-500">Qty: {item.quantity}</p>
                      </div>
                      <p class="text-sm font-semibold text-stone-900 flex-shrink-0">
                        {Currency.format_price(item.unit_price * item.quantity, @store.currency)}
                      </p>
                    </div>
                    <div :if={@cart == []} class="text-sm text-stone-400 py-4 text-center">Your cart is empty</div>
                  </div>

                  <%!-- Price Breakdown --%>
                  <div class="border-t border-stone-200 pt-4 space-y-2.5 text-sm">
                    <div class="flex justify-between">
                      <span class="text-stone-500">Subtotal</span>
                      <span class="font-medium text-stone-900">{Currency.format_price(@cart_total, @store.currency)}</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-stone-500">Shipping</span>
                      <span class={"font-medium #{if @effective_delivery_fee == 0, do: "text-emerald-600", else: "text-stone-900"}"}>
                        {if @effective_delivery_fee == 0, do: "Free", else: Currency.format_price(@effective_delivery_fee, @store.currency)}
                      </span>
                    </div>
                    <div :if={@discount_amount > 0} class="flex justify-between">
                      <div class="flex items-center gap-1.5">
                        <span class="text-stone-500">Promo</span>
                        <span class="inline-flex items-center gap-1 text-xs font-medium text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full">
                          <svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>
                          {String.upcase(@coupon_code)}
                        </span>
                      </div>
                      <span class="font-medium text-emerald-600">-{Currency.format_price(@discount_amount, @store.currency)}</span>
                    </div>
                  </div>

                  <%!-- Total --%>
                  <div class="border-t border-stone-200 mt-4 pt-4 flex justify-between items-baseline">
                    <span class="font-[Cormorant,Georgia,serif] text-lg font-semibold text-stone-900">Total</span>
                    <span class="font-[Cormorant,Georgia,serif] text-2xl font-bold text-stone-900">{Currency.format_price(@order_total, @store.currency)}</span>
                  </div>

                  <%!-- Trust Badges --%>
                  <div class="grid grid-cols-3 gap-3 mt-6 pt-6 border-t border-stone-100">
                    <div class="flex flex-col items-center gap-1.5 text-center">
                      <svg class="w-5 h-5 text-stone-400" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3" />
                      </svg>
                      <p class="text-xs text-stone-500 leading-tight"><span class="font-semibold text-stone-700 block">Free</span>Returns</p>
                    </div>
                    <div class="flex flex-col items-center gap-1.5 text-center">
                      <svg class="w-5 h-5 text-stone-400" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
                      </svg>
                      <p class="text-xs text-stone-500 leading-tight"><span class="font-semibold text-stone-700 block">Secure</span>Payment</p>
                    </div>
                    <div class="flex flex-col items-center gap-1.5 text-center">
                      <svg class="w-5 h-5 text-stone-400" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" />
                      </svg>
                      <p class="text-xs text-stone-500 leading-tight"><span class="font-semibold text-stone-700 block">100%</span>Authentic</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>

      <%!-- Minimal Footer --%>
      <footer class="border-t border-stone-200 bg-white mt-auto">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex flex-col sm:flex-row items-center justify-between gap-4">
            <p class="text-xs text-stone-400">&copy; 2026 {String.upcase(@store.name)}. All rights reserved.</p>
            <div class="flex items-center gap-6">
              <a href="#" class="text-xs text-stone-400 hover:text-stone-600 transition-colors">Privacy Policy</a>
              <a href="#" class="text-xs text-stone-400 hover:text-stone-600 transition-colors">Terms of Service</a>
              <a href="#" class="text-xs text-stone-400 hover:text-stone-600 transition-colors">Refund Policy</a>
            </div>
          </div>
        </div>
      </footer>
    </div>
    """
  end

  # -- Components -----------------------------------------------------------

  attr :payment_method, :string, required: true
  attr :order, :any, required: true
  attr :phone, :string, required: true
  attr :timer_seconds, :integer, required: true

  defp momo_waiting_state(assigns) do
    assigns =
      assigns
      |> assign(:brand_color, momo_brand_color(assigns.payment_method))
      |> assign(:brand_name, momo_brand_name(assigns.payment_method))
      |> assign(:timer_display, format_timer(assigns.timer_seconds))
      |> assign(:masked_phone, mask_phone(assigns.phone))

    ~H"""
    <div class="bg-white border border-stone-200 rounded-2xl p-8">
      <div class="flex justify-center mb-6">
        <div class="relative">
          <div class="w-20 h-20 rounded-full flex items-center justify-center animate-pulse" style={"background-color: #{@brand_color}20;"}>
            <div class="w-14 h-14 rounded-full flex items-center justify-center" style={"background-color: #{@brand_color}30;"}>
              <svg class="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke={@brand_color}>
                <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3" />
              </svg>
            </div>
          </div>
        </div>
      </div>

      <h3 class="font-[Cormorant,Georgia,serif] text-2xl font-semibold text-stone-900 text-center mb-1">Approve on your phone</h3>
      <p class="text-sm text-stone-600 text-center mb-8">
        A {@brand_name} payment prompt has been sent to your phone
      </p>

      <div class="space-y-4 mb-8">
        <div class="flex items-start gap-3">
          <div class="w-6 h-6 rounded-full bg-emerald-600 flex items-center justify-center flex-shrink-0 mt-0.5">
            <svg class="w-3.5 h-3.5 text-white" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
            </svg>
          </div>
          <div>
            <p class="text-sm font-medium text-stone-900">Order created</p>
            <p :if={@order} class="text-xs text-stone-500">#{@order.order_number}</p>
          </div>
        </div>
        <div class="flex items-start gap-3">
          <div class="w-6 h-6 rounded-full bg-emerald-600 flex items-center justify-center flex-shrink-0 mt-0.5">
            <svg class="w-3.5 h-3.5 text-white" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
            </svg>
          </div>
          <div>
            <p class="text-sm font-medium text-stone-900">Payment request sent</p>
            <p class="text-xs text-stone-500">+233 {@masked_phone}</p>
          </div>
        </div>
        <div class="flex items-start gap-3">
          <div class="w-6 h-6 rounded-full bg-amber-100 flex items-center justify-center flex-shrink-0 mt-0.5">
            <div class="w-2.5 h-2.5 rounded-full bg-amber-500 animate-pulse" />
          </div>
          <div>
            <p class="text-sm font-medium text-stone-900">Awaiting approval</p>
            <p class="text-xs text-stone-500">Dial *170# if you don't see the prompt</p>
          </div>
        </div>
      </div>

      <div class="text-center mb-4">
        <div class="inline-flex items-center gap-2 bg-stone-50 rounded-xl px-5 py-2.5">
          <svg class="w-4 h-4 text-stone-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
          </svg>
          <span class="text-sm font-mono font-semibold text-stone-900">{@timer_display}</span>
        </div>
      </div>

      <p class="text-center text-xs text-stone-400">
        Didn't receive the prompt?
        <a href="#" class="text-amber-600 font-medium hover:underline">Get help</a>
      </p>
    </div>
    """
  end

  # -- Private Helpers ------------------------------------------------------

  defp create_order(socket) do
    %{
      store: store,
      cart: cart,
      phone: phone,
      fullname: fullname,
      address: address,
      region: region,
      notes: notes
    } = socket.assigns

    items = Enum.map(cart, fn item -> %{variant_id: item.variant_id, quantity: item.quantity} end)

    shipping_address = %{
      "name" => fullname,
      "phone" => "+233#{phone}",
      "address" => address,
      "region" => region
    }

    delivery_fee = socket.assigns[:delivery_fee] || 0

    opts = [
      notes: notes,
      shipping_address: shipping_address,
      delivery_fee: delivery_fee
    ]

    opts =
      if socket.assigns.coupon do
        Keyword.put(opts, :coupon_id, socket.assigns.coupon.id)
      else
        opts
      end

    CheckoutService.checkout!(store.id, items, opts)
  end

  defp handle_payment(socket, order) do
    case socket.assigns.payment_method do
      "cod" ->
        if socket.assigns[:cart_session_id],
          do: CartStore.clear_cart(socket.assigns.cart_session_id)

        {:noreply,
         socket
         |> assign(:processing, false)
         |> redirect(
           to: "/s/#{socket.assigns.store.slug}/orders/#{order.order_number}/confirmation"
         )}

      method when method in ["momo", "vodafone", "card"] ->
        initiate_gateway_payment(socket, order, method)

      _ ->
        {:noreply,
         socket |> assign(:processing, false) |> put_flash(:error, "Unknown payment method")}
    end
  end

  defp initiate_gateway_payment(socket, order, method) do
    store = socket.assigns.store
    gateway = Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)

    params = %{
      amount: order.total,
      email: "#{socket.assigns.phone}@checkout.emakola.com",
      currency: store.currency || "GHS",
      order_id: order.id,
      store_id: store.id,
      order_reference: order.order_number,
      callback_url:
        "#{EmakolaWeb.Endpoint.url()}/s/#{store.slug}/orders/#{order.order_number}/confirmation",
      return_url:
        "#{EmakolaWeb.Endpoint.url()}/s/#{store.slug}/orders/#{order.order_number}/confirmation",
      channel: paystack_channel(method),
      metadata: %{payment_method: method}
    }

    case gateway.initiate_payment(params) do
      {:ok, %{reference: reference} = resp} ->
        Emakola.Payments.Payment
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          order_id: order.id,
          amount: order.total,
          currency: store.currency || "GHS",
          gateway: :paystack,
          gateway_reference: reference,
          metadata: %{payment_method: method}
        })
        |> Ash.create()

        if method == "card" do
          url = Map.get(resp, :authorization_url, "")

          if url != "",
            do: {:noreply, socket |> assign(:processing, false) |> redirect(external: url)},
            else:
              {:noreply,
               socket
               |> assign(:processing, false)
               |> redirect(to: "/s/#{store.slug}/orders/#{order.order_number}/confirmation")}
        else
          Process.send_after(self(), :poll_payment_status, @payment_poll_interval_ms)
          Process.send_after(self(), :tick_timer, 1000)

          {:noreply,
           socket
           |> assign(:payment_status, :awaiting_payment)
           |> assign(:gateway_reference, reference)
           |> assign(:timer_seconds, 180)}
        end

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> assign(:checkout_error, "Payment initiation failed.")
         |> put_flash(:error, "Payment error: #{inspect(reason)}")}
    end
  end

  defp verify_payment_status(socket) do
    ref = socket.assigns[:gateway_reference]

    if ref do
      gateway =
        Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)

      case gateway.verify_payment(ref) do
        {:ok, %{status: status}} when status in [:success, "success", "Paid", "Success"] ->
          :success

        {:ok, %{status: status}} when status in [:failed, "failed", "Failed", "Expired"] ->
          :failed

        _ ->
          :pending
      end
    else
      :pending
    end
  end

  defp paystack_channel("momo"), do: "mobile_money"
  defp paystack_channel("vodafone"), do: "mobile_money"
  defp paystack_channel("card"), do: "card"
  defp paystack_channel(_), do: "mobile_money"

  defp update_delivery_fee(socket) do
    fee =
      case socket.assigns.region do
        "greater_accra" -> 1500
        "ashanti" -> 2500
        "central" -> 2500
        _ -> 3500
      end

    assign(socket, :delivery_fee, fee)
  end

  defp validate_contact_fields(assigns) do
    errors = %{}

    errors =
      if assigns.phone == "",
        do: Map.put(errors, :phone, "Phone number is required"),
        else: errors

    errors =
      if assigns.fullname == "",
        do: Map.put(errors, :fullname, "Full name is required"),
        else: errors

    if assigns.address == "",
      do: Map.put(errors, :address, "Delivery address is required"),
      else: errors
  end

  defp calculate_order_total(assigns) do
    max(assigns.cart_total - assigns.discount_amount + effective_delivery_fee(assigns), 0)
  end

  defp effective_delivery_fee(assigns) do
    if assigns.coupon && Map.get(assigns.coupon, :type) == :free_shipping do
      0
    else
      assigns.delivery_fee
    end
  end

  defp delivery_estimate("greater_accra"), do: "1-2 business days"
  defp delivery_estimate("ashanti"), do: "2-4 business days"
  defp delivery_estimate("central"), do: "2-4 business days"
  defp delivery_estimate(_), do: "3-5 business days"

  defp momo_brand_color("momo"), do: "#FFC107"
  defp momo_brand_color("vodafone"), do: "#E60000"
  defp momo_brand_color(_), do: "#F59E0B"

  defp momo_brand_name("momo"), do: "MTN Mobile Money"
  defp momo_brand_name("vodafone"), do: "Vodafone Cash"
  defp momo_brand_name(_), do: "Mobile Money"

  defp format_timer(seconds) do
    mins = div(seconds, 60)
    secs = rem(seconds, 60)

    "#{String.pad_leading(Integer.to_string(mins), 2, "0")}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp mask_phone(phone) when byte_size(phone) > 4 do
    visible = String.slice(phone, -4, 4)
    masked = String.duplicate("*", max(String.length(phone) - 4, 0))
    "#{masked}#{visible}"
  end

  defp mask_phone(phone), do: phone

  defp checkout_error_message(:empty_cart), do: "Your cart is empty"
  defp checkout_error_message(:variant_not_found), do: "Some items are no longer available"
  defp checkout_error_message(:variant_not_in_store), do: "Some items are not from this store"
  defp checkout_error_message(:insufficient_stock), do: "Some items are out of stock"
  defp checkout_error_message(_), do: "Something went wrong. Please try again."

  defp coupon_error_message(:coupon_not_found), do: "Coupon code not found"
  defp coupon_error_message(:coupon_inactive), do: "This coupon is no longer active"
  defp coupon_error_message(:coupon_expired), do: "This coupon has expired"
  defp coupon_error_message(:coupon_not_started), do: "This coupon is not yet active"
  defp coupon_error_message(:coupon_minimum_not_met), do: "Order does not meet the minimum amount"

  defp coupon_error_message(:coupon_max_uses_reached),
    do: "This coupon has reached its usage limit"

  defp coupon_error_message(_), do: "Invalid coupon code"
end
