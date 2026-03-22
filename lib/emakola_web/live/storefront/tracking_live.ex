defmodule EmakolaWeb.Storefront.TrackingLive do
  @moduledoc """
  Delivery tracking page — shows order status timeline, rider info,
  map placeholder, and collapsible order details.

  Uses placeholder data until real order tracking is implemented.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

  @impl true
  def mount(%{"store_slug" => slug, "order_number" => order_number}, _session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        order = placeholder_order(order_number, store)

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:order_number, order_number)
         |> assign(:order, order)
         |> assign(:details_open, false)
         |> assign(:page_title, "Track Order ##{order_number} - #{store.name}")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("toggle_details", _params, socket) do
    {:noreply, assign(socket, :details_open, !socket.assigns.details_open)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-[#FAFAF9] min-h-screen font-sans antialiased text-stone-800">
      <div class="max-w-lg mx-auto">
        <%!-- HEADER --%>
        <header class="bg-white border-b border-stone-200 px-4 py-4 sticky top-0 z-50">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-base font-bold text-[#1C1917]">{@store.name}</h1>
              <p class="text-xs text-stone-400 font-mono mt-0.5">Order #{@order_number}</p>
            </div>
            <a
              href={"/s/#{@store.slug}"}
              class="text-xs font-semibold text-[#B45309] cursor-pointer"
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
          <%!-- RIDER INFO CARD --%>
          <div class="bg-white rounded-2xl border border-stone-200 p-5">
            <div class="flex items-center gap-4">
              <div class="w-14 h-14 rounded-full bg-[#B45309] flex items-center justify-center text-white text-lg font-bold">
                KA
              </div>
              <div class="flex-1 min-w-0">
                <h2 class="text-base font-bold text-[#1C1917]">{@order.rider.name}</h2>
                <div class="flex items-center gap-2 mt-1">
                  <div class="flex items-center gap-0.5">
                    <svg
                      class="w-3.5 h-3.5 text-amber-400"
                      fill="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z" />
                    </svg>
                    <span class="text-xs font-semibold text-stone-700">{@order.rider.rating}</span>
                  </div>
                  <span class="text-[10px] text-stone-400">
                    ({@order.rider.deliveries} deliveries)
                  </span>
                </div>
                <p class="text-xs text-stone-400 mt-0.5">{@order.rider.vehicle}</p>
              </div>
            </div>

            <%!-- Contact buttons --%>
            <div class="flex gap-3 mt-4">
              <a
                href={"tel:#{@order.rider.phone}"}
                class="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-[#B45309] hover:bg-amber-800 text-white rounded-xl text-sm font-semibold transition-colors"
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
                    d="M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 4.5v2.25z"
                  />
                </svg>
                Call Rider
              </a>
              <a
                href={"https://wa.me/#{String.replace(@order.rider.phone, "+", "")}"}
                target="_blank"
                rel="noopener noreferrer"
                class="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-[#25D366] hover:bg-[#20bd5a] text-white rounded-xl text-sm font-semibold transition-colors"
              >
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
                </svg>
                WhatsApp
              </a>
            </div>
          </div>

          <%!-- STATUS TIMELINE --%>
          <div class="bg-white rounded-2xl border border-stone-200 p-5">
            <h2 class="text-xs font-semibold text-stone-500 uppercase tracking-wide mb-5">
              Delivery Status
            </h2>

            <div class="relative pl-8 space-y-6" role="list" aria-label="Delivery timeline">
              <%!-- Vertical line --%>
              <div class="absolute left-[11px] top-1 bottom-1 w-0.5" aria-hidden="true">
                <div class={"w-full bg-[#B45309] h-[#{timeline_progress(@order.current_step)}%]"}>
                </div>
                <div class={"w-full bg-stone-200 h-[#{100 - timeline_progress(@order.current_step)}%]"}>
                </div>
              </div>

              <div
                :for={{step, index} <- Enum.with_index(@order.timeline)}
                class="relative"
                role="listitem"
                aria-current={if(index == @order.current_step, do: "step")}
              >
                <%!-- Step indicator --%>
                <div class={[
                  "absolute -left-8 top-0 w-6 h-6 rounded-full flex items-center justify-center",
                  cond do
                    index < @order.current_step -> "bg-[#B45309]"
                    index == @order.current_step -> "bg-[#B45309]"
                    true -> "bg-stone-200"
                  end
                ]}>
                  <svg
                    :if={index < @order.current_step}
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
                    :if={index == @order.current_step}
                    class="w-2.5 h-2.5 bg-white rounded-full"
                  >
                  </div>
                  <div
                    :if={index > @order.current_step}
                    class="w-2.5 h-2.5 bg-stone-300 rounded-full"
                  >
                  </div>
                </div>

                <%!-- Step content --%>
                <div>
                  <p class={[
                    "text-sm",
                    cond do
                      index < @order.current_step -> "font-semibold text-[#1C1917]"
                      index == @order.current_step -> "font-bold text-[#B45309]"
                      true -> "font-medium text-stone-400"
                    end
                  ]}>
                    {step.title}
                  </p>
                  <p
                    :if={step.subtitle}
                    class={[
                      "text-xs mt-0.5",
                      if(index == @order.current_step,
                        do: "text-[#B45309] font-medium",
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

          <%!-- MAP PLACEHOLDER --%>
          <div class="bg-white rounded-2xl border border-stone-200 overflow-hidden">
            <div class="relative bg-stone-100 h-48">
              <svg
                class="w-full h-full"
                viewBox="0 0 400 200"
                aria-label="Map showing rider location"
              >
                <defs>
                  <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
                    <path
                      d="M 40 0 L 0 0 0 40"
                      fill="none"
                      stroke="#E2E8F0"
                      stroke-width="0.5"
                    />
                  </pattern>
                </defs>
                <rect width="400" height="200" fill="#F1F5F9" />
                <rect width="400" height="200" fill="url(#grid)" />
                <line
                  x1="0"
                  y1="100"
                  x2="400"
                  y2="100"
                  stroke="#CBD5E1"
                  stroke-width="6"
                  stroke-linecap="round"
                />
                <line
                  x1="200"
                  y1="0"
                  x2="200"
                  y2="200"
                  stroke="#CBD5E1"
                  stroke-width="6"
                  stroke-linecap="round"
                />
                <path
                  d="M140 120 C180 110 220 90 300 80"
                  fill="none"
                  stroke="#B45309"
                  stroke-width="3"
                  stroke-dasharray="6 4"
                  stroke-linecap="round"
                />
                <g transform="translate(300, 80)">
                  <circle cx="0" cy="0" r="10" fill="#B45309" opacity="0.15" />
                  <circle cx="0" cy="0" r="5" fill="#B45309" opacity="0.3" />
                  <circle cx="0" cy="-12" r="8" fill="#F43F5E" />
                  <circle cx="0" cy="-12" r="3" fill="white" />
                  <path d="M0 -4 L0 0" stroke="#F43F5E" stroke-width="2" />
                </g>
                <g transform="translate(140, 120)">
                  <circle cx="0" cy="0" r="12" fill="#B45309" opacity="0.15" />
                  <circle cx="0" cy="0" r="6" fill="#B45309" />
                  <circle cx="0" cy="0" r="2.5" fill="white" />
                </g>
                <text
                  x="140"
                  y="145"
                  fill="#B45309"
                  font-size="9"
                  font-family="Inter, sans-serif"
                  font-weight="600"
                  text-anchor="middle"
                >
                  {@order.rider.first_name}
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
                    <span class="w-2.5 h-2.5 bg-[#B45309] rounded-full animate-pulse"></span>
                    <p class="text-sm font-semibold text-[#1C1917]">
                      {@order.rider.first_name} is {@order.rider.distance} away
                    </p>
                  </div>
                  <span class="text-sm font-bold text-[#B45309]">
                    Estimated {@order.rider.eta}
                  </span>
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
              <span class="text-sm font-semibold text-[#1C1917]">Order Details</span>
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
                  :for={item <- @order.items}
                  class="flex items-center justify-between"
                >
                  <div>
                    <p class="text-sm text-stone-800">{item.title}</p>
                    <p class="text-xs text-stone-400">Qty: {item.quantity}</p>
                  </div>
                  <span class="text-sm font-semibold text-[#1C1917] font-mono">
                    {Currency.format_price(item.price, @store.currency)}
                  </span>
                </div>

                <%!-- Delivery --%>
                <div class="flex items-center justify-between">
                  <p class="text-sm text-stone-500">Delivery</p>
                  <span class="text-sm font-semibold text-[#1C1917] font-mono">
                    {Currency.format_price(@order.delivery_fee, @store.currency)}
                  </span>
                </div>

                <%!-- Total --%>
                <div class="border-t border-stone-100 pt-3 flex items-center justify-between">
                  <p class="text-sm font-bold text-[#1C1917]">Total</p>
                  <span class="text-base font-bold text-[#1C1917] font-mono">
                    {Currency.format_price(@order.total, @store.currency)}
                  </span>
                </div>

                <%!-- Payment --%>
                <div class="flex items-center gap-2 pt-1 pb-2">
                  <span class="w-5 h-5 bg-[#FFC107] rounded-full flex items-center justify-center shrink-0">
                    <svg class="w-3 h-3 text-[#1C1917]" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 14H9V8h2v8zm4 0h-2V8h2v8z" />
                    </svg>
                  </span>
                  <span class="text-xs text-stone-500">{@order.payment_method}</span>
                  <svg
                    class="w-3.5 h-3.5 text-green-500 ml-auto"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.5"
                    viewBox="0 0 24 24"
                    aria-label="Paid"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M4.5 12.75l6 6 9-13.5"
                    />
                  </svg>
                  <span class="text-xs font-semibold text-green-600">Paid</span>
                </div>
              </div>
            </div>
          </div>
        </main>

        <%!-- FOOTER --%>
        <footer class="px-4 py-6 border-t border-stone-200 bg-white text-center space-y-2">
          <div class="flex items-center justify-center gap-2">
            <span class="text-xs text-stone-400">Powered by</span>
            <span class="text-xs font-bold text-stone-600">emakola</span>
          </div>
          <a
            href={"/s/#{@store.slug}"}
            class="text-xs text-[#B45309] font-semibold cursor-pointer"
          >
            Need help? Contact store
          </a>
        </footer>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp timeline_progress(current_step) do
    case current_step do
      0 -> 0
      1 -> 33
      2 -> 65
      3 -> 100
    end
  end

  defp placeholder_order(order_number, _store) do
    %{
      number: order_number,
      current_step: 2,
      rider: %{
        name: "Kofi Asante",
        first_name: "Kofi",
        rating: 4.8,
        deliveries: 142,
        vehicle: "Honda CG 125 (Red)",
        phone: "+233240000000",
        distance: "1.2 km",
        eta: "8 min"
      },
      timeline: [
        %{title: "Order Confirmed", subtitle: nil, time: "2:10 PM"},
        %{title: "Picked Up", subtitle: "Rider collected your package", time: "2:28 PM"},
        %{title: "On The Way", subtitle: "Estimated arrival: 3:10 PM", time: "2:45 PM"},
        %{title: "Delivered", subtitle: nil, time: nil}
      ],
      items: [
        %{title: "Kente Wrap Dress", quantity: 1, price: 28_000}
      ],
      delivery_fee: 1_500,
      total: 29_500,
      payment_method: "MTN Mobile Money"
    }
  end
end
