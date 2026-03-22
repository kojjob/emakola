defmodule EmakolaWeb.Storefront.AccountLive do
  @moduledoc """
  Customer account page — profile details, order history, addresses, and preferences.
  Uses placeholder data until Ash customer resources are implemented.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

  @impl true
  def mount(%{"store_slug" => slug}, _session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:active_tab, "profile")
         |> assign(:page_title, "My Account - #{store.name}")
         |> assign(:customer, placeholder_customer())
         |> assign(:orders, placeholder_orders())
         |> assign(:addresses, placeholder_addresses())}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("save_profile", _params, socket) do
    {:noreply, put_flash(socket, :info, "Profile updated")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-[#FAFAF9] min-h-screen font-sans antialiased">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 class="text-3xl sm:text-4xl font-semibold text-[#1C1917] mb-8">My Account</h1>

        <div class="flex flex-col lg:flex-row gap-8 lg:gap-12">
          <%!-- LEFT SIDEBAR --%>
          <aside class="lg:w-64 flex-shrink-0">
            <%!-- Mobile: horizontal scrollable tabs --%>
            <div class="lg:hidden flex gap-2 overflow-x-auto pb-2 -mx-4 px-4">
              <button
                :for={tab <- tabs()}
                phx-click="switch_tab"
                phx-value-tab={tab.id}
                class={[
                  "cursor-pointer whitespace-nowrap px-4 py-2 text-sm font-medium rounded-full border transition-colors",
                  if(@active_tab == tab.id,
                    do: "bg-[#1C1917] text-white border-[#1C1917]",
                    else: "bg-white text-[#44403C] border-stone-200 hover:border-stone-400"
                  )
                ]}
              >
                {tab.label}
              </button>
            </div>

            <%!-- Desktop: vertical tabs --%>
            <nav class="hidden lg:block space-y-1">
              <button
                :for={tab <- tabs()}
                phx-click="switch_tab"
                phx-value-tab={tab.id}
                class={[
                  "cursor-pointer w-full flex items-center gap-3 px-4 py-3 text-sm rounded-r-lg transition-colors",
                  if(@active_tab == tab.id,
                    do: "font-semibold text-[#1C1917] border-l-2 border-[#B45309] bg-stone-50",
                    else: "text-[#44403C] border-l-2 border-transparent hover:bg-stone-50"
                  )
                ]}
              >
                {tab.label}
              </button>
            </nav>
          </aside>

          <%!-- RIGHT CONTENT --%>
          <div class="flex-1 min-w-0">
            <%!-- PROFILE TAB --%>
            <div :if={@active_tab == "profile"} class="space-y-10">
              <.profile_section customer={@customer} />
              <.recent_orders_section orders={@orders} store={@store} />
            </div>

            <%!-- ORDERS TAB --%>
            <div :if={@active_tab == "orders"} class="space-y-6">
              <h2 class="text-2xl font-semibold text-[#1C1917]">Order History</h2>
              <.order_list orders={@orders} store={@store} />
            </div>

            <%!-- ADDRESSES TAB --%>
            <div :if={@active_tab == "addresses"} class="space-y-6">
              <div class="flex items-center justify-between">
                <h2 class="text-2xl font-semibold text-[#1C1917]">Addresses</h2>
                <button class="cursor-pointer bg-[#1C1917] text-white text-xs font-semibold uppercase tracking-wider px-5 py-2.5 rounded-[20px] hover:bg-stone-800 transition-colors flex items-center gap-2">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 4.5v15m7.5-7.5h-15"
                    />
                  </svg>
                  Add New
                </button>
              </div>
              <.address_list addresses={@addresses} />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # -- Components --

  defp profile_section(assigns) do
    ~H"""
    <section>
      <h2 class="text-2xl font-semibold text-[#1C1917] mb-6">Profile</h2>
      <div class="bg-white rounded-xl border border-stone-200 p-6 sm:p-8">
        <%!-- Avatar --%>
        <div class="flex items-center gap-6 mb-8">
          <div class="w-20 h-20 rounded-full bg-[#B45309] flex items-center justify-center text-white text-2xl font-bold">
            {String.first(@customer.first_name)}{String.first(@customer.last_name)}
          </div>
          <div>
            <h3 class="font-semibold text-[#1C1917] text-lg">
              {@customer.first_name} {@customer.last_name}
            </h3>
            <p class="text-sm text-[#44403C]">Member since March 2026</p>
          </div>
        </div>

        <%!-- Form --%>
        <form phx-submit="save_profile" class="space-y-6">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
            <div>
              <label class="block text-xs font-medium uppercase tracking-wider text-[#44403C] mb-2">
                First Name
              </label>
              <input
                type="text"
                name="first_name"
                value={@customer.first_name}
                class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-[#1C1917] focus:ring-2 focus:ring-[#B45309] focus:border-[#B45309] focus:outline-none transition-colors"
              />
            </div>
            <div>
              <label class="block text-xs font-medium uppercase tracking-wider text-[#44403C] mb-2">
                Last Name
              </label>
              <input
                type="text"
                name="last_name"
                value={@customer.last_name}
                class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-[#1C1917] focus:ring-2 focus:ring-[#B45309] focus:border-[#B45309] focus:outline-none transition-colors"
              />
            </div>
          </div>
          <div>
            <label class="block text-xs font-medium uppercase tracking-wider text-[#44403C] mb-2">
              Email
            </label>
            <input
              type="email"
              name="email"
              value={@customer.email}
              class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-[#1C1917] focus:ring-2 focus:ring-[#B45309] focus:border-[#B45309] focus:outline-none transition-colors"
            />
          </div>
          <div>
            <label class="block text-xs font-medium uppercase tracking-wider text-[#44403C] mb-2">
              Phone
            </label>
            <input
              type="tel"
              name="phone"
              value={@customer.phone}
              class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-[#1C1917] focus:ring-2 focus:ring-[#B45309] focus:border-[#B45309] focus:outline-none transition-colors"
            />
          </div>
          <div class="pt-2">
            <button
              type="submit"
              class="cursor-pointer bg-[#1C1917] text-white text-xs font-semibold uppercase tracking-wider px-8 py-3 rounded-[20px] hover:bg-stone-800 transition-colors"
            >
              Save Changes
            </button>
          </div>
        </form>
      </div>
    </section>
    """
  end

  defp recent_orders_section(assigns) do
    ~H"""
    <section>
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-semibold text-[#1C1917]">Recent Orders</h2>
        <button
          phx-click="switch_tab"
          phx-value-tab="orders"
          class="text-sm font-medium text-[#B45309] hover:text-amber-800 cursor-pointer transition-colors"
        >
          View All
        </button>
      </div>
      <.order_list orders={Enum.take(@orders, 3)} store={@store} />
    </section>
    """
  end

  defp order_list(assigns) do
    ~H"""
    <div class="space-y-4">
      <div
        :for={order <- @orders}
        class="bg-white rounded-xl border border-stone-200 p-5 sm:p-6"
      >
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-4">
            <div class="w-14 h-14 rounded-lg bg-stone-100 flex items-center justify-center flex-shrink-0">
              <svg
                class="w-6 h-6 text-stone-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="1.5"
                  d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
                />
              </svg>
            </div>
            <div>
              <p class="text-sm font-semibold text-[#1C1917]">Order #{order.number}</p>
              <p class="text-xs text-[#44403C] mt-0.5">
                {order.date} &middot; {order.item_count} item{if order.item_count != 1, do: "s"}
              </p>
            </div>
          </div>
          <div class="flex items-center gap-4 sm:gap-6">
            <p class="text-sm font-semibold text-[#1C1917]">
              {Currency.format_price(order.total, @store.currency)}
            </p>
            <span class={[
              "inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium",
              status_badge_classes(order.status)
            ]}>
              {order.status}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp address_list(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <div
        :for={address <- @addresses}
        class="bg-white rounded-xl border border-stone-200 p-6"
      >
        <div class="flex items-center gap-2 mb-3">
          <h3 class="text-sm font-semibold text-[#1C1917]">{address.label}</h3>
          <span
            :if={address.default}
            class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-medium bg-amber-50 text-[#B45309] uppercase tracking-wider"
          >
            Default
          </span>
        </div>
        <p class="text-sm text-[#44403C] leading-relaxed">
          {address.name}<br /> {address.line1}<br /> {address.city}, {address.region}
        </p>
        <div class="flex items-center gap-4 mt-4 pt-4 border-t border-stone-100">
          <button class="cursor-pointer text-xs font-medium text-[#44403C] hover:text-[#1C1917] transition-colors">
            Edit
          </button>
          <button class="cursor-pointer text-xs font-medium text-[#44403C] hover:text-rose-600 transition-colors">
            Delete
          </button>
        </div>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp tabs do
    [
      %{id: "profile", label: "Profile"},
      %{id: "orders", label: "Orders"},
      %{id: "addresses", label: "Addresses"}
    ]
  end

  defp status_badge_classes("Delivered"), do: "bg-green-50 text-green-700"
  defp status_badge_classes("Shipped"), do: "bg-blue-50 text-blue-700"
  defp status_badge_classes("Processing"), do: "bg-amber-50 text-amber-700"
  defp status_badge_classes("Cancelled"), do: "bg-red-50 text-red-700"
  defp status_badge_classes(_), do: "bg-stone-50 text-stone-700"

  defp placeholder_customer do
    %{
      first_name: "Ama",
      last_name: "Mensah",
      email: "ama@example.com",
      phone: "+233 24 000 0000"
    }
  end

  defp placeholder_orders do
    [
      %{
        number: "EM-4821",
        date: "Mar 19, 2026",
        item_count: 1,
        total: 48_500,
        status: "Delivered"
      },
      %{
        number: "EM-4756",
        date: "Mar 12, 2026",
        item_count: 2,
        total: 59_500,
        status: "Shipped"
      },
      %{
        number: "EM-4690",
        date: "Feb 28, 2026",
        item_count: 1,
        total: 27_500,
        status: "Delivered"
      }
    ]
  end

  defp placeholder_addresses do
    [
      %{
        label: "Home",
        default: true,
        name: "Ama Mensah",
        line1: "14 Independence Ave",
        city: "Accra",
        region: "Greater Accra"
      },
      %{
        label: "Office",
        default: false,
        name: "Ama Mensah",
        line1: "5 Oxford Street, Osu",
        city: "Accra",
        region: "Greater Accra"
      }
    ]
  end
end
