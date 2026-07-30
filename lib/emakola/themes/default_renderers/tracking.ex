defmodule Emakola.Themes.DefaultRenderers.Tracking do
  @moduledoc """
  Default render for the storefront order-tracking page.

  Used by `EmakolaWeb.Storefront.TrackingLive` when no theme overrides
  `:render_tracking`. Includes the status hero, status icons, rider
  card, timeline progress computation, and per-status copy helpers.

  See `docs/PATTERN-default-renderer-extraction.md`.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias EmakolaWeb.Helpers.Currency

  def render(assigns) do
    ~H"""
    <Emakola.Themes.DefaultRenderers.Chrome.navbar
      theme_module={assigns[:theme_module]}
      store={@store}
      categories={@categories}
      cart_count={@cart_count}
      active_path="track"
    />

    <div class="bg-[#FAFAF9] min-h-screen font-sans antialiased text-stone-800">
      <div class="max-w-lg mx-auto">
        <%!-- HEADER --%>
        <header class="bg-white border-b border-stone-200 px-4 py-4 sticky top-0 z-50">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-base font-bold text-cta-dark">{@store.name}</h1>
              <p class="text-xs text-stone-400 font-mono mt-0.5">Order #{@order_number}</p>
            </div>
            <a
              href={store_path(@store.slug, "/")}
              class="text-xs font-semibold text-store-accent cursor-pointer"
              aria-label="Go back"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </a>
          </div>
        </header>

        <%!-- MAIN CONTENT --%>
        <main class="px-4 py-5 space-y-5">
          <%!-- STATUS HERO / RIDER CARD --%>
          <%= if @order.status == :shipped do %>
            <.rider_card store={@store} />
          <% else %>
            <.status_hero status={@order.status} />
          <% end %>

          <%!-- BUYER PROTECTION STRIP (any viewer, when a hold exists) --%>
          <.protection_strip
            :if={@protection_hold}
            hold={@protection_hold}
            buyer_authorized?={@buyer_authorized?}
            complaint_form_open={@complaint_form_open}
          />

          <%!-- STATUS TIMELINE --%>
          <div class="bg-white rounded-2xl border border-stone-200 p-5">
            <h2 class="text-xs font-semibold text-stone-500 uppercase tracking-wide mb-5">
              Delivery Status
            </h2>

            <div class="relative pl-8 space-y-6" role="list" aria-label="Delivery timeline">
              <%!-- Vertical line --%>
              <div class="absolute left-[11px] top-1 bottom-1 w-0.5" aria-hidden="true">
                <div class={"w-full bg-store-accent h-[#{timeline_progress(@tracking.current_step)}%]"}>
                </div>
                <div class={"w-full bg-stone-200 h-[#{100 - timeline_progress(@tracking.current_step)}%]"}>
                </div>
              </div>

              <div
                :for={{step, index} <- Enum.with_index(@tracking.timeline)}
                class="relative"
                role="listitem"
                aria-current={if(index == @tracking.current_step, do: "step")}
              >
                <%!-- Step indicator --%>
                <div class={[
                  "absolute -left-8 top-0 w-6 h-6 rounded-full flex items-center justify-center",
                  cond do
                    index < @tracking.current_step -> "bg-store-accent"
                    index == @tracking.current_step -> "bg-store-accent"
                    true -> "bg-stone-200"
                  end
                ]}>
                  <svg
                    :if={index < @tracking.current_step}
                    class="w-3.5 h-3.5 text-white"
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
                  <div
                    :if={index == @tracking.current_step}
                    class="w-2.5 h-2.5 bg-white rounded-full"
                  >
                  </div>
                  <div
                    :if={index > @tracking.current_step}
                    class="w-2.5 h-2.5 bg-stone-300 rounded-full"
                  >
                  </div>
                </div>

                <%!-- Step content --%>
                <div>
                  <p class={[
                    "text-sm",
                    cond do
                      index < @tracking.current_step -> "font-semibold text-cta-dark"
                      index == @tracking.current_step -> "font-bold text-store-accent"
                      true -> "font-medium text-stone-400"
                    end
                  ]}>
                    {step.title}
                  </p>
                  <p
                    :if={step.subtitle}
                    class={[
                      "text-xs mt-0.5",
                      if(index == @tracking.current_step,
                        do: "text-store-accent font-medium",
                        else: "text-stone-500"
                      )
                    ]}
                  >
                    {step.subtitle}
                  </p>
                  <p :if={step.time} class="text-xs text-stone-400 mt-0.5">{step.time}</p>
                </div>
              </div>
            </div>
          </div>

          <%!-- MAP PLACEHOLDER (only when shipped) --%>
          <div
            :if={@order.status == :shipped}
            class="bg-white rounded-2xl border border-stone-200 overflow-hidden"
          >
            <div class="relative bg-stone-100 h-48">
              <svg
                class="w-full h-full"
                viewBox="0 0 400 200"
                aria-label="Map showing delivery route"
              >
                <defs>
                  <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
                    <path
                      d="M 40 0 L 0 0 0 40"
                      fill="none"
                      stroke="#E7E5E4"
                      stroke-width="0.5"
                    />
                  </pattern>
                </defs>
                <rect width="400" height="200" fill="#F5F5F4" />
                <rect width="400" height="200" fill="url(#grid)" />
                <line
                  x1="0"
                  y1="100"
                  x2="400"
                  y2="100"
                  stroke="#D6D3D1"
                  stroke-width="6"
                  stroke-linecap="round"
                />
                <line
                  x1="200"
                  y1="0"
                  x2="200"
                  y2="200"
                  stroke="#D6D3D1"
                  stroke-width="6"
                  stroke-linecap="round"
                />
                <path
                  d="M140 120 C180 110 220 90 300 80"
                  fill="none"
                  stroke="var(--theme-primary, #B45309)"
                  stroke-width="3"
                  stroke-dasharray="6 4"
                  stroke-linecap="round"
                />
                <g transform="translate(300, 80)">
                  <circle cx="0" cy="0" r="10" fill="var(--theme-primary, #B45309)" opacity="0.15" />
                  <circle cx="0" cy="0" r="5" fill="var(--theme-primary, #B45309)" opacity="0.3" />
                  <circle cx="0" cy="-12" r="8" fill="#F43F5E" />
                  <circle cx="0" cy="-12" r="3" fill="white" />
                  <path d="M0 -4 L0 0" stroke="#F43F5E" stroke-width="2" />
                </g>
                <g transform="translate(140, 120)">
                  <circle cx="0" cy="0" r="12" fill="var(--theme-primary, #B45309)" opacity="0.15" />
                  <circle cx="0" cy="0" r="6" fill="var(--theme-primary, #B45309)" />
                  <circle cx="0" cy="0" r="2.5" fill="white" />
                </g>
                <text
                  x="140"
                  y="145"
                  fill="var(--theme-primary, #B45309)"
                  font-size="9"
                  font-family="Inter, sans-serif"
                  font-weight="600"
                  text-anchor="middle"
                >
                  Rider
                </text>
                <text
                  x="300"
                  y="60"
                  fill="#F43F5E"
                  font-size="9"
                  font-family="Inter, sans-serif"
                  font-weight="600"
                  text-anchor="middle"
                >
                  Drop-off
                </text>
              </svg>

              <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-white/90 to-transparent px-4 py-3">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <span class="w-2.5 h-2.5 bg-store-accent rounded-full animate-pulse"></span>
                    <p class="text-sm font-semibold text-cta-dark">
                      Your order is on the way
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- ORDER SUMMARY (Collapsible) --%>
          <div class="bg-white rounded-2xl border border-stone-200">
            <button
              phx-click="toggle_details"
              class="w-full flex items-center justify-between px-5 py-4 cursor-pointer rounded-2xl"
              aria-expanded={to_string(@details_open)}
            >
              <span class="text-sm font-semibold text-cta-dark">Order Details</span>
              <svg
                class={"w-4 h-4 text-stone-400 transition-transform #{if @details_open, do: "rotate-180"}"}
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                />
              </svg>
            </button>

            <div :if={@details_open} class="px-5">
              <div class="border-t border-stone-100 py-4 space-y-3">
                <%!-- Items --%>
                <div
                  :for={item <- @order.line_items}
                  class="flex items-center justify-between"
                >
                  <div>
                    <p class="text-sm text-stone-800">{item.product_title}</p>
                    <p class="text-xs text-stone-400">Qty: {item.quantity}</p>
                  </div>
                  <span class="text-sm font-semibold text-cta-dark font-mono">
                    {Currency.format_price(item.line_total, @order.currency)}
                  </span>
                </div>

                <%!-- Subtotal --%>
                <div class="flex items-center justify-between">
                  <p class="text-sm text-stone-500">Subtotal</p>
                  <span class="text-sm font-semibold text-cta-dark font-mono">
                    {Currency.format_price(@order.subtotal, @order.currency)}
                  </span>
                </div>

                <%!-- Total --%>
                <div class="border-t border-stone-100 pt-3 flex items-center justify-between">
                  <p class="text-sm font-bold text-cta-dark">Total</p>
                  <span class="text-base font-bold text-cta-dark font-mono">
                    {Currency.format_price(@order.total, @order.currency)}
                  </span>
                </div>

                <%!-- Shipping address --%>
                <div :if={@order.shipping_address} class="pt-2 border-t border-stone-100">
                  <p class="text-xs font-semibold text-stone-500 uppercase tracking-wide mb-1">
                    Delivery To
                  </p>
                  <p :if={@order.shipping_address["name"]} class="text-sm text-stone-700">
                    {@order.shipping_address["name"]}
                  </p>
                  <p :if={@order.shipping_address["address"]} class="text-xs text-stone-500">
                    {@order.shipping_address["address"]}
                  </p>
                  <p :if={@order.shipping_address["phone"]} class="text-xs text-stone-500">
                    {@order.shipping_address["phone"]}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </main>

        <%!-- FOOTER --%>
        <Emakola.Themes.DefaultRenderers.Chrome.footer
          theme_module={assigns[:theme_module]}
          store={@store}
          categories={@categories}
        />
      </div>
    </div>
    """
  end

  # -- Components --

  attr :status, :atom, required: true

  defp status_hero(assigns) do
    {icon, color, title, subtitle} = status_hero_content(assigns.status)
    assigns = assign(assigns, icon: icon, color: color, title: title, subtitle: subtitle)

    ~H"""
    <div class="bg-white rounded-2xl border border-stone-200 p-5">
      <div class="flex items-center gap-4">
        <div class={"w-14 h-14 rounded-full flex items-center justify-center #{@color}"}>
          <.status_icon icon={@icon} />
        </div>
        <div class="flex-1 min-w-0">
          <h2 class="text-base font-bold text-cta-dark">{@title}</h2>
          <p class="text-sm text-stone-500 mt-1">{@subtitle}</p>
        </div>
      </div>
    </div>
    """
  end

  attr :icon, :atom, required: true

  defp status_icon(%{icon: :clock} = assigns) do
    ~H"""
    <svg
      class="w-6 h-6 text-white"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
    """
  end

  defp status_icon(%{icon: :check} = assigns) do
    ~H"""
    <svg
      class="w-6 h-6 text-white"
      fill="none"
      stroke="currentColor"
      stroke-width="2.5"
      viewBox="0 0 24 24"
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
    </svg>
    """
  end

  defp status_icon(%{icon: :box} = assigns) do
    ~H"""
    <svg
      class="w-6 h-6 text-white"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"
      />
    </svg>
    """
  end

  defp status_icon(%{icon: :delivered} = assigns) do
    ~H"""
    <svg
      class="w-6 h-6 text-white"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
    """
  end

  defp status_icon(%{icon: :cancelled} = assigns) do
    ~H"""
    <svg
      class="w-6 h-6 text-white"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      viewBox="0 0 24 24"
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
    </svg>
    """
  end

  attr :store, :map, required: true

  defp rider_card(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-stone-200 p-5">
      <div class="flex items-center gap-4">
        <div class="w-14 h-14 rounded-full bg-store-accent flex items-center justify-center text-white text-lg font-bold">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
            />
          </svg>
        </div>
        <div class="flex-1 min-w-0">
          <h2 class="text-base font-bold text-cta-dark">Order Shipped</h2>
          <p class="text-sm text-stone-500 mt-1">Your order is on its way to you</p>
        </div>
      </div>

      <%!-- Contact store button --%>
      <div class="flex gap-3 mt-4">
        <a
          href={store_path(@store.slug, "/about")}
          class="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-store-accent hover:opacity-90 text-white rounded-xl text-sm font-semibold transition-opacity"
        >
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
              d="M13.5 21v-7.5a.75.75 0 01.75-.75h3a.75.75 0 01.75.75V21m-4.5 0H2.36m11.14 0H18m0 0h3.64m-1.39 0V9.349m-16.5 11.65V9.35m0 0a3.001 3.001 0 003.75-.615A2.993 2.993 0 009.75 9.75c.896 0 1.7-.393 2.25-1.016a2.993 2.993 0 002.25 1.016c.896 0 1.7-.393 2.25-1.016a3.001 3.001 0 003.75.614m-16.5 0a3.004 3.004 0 01-.621-4.72L4.318 3.44A1.5 1.5 0 015.378 3h13.243a1.5 1.5 0 011.06.44l1.19 1.189a3 3 0 01-.621 4.72m-13.5 8.65h3.75a.75.75 0 00.75-.75V13.5a.75.75 0 00-.75-.75H6.75a.75.75 0 00-.75.75v3.75c0 .415.336.75.75.75z"
            />
          </svg>
          Contact Store
        </a>
      </div>
    </div>
    """
  end

  # Renders for ANY viewer once a hold exists (held/frozen/released/refunded)
  # — the buyer/report controls render ONLY when `buyer_authorized?` (TC-2:
  # a bare tracking URL must never move money; only the signed link does).
  attr :hold, :map, required: true
  attr :buyer_authorized?, :boolean, required: true
  attr :complaint_form_open, :boolean, required: true

  defp protection_strip(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-stone-200 p-5">
      <div class="flex items-start gap-3">
        <span class="text-xl" aria-hidden="true">🛡️</span>
        <div class="flex-1 min-w-0">
          <h2 class="text-sm font-bold text-cta-dark">Makola Buyer Protection</h2>
          <p class="text-sm text-stone-600 mt-1">{protection_status_copy(@hold)}</p>
        </div>
      </div>

      <div
        :if={@buyer_authorized? and @hold.status == :held and is_nil(@hold.frozen_at)}
        class="mt-4 flex flex-col gap-2"
      >
        <button
          phx-click="confirm_received"
          class="w-full px-4 py-2.5 bg-store-accent hover:opacity-90 text-white rounded-xl text-sm font-semibold transition-opacity"
        >
          I received my order
        </button>
        <button
          phx-click="open_complaint"
          class="w-full px-4 py-2.5 border border-stone-300 hover:bg-stone-50 text-stone-700 rounded-xl text-sm font-semibold transition-colors"
        >
          Report a problem
        </button>
      </div>

      <form
        :if={@buyer_authorized? and @complaint_form_open}
        phx-submit="file_complaint"
        class="mt-4 space-y-3 border-t border-stone-100 pt-4"
      >
        <div>
          <label
            class="text-xs font-semibold text-stone-500 uppercase tracking-wide"
            for="complaint_reason"
          >
            What went wrong?
          </label>
          <select
            id="complaint_reason"
            name="reason"
            class="mt-1 w-full rounded-lg border border-stone-300 text-sm px-3 py-2"
          >
            <option value="not_received">I never received it</option>
            <option value="not_as_described">Not as described</option>
            <option value="other">Something else</option>
          </select>
        </div>
        <div>
          <label
            class="text-xs font-semibold text-stone-500 uppercase tracking-wide"
            for="complaint_text"
          >
            Details
          </label>
          <textarea
            id="complaint_text"
            name="text"
            rows="3"
            class="mt-1 w-full rounded-lg border border-stone-300 text-sm px-3 py-2"
            placeholder="Tell us what happened"
          ></textarea>
        </div>
        <button
          type="submit"
          class="w-full px-4 py-2.5 bg-cta-dark hover:opacity-90 text-white rounded-xl text-sm font-semibold transition-opacity"
        >
          Submit complaint
        </button>
      </form>
    </div>
    """
  end

  defp protection_status_copy(%{status: :held, frozen_at: frozen_at})
       when not is_nil(frozen_at) do
    "Complaint under review — the payment stays held while we look into it."
  end

  defp protection_status_copy(%{status: :held, release_after: release_after})
       when not is_nil(release_after) do
    "Payment held until #{format_date(release_after)}, or as soon as you confirm delivery."
  end

  defp protection_status_copy(%{status: :held}) do
    "Payment held until you confirm delivery."
  end

  defp protection_status_copy(%{status: :released}) do
    "Payment released to the seller — thanks for confirming."
  end

  defp protection_status_copy(%{status: :refunded}) do
    "This order was refunded and the protection hold closed."
  end

  defp format_date(datetime), do: Calendar.strftime(datetime, "%b %d, %Y")

  # -- Helpers --

  defp status_hero_content(:pending) do
    {:clock, "bg-amber-500", "Awaiting Confirmation", "Waiting for payment confirmation"}
  end

  defp status_hero_content(:confirmed) do
    {:check, "bg-green-500", "Order Confirmed", "Your payment has been verified"}
  end

  defp status_hero_content(:processing) do
    {:box, "bg-blue-500", "Being Prepared", "The seller is preparing your order"}
  end

  defp status_hero_content(:delivered) do
    {:delivered, "bg-green-600", "Delivered", "Your order has been delivered"}
  end

  defp status_hero_content(:cancelled) do
    {:cancelled, "bg-red-500", "Order Cancelled", "This order has been cancelled"}
  end

  defp status_hero_content(_) do
    {:clock, "bg-stone-400", "Order Status", "Checking order status..."}
  end

  defp timeline_progress(current_step) do
    case current_step do
      0 -> 0
      1 -> 25
      2 -> 50
      3 -> 75
      4 -> 100
      _ -> 0
    end
  end
end
