defmodule EmakolaWeb.Storefront.CheckoutLive do
  @moduledoc """
  Checkout page — matches emakola-checkout.html prototype.

  Multi-step checkout flow:
  1. Payment method selection (MTN MoMo, Vodafone Cash, Card, Cash on Delivery)
  2. Contact & delivery details (phone, name, address, region)
  3. Order confirmation / review
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

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
         |> assign(:page_title, "Checkout - #{store.name}")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("select_payment", %{"method" => method}, socket) do
    {:noreply, assign(socket, :payment_method, method)}
  end

  @impl true
  def handle_event("go_to_step", %{"step" => step_str}, socket) do
    step = String.to_integer(step_str)
    {:noreply, assign(socket, :step, step)}
  end

  @impl true
  def handle_event("update_details", params, socket) do
    {:noreply,
     socket
     |> assign(:phone, Map.get(params, "phone", socket.assigns.phone))
     |> assign(:fullname, Map.get(params, "fullname", socket.assigns.fullname))
     |> assign(:address, Map.get(params, "address", socket.assigns.address))
     |> assign(:region, Map.get(params, "region", socket.assigns.region))
     |> assign(:notes, Map.get(params, "notes", socket.assigns.notes))
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

    if socket.assigns.phone != "" and socket.assigns.fullname != "" and
         socket.assigns.address != "" do
      {:noreply, assign(socket, :step, 3)}
    else
      {:noreply, put_flash(socket, :error, "Please fill in all required fields")}
    end
  end

  @impl true
  def handle_event("place_order", _params, socket) do
    {:noreply, assign(socket, :processing, true)}
    # In a real implementation, this would call the checkout service
    # For now, just show success after a brief moment
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col bg-[#FAFAF9]">
      <%!-- Checkout header (overrides layout header) --%>
      <header class="bg-white border-b border-[#E2E8F0] sticky top-0 z-50">
        <div class="max-w-[768px] mx-auto px-4 h-14 flex items-center justify-between">
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

      <%!-- Progress steps --%>
      <div class="bg-white border-b border-[#E2E8F0]">
        <div class="max-w-lg mx-auto px-4 py-4">
          <div
            class="flex items-center justify-between"
            role="navigation"
            aria-label="Checkout progress"
          >
            <.step_indicator number={1} label="Payment" current_step={@step} />
            <div class="flex-1 h-[2px] mx-2 sm:mx-3 bg-[#E2E8F0] rounded-full overflow-hidden">
              <div class={"h-full bg-[#059669] rounded-full transition-all duration-500 #{if @step > 1, do: "w-full", else: "w-0"}"} />
            </div>
            <.step_indicator number={2} label="Details" current_step={@step} />
            <div class="flex-1 h-[2px] mx-2 sm:mx-3 bg-[#E2E8F0] rounded-full overflow-hidden">
              <div class={"h-full bg-[#059669] rounded-full transition-all duration-500 #{if @step > 2, do: "w-full", else: "w-0"}"} />
            </div>
            <.step_indicator number={3} label="Confirm" current_step={@step} />
          </div>
        </div>
      </div>

      <%!-- Main content --%>
      <main class="flex-1">
        <div class="max-w-[768px] mx-auto px-4 py-6 lg:py-8">
          <div class="flex flex-col lg:flex-row gap-6 lg:gap-8">
            <%!-- Left column: steps --%>
            <div class="flex-1 lg:max-w-xl">
              <%!-- Step 1: Payment method --%>
              <div :if={@step == 1}>
                <h2 class="text-lg font-semibold text-[#0F172A] mb-1">How would you like to pay?</h2>
                <p class="text-sm text-[#475569] mb-5">Choose your preferred payment method</p>

                <div class="space-y-3" role="radiogroup" aria-label="Payment methods">
                  <.payment_card
                    method="momo"
                    selected={@payment_method}
                    title="MTN Mobile Money"
                    subtitle="Pay with your MoMo wallet"
                    badge_text="MTN"
                    badge_bg="bg-[#FFC107]"
                    badge_text_color="text-[#1C1917]"
                    border_color="border-[#FFC107]"
                  />
                  <.payment_card
                    method="vodafone"
                    selected={@payment_method}
                    title="Vodafone Cash"
                    subtitle="Pay with Vodafone Cash"
                    badge_text="VODA"
                    badge_bg="bg-[#E60000]"
                    badge_text_color="text-white"
                    border_color="border-[#E60000]"
                  />
                  <.payment_card
                    method="card"
                    selected={@payment_method}
                    title="Card Payment"
                    subtitle="Visa, Mastercard"
                    badge_text="CARD"
                    badge_bg="bg-[#EFF6FF]"
                    badge_text_color="text-[#3B82F6]"
                    border_color="border-[#3B82F6]"
                  />
                  <.payment_card
                    method="cod"
                    selected={@payment_method}
                    title="Cash on Delivery"
                    subtitle="Pay when you receive your order"
                    badge_text="COD"
                    badge_bg="bg-[#F8FAFC]"
                    badge_text_color="text-[#64748B]"
                    border_color="border-[#64748B]"
                  />
                </div>

                <button
                  phx-click="go_to_step"
                  phx-value-step="2"
                  class="mt-6 w-full bg-[#1C1917] text-white py-3.5 rounded-xl text-sm font-semibold hover:bg-[#292524] transition-colors"
                >
                  Continue
                </button>
              </div>

              <%!-- Step 2: Contact & delivery details --%>
              <div :if={@step == 2}>
                <h2 class="text-lg font-semibold text-[#0F172A] mb-1">Contact & delivery details</h2>
                <p class="text-sm text-[#475569] mb-5">
                  We need this to deliver your order and send updates
                </p>

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
                        required
                        class="flex-1 border border-[#E2E8F0] rounded-r-lg px-3 py-2.5 text-sm text-[#0F172A] placeholder:text-[#94A3B8] focus:outline-none focus:ring-2 focus:ring-[#059669] focus:border-[#059669]"
                      />
                    </div>
                    <p class="text-xs text-[#94A3B8] mt-1">For SMS order updates</p>
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
                      required
                      class="w-full border border-[#E2E8F0] rounded-lg px-3 py-2.5 text-sm text-[#0F172A] placeholder:text-[#94A3B8] focus:outline-none focus:ring-2 focus:ring-[#059669] focus:border-[#059669]"
                    />
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
                      required
                      class="w-full border border-[#E2E8F0] rounded-lg px-3 py-2.5 text-sm text-[#0F172A] placeholder:text-[#94A3B8] focus:outline-none focus:ring-2 focus:ring-[#059669] focus:border-[#059669]"
                    />
                  </div>

                  <div>
                    <label for="region" class="block text-sm font-medium text-[#0F172A] mb-1.5">
                      Region
                    </label>
                    <select
                      id="region"
                      name="region"
                      class="w-full border border-[#E2E8F0] rounded-lg px-3 py-2.5 text-sm text-[#0F172A] bg-white focus:outline-none focus:ring-2 focus:ring-[#059669] focus:border-[#059669]"
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
                      class="w-full border border-[#E2E8F0] rounded-lg px-3 py-2.5 text-sm text-[#0F172A] placeholder:text-[#94A3B8] focus:outline-none focus:ring-2 focus:ring-[#059669] focus:border-[#059669] resize-none"
                    >{@notes}</textarea>
                  </div>

                  <div class="flex gap-3 pt-2">
                    <button
                      type="button"
                      phx-click="go_to_step"
                      phx-value-step="1"
                      class="px-6 py-3 border border-[#E2E8F0] rounded-xl text-sm font-medium text-[#475569] hover:bg-[#F1F5F9] transition-colors"
                    >
                      Back
                    </button>
                    <button
                      type="submit"
                      class="flex-1 bg-[#1C1917] text-white py-3 rounded-xl text-sm font-semibold hover:bg-[#292524] transition-colors"
                    >
                      Continue to Review
                    </button>
                  </div>
                </form>
              </div>

              <%!-- Step 3: Confirm --%>
              <div :if={@step == 3}>
                <h2 class="text-lg font-semibold text-[#0F172A] mb-1">Review your order</h2>
                <p class="text-sm text-[#475569] mb-5">
                  Please check everything before placing your order
                </p>

                <%!-- Payment method summary --%>
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
                      phx-value-step="1"
                      class="text-xs font-medium text-[#B45309] hover:text-[#92400E]"
                    >
                      Change
                    </button>
                  </div>
                </div>

                <%!-- Delivery details summary --%>
                <div class="bg-white border border-[#E2E8F0] rounded-xl p-4 mb-6">
                  <div class="flex items-center justify-between mb-2">
                    <p class="text-xs text-[#94A3B8] uppercase tracking-wide font-medium">Delivery</p>
                    <button
                      phx-click="go_to_step"
                      phx-value-step="2"
                      class="text-xs font-medium text-[#B45309] hover:text-[#92400E]"
                    >
                      Change
                    </button>
                  </div>
                  <p class="text-sm font-semibold text-[#0F172A]">{@fullname}</p>
                  <p class="text-sm text-[#475569]">{@address}</p>
                  <p class="text-sm text-[#475569]">+233 {@phone}</p>
                </div>

                <%!-- Order total --%>
                <div class="bg-white border border-[#E2E8F0] rounded-xl p-4 mb-6">
                  <div class="space-y-2 text-sm">
                    <div class="flex justify-between">
                      <span class="text-[#475569]">Subtotal</span>
                      <span class="font-medium text-[#0F172A]">
                        {Currency.format_price(@cart_total, @store.currency)}
                      </span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-[#475569]">Delivery ({region_label(@region)})</span>
                      <span class="font-medium text-[#0F172A]">
                        {Currency.format_price(@delivery_fee, @store.currency)}
                      </span>
                    </div>
                    <div class="flex justify-between text-base font-bold pt-2 border-t border-[#E2E8F0]">
                      <span class="text-[#0F172A]">Total</span>
                      <span class="text-[#0F172A]">
                        {Currency.format_price(@cart_total + @delivery_fee, @store.currency)}
                      </span>
                    </div>
                  </div>
                </div>

                <div class="flex gap-3">
                  <button
                    type="button"
                    phx-click="go_to_step"
                    phx-value-step="2"
                    class="px-6 py-3 border border-[#E2E8F0] rounded-xl text-sm font-medium text-[#475569] hover:bg-[#F1F5F9] transition-colors"
                  >
                    Back
                  </button>
                  <button
                    phx-click="place_order"
                    disabled={@processing}
                    class="flex-1 bg-[#1C1917] text-white py-3.5 rounded-xl text-sm font-semibold hover:bg-[#292524] transition-colors disabled:bg-[#E2E8F0] disabled:text-[#94A3B8]"
                  >
                    <%= if @processing do %>
                      Processing...
                    <% else %>
                      Place Order
                    <% end %>
                  </button>
                </div>
              </div>
            </div>

            <%!-- Right column: order summary (desktop) --%>
            <div class="hidden lg:block w-[320px] flex-shrink-0">
              <div class="sticky top-20 bg-white border border-[#E2E8F0] rounded-xl p-5">
                <h3 class="text-sm font-semibold text-[#0F172A] mb-4">Order Summary</h3>
                <div :if={@cart != []} class="space-y-3 mb-4">
                  <div :for={item <- @cart} class="flex gap-3">
                    <div class="w-14 h-14 bg-[#F1F5F9] rounded-lg flex items-center justify-center flex-shrink-0">
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
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-[#0F172A] truncate">{item.product_title}</p>
                      <p :if={item.variant_info} class="text-xs text-[#94A3B8]">
                        {item.variant_info}
                      </p>
                      <p class="text-xs text-[#94A3B8]">Qty: {item.quantity}</p>
                    </div>
                    <span class="text-sm font-medium text-[#0F172A] flex-shrink-0">
                      {Currency.format_price(item.unit_price * item.quantity, @store.currency)}
                    </span>
                  </div>
                </div>
                <div class="border-t border-[#E2E8F0] pt-3 space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-[#475569]">Subtotal</span>
                    <span class="text-[#0F172A]">
                      {Currency.format_price(@cart_total, @store.currency)}
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-[#475569]">Delivery</span>
                    <span class="text-[#0F172A]">
                      {Currency.format_price(@delivery_fee, @store.currency)}
                    </span>
                  </div>
                  <div class="flex justify-between font-bold pt-2 border-t border-[#E2E8F0]">
                    <span>Total</span>
                    <span>{Currency.format_price(@cart_total + @delivery_fee, @store.currency)}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  # -- Components --

  attr :number, :integer, required: true
  attr :label, :string, required: true
  attr :current_step, :integer, required: true

  defp step_indicator(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div class={[
        "w-7 h-7 rounded-full flex items-center justify-center text-xs font-semibold",
        cond do
          @current_step > @number -> "bg-[#059669] text-white"
          @current_step == @number -> "bg-[#059669] text-white"
          true -> "border-2 border-[#E2E8F0] text-[#94A3B8]"
        end
      ]}>
        <%= if @current_step > @number do %>
          <svg
            class="w-3.5 h-3.5"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
          </svg>
        <% else %>
          {@number}
        <% end %>
      </div>
      <span class={[
        "text-sm hidden sm:inline",
        if(@current_step >= @number,
          do: "font-semibold text-[#0F172A]",
          else: "font-medium text-[#94A3B8]"
        )
      ]}>
        {@label}
      </span>
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
  attr :border_color, :string, required: true

  defp payment_card(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="select_payment"
      phx-value-method={@method}
      role="radio"
      aria-checked={@selected == @method}
      class={[
        "w-full bg-white border-2 rounded-xl p-4 flex items-center gap-4 cursor-pointer text-left transition-all",
        if(@selected == @method,
          do: "border-[#059669] shadow-[0_0_0_1px_#059669]",
          else: "border-[#E2E8F0] hover:border-[#CBD5E1]"
        )
      ]}
    >
      <div class={"w-12 h-12 rounded-xl #{@badge_bg} flex items-center justify-center border-l-4 #{@border_color} flex-shrink-0"}>
        <span class={"#{@badge_text_color} font-bold text-xs tracking-wide"}>{@badge_text}</span>
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm font-semibold text-[#0F172A]">{@title}</p>
        <p class="text-xs text-[#94A3B8] mt-0.5">{@subtitle}</p>
      </div>
      <div class="flex-shrink-0">
        <%= if @selected == @method do %>
          <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="10" fill="#059669" />
            <path
              d="M8 12L11 15L16 9"
              stroke="white"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        <% else %>
          <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="10" stroke="#E2E8F0" stroke-width="2" />
          </svg>
        <% end %>
      </div>
    </button>
    """
  end

  # -- Helpers --

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
end
