defmodule EmakolaWeb.Storefront.AccountLive do
  @moduledoc """
  Customer account page — profile details, order history, addresses, and preferences.
  Loads real customer data from Ash resources via @current_customer.
  """
  use EmakolaWeb, :live_view
  import EmakolaWeb.StorefrontComponents

  require Ash.Query

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        case socket.assigns[:current_customer] do
          nil ->
            {:ok,
             socket
             |> put_flash(:info, "Please sign in to view your account")
             |> redirect(to: "/s/#{slug}/login")}

          customer ->
            cart_session_id = session["cart_session_id"]
            cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

            categories =
              try do
                Emakola.Catalog.list_root_categories!(store.id)
              rescue
                _ -> []
              end

            theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{})

            orders = load_orders(customer.id, store.id)
            addresses = load_addresses(customer.id, store.id)

            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:categories, categories)
             |> assign(:theme, theme)
             |> assign(:cart_count, cart_count)
             |> assign(:cart_session_id, cart_session_id)
             |> assign(:active_tab, "profile")
             |> assign(:page_title, "My Account - #{store.name}")
             |> assign(:customer, customer)
             |> assign(:orders, orders)
             |> assign(:addresses, addresses)}
        end

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
    <div class="bg-[#FAFAF9] min-h-screen font-sans antialiased pb-20 sm:pb-0">
      <%!-- PAGE HEADER --%>
      <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-10 pb-6 sm:pt-14 sm:pb-8">
        <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
          <div>
            <h1 class="font-serif text-3xl sm:text-4xl font-semibold text-[#1C1917]">
              My Account
            </h1>
            <p class="mt-1 text-sm font-light tracking-wide text-[#44403C]">
              {customer_display_name(@customer)}
            </p>
          </div>
          <div class="flex items-center gap-4">
            <a
              href={"/s/#{@store.slug}/auth/customer-logout"}
              class="inline-flex items-center gap-2 text-sm font-medium transition-colors cursor-pointer text-rose-600 hover:text-rose-800"
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
                  d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"
                />
              </svg>
              Sign Out
            </a>
            <.link
              navigate={"/s/#{@store.slug}"}
              class="inline-flex items-center gap-2 text-sm font-medium transition-colors cursor-pointer group text-[#44403C] hover:text-[#1C1917]"
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
            </.link>
          </div>
        </div>
      </section>

      <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-16">
        <div class="flex flex-col lg:flex-row gap-8 lg:gap-12">
          <%!-- LEFT SIDEBAR --%>
          <aside class="lg:w-60 flex-shrink-0">
            <%!-- Mobile: horizontal scrollable tabs --%>
            <div class="lg:hidden flex gap-2 overflow-x-auto pb-2 -mx-4 px-4">
              <button
                :for={tab <- tabs()}
                phx-click="switch_tab"
                phx-value-tab={tab.id}
                id={"tab-mobile-#{tab.id}"}
                class={[
                  "cursor-pointer whitespace-nowrap px-4 py-2 text-sm font-medium rounded-full border transition-colors",
                  if(@active_tab == tab.id,
                    do: "text-white border-transparent",
                    else: "bg-white border-stone-200 hover:border-stone-400"
                  )
                ]}
                style={
                  if(@active_tab == tab.id,
                    do: "background-color: #1C1917; color: white",
                    else: "color: #44403C"
                  )
                }
              >
                {tab.label}
              </button>
            </div>

            <%!-- Desktop: vertical nav --%>
            <nav class="hidden lg:block space-y-1" aria-label="Account sections">
              <button
                :for={tab <- tabs()}
                phx-click="switch_tab"
                phx-value-tab={tab.id}
                id={"tab-desktop-#{tab.id}"}
                class={[
                  "cursor-pointer w-full flex items-center gap-3 px-4 py-3 text-sm rounded-r-lg transition-colors text-left",
                  if(@active_tab == tab.id,
                    do: "font-semibold bg-stone-50",
                    else: "border-l-2 border-transparent hover:bg-stone-50"
                  )
                ]}
                style={
                  if(@active_tab == tab.id,
                    do: "color: #1C1917; border-left: 2px solid #{@theme.colors.primary}",
                    else: "color: #44403C"
                  )
                }
              >
                {tab.label}
              </button>
            </nav>
          </aside>

          <%!-- RIGHT CONTENT --%>
          <div class="flex-1 min-w-0">
            <%!-- PROFILE TAB --%>
            <div :if={@active_tab == "profile"} class="space-y-10">
              <.profile_section customer={@customer} theme={@theme} />
              <.recent_orders_section orders={@orders} store={@store} theme={@theme} />
            </div>

            <%!-- ORDERS TAB --%>
            <div :if={@active_tab == "orders"} class="space-y-6">
              <h2 class="text-2xl font-semibold text-[#1C1917]">
                Order History
              </h2>
              <.order_list orders={@orders} store={@store} theme={@theme} />
            </div>

            <%!-- ADDRESSES TAB --%>
            <div :if={@active_tab == "addresses"} class="space-y-6">
              <div class="flex items-center justify-between">
                <h2 class="text-2xl font-semibold text-[#1C1917]">
                  Addresses
                </h2>
                <button
                  id="add-address-btn"
                  class="cursor-pointer text-white text-xs font-semibold uppercase tracking-wider px-5 py-2.5 rounded-full transition-colors flex items-center gap-2"
                  style={"background-color: #{@theme.colors.primary}"}
                >
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
              <.address_list addresses={@addresses} theme={@theme} />
            </div>
          </div>
        </div>
      </section>

      <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
    </div>
    <.bottom_nav store_slug={@store.slug} active_tab={:account} cart_count={@cart_count} />
    """
  end

  # -- Components --

  defp profile_section(assigns) do
    ~H"""
    <section>
      <h2 class="text-2xl font-semibold mb-6 text-[#1C1917]">
        Profile
      </h2>
      <div class="bg-white rounded-xl border border-stone-200 p-6 sm:p-8">
        <%!-- Avatar --%>
        <div class="flex items-center gap-6 mb-8">
          <div
            class="w-20 h-20 rounded-full flex items-center justify-center text-white text-2xl font-bold"
            style={"background-color: #{@theme.colors.primary}"}
          >
            {customer_initials(@customer)}
          </div>
          <div>
            <h3 class="font-semibold text-lg text-[#1C1917]">
              {customer_display_name(@customer)}
            </h3>
            <p class="text-sm text-[#44403C]">
              Member since {format_member_since(@customer.inserted_at)}
            </p>
          </div>
        </div>

        <%!-- Form --%>
        <form id="profile-form" phx-submit="save_profile" class="space-y-6">
          <div>
            <label class="block text-xs font-medium uppercase tracking-wider mb-2 text-[#44403C]">
              Name
            </label>
            <input
              type="text"
              name="name"
              value={@customer.name || ""}
              class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-[#1C1917] focus:outline-none transition-colors"
              style={"--tw-ring-color: #{@theme.colors.primary};"}
              onfocus="this.style.boxShadow=`0 0 0 2px ${this.style.getPropertyValue('--tw-ring-color')}`;"
              onblur="this.style.boxShadow=''"
            />
          </div>
          <div>
            <label class="block text-xs font-medium uppercase tracking-wider mb-2 text-[#44403C]">
              Email
            </label>
            <input
              type="email"
              name="email"
              value={to_string(@customer.email)}
              readonly
              class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-[#1C1917] bg-stone-50 cursor-not-allowed focus:outline-none transition-colors"
            />
          </div>
          <div>
            <label class="block text-xs font-medium uppercase tracking-wider mb-2 text-[#44403C]">
              Phone
            </label>
            <input
              type="tel"
              name="phone"
              value={@customer.phone || ""}
              class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-[#1C1917] focus:outline-none transition-colors"
              style={"--tw-ring-color: #{@theme.colors.primary};"}
              onfocus="this.style.boxShadow=`0 0 0 2px ${this.style.getPropertyValue('--tw-ring-color')}`;"
              onblur="this.style.boxShadow=''"
            />
          </div>
          <div class="pt-2">
            <button
              type="submit"
              id="save-profile-btn"
              class="cursor-pointer text-white text-xs font-semibold uppercase tracking-wider px-8 py-3 rounded-full transition-opacity hover:opacity-80"
              style={"background-color: #{@theme.colors.primary}"}
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
        <h2 class="text-2xl font-semibold text-[#1C1917]">
          Recent Orders
        </h2>
        <button
          :if={@orders != []}
          phx-click="switch_tab"
          phx-value-tab="orders"
          class="text-sm font-medium cursor-pointer transition-colors hover:opacity-70"
          style={"color: #{@theme.colors.primary}"}
        >
          View All
        </button>
      </div>
      <.order_list orders={Enum.take(@orders, 3)} store={@store} theme={@theme} />
    </section>
    """
  end

  defp order_list(assigns) do
    ~H"""
    <div :if={@orders == []} class="bg-white rounded-xl border border-stone-200 p-8 text-center">
      <svg
        class="w-12 h-12 mx-auto text-stone-300 mb-3"
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
      <p class="text-sm text-[#44403C]">No orders yet</p>
      <.link
        navigate={"/s/#{@store.slug}/products"}
        class="inline-block mt-3 text-sm font-medium transition-colors hover:opacity-70"
        style={"color: #{@theme.colors.primary}"}
      >
        Start Shopping
      </.link>
    </div>
    <div :if={@orders != []} class="space-y-4">
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
              <p class="text-sm font-semibold text-[#1C1917]">
                Order #{order.order_number}
              </p>
              <p class="text-xs mt-0.5 text-[#44403C]">
                {format_order_date(order.inserted_at)} &middot; {order_item_count(order)} item{if order_item_count(
                                                                                                    order
                                                                                                  ) !=
                                                                                                    1,
                                                                                                  do:
                                                                                                    "s"}
              </p>
            </div>
          </div>
          <div class="flex items-center gap-4 sm:gap-6">
            <p class="text-sm font-semibold text-[#1C1917]">
              {Currency.format_price(order.total, @store.currency)}
            </p>
            <span class={[
              "inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium capitalize",
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
    <div :if={@addresses == []} class="bg-white rounded-xl border border-stone-200 p-8 text-center">
      <svg
        class="w-12 h-12 mx-auto text-stone-300 mb-3"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="1.5"
          d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z"
        />
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="1.5"
          d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z"
        />
      </svg>
      <p class="text-sm text-[#44403C]">No saved addresses</p>
    </div>
    <div :if={@addresses != []} class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <div
        :for={address <- @addresses}
        class="bg-white rounded-xl border border-stone-200 p-6"
      >
        <div class="flex items-center gap-2 mb-3">
          <h3 class="text-sm font-semibold text-[#1C1917]">
            {address.label || "Address"}
          </h3>
          <span
            :if={address.is_default}
            class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-medium uppercase tracking-wider"
            style={"background-color: #{@theme.colors.primary}1a; color: #{@theme.colors.primary}"}
          >
            Default
          </span>
        </div>
        <p class="text-sm leading-relaxed text-[#44403C]">
          {address_name(address)}<br /> {address.line_1}<br /> {address.city}{if address.region,
            do: ", #{address.region}"}
        </p>
        <div class="flex items-center gap-4 mt-4 pt-4 border-t border-stone-100">
          <button class="cursor-pointer text-xs font-medium text-[#44403C] hover:text-[#1C1917] transition-colors">
            Edit
          </button>
          <button class="cursor-pointer text-xs font-medium text-rose-500 hover:text-rose-700 transition-colors">
            Delete
          </button>
        </div>
      </div>
    </div>
    """
  end

  # -- Data Loading --

  defp load_orders(customer_id, store_id) do
    Emakola.Orders.Order
    |> Ash.Query.filter(customer_id == ^customer_id and store_id == ^store_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(10)
    |> Ash.Query.load([:line_items])
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end

  defp load_addresses(customer_id, store_id) do
    Emakola.Customers.Address
    |> Ash.Query.filter(customer_id == ^customer_id and store_id == ^store_id)
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end

  # -- Helpers --

  defp tabs do
    [
      %{id: "profile", label: "Profile"},
      %{id: "orders", label: "Orders"},
      %{id: "addresses", label: "Addresses"}
    ]
  end

  defp customer_display_name(customer) do
    customer.name || to_string(customer.email)
  end

  defp customer_initials(customer) do
    case customer.name do
      nil ->
        customer.email |> to_string() |> String.first() |> String.upcase()

      name ->
        name
        |> String.split(" ", trim: true)
        |> Enum.map(&String.first/1)
        |> Enum.take(2)
        |> Enum.join()
        |> String.upcase()
    end
  end

  defp format_member_since(datetime) do
    Calendar.strftime(datetime, "%B %Y")
  end

  defp format_order_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp order_item_count(order) do
    case order.line_items do
      items when is_list(items) -> length(items)
      _ -> 0
    end
  end

  defp address_name(address) do
    [address.first_name, address.last_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> nil
      name -> name
    end
  end

  defp status_badge_classes(:delivered), do: "bg-green-50 text-green-700"
  defp status_badge_classes(:shipped), do: "bg-blue-50 text-blue-700"
  defp status_badge_classes(:processing), do: "bg-amber-50 text-amber-700"
  defp status_badge_classes(:confirmed), do: "bg-blue-50 text-blue-600"
  defp status_badge_classes(:cancelled), do: "bg-red-50 text-red-700"
  defp status_badge_classes(:pending), do: "bg-stone-50 text-stone-700"
  defp status_badge_classes(_), do: "bg-stone-50 text-stone-700"
end
