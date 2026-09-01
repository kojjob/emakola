defmodule Emakola.Themes.DefaultRenderers.Checkout do
  @moduledoc """
  Default render for the storefront checkout page.

  Used by `EmakolaWeb.Storefront.CheckoutLive` when no theme overrides
  `:checkout`. Holds the entire 880-line checkout template plus the
  MoMo waiting-state component and pure display helpers (delivery
  estimate, MoMo brand color/name, timer formatting, phone masking).

  Extracted from CheckoutLive (was 1,645 lines, now ~620 after this
  extraction). Behavior unchanged — pure renderer; CheckoutLive owns
  events, queries, gateway calls.

  See docs/PATTERN-default-renderer-extraction.md.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Payments.Protection
  alias Emakola.Suppliers.GhanaRegions
  alias EmakolaWeb.AddressComponents
  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    assigns = assign(assigns, :protection_badge?, protection_badge?(assigns))

    ~H"""
    <div class="min-h-screen flex flex-col bg-stone-50 text-stone-950 antialiased">
      <%!-- Minimal Navigation --%>
      <header class="border-b border-stone-200 bg-white/80 backdrop-blur-md sticky top-0 z-50">
        <h1 class="sr-only">Checkout — {@store.name}</h1>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <a
              href={store_path(@store.slug, "/cart")}
              aria-label="Back to Bag"
              class="cursor-pointer flex items-center gap-2 text-stone-600 hover:text-stone-900 transition-colors text-sm font-medium rounded-lg px-2 py-1 -ml-2"
            >
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
              </svg>
              <%!-- Icon-only on mobile (mirrors Secure Checkout on the right)
                    so the centered wordmark has clean room at 375px. --%>
              <span class="hidden sm:inline">Back to Bag</span>
            </a>
            <%!-- Bounded + truncated: unbounded absolute text wraps to two
                  lines on long store names and collides with the side links. --%>
            <span class="absolute left-1/2 -translate-x-1/2 max-w-[55%] truncate text-lg sm:text-3xl font-semibold tracking-[0.15em] text-stone-900">
              {String.upcase(@store.name)}
            </span>
            <div class="flex items-center gap-2 text-stone-600 text-sm font-medium">
              <svg
                class="w-4 h-4 text-store-accent"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                <path d="M7 11V7a5 5 0 0 1 10 0v4" />
              </svg>
              <span class="hidden sm:inline">Secure Checkout</span>
            </div>
          </div>
        </div>
      </header>

      <%!-- Checkout Progress Stepper. Reads @step: the LiveView has carried it
            since it was written, but this markup used to hardcode step 1 as
            current while every section rendered at once. A cart of downloads
            has no shipping step, so it is dropped from the ladder rather than
            shown as a stage nobody can reach. --%>
      <div class="bg-white border-b border-stone-100">
        <div class="max-w-2xl mx-auto px-4 sm:px-6 py-6">
          <div class="flex items-center justify-between">
            <%= for {{n, label}, index} <- Enum.with_index(checkout_steps(@requires_shipping)) do %>
              <div class="flex items-center gap-2.5">
                <div
                  id={"checkout-step-#{n}"}
                  data-state={step_state(@step, n)}
                  class={[
                    "w-8 h-8 rounded-full flex items-center justify-center text-xs font-semibold",
                    if(@step >= n,
                      do: "bg-cta-dark text-white shadow-sm shadow-cta-dark/20",
                      else: "border-2 border-stone-300 text-stone-400"
                    )
                  ]}
                >
                  <svg
                    :if={@step > n}
                    class="w-3.5 h-3.5"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                  </svg>
                  <span :if={@step <= n}>{n}</span>
                </div>
                <span class={[
                  "text-sm hidden sm:inline",
                  if(@step == n,
                    do: "font-semibold text-stone-900",
                    else: "font-medium text-stone-400"
                  )
                ]}>
                  {label}
                </span>
              </div>
              <div
                :if={index < length(checkout_steps(@requires_shipping)) - 1}
                class={[
                  "h-0.5 flex-1 mx-3 sm:mx-4 rounded-full",
                  if(@step > n, do: "bg-cta-dark", else: "bg-stone-200")
                ]}
              >
              </div>
            <% end %>
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
              store={@store}
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
              <h3 class="text-2xl font-semibold text-red-900 mb-1">
                Payment failed
              </h3>
              <p class="text-sm text-red-700 mb-4">
                The payment was not completed. Please try again.
              </p>
              <button
                phx-click="retry_payment"
                class="cursor-pointer inline-flex items-center px-8 py-3.5 bg-cta-dark text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-opacity"
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
              <h3 class="text-2xl font-semibold text-amber-900 mb-1">
                Payment timed out
              </h3>
              <p class="text-sm text-amber-700 mb-4">
                We didn't receive a response in time. You can try again.
              </p>
              <button
                phx-click="retry_payment"
                class="cursor-pointer inline-flex items-center px-8 py-3.5 bg-cta-dark text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-opacity"
              >
                Retry Payment
              </button>
            </div>
          </div>

          <%!-- Main Checkout Content: Two-Column Layout --%>
          <div
            :if={@payment_status not in [:awaiting_payment, :failed, :timeout]}
            class="lg:grid lg:grid-cols-5 lg:gap-12 xl:gap-16"
          >
            <%!-- LEFT COLUMN: Checkout Form (60%) --%>
            <div class="lg:col-span-3">
              <%!-- One step at a time. Three forms rather than one, so each
                    step submits its own event; `place_order` keeps meaning
                    "place the order" and is never gated on the step. Fields on
                    a step that is not rendered are absent from the params,
                    which is why every handler falls back to its assign. --%>
              <form
                :if={@step == 1}
                phx-submit="submit_details"
                phx-change="update_details"
                novalidate
                class="space-y-10"
              >
                <%!-- SECTION 1: Contact Information --%>
                <section>
                  <h2 class="text-2xl sm:text-3xl font-semibold text-stone-900 mb-6">
                    Contact
                  </h2>
                  <div class="space-y-4">
                    <div>
                      <label for="phone" class="block text-sm font-medium text-stone-900 mb-1.5">
                        Phone number <span class="text-store-accent">*</span>
                      </label>
                      <div class="relative">
                        <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                          <svg
                            class="w-4 h-4 text-stone-400"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="1.5"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 4.5v2.25z"
                            />
                          </svg>
                        </div>
                        <input
                          type="tel"
                          id="phone"
                          name="phone"
                          value={@phone}
                          placeholder="+233 24 123 4567"
                          class={"w-full bg-white border rounded-xl pl-11 pr-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-store-accent/30 focus:border-store-accent transition-all #{if @form_errors[:phone], do: "border-red-400 bg-red-50", else: "border-stone-200"}"}
                        />
                      </div>
                      <p :if={@form_errors[:phone]} class="text-xs text-red-600 mt-1">
                        {@form_errors[:phone]}
                      </p>
                    </div>

                    <div>
                      <label for="fullname" class="block text-sm font-medium text-stone-900 mb-1.5">
                        Full name <span class="text-store-accent">*</span>
                      </label>
                      <input
                        type="text"
                        id="fullname"
                        name="fullname"
                        value={@fullname}
                        placeholder="Ama Mensah"
                        class={"w-full bg-white border rounded-xl px-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-store-accent/30 focus:border-store-accent transition-all #{if @form_errors[:fullname], do: "border-red-400 bg-red-50", else: "border-stone-200"}"}
                      />
                      <p :if={@form_errors[:fullname]} class="text-xs text-red-600 mt-1">
                        {@form_errors[:fullname]}
                      </p>
                    </div>

                    <div>
                      <label for="email" class="block text-sm font-medium text-stone-900 mb-1.5">
                        Email <span class="text-stone-400 text-xs">(optional, for receipt)</span>
                      </label>
                      <input
                        type="email"
                        id="email"
                        name="email"
                        value={@email}
                        placeholder="ama@example.com"
                        autocomplete="email"
                        class={"w-full bg-white border rounded-xl px-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-store-accent/30 focus:border-store-accent transition-all #{if @form_errors[:email], do: "border-red-400 bg-red-50", else: "border-stone-200"}"}
                      />
                      <p :if={@form_errors[:email]} class="text-xs text-red-600 mt-1">
                        {@form_errors[:email]}
                      </p>
                    </div>
                  </div>
                </section>

                <div>
                  <div
                    :if={@checkout_error}
                    class="mb-4 bg-red-50 border border-red-200 rounded-xl p-4"
                  >
                    <p class="text-sm text-red-700">{@checkout_error}</p>
                  </div>
                  <button
                    type="submit"
                    class="cursor-pointer w-full bg-cta-dark text-white py-4 rounded-xl text-sm font-semibold hover:opacity-90 transition-opacity shadow-sm shadow-cta-dark/20"
                  >
                    Continue to delivery
                  </button>
                </div>
              </form>

              <div :if={@step > 1} class="space-y-3">
                <div
                  id="step-summary-contact"
                  class="flex items-center gap-3 rounded-xl border border-stone-200 bg-white px-4 py-3.5"
                >
                  <span class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-cta-dark">
                    <svg
                      class="w-3 h-3 text-white"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="3"
                      viewBox="0 0 24 24"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                    </svg>
                  </span>
                  <div class="min-w-0 flex-1">
                    <p class="text-xs text-stone-400">Your details</p>
                    <p class="truncate text-sm font-semibold text-stone-900">
                      {@phone} · {@fullname}
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click="go_to_step"
                    phx-value-step="1"
                    class="cursor-pointer rounded px-2 py-1 text-xs font-semibold text-store-accent hover:underline"
                  >
                    Change
                  </button>
                </div>
                <div :if={@step > 2 and @requires_shipping}>
                  <div
                    id="step-summary-delivery"
                    class="flex items-center gap-3 rounded-xl border border-stone-200 bg-white px-4 py-3.5"
                  >
                    <span class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-cta-dark">
                      <svg
                        class="w-3 h-3 text-white"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="3"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M4.5 12.75l6 6 9-13.5"
                        />
                      </svg>
                    </span>
                    <div class="min-w-0 flex-1">
                      <p class="text-xs text-stone-400">Deliver to</p>
                      <p class="truncate text-sm font-semibold text-stone-900">{@address}</p>
                    </div>
                    <button
                      type="button"
                      phx-click="go_to_step"
                      phx-value-step="2"
                      class="cursor-pointer rounded px-2 py-1 text-xs font-semibold text-store-accent hover:underline"
                    >
                      Change
                    </button>
                  </div>
                </div>
              </div>

              <form
                :if={@step == 2 and @requires_shipping}
                phx-submit="submit_delivery"
                phx-change="update_details"
                novalidate
                class="mt-10 space-y-10"
              >
                <%!-- SECTION 2: Shipping Address. Hidden for a cart of
                     downloads — there is nothing to deliver, and the server
                     (CheckoutService.run_checkout/4) charges no fee either. --%>
                <section>
                  <h2 class="text-2xl sm:text-3xl font-semibold text-stone-900 mb-6">
                    Shipping Address
                  </h2>
                  <div class="space-y-4">
                    <div>
                      <label for="address" class="block text-sm font-medium text-stone-900 mb-1.5">
                        Address <span class="text-store-accent">*</span>
                      </label>
                      <input
                        type="text"
                        id="address"
                        name="address"
                        value={@address}
                        placeholder="House 14, Osu Badu Street"
                        class={"w-full bg-white border rounded-xl px-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-store-accent/30 focus:border-store-accent transition-all #{if @form_errors[:address], do: "border-red-400 bg-red-50", else: "border-stone-200"}"}
                      />
                      <p :if={@form_errors[:address]} class="text-xs text-red-600 mt-1">
                        {@form_errors[:address]}
                      </p>
                    </div>

                    <div>
                      <AddressComponents.gh_address_fields
                        digital_address={@digital_address}
                        landmark={@landmark}
                        field_prefix=""
                      />
                      <p :if={@form_errors[:digital_address]} class="text-xs text-red-600 mt-1">
                        {@form_errors[:digital_address]}
                      </p>
                    </div>

                    <div>
                      <label for="region" class="block text-sm font-medium text-stone-900 mb-1.5">
                        Region <span class="text-store-accent">*</span>
                      </label>
                      <div class="relative">
                        <select
                          id="region"
                          name="region"
                          class="cursor-pointer w-full bg-white border border-stone-200 rounded-xl px-4 py-3.5 text-sm text-stone-900 appearance-none focus:ring-2 focus:ring-store-accent/30 focus:border-store-accent transition-all"
                        >
                          <%= for {label, param} <- GhanaRegions.select_options() do %>
                            <option value={param} selected={@region == param}>{label}</option>
                          <% end %>
                        </select>
                        <div class="absolute inset-y-0 right-0 pr-4 flex items-center pointer-events-none">
                          <svg
                            class="w-4 h-4 text-stone-400"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="2"
                            viewBox="0 0 24 24"
                          >
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
                        class="w-full bg-white border border-stone-200 rounded-xl px-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-store-accent/30 focus:border-store-accent transition-all"
                      />
                    </div>
                  </div>
                </section>

                <%!-- SECTION 3: Delivery Method --%>
                <section>
                  <h2 class="text-2xl sm:text-3xl font-semibold text-stone-900 mb-6">
                    Delivery Method
                  </h2>
                  <div class="space-y-3">
                    <%!-- Standard Delivery (selected based on region) --%>
                    <div class="flex items-center justify-between p-4 sm:p-5 bg-white border-2 border-store-accent bg-store-accent/5 rounded-xl">
                      <div class="flex items-center gap-4">
                        <div class="w-5 h-5 rounded-full border-2 border-store-accent flex items-center justify-center shrink-0">
                          <div class="w-2.5 h-2.5 rounded-full bg-store-accent"></div>
                        </div>
                        <div>
                          <p class="text-sm font-semibold text-stone-900">Standard Delivery</p>
                          <%!-- The store's own estimate, from the same delivery
                               zone the fee on the right is charged from. A store
                               that has configured no zone for this region has
                               promised no timeline, so none is shown. --%>
                          <p :if={@delivery_estimate} class="text-xs text-stone-600 mt-0.5">
                            {@delivery_estimate}
                          </p>
                          <p :if={!@delivery_estimate} class="text-xs text-stone-600 mt-0.5">
                            The seller will confirm your delivery time
                          </p>
                        </div>
                      </div>
                      <span class="text-sm font-semibold text-stone-900">
                        {Currency.format_price(@delivery_fee, @store.currency)}
                      </span>
                    </div>

                    <%!-- An "Express Delivery — Next business day" row sat here
                         on every store's checkout: a div styled as an unselected
                         radio at opacity-50 with a "Coming soon" pill. It read as
                         a delivery option the shopper could pick, it was inert,
                         and no merchant on the platform offers next-business-day
                         delivery. A checkout is the last place to advertise
                         something that does not exist. --%>
                  </div>
                </section>

                <div>
                  <div
                    :if={@checkout_error}
                    class="mb-4 bg-red-50 border border-red-200 rounded-xl p-4"
                  >
                    <p class="text-sm text-red-700">{@checkout_error}</p>
                  </div>
                  <button
                    type="submit"
                    class="cursor-pointer w-full bg-cta-dark text-white py-4 rounded-xl text-sm font-semibold hover:opacity-90 transition-opacity shadow-sm shadow-cta-dark/20"
                  >
                    Continue to payment
                  </button>
                </div>
              </form>

              <form
                :if={@step == 3}
                phx-submit="place_order"
                phx-change="update_details"
                novalidate
                class="mt-10 space-y-10"
              >
                <%!-- SECTION 4: Payment Method --%>
                <section>
                  <h2 class="text-2xl sm:text-3xl font-semibold text-stone-900 mb-2">
                    How do you want to pay?
                  </h2>
                  <p class="text-sm text-stone-500 mb-6">Choose your preferred payment method</p>

                  <%!-- Laid out across rather than down: three per row on a
                        desktop, two on a phone, so every brand mark stays big
                        enough to recognise without reading its caption. --%>
                  <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
                    <%!-- MTN Mobile Money --%>
                    <button
                      type="button"
                      phx-click="select_payment"
                      phx-value-method="momo"
                      class={"cursor-pointer relative flex flex-col items-center text-center gap-3 p-5 sm:p-6 bg-white border-2 rounded-2xl transition-all #{if @payment_method == "momo", do: "border-[#FFC107] bg-mtn/5 shadow-sm", else: "border-stone-200 hover:border-stone-300"}"}
                    >
                      <div class={"absolute top-3 right-3 w-5 h-5 rounded-full border-2 flex items-center justify-center #{if @payment_method == "momo", do: "border-[#FFC107] bg-mtn", else: "border-stone-300"}"}>
                        <svg
                          :if={@payment_method == "momo"}
                          class="w-3 h-3 text-stone-900"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="3"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M4.5 12.75l6 6 9-13.5"
                          />
                        </svg>
                      </div>
                      <div class="w-14 h-14 rounded-2xl bg-mtn flex items-center justify-center shadow-sm">
                        <span class="text-stone-900 font-extrabold text-lg tracking-tight">MTN</span>
                      </div>
                      <div>
                        <p class="text-sm font-bold text-stone-900">MTN MoMo</p>
                        <p class="text-xs text-stone-500 mt-0.5">Mobile Money</p>
                      </div>
                    </button>

                    <%!-- Telecel Cash --%>
                    <button
                      type="button"
                      phx-click="select_payment"
                      phx-value-method="vodafone"
                      class={"cursor-pointer relative flex flex-col items-center text-center gap-3 p-5 sm:p-6 bg-white border-2 rounded-2xl transition-all #{if @payment_method == "vodafone", do: "border-voda bg-voda/5 shadow-sm", else: "border-stone-200 hover:border-stone-300"}"}
                    >
                      <div class={"absolute top-3 right-3 w-5 h-5 rounded-full border-2 flex items-center justify-center #{if @payment_method == "vodafone", do: "border-voda bg-voda", else: "border-stone-300"}"}>
                        <svg
                          :if={@payment_method == "vodafone"}
                          class="w-3 h-3 text-white"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="3"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M4.5 12.75l6 6 9-13.5"
                          />
                        </svg>
                      </div>
                      <div class="w-14 h-14 rounded-2xl bg-voda flex items-center justify-center shadow-sm">
                        <span class="text-white font-extrabold text-xs tracking-tight">Telecel</span>
                      </div>
                      <div>
                        <p class="text-sm font-bold text-stone-900">Telecel Cash</p>
                        <p class="text-xs text-stone-500 mt-0.5">Mobile Money</p>
                      </div>
                    </button>

                    <%!-- AirtelTigo Money --%>
                    <button
                      type="button"
                      phx-click="select_payment"
                      phx-value-method="airteltigo"
                      class={"cursor-pointer relative flex flex-col items-center text-center gap-3 p-5 sm:p-6 bg-white border-2 rounded-2xl transition-all #{if @payment_method == "airteltigo", do: "border-atl bg-atl/5 shadow-sm", else: "border-stone-200 hover:border-stone-300"}"}
                    >
                      <div class={"absolute top-3 right-3 w-5 h-5 rounded-full border-2 flex items-center justify-center #{if @payment_method == "airteltigo", do: "border-atl bg-atl", else: "border-stone-300"}"}>
                        <svg
                          :if={@payment_method == "airteltigo"}
                          class="w-3 h-3 text-white"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="3"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M4.5 12.75l6 6 9-13.5"
                          />
                        </svg>
                      </div>
                      <div class="w-14 h-14 rounded-2xl bg-atl flex items-center justify-center shadow-sm">
                        <span class="text-white font-extrabold text-lg tracking-tight">AT</span>
                      </div>
                      <div>
                        <p class="text-sm font-bold text-stone-900">AirtelTigo Money</p>
                        <p class="text-xs text-stone-500 mt-0.5">Mobile Money</p>
                      </div>
                    </button>

                    <%!-- Card Payment --%>
                    <button
                      type="button"
                      phx-click="select_payment"
                      phx-value-method="card"
                      class={"cursor-pointer relative flex flex-col items-center text-center gap-3 p-5 sm:p-6 bg-white border-2 rounded-2xl transition-all #{if @payment_method == "card", do: "border-blue-500 bg-blue-50/50 shadow-sm", else: "border-stone-200 hover:border-stone-300"}"}
                    >
                      <div class={"absolute top-3 right-3 w-5 h-5 rounded-full border-2 flex items-center justify-center #{if @payment_method == "card", do: "border-blue-500 bg-blue-500", else: "border-stone-300"}"}>
                        <svg
                          :if={@payment_method == "card"}
                          class="w-3 h-3 text-white"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="3"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M4.5 12.75l6 6 9-13.5"
                          />
                        </svg>
                      </div>
                      <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-500 to-blue-700 flex items-center justify-center shadow-sm">
                        <svg
                          class="w-7 h-7 text-white"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v10.5a2.25 2.25 0 002.25 2.25z"
                          />
                        </svg>
                      </div>
                      <div>
                        <p class="text-sm font-bold text-stone-900">Visa / Mastercard</p>
                        <p class="text-xs text-stone-500 mt-0.5">Debit or credit card</p>
                      </div>
                    </button>

                    <%!-- Cash on Delivery. Meaningless for a download: there is
                         no delivery for the buyer to pay cash at. Also refused
                         server-side in handle_payment/2. --%>
                    <button
                      :if={@requires_shipping}
                      type="button"
                      phx-click="select_payment"
                      phx-value-method="cod"
                      class={"cursor-pointer relative flex flex-col items-center text-center gap-3 p-5 sm:p-6 bg-white border-2 rounded-2xl transition-all #{if @payment_method == "cod", do: "border-emerald-500 bg-emerald-50/50 shadow-sm", else: "border-stone-200 hover:border-stone-300"}"}
                    >
                      <div class={"absolute top-3 right-3 w-5 h-5 rounded-full border-2 flex items-center justify-center #{if @payment_method == "cod", do: "border-emerald-500 bg-emerald-500", else: "border-stone-300"}"}>
                        <svg
                          :if={@payment_method == "cod"}
                          class="w-3 h-3 text-white"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="3"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M4.5 12.75l6 6 9-13.5"
                          />
                        </svg>
                      </div>
                      <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-500 to-emerald-700 flex items-center justify-center shadow-sm">
                        <svg
                          class="w-7 h-7 text-white"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z"
                          />
                        </svg>
                      </div>
                      <div>
                        <p class="text-sm font-bold text-stone-900">Pay on Delivery</p>
                        <p class="text-xs text-stone-500 mt-0.5">Cash or MoMo</p>
                      </div>
                    </button>
                  </div>

                  <%!-- Selected method info --%>
                  <div class="mt-5 p-4 bg-stone-50 rounded-xl">
                    <div :if={@payment_method == "momo"} class="flex items-start gap-3">
                      <svg
                        class="w-5 h-5 text-[#FFC107] mt-0.5 shrink-0"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"
                        />
                      </svg>
                      <span class="text-sm text-stone-600">
                        A prompt will appear on your phone. Approve it to pay.
                      </span>
                    </div>
                    <div :if={@payment_method == "vodafone"} class="flex items-start gap-3">
                      <svg
                        class="w-5 h-5 text-voda mt-0.5 shrink-0"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"
                        />
                      </svg>
                      <span class="text-sm text-stone-600">
                        A prompt will appear on your phone. Approve it to pay.
                      </span>
                    </div>
                    <div :if={@payment_method == "card"} class="flex items-start gap-3">
                      <svg
                        class="w-5 h-5 text-blue-500 mt-0.5 shrink-0"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
                        />
                      </svg>
                      <span class="text-sm text-stone-600">
                        You'll be redirected to enter your card details securely.
                      </span>
                    </div>
                    <div :if={@payment_method == "cod"} class="flex items-start gap-3">
                      <svg
                        class="w-5 h-5 text-emerald-500 mt-0.5 shrink-0"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
                        />
                      </svg>
                      <span class="text-sm text-stone-600">
                        Pay the rider with cash or MoMo when your order arrives.
                      </span>
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
                        class={"flex-1 bg-white border rounded-xl px-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-store-accent/30 focus:border-store-accent transition-all #{if @coupon_error, do: "border-red-400", else: "border-stone-200"} disabled:bg-stone-50 disabled:text-stone-400"}
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
                  <div
                    :if={@checkout_error}
                    class="mb-4 bg-red-50 border border-red-200 rounded-xl p-4"
                  >
                    <p class="text-sm text-red-700">{@checkout_error}</p>
                  </div>

                  <button
                    type="submit"
                    disabled={@processing}
                    class="cursor-pointer w-full bg-cta-dark text-white py-4 rounded-xl text-sm font-semibold hover:opacity-90 disabled:bg-stone-200 disabled:text-stone-400 disabled:opacity-100 transition-opacity shadow-sm shadow-cta-dark/20"
                  >
                    <%= if @processing do %>
                      <span class="inline-flex items-center gap-2">
                        <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                          <circle
                            class="opacity-25"
                            cx="12"
                            cy="12"
                            r="10"
                            stroke="currentColor"
                            stroke-width="4"
                          >
                          </circle>
                          <path
                            class="opacity-75"
                            fill="currentColor"
                            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                          >
                          </path>
                        </svg>
                        Processing...
                      </span>
                    <% else %>
                      {"Place Order · #{Currency.format_price(@order_total, @store.currency)}"}
                    <% end %>
                  </button>

                  <div class="flex items-center justify-center gap-2 mt-4 text-xs text-stone-400">
                    <svg
                      class="w-3.5 h-3.5"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      viewBox="0 0 24 24"
                    >
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
                    <h2 class="text-xl font-semibold text-stone-900">
                      Order Summary
                    </h2>
                    <a
                      href={store_path(@store.slug, "/cart")}
                      class="text-sm font-medium text-store-accent hover:underline"
                    >
                      Edit
                    </a>
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
                        <div
                          :if={!item[:image_url]}
                          class="w-full h-full flex items-center justify-center"
                        >
                          <svg
                            class="w-6 h-6 text-stone-300"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="1"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                            />
                          </svg>
                        </div>
                      </div>
                      <div class="flex-1 min-w-0">
                        <h3 class="text-sm font-semibold text-stone-900 truncate">
                          {item.product_title}
                        </h3>
                        <p
                          :if={
                            item[:variant_info] not in [nil, ""] &&
                              item[:variant_info] != item[:sku]
                          }
                          class="text-xs text-stone-500 mt-0.5"
                        >
                          {item[:variant_info]}
                        </p>
                        <p class="text-xs text-stone-500">Qty: {item.quantity}</p>
                      </div>
                      <p class="text-sm font-semibold text-stone-900 flex-shrink-0">
                        {Currency.format_price(item.unit_price * item.quantity, @store.currency)}
                      </p>
                    </div>
                    <div :if={@cart == []} class="text-sm text-stone-400 py-4 text-center">
                      Your cart is empty
                    </div>
                  </div>

                  <%!-- Price Breakdown --%>
                  <div class="border-t border-stone-200 pt-4 space-y-2.5 text-sm">
                    <div class="flex justify-between">
                      <span class="text-stone-500">Subtotal</span>
                      <span class="font-medium text-stone-900">
                        {Currency.format_price(@cart_total, @store.currency)}
                      </span>
                    </div>
                    <%!-- Supplier dispatch is folded into Shipping: buyers
                          shouldn't see supply-chain vocabulary. The merchant
                          admin keeps the per-fulfillment breakdown. --%>
                    <div class="flex justify-between">
                      <span class="text-stone-500">Shipping</span>
                      <span class={"font-medium #{if @effective_delivery_fee + @dispatch_fee_total == 0, do: "text-emerald-600", else: "text-stone-900"}"}>
                        {if @effective_delivery_fee + @dispatch_fee_total == 0,
                          do: "Free",
                          else:
                            Currency.format_price(
                              @effective_delivery_fee + @dispatch_fee_total,
                              @store.currency
                            )}
                      </span>
                    </div>
                    <div :if={@discount_amount > 0} class="flex justify-between">
                      <div class="flex items-center gap-1.5">
                        <span class="text-stone-500">Promo</span>
                        <span class="inline-flex items-center gap-1 text-xs font-medium text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full">
                          <svg
                            class="w-3 h-3"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="2"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M4.5 12.75l6 6 9-13.5"
                            />
                          </svg>
                          {String.upcase(@coupon_code)}
                        </span>
                      </div>
                      <span class="font-medium text-emerald-600">
                        -{Currency.format_price(@discount_amount, @store.currency)}
                      </span>
                    </div>
                  </div>

                  <%!-- Total --%>
                  <div class="border-t border-stone-200 mt-4 pt-4 flex justify-between items-baseline">
                    <span class="text-lg font-semibold text-stone-900">
                      Total
                    </span>
                    <span class="text-2xl font-bold text-stone-900">
                      {Currency.format_price(@order_total, @store.currency)}
                    </span>
                  </div>

                  <%!-- Buyer Protection Badge (TC-2) --%>
                  <div
                    :if={@protection_badge?}
                    id="buyer-protection-badge"
                    class="mt-4 flex items-start gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3.5 text-xs text-emerald-800"
                  >
                    <svg
                      class="w-4 h-4 shrink-0 mt-0.5"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.8"
                      viewBox="0 0 24 24"
                      aria-hidden="true"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
                      />
                    </svg>
                    <span>Protected by Makola — payment held until you confirm delivery.</span>
                  </div>

                  <%!-- Trust Badges --%>
                  <%!-- Honest trust row: real payment facts and the store's own
                       policies — never guarantees no merchant wrote. --%>
                  <div class="grid grid-cols-3 gap-3 mt-6 pt-6 border-t border-stone-100">
                    <div class="flex flex-col items-center gap-1.5 text-center">
                      <svg
                        class="w-5 h-5 text-stone-400"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
                        />
                      </svg>
                      <p class="text-xs text-stone-500 leading-tight">
                        <span class="font-semibold text-stone-700 block">Secure</span>Payment
                      </p>
                    </div>
                    <div class="flex flex-col items-center gap-1.5 text-center">
                      <svg
                        class="w-5 h-5 text-stone-400"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z"
                        />
                      </svg>
                      <p class="text-xs text-stone-500 leading-tight">
                        <span class="font-semibold text-stone-700 block">MoMo</span>&amp; Cards
                      </p>
                    </div>
                    <.link
                      navigate={store_path(@store.slug, "/policies#returns")}
                      class="flex flex-col items-center gap-1.5 text-center rounded focus-visible:ring-2 focus-visible:ring-store-accent focus-visible:outline-none"
                    >
                      <svg
                        class="w-5 h-5 text-stone-400"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3"
                        />
                      </svg>
                      <p class="text-xs text-stone-500 leading-tight underline decoration-stone-300 underline-offset-2">
                        <span class="font-semibold text-stone-700 block no-underline">Returns</span>
                        Store policy
                      </p>
                    </.link>
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
            <p class="text-xs text-stone-400">
              &copy; {Date.utc_today().year} {String.upcase(@store.name)}. All rights reserved.
            </p>
            <div class="flex items-center gap-6">
              <a
                href={store_path(@store.slug, "/policies#privacy")}
                class="text-xs text-stone-400 hover:text-stone-600 transition-colors"
              >
                Privacy Policy
              </a>
              <a
                href={store_path(@store.slug, "/policies#terms")}
                class="text-xs text-stone-400 hover:text-stone-600 transition-colors"
              >
                Terms of Service
              </a>
              <a
                href={store_path(@store.slug, "/policies#shipping")}
                class="text-xs text-stone-400 hover:text-stone-600 transition-colors"
              >
                Refund Policy
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
    """
  end

  # ── Components ──────────────────────────────────────────────────

  attr :payment_method, :string, required: true
  attr :order, :any, required: true
  attr :phone, :string, required: true
  attr :timer_seconds, :integer, required: true
  attr :store, :map, required: true

  defp momo_waiting_state(assigns) do
    assigns =
      assigns
      |> assign(:brand_color, momo_brand_color(assigns.payment_method))
      |> assign(:brand_name, momo_brand_name(assigns.payment_method))
      |> assign(:ussd, momo_ussd(assigns.payment_method))
      |> assign(:timer_display, format_timer(assigns.timer_seconds))
      |> assign(:masked_phone, mask_phone(assigns.phone))

    ~H"""
    <div class="bg-white border border-stone-200 rounded-2xl p-8">
      <div class="flex justify-center mb-6">
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

      <h3 class="text-2xl font-semibold text-stone-900 text-center mb-1">
        Approve on your phone
      </h3>
      <p class="text-sm text-stone-600 text-center mb-8">
        A {@brand_name} payment prompt has been sent to your phone
      </p>

      <div class="space-y-4 mb-8">
        <div class="flex items-start gap-3">
          <div class="w-6 h-6 rounded-full bg-emerald-600 flex items-center justify-center flex-shrink-0 mt-0.5">
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
            <p class="text-sm font-medium text-stone-900">Order created</p>
            <p :if={@order} class="text-xs text-stone-500">#{@order.order_number}</p>
          </div>
        </div>
        <div class="flex items-start gap-3">
          <div class="w-6 h-6 rounded-full bg-emerald-600 flex items-center justify-center flex-shrink-0 mt-0.5">
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
            <p :if={@ussd} id="momo-ussd-hint" class="text-xs text-stone-500">
              Dial {@ussd} if you don't see the prompt
            </p>
          </div>
        </div>
      </div>

      <div class="text-center mb-4">
        <div class="inline-flex items-center gap-2 bg-stone-50 rounded-xl px-5 py-2.5">
          <svg
            class="w-4 h-4 text-stone-500"
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
          <span class="text-sm font-mono font-semibold text-stone-900">{@timer_display}</span>
        </div>
      </div>

      <p class="text-center text-xs text-stone-400">
        Didn't receive the prompt?
        <a
          href={store_path(@store.slug, "/contact")}
          class="text-store-accent font-medium hover:underline"
        >
          Get help
        </a>
      </p>
    </div>
    """
  end

  # The ladder, and the numbers that key it. `@step` values stay 1/2/3 across
  # both shapes so nothing downstream has to know which cart it is looking at.
  defp checkout_steps(true), do: [{1, "Information"}, {2, "Shipping"}, {3, "Payment"}]
  defp checkout_steps(false), do: [{1, "Information"}, {3, "Payment"}]

  defp step_state(step, n) when step > n, do: "done"
  defp step_state(step, n) when step == n, do: "current"
  defp step_state(_step, _n), do: "upcoming"

  # ── Display helpers ─────────────────────────────────────────────

  # TC-2 Buyer Protection: shown only when the charge WILL actually be held —
  # same predicate `OrderSettlement.prepare/2` uses (`Protection.applies?/2`),
  # so the badge and the real settlement decision can never disagree.
  #
  # Dropship caveat: `applies?/2` is a store/link-level predicate that knows
  # nothing about THIS cart. A cart mixing supplier-fulfilled (dropship)
  # items always settles via the dropship split at charge time — dropship
  # wins unconditionally over a protection hold (see
  # `OrderSettlement.prepare/2`) — so showing the badge for one would be a
  # lie. `@dispatch_variants` (loaded at mount, keyed by the cart's own
  # variant ids) already carries each variant's `supplier_id`, so checking
  # it here is free — no extra query.
  defp protection_badge?(assigns) do
    Protection.applies?(assigns.store, nil) and not dropship_cart?(assigns)
  end

  defp dropship_cart?(assigns) do
    Enum.any?(assigns.cart, fn item ->
      case Map.get(assigns.dispatch_variants, item.variant_id) do
        %{supplier_id: supplier_id} -> not is_nil(supplier_id)
        _ -> false
      end
    end)
  end

  defp momo_brand_color("momo"), do: "#FFC107"
  defp momo_brand_color("vodafone"), do: "#E60000"
  defp momo_brand_color(_), do: "#F59E0B"

  # *170# is MTN's alone. It was hardcoded here, so a Telecel or AirtelTigo
  # buyer was told to dial a code that does not belong to their wallet. A
  # method with no USSD code shows no line at all rather than a wrong one.
  defp momo_ussd("momo"), do: "*170#"
  defp momo_ussd("vodafone"), do: "*110#"
  defp momo_ussd("airteltigo"), do: "*110#"
  defp momo_ussd(_), do: nil

  defp momo_brand_name("momo"), do: "MTN Mobile Money"
  defp momo_brand_name("vodafone"), do: "Telecel Cash"
  defp momo_brand_name("airteltigo"), do: "AirtelTigo Money"
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
end
