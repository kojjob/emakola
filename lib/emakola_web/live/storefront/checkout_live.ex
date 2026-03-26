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

        {:ok,
         socket
         |> assign(:store, store)
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
  def handle_event("place_order", _params, socket) do
    socket = assign(socket, :processing, true)

    if socket.assigns.cart == [] do
      {:noreply,
       socket
       |> assign(:processing, false)
       |> put_flash(:error, "Your cart is empty -- please add items before checking out")}
    else
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
    <div class="min-h-screen flex flex-col bg-[#FAFAF9]">
      <%!-- Header --%>
      <header class="bg-white border-b border-[#E2E8F0] sticky top-0 z-50">
        <div class="max-w-5xl mx-auto px-4 h-14 flex items-center justify-between">
          <a
            href={"/s/#{@store.slug}/cart"}
            class="flex items-center gap-1.5 text-[#475569] hover:text-[#0F172A] transition-colors text-sm font-medium"
          >
            <svg
              class="w-5 h-5"
              fill="none"
              viewBox="0 0 20 20"
              stroke="currentColor"
              stroke-width="1.5"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M12.5 15L7.5 10L12.5 5" />
            </svg>
            <span class="hidden sm:inline">Back to bag</span>
          </a>
          <span class="text-sm font-semibold text-[#0F172A] tracking-tight">{@store.name}</span>
          <div class="flex items-center gap-1.5 text-[#94A3B8] text-xs">
            <svg
              class="w-4 h-4"
              fill="none"
              viewBox="0 0 16 16"
              stroke="currentColor"
              stroke-width="1.5"
            >
              <rect x="3" y="7" width="10" height="7" rx="1.5" />
              <path
                d="M5 7V5C5 3.34315 6.34315 2 8 2C9.65685 2 11 3.34315 11 5V7"
                stroke-linecap="round"
              />
            </svg>
            <span class="hidden sm:inline">Secure checkout</span>
          </div>
        </div>
      </header>

      <%!-- Progress Bar --%>
      <div class="bg-white border-b border-[#E2E8F0]">
        <div class="max-w-5xl mx-auto px-4 py-3">
          <div class="flex gap-2">
            <div class={"h-1 flex-1 rounded-full #{if @step >= 1, do: "bg-[#059669]", else: "bg-[#E2E8F0]"}"} />
            <div class={"h-1 flex-1 rounded-full #{if @step >= 2, do: "bg-[#059669]", else: "bg-[#E2E8F0]"}"} />
            <div class={"h-1 flex-1 rounded-full #{if @step >= 3, do: "bg-[#059669]", else: "bg-[#E2E8F0]"}"} />
          </div>
        </div>
      </div>

      <main class="flex-1">
        <div class="max-w-5xl mx-auto px-4 py-6 lg:py-8">
          <%!-- MoMo Rich Waiting State --%>
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
                <svg
                  class="w-6 h-6 text-red-600"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
              <h3 class="text-lg font-semibold text-red-900 mb-1">Payment failed</h3>
              <p class="text-sm text-red-700 mb-4">
                The payment was not completed. Please try again.
              </p>
              <button
                phx-click="retry_payment"
                class="inline-flex items-center px-6 py-2.5 bg-[#1C1917] text-white rounded-xl text-sm font-semibold hover:bg-[#292524] transition-colors"
              >
                Retry Payment
              </button>
            </div>
          </div>

          <%!-- Payment Timeout State --%>
          <div :if={@payment_status == :timeout} class="max-w-lg mx-auto mb-6">
            <div class="bg-amber-50 border border-amber-200 rounded-xl p-6 text-center">
              <div class="w-12 h-12 mx-auto mb-3 bg-amber-100 rounded-full flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-amber-600"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
                  />
                </svg>
              </div>
              <h3 class="text-lg font-semibold text-amber-900 mb-1">Payment timed out</h3>
              <p class="text-sm text-amber-700 mb-4">
                We didn't receive a response in time. You can try again.
              </p>
              <button
                phx-click="retry_payment"
                class="inline-flex items-center px-6 py-2.5 bg-[#1C1917] text-white rounded-xl text-sm font-semibold hover:bg-[#292524] transition-colors"
              >
                Retry Payment
              </button>
            </div>
          </div>

          <%!-- Main Checkout Content --%>
          <div
            :if={@payment_status not in [:awaiting_payment, :failed, :timeout]}
            class="flex flex-col lg:flex-row gap-6 lg:gap-8"
          >
            <%!-- Left Column: Accordion Steps --%>
            <div class="flex-1 lg:max-w-xl">
              <%!-- Mobile Order Summary Toggle --%>
              <div class="lg:hidden mb-4">
                <button
                  phx-click="toggle_mobile_summary"
                  class="w-full flex items-center justify-between bg-white border border-[#E2E8F0] rounded-xl p-4"
                >
                  <div class="flex items-center gap-2">
                    <svg
                      class="w-5 h-5 text-[#475569]"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="1.5"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
                      />
                    </svg>
                    <span class="text-sm font-medium text-[#0F172A]">
                      Order summary ({@cart_count} items)
                    </span>
                  </div>
                  <div class="flex items-center gap-2">
                    <span class="text-sm font-semibold text-[#0F172A]">
                      {Currency.format_price(@order_total, @store.currency)}
                    </span>
                    <svg
                      class={"w-4 h-4 text-[#475569] transition-transform #{if @show_mobile_summary, do: "rotate-180"}"}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                      />
                    </svg>
                  </div>
                </button>
                <div
                  :if={@show_mobile_summary}
                  class="bg-white border border-t-0 border-[#E2E8F0] rounded-b-xl p-4 -mt-2"
                >
                  <.order_summary_content
                    cart={@cart}
                    cart_total={@cart_total}
                    delivery_fee={@effective_delivery_fee}
                    discount_amount={@discount_amount}
                    coupon={@coupon}
                    order_total={@order_total}
                    store={@store}
                  />
                </div>
              </div>

              <%!-- Step 1: Contact & Delivery --%>
              <.accordion_step
                number={1}
                title="Contact & Delivery"
                current_step={@step}
                summary={step_1_summary(assigns)}
              >
                <form phx-submit="submit_details" phx-change="update_details" class="space-y-4">
                  <div>
                    <label for="phone" class="block text-sm font-medium text-[#0F172A] mb-1.5">
                      Phone number <span class="text-red-600">*</span>
                    </label>
                    <div class="flex">
                      <span class="inline-flex items-center px-3 bg-[#FAFAF9] border border-r-0 border-[#E2E8F0] rounded-l-lg text-sm text-[#475569] font-medium">
                        +233
                      </span>
                      <input
                        type="tel"
                        id="phone"
                        name="phone"
                        value={@phone}
                        placeholder="24 123 4567"
                        class={"flex-1 border rounded-r-lg px-3 py-2.5 text-sm #{if @form_errors[:phone], do: "border-red-400 bg-red-50", else: "border-[#E2E8F0]"}"}
                      />
                    </div>
                    <p :if={@form_errors[:phone]} class="text-xs text-red-600 mt-1">
                      {@form_errors[:phone]}
                    </p>
                    <p :if={!@form_errors[:phone]} class="text-xs text-[#94A3B8] mt-1">
                      For SMS order updates
                    </p>
                  </div>
                  <div>
                    <label for="fullname" class="block text-sm font-medium text-[#0F172A] mb-1.5">
                      Full name <span class="text-red-600">*</span>
                    </label>
                    <input
                      type="text"
                      id="fullname"
                      name="fullname"
                      value={@fullname}
                      placeholder="Ama Mensah"
                      class={"w-full border rounded-lg px-3 py-2.5 text-sm #{if @form_errors[:fullname], do: "border-red-400 bg-red-50", else: "border-[#E2E8F0]"}"}
                    />
                    <p :if={@form_errors[:fullname]} class="text-xs text-red-600 mt-1">
                      {@form_errors[:fullname]}
                    </p>
                  </div>
                  <div>
                    <label for="address" class="block text-sm font-medium text-[#0F172A] mb-1.5">
                      Delivery address <span class="text-red-600">*</span>
                    </label>
                    <input
                      type="text"
                      id="address"
                      name="address"
                      value={@address}
                      placeholder="House 14, Osu Badu Street"
                      class={"w-full border rounded-lg px-3 py-2.5 text-sm #{if @form_errors[:address], do: "border-red-400 bg-red-50", else: "border-[#E2E8F0]"}"}
                    />
                    <p :if={@form_errors[:address]} class="text-xs text-red-600 mt-1">
                      {@form_errors[:address]}
                    </p>
                  </div>
                  <div>
                    <label for="region" class="block text-sm font-medium text-[#0F172A] mb-1.5">
                      Region
                    </label>
                    <select
                      id="region"
                      name="region"
                      class="w-full border border-[#E2E8F0] rounded-lg px-3 py-2.5 text-sm bg-white"
                    >
                      <option value="greater_accra" selected={@region == "greater_accra"}>
                        Greater Accra
                      </option>
                      <option value="ashanti" selected={@region == "ashanti"}>Ashanti</option>
                      <option value="central" selected={@region == "central"}>Central</option>
                      <option value="western" selected={@region == "western"}>Western</option>
                      <option value="eastern" selected={@region == "eastern"}>Eastern</option>
                      <option value="northern" selected={@region == "northern"}>Northern</option>
                      <option value="volta" selected={@region == "volta"}>Volta</option>
                      <option value="other" selected={@region == "other"}>Other</option>
                    </select>
                  </div>
                  <div>
                    <label for="notes" class="block text-sm font-medium text-[#0F172A] mb-1.5">
                      Order notes <span class="text-[#94A3B8] font-normal">(optional)</span>
                    </label>
                    <textarea
                      id="notes"
                      name="notes"
                      rows="3"
                      placeholder="Any special instructions..."
                      class="w-full border border-[#E2E8F0] rounded-lg px-3 py-2.5 text-sm resize-none"
                    >{@notes}</textarea>
                  </div>
                  <button
                    type="submit"
                    class="w-full bg-[#1C1917] text-white py-3.5 rounded-xl text-sm font-semibold hover:bg-[#292524] transition-colors"
                  >
                    Continue to Payment
                  </button>
                </form>
              </.accordion_step>

              <%!-- Step 2: Payment Method --%>
              <.accordion_step
                number={2}
                title="Payment Method"
                current_step={@step}
                summary={step_2_summary(assigns)}
              >
                <div class="grid grid-cols-2 gap-3" role="radiogroup" aria-label="Payment methods">
                  <.payment_card
                    method="momo"
                    selected={@payment_method}
                    title="MTN MoMo"
                    subtitle="Mobile Money"
                    badge_text="MTN"
                    badge_bg="bg-[#FFC107]"
                    badge_text_color="text-[#1C1917]"
                    accent_color="#FFC107"
                  />
                  <.payment_card
                    method="vodafone"
                    selected={@payment_method}
                    title="Vodafone Cash"
                    subtitle="Mobile Money"
                    badge_text="VODA"
                    badge_bg="bg-[#E60000]"
                    badge_text_color="text-white"
                    accent_color="#E60000"
                  />
                  <.payment_card
                    method="card"
                    selected={@payment_method}
                    title="Card"
                    subtitle="Visa, Mastercard"
                    badge_text="CARD"
                    badge_bg="bg-[#EFF6FF]"
                    badge_text_color="text-[#3B82F6]"
                    accent_color="#3B82F6"
                  />
                  <.payment_card
                    method="cod"
                    selected={@payment_method}
                    title="Pay on Delivery"
                    subtitle="Cash / MoMo"
                    badge_text="COD"
                    badge_bg="bg-[#F8FAFC]"
                    badge_text_color="text-[#64748B]"
                    accent_color="#64748B"
                  />
                </div>
                <div class="flex gap-3 mt-6">
                  <button
                    type="button"
                    phx-click="go_to_step"
                    phx-value-step="1"
                    class="px-6 py-3 border border-[#E2E8F0] rounded-xl text-sm font-medium text-[#475569] hover:bg-[#F8FAFC] transition-colors"
                  >
                    Back
                  </button>
                  <button
                    phx-click="go_to_step"
                    phx-value-step="3"
                    class="flex-1 bg-[#1C1917] text-white py-3.5 rounded-xl text-sm font-semibold hover:bg-[#292524] transition-colors"
                  >
                    Continue to Review
                  </button>
                </div>
              </.accordion_step>

              <%!-- Step 3: Review & Pay --%>
              <.accordion_step
                number={3}
                title="Review & Pay"
                current_step={@step}
                summary={nil}
              >
                <%!-- Coupon Code --%>
                <div class="mb-5">
                  <label class="block text-sm font-medium text-[#0F172A] mb-1.5">Discount code</label>
                  <form phx-submit="apply_coupon" class="flex gap-2">
                    <input
                      type="text"
                      name="coupon_code"
                      value={@coupon_code}
                      placeholder="Enter code"
                      disabled={@coupon != nil}
                      class={"flex-1 border rounded-lg px-3 py-2.5 text-sm #{if @coupon_error, do: "border-red-400", else: "border-[#E2E8F0]"} disabled:bg-[#F8FAFC] disabled:text-[#94A3B8]"}
                    />
                    <button
                      :if={@coupon == nil}
                      type="submit"
                      class="px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-sm font-medium text-[#475569] hover:bg-[#F8FAFC] transition-colors"
                    >
                      Apply
                    </button>
                    <button
                      :if={@coupon != nil}
                      type="button"
                      phx-click="remove_coupon"
                      class="px-4 py-2.5 border border-red-200 rounded-lg text-sm font-medium text-red-600 hover:bg-red-50 transition-colors"
                    >
                      Remove
                    </button>
                  </form>
                  <p :if={@coupon_error} class="text-xs text-red-600 mt-1">{@coupon_error}</p>
                  <p :if={@coupon} class="text-xs text-[#059669] mt-1">
                    Coupon applied: -{Currency.format_price(@discount_amount, @store.currency)} off
                  </p>
                </div>

                <%!-- Order Items --%>
                <div class="bg-white border border-[#E2E8F0] rounded-xl p-4 mb-4">
                  <h4 class="text-xs text-[#94A3B8] uppercase tracking-wide font-medium mb-3">
                    Items
                  </h4>
                  <div class="space-y-3">
                    <div :for={item <- @cart} class="flex gap-3">
                      <div class="w-12 h-12 bg-[#F1F5F9] rounded-lg flex-shrink-0 overflow-hidden">
                        <img
                          :if={item[:image_url]}
                          src={item[:image_url]}
                          alt={item.product_title}
                          class="w-full h-full object-cover"
                        />
                        <div
                          :if={!item[:image_url]}
                          class="w-full h-full flex items-center justify-center"
                        >
                          <svg
                            class="w-5 h-5 text-[#94A3B8]"
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
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-medium text-[#0F172A] truncate">
                          {item.product_title}
                        </p>
                        <p :if={item[:variant_info]} class="text-xs text-[#94A3B8]">
                          {item[:variant_info]}
                        </p>
                        <p class="text-xs text-[#94A3B8]">Qty: {item.quantity}</p>
                      </div>
                      <span class="text-sm font-medium text-[#0F172A] flex-shrink-0">
                        {Currency.format_price(item.unit_price * item.quantity, @store.currency)}
                      </span>
                    </div>
                  </div>
                </div>

                <%!-- Delivery Summary --%>
                <div class="bg-white border border-[#E2E8F0] rounded-xl p-4 mb-4">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-xs text-[#94A3B8] uppercase tracking-wide font-medium mb-1">
                        Delivery
                      </p>
                      <p class="text-sm font-semibold text-[#0F172A]">{@fullname}</p>
                      <p class="text-sm text-[#475569]">{@address}</p>
                      <p class="text-sm text-[#475569]">+233 {@phone} -- {region_label(@region)}</p>
                    </div>
                    <button
                      phx-click="go_to_step"
                      phx-value-step="1"
                      class="text-xs font-medium text-[#B45309]"
                    >
                      Edit
                    </button>
                  </div>
                </div>

                <%!-- Payment Summary --%>
                <div class="bg-white border border-[#E2E8F0] rounded-xl p-4 mb-4">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-xs text-[#94A3B8] uppercase tracking-wide font-medium mb-1">
                        Payment
                      </p>
                      <p class="text-sm font-semibold text-[#0F172A]">
                        {payment_method_label(@payment_method)}
                      </p>
                    </div>
                    <button
                      phx-click="go_to_step"
                      phx-value-step="2"
                      class="text-xs font-medium text-[#B45309]"
                    >
                      Edit
                    </button>
                  </div>
                </div>

                <%!-- Totals --%>
                <div class="bg-white border border-[#E2E8F0] rounded-xl p-4 mb-6">
                  <div class="space-y-2 text-sm">
                    <div class="flex justify-between">
                      <span class="text-[#475569]">Subtotal</span>
                      <span class="font-medium text-[#0F172A]">
                        {Currency.format_price(@cart_total, @store.currency)}
                      </span>
                    </div>
                    <div :if={@discount_amount > 0} class="flex justify-between text-[#059669]">
                      <span>Discount</span>
                      <span class="font-medium">
                        -{Currency.format_price(@discount_amount, @store.currency)}
                      </span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-[#475569]">Delivery ({region_label(@region)})</span>
                      <span class="font-medium text-[#0F172A]">
                        {Currency.format_price(@effective_delivery_fee, @store.currency)}
                      </span>
                    </div>
                    <div class="flex justify-between text-base font-bold pt-2 border-t border-[#E2E8F0]">
                      <span class="text-[#0F172A]">Total</span>
                      <span class="text-[#0F172A]">
                        {Currency.format_price(@order_total, @store.currency)}
                      </span>
                    </div>
                  </div>
                </div>

                <div :if={@checkout_error} class="mb-4 bg-red-50 border border-red-200 rounded-xl p-4">
                  <p class="text-sm text-red-700">{@checkout_error}</p>
                </div>

                <div class="flex gap-3">
                  <button
                    type="button"
                    phx-click="go_to_step"
                    phx-value-step="2"
                    disabled={@processing}
                    class="px-6 py-3 border border-[#E2E8F0] rounded-xl text-sm font-medium text-[#475569] disabled:opacity-50"
                  >
                    Back
                  </button>
                  <button
                    phx-click="place_order"
                    disabled={@processing}
                    class="flex-1 bg-[#1C1917] text-white py-3.5 rounded-xl text-sm font-semibold disabled:bg-[#E2E8F0] disabled:text-[#94A3B8] hover:bg-[#292524] transition-colors"
                  >
                    <%= if @processing do %>
                      Processing...
                    <% else %>
                      <%= if @payment_method == "cod" do %>
                        Place Order
                      <% else %>
                        Pay {Currency.format_price(@order_total, @store.currency)}
                      <% end %>
                    <% end %>
                  </button>
                </div>
              </.accordion_step>
            </div>

            <%!-- Desktop Sidebar: Order Summary --%>
            <div class="hidden lg:block w-80 flex-shrink-0">
              <div class="sticky top-20 bg-white border border-[#E2E8F0] rounded-xl p-5">
                <h3 class="text-sm font-semibold text-[#0F172A] mb-4">Order Summary</h3>
                <.order_summary_content
                  cart={@cart}
                  cart_total={@cart_total}
                  delivery_fee={@effective_delivery_fee}
                  discount_amount={@discount_amount}
                  coupon={@coupon}
                  order_total={@order_total}
                  store={@store}
                />
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  # -- Components -----------------------------------------------------------

  attr :cart, :list, required: true
  attr :cart_total, :integer, required: true
  attr :delivery_fee, :integer, required: true
  attr :discount_amount, :integer, required: true
  attr :coupon, :any, required: true
  attr :order_total, :integer, required: true
  attr :store, :any, required: true

  defp order_summary_content(assigns) do
    ~H"""
    <div :if={@cart != []} class="space-y-3 mb-4">
      <div :for={item <- @cart} class="flex gap-3">
        <div class="w-12 h-12 bg-[#F1F5F9] rounded-lg flex-shrink-0 overflow-hidden">
          <img
            :if={item[:image_url]}
            src={item[:image_url]}
            alt={item.product_title}
            class="w-full h-full object-cover"
          />
          <div :if={!item[:image_url]} class="w-full h-full flex items-center justify-center">
            <svg class="w-5 h-5 text-[#94A3B8]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="1"
                d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
          </div>
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-[#0F172A] truncate">{item.product_title}</p>
          <p :if={item[:variant_info]} class="text-xs text-[#94A3B8]">{item[:variant_info]}</p>
          <p class="text-xs text-[#94A3B8]">Qty: {item.quantity}</p>
        </div>
        <span class="text-sm font-medium text-[#0F172A] flex-shrink-0">
          {Currency.format_price(item.unit_price * item.quantity, @store.currency)}
        </span>
      </div>
    </div>
    <div :if={@cart == []} class="text-sm text-[#94A3B8] mb-4">No items in cart</div>
    <div class="border-t border-[#E2E8F0] pt-3 space-y-2 text-sm">
      <div class="flex justify-between">
        <span class="text-[#475569]">Subtotal</span>
        <span class="text-[#0F172A]">{Currency.format_price(@cart_total, @store.currency)}</span>
      </div>
      <div :if={@discount_amount > 0} class="flex justify-between text-[#059669]">
        <span>Discount</span>
        <span>-{Currency.format_price(@discount_amount, @store.currency)}</span>
      </div>
      <div class="flex justify-between">
        <span class="text-[#475569]">Delivery</span>
        <span class="text-[#0F172A]">{Currency.format_price(@delivery_fee, @store.currency)}</span>
      </div>
      <div class="flex justify-between font-bold pt-2 border-t border-[#E2E8F0]">
        <span>Total</span>
        <span>{Currency.format_price(@order_total, @store.currency)}</span>
      </div>
    </div>
    """
  end

  attr :number, :integer, required: true
  attr :title, :string, required: true
  attr :current_step, :integer, required: true
  attr :summary, :any, default: nil
  slot :inner_block, required: true

  defp accordion_step(assigns) do
    ~H"""
    <div class="mb-4">
      <%!-- Completed step: collapsed summary --%>
      <div :if={@current_step > @number} class="bg-white border border-[#E2E8F0] rounded-xl p-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-7 h-7 rounded-full bg-[#059669] flex items-center justify-center flex-shrink-0">
              <svg
                class="w-3.5 h-3.5 text-white"
                fill="none"
                stroke="currentColor"
                stroke-width="2.5"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
              </svg>
            </div>
            <div>
              <p class="text-sm font-semibold text-[#0F172A]">{@title}</p>
              <p :if={@summary} class="text-xs text-[#475569] mt-0.5">{@summary}</p>
            </div>
          </div>
          <button
            phx-click="go_to_step"
            phx-value-step={@number}
            class="text-xs font-medium text-[#B45309] hover:text-[#92400E] transition-colors"
          >
            Edit
          </button>
        </div>
      </div>

      <%!-- Active step: full form --%>
      <div :if={@current_step == @number} class="bg-white border-2 border-[#0F172A] rounded-xl p-5">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-7 h-7 rounded-full bg-[#0F172A] flex items-center justify-center flex-shrink-0">
            <span class="text-white text-xs font-semibold">{@number}</span>
          </div>
          <h2 class="text-lg font-semibold text-[#0F172A]">{@title}</h2>
        </div>
        {render_slot(@inner_block)}
      </div>

      <%!-- Upcoming step: dimmed --%>
      <div
        :if={@current_step < @number}
        class="bg-white border border-[#E2E8F0] rounded-xl p-4 opacity-50"
      >
        <div class="flex items-center gap-3">
          <div class="w-7 h-7 rounded-full border-2 border-[#CBD5E1] flex items-center justify-center flex-shrink-0">
            <span class="text-[#94A3B8] text-xs font-semibold">{@number}</span>
          </div>
          <p class="text-sm font-medium text-[#94A3B8]">{@title}</p>
        </div>
      </div>
    </div>
    """
  end

  attr :method, :string, required: true
  attr :selected, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :badge_text, :string, required: true
  attr :badge_bg, :string, required: true
  attr :badge_text_color, :string, required: true
  attr :accent_color, :string, required: true

  defp payment_card(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="select_payment"
      phx-value-method={@method}
      role="radio"
      aria-checked={@selected == @method}
      class={[
        "bg-white border-2 rounded-xl p-4 flex flex-col items-center gap-2 cursor-pointer text-center transition-all",
        if(@selected == @method,
          do: "border-[#{@accent_color}] shadow-[0_0_0_1px_#{@accent_color}]",
          else: "border-[#E2E8F0] hover:border-[#CBD5E1]"
        )
      ]}
      style={
        if @selected == @method,
          do: "border-color: #{@accent_color}; box-shadow: 0 0 0 1px #{@accent_color};",
          else: ""
      }
    >
      <div class={"w-10 h-10 rounded-lg #{@badge_bg} flex items-center justify-center"}>
        <span class={"#{@badge_text_color} font-bold text-xs tracking-wide"}>{@badge_text}</span>
      </div>
      <div>
        <p class="text-sm font-semibold text-[#0F172A]">{@title}</p>
        <p class="text-xs text-[#94A3B8] mt-0.5">{@subtitle}</p>
      </div>
      <div :if={@selected == @method} class="mt-1">
        <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none">
          <circle cx="12" cy="12" r="10" fill="#059669" />
          <path
            d="M8 12L11 15L16 9"
            stroke="white"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </div>
    </button>
    """
  end

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
    <div class="bg-white border border-[#E2E8F0] rounded-xl p-6">
      <%!-- Phone icon with brand halo --%>
      <div class="flex justify-center mb-5">
        <div class="relative">
          <div
            class="w-20 h-20 rounded-full flex items-center justify-center animate-pulse"
            style={"background-color: #{@brand_color}20;"}
          >
            <div
              class="w-14 h-14 rounded-full flex items-center justify-center"
              style={"background-color: #{@brand_color}30;"}
            >
              <svg
                class="w-7 h-7"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke={@brand_color}
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"
                />
              </svg>
            </div>
          </div>
        </div>
      </div>

      <h3 class="text-lg font-semibold text-[#0F172A] text-center mb-1">Approve on your phone</h3>
      <p class="text-sm text-[#475569] text-center mb-6">
        A {@brand_name} payment prompt has been sent to your phone
      </p>

      <%!-- 3-step progress tracker --%>
      <div class="space-y-4 mb-6">
        <%!-- Step 1: Order created --%>
        <div class="flex items-start gap-3">
          <div class="w-6 h-6 rounded-full bg-[#059669] flex items-center justify-center flex-shrink-0 mt-0.5">
            <svg
              class="w-3.5 h-3.5 text-white"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
            </svg>
          </div>
          <div>
            <p class="text-sm font-medium text-[#0F172A]">Order created</p>
            <p :if={@order} class="text-xs text-[#94A3B8]">#{@order.order_number}</p>
          </div>
        </div>

        <%!-- Step 2: Payment request sent --%>
        <div class="flex items-start gap-3">
          <div class="w-6 h-6 rounded-full bg-[#059669] flex items-center justify-center flex-shrink-0 mt-0.5">
            <svg
              class="w-3.5 h-3.5 text-white"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
            </svg>
          </div>
          <div>
            <p class="text-sm font-medium text-[#0F172A]">Payment request sent</p>
            <p class="text-xs text-[#94A3B8]">+233 {@masked_phone}</p>
          </div>
        </div>

        <%!-- Step 3: Awaiting approval --%>
        <div class="flex items-start gap-3">
          <div class="w-6 h-6 rounded-full bg-amber-100 flex items-center justify-center flex-shrink-0 mt-0.5">
            <div class="w-2.5 h-2.5 rounded-full bg-amber-500 animate-pulse" />
          </div>
          <div>
            <p class="text-sm font-medium text-[#0F172A]">Awaiting approval</p>
            <p class="text-xs text-[#94A3B8]">
              Dial *170# if you don't see the prompt
            </p>
          </div>
        </div>
      </div>

      <%!-- Countdown timer --%>
      <div class="text-center mb-4">
        <div class="inline-flex items-center gap-2 bg-[#F8FAFC] rounded-lg px-4 py-2">
          <svg
            class="w-4 h-4 text-[#475569]"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="1.5"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
            />
          </svg>
          <span class="text-sm font-mono font-semibold text-[#0F172A]">{@timer_display}</span>
        </div>
      </div>

      <%!-- Help link --%>
      <p class="text-center text-xs text-[#94A3B8]">
        Didn't receive the prompt?
        <a href="#" class="text-[#B45309] font-medium hover:underline">Get help</a>
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

  defp step_1_summary(assigns) do
    if assigns.fullname != "" and assigns.phone != "" do
      "#{assigns.fullname} -- +233 #{assigns.phone} -- #{region_label(assigns.region)}"
    else
      nil
    end
  end

  defp step_2_summary(assigns) do
    if assigns.step > 2 do
      payment_method_label(assigns.payment_method)
    else
      nil
    end
  end

  defp payment_method_label("momo"), do: "MTN Mobile Money"
  defp payment_method_label("vodafone"), do: "Vodafone Cash"
  defp payment_method_label("card"), do: "Card Payment"
  defp payment_method_label("cod"), do: "Cash on Delivery"
  defp payment_method_label(_), do: "Unknown"

  defp region_label("greater_accra"), do: "Greater Accra"
  defp region_label("ashanti"), do: "Ashanti"
  defp region_label("central"), do: "Central"
  defp region_label("western"), do: "Western"
  defp region_label("eastern"), do: "Eastern"
  defp region_label("northern"), do: "Northern"
  defp region_label("volta"), do: "Volta"
  defp region_label(_), do: "Other"

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
