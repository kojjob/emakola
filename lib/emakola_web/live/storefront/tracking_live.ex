defmodule EmakolaWeb.Storefront.TrackingLive do
  @moduledoc """
  Delivery tracking page — shows order status timeline, rider info,
  map placeholder, and collapsible order details.

  Loads real order data from the database and maps the order status
  to a visual timeline.
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
            tracking = build_tracking_data(order)
            categories = load_root_categories(store)

            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:order_number, order_number)
             |> assign(:order, order)
             |> assign(:tracking, tracking)
             |> assign(:categories, categories)
             |> assign(:details_open, false)
             |> assign(:page_title, "Track Order ##{order_number} - #{store.name}")}

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
  def handle_event("toggle_details", _params, socket) do
    {:noreply, assign(socket, :details_open, !socket.assigns.details_open)}
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :tracking) do
      {:ok, rendered} -> rendered
      :default -> render_default(assigns)
    end
  end

  defp render_default(assigns) do
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
          <%!-- STATUS HERO / RIDER CARD --%>
          <%= if @order.status == :shipped do %>
            <.rider_card store={@store} />
          <% else %>
            <.status_hero status={@order.status} />
          <% end %>

          <%!-- STATUS TIMELINE --%>
          <div class="bg-white rounded-2xl border border-stone-200 p-5">
            <h2 class="text-xs font-semibold text-stone-500 uppercase tracking-wide mb-5">
              Delivery Status
            </h2>

            <div class="relative pl-8 space-y-6" role="list" aria-label="Delivery timeline">
              <%!-- Vertical line --%>
              <div class="absolute left-[11px] top-1 bottom-1 w-0.5" aria-hidden="true">
                <div class={"w-full bg-[#B45309] h-[#{timeline_progress(@tracking.current_step)}%]"}>
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
                    index < @tracking.current_step -> "bg-[#B45309]"
                    index == @tracking.current_step -> "bg-[#B45309]"
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
                      index < @tracking.current_step -> "font-semibold text-[#1C1917]"
                      index == @tracking.current_step -> "font-bold text-[#B45309]"
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
                    <span class="w-2.5 h-2.5 bg-[#B45309] rounded-full animate-pulse"></span>
                    <p class="text-sm font-semibold text-[#1C1917]">
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
                  :for={item <- @order.line_items}
                  class="flex items-center justify-between"
                >
                  <div>
                    <p class="text-sm text-stone-800">{item.product_title}</p>
                    <p class="text-xs text-stone-400">Qty: {item.quantity}</p>
                  </div>
                  <span class="text-sm font-semibold text-[#1C1917] font-mono">
                    {Currency.format_price(item.line_total, @order.currency)}
                  </span>
                </div>

                <%!-- Subtotal --%>
                <div class="flex items-center justify-between">
                  <p class="text-sm text-stone-500">Subtotal</p>
                  <span class="text-sm font-semibold text-[#1C1917] font-mono">
                    {Currency.format_price(@order.subtotal, @order.currency)}
                  </span>
                </div>

                <%!-- Total --%>
                <div class="border-t border-stone-100 pt-3 flex items-center justify-between">
                  <p class="text-sm font-bold text-[#1C1917]">Total</p>
                  <span class="text-base font-bold text-[#1C1917] font-mono">
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
        <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
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
          <h2 class="text-base font-bold text-[#1C1917]">{@title}</h2>
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
        <div class="w-14 h-14 rounded-full bg-[#B45309] flex items-center justify-center text-white text-lg font-bold">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
            />
          </svg>
        </div>
        <div class="flex-1 min-w-0">
          <h2 class="text-base font-bold text-[#1C1917]">Order Shipped</h2>
          <p class="text-sm text-stone-500 mt-1">Your order is on its way to you</p>
        </div>
      </div>

      <%!-- Contact store button --%>
      <div class="flex gap-3 mt-4">
        <a
          href={"/s/#{@store.slug}/about"}
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
              d="M13.5 21v-7.5a.75.75 0 01.75-.75h3a.75.75 0 01.75.75V21m-4.5 0H2.36m11.14 0H18m0 0h3.64m-1.39 0V9.349m-16.5 11.65V9.35m0 0a3.001 3.001 0 003.75-.615A2.993 2.993 0 009.75 9.75c.896 0 1.7-.393 2.25-1.016a2.993 2.993 0 002.25 1.016c.896 0 1.7-.393 2.25-1.016a3.001 3.001 0 003.75.614m-16.5 0a3.004 3.004 0 01-.621-4.72L4.318 3.44A1.5 1.5 0 015.378 3h13.243a1.5 1.5 0 011.06.44l1.19 1.189a3 3 0 01-.621 4.72m-13.5 8.65h3.75a.75.75 0 00.75-.75V13.5a.75.75 0 00-.75-.75H6.75a.75.75 0 00-.75.75v3.75c0 .415.336.75.75.75z"
            />
          </svg>
          Contact Store
        </a>
      </div>
    </div>
    """
  end

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

  defp build_tracking_data(order) do
    current_step = status_to_step(order.status)
    placed_time = format_time(order.inserted_at)
    updated_time = format_time(order.updated_at)

    timeline = [
      %{
        title: "Order Placed",
        subtitle: "Order ##{order.order_number}",
        time: placed_time
      },
      %{
        title: "Confirmed",
        subtitle: "Payment verified",
        time: if(current_step >= 1, do: updated_time)
      },
      %{
        title: "Being Prepared",
        subtitle: "Seller is preparing your order",
        time: if(current_step >= 2, do: updated_time)
      },
      %{
        title: "Shipped",
        subtitle: "On the way to you",
        time: if(current_step >= 3, do: updated_time)
      },
      %{
        title: "Delivered",
        subtitle: nil,
        time: if(current_step >= 4, do: updated_time)
      }
    ]

    %{current_step: current_step, timeline: timeline}
  end

  defp status_to_step(:pending), do: 0
  defp status_to_step(:confirmed), do: 1
  defp status_to_step(:processing), do: 2
  defp status_to_step(:shipped), do: 3
  defp status_to_step(:delivered), do: 4
  defp status_to_step(:cancelled), do: 0
  defp status_to_step(_), do: 0

  defp format_time(nil), do: nil

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  # -- Data Loading --

  defp load_order(store, order_number) do
    case Emakola.Orders.Order
         |> Ash.Query.filter(store_id == ^store.id and order_number == ^order_number)
         |> Ash.Query.load([:line_items])
         |> Ash.read_one() do
      {:ok, nil} -> {:error, :not_found}
      {:ok, order} -> {:ok, order}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp load_root_categories(store) do
    try do
      Emakola.Catalog.list_root_categories!(store.id)
    rescue
      _ -> []
    end
  end
end
