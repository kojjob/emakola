defmodule EmakolaWeb.Storefront.WishlistLive do
  @moduledoc """
  Wishlist page — displays saved/wishlisted products.

  For logged-in customers (`@current_customer` is not nil): loads from the DB
  and persists add/remove operations to the wishlist_items table.

  For guests: keeps session-based behavior as a fallback and shows a
  "Sign in to save your wishlist" prompt.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.{Currency, StoreResolver}
  alias EmakolaWeb.StorefrontComponents

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        customer = resolve_customer(session, store)

        socket =
          socket
          |> assign(:store, store)
          |> assign(:current_customer, customer)
          |> assign(:flash_bag, nil)
          |> assign(:page_title, "My Wishlist - #{store.name}")
          |> load_wishlist()

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("add_to_wishlist", params, socket) do
    case socket.assigns.current_customer do
      nil ->
        # Guest: session-based fallback
        item = %{
          product_id: params["product_id"],
          title: params["title"],
          price: String.to_integer(params["price"]),
          image_url: params["image_url"]
        }

        wishlist = socket.assigns.wishlist

        unless Enum.any?(wishlist, &(&1.product_id == item.product_id)) do
          {:noreply, assign(socket, :wishlist, wishlist ++ [item])}
        else
          {:noreply, socket}
        end

      customer ->
        store = socket.assigns.store

        Emakola.Customers.add_to_wishlist(%{
          customer_id: customer.id,
          product_id: params["product_id"],
          store_id: store.id
        })

        {:noreply, load_wishlist(socket)}
    end
  end

  @impl true
  def handle_event("toggle_wishlist", %{"product_id" => product_id}, socket) do
    case socket.assigns.current_customer do
      nil ->
        {:noreply, socket}

      customer ->
        store = socket.assigns.store
        wishlisted_ids = socket.assigns.wishlisted_product_ids

        if MapSet.member?(wishlisted_ids, product_id) do
          Emakola.Customers.remove_from_wishlist(customer.id, product_id, store.id)
        else
          Emakola.Customers.add_to_wishlist(%{
            customer_id: customer.id,
            product_id: product_id,
            store_id: store.id
          })
        end

        {:noreply, load_wishlist(socket)}
    end
  end

  @impl true
  def handle_event("remove_from_wishlist", %{"product_id" => product_id}, socket) do
    case socket.assigns.current_customer do
      nil ->
        wishlist = Enum.reject(socket.assigns.wishlist, &(&1.product_id == product_id))
        {:noreply, assign(socket, :wishlist, wishlist)}

      customer ->
        store = socket.assigns.store
        Emakola.Customers.remove_from_wishlist(customer.id, product_id, store.id)
        {:noreply, load_wishlist(socket)}
    end
  end

  @impl true
  def handle_event("add_to_bag", %{"product_id" => _product_id}, socket) do
    {:noreply,
     socket
     |> assign(:flash_bag, "Added to bag")
     |> then(fn s ->
       Process.send_after(self(), :clear_flash_bag, 2000)
       s
     end)}
  end

  @impl true
  def handle_info(:clear_flash_bag, socket) do
    {:noreply, assign(socket, :flash_bag, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-[#FAFAF9] min-h-screen font-sans antialiased">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between mb-10">
          <div>
            <h1 class="text-3xl sm:text-4xl font-semibold text-[#1C1917] mb-2">My Wishlist</h1>
            <p class="text-sm text-[#44403C]">
              {wishlist_count_text(length(@wishlist))}
            </p>
          </div>
          <div class="mt-4 sm:mt-0">
            <a
              href={"/s/#{@store.slug}/products"}
              class="text-sm font-medium text-[#B45309] hover:text-amber-800 transition-colors flex items-center gap-1"
            >
              Continue Shopping
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                />
              </svg>
            </a>
          </div>
        </div>

        <%!-- Guest sign-in prompt --%>
        <div
          :if={is_nil(@current_customer)}
          class="mb-6 px-4 py-3 bg-amber-50 border border-amber-200 rounded-xl text-sm text-amber-800 font-medium flex items-center gap-2"
        >
          <svg
            class="w-5 h-5 flex-shrink-0"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
            />
          </svg>
          <span>Sign in to save your wishlist across devices and sessions.</span>
        </div>

        <%!-- Flash for "Added to bag" --%>
        <div
          :if={@flash_bag}
          class="mb-6 px-4 py-3 bg-green-50 border border-green-200 rounded-xl text-sm text-green-700 font-medium"
        >
          {@flash_bag}
        </div>

        <%!-- Wishlist Grid --%>
        <div :if={@wishlist != []} class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
          <div :for={item <- @wishlist} class="group">
            <div class="relative overflow-hidden rounded-lg bg-stone-100 aspect-[3/4] mb-3">
              <img
                :if={item_image(item)}
                src={item_image(item)}
                alt={item_title(item)}
                class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                loading="lazy"
              />
              <div :if={!item_image(item)} class="w-full h-full flex items-center justify-center">
                <StorefrontComponents.image_placeholder />
              </div>
              <button
                phx-click="remove_from_wishlist"
                phx-value-product_id={item_product_id(item)}
                class="absolute top-3 right-3 cursor-pointer w-9 h-9 rounded-full bg-white/90 backdrop-blur-sm flex items-center justify-center hover:bg-white transition-colors shadow-sm"
                aria-label="Remove from wishlist"
              >
                <svg class="w-5 h-5 text-rose-500" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M11.645 20.91l-.007-.003-.022-.012a15.247 15.247 0 01-.383-.218 25.18 25.18 0 01-4.244-3.17C4.688 15.36 2.25 12.174 2.25 8.25 2.25 5.322 4.714 3 7.688 3A5.5 5.5 0 0112 5.052 5.5 5.5 0 0116.313 3c2.973 0 5.437 2.322 5.437 5.25 0 3.925-2.438 7.111-4.739 9.256a25.175 25.175 0 01-4.244 3.17 15.247 15.247 0 01-.383.219l-.022.012-.007.004-.003.001a.752.752 0 01-.704 0l-.003-.001z" />
                </svg>
              </button>
            </div>
            <div class="px-1">
              <h3 class="text-sm font-medium text-[#1C1917] truncate">{item_title(item)}</h3>
              <p class="text-sm font-semibold text-[#1C1917] mt-1">
                {format_item_price(item, @store)}
              </p>
              <p
                :if={item_stock_status(item)}
                class={"text-xs mt-1 " <> stock_status_class(item_stock_status(item))}
              >
                {item_stock_status(item)}
              </p>
              <div class="mt-3 space-y-2">
                <button
                  phx-click="add_to_bag"
                  phx-value-product_id={item_product_id(item)}
                  class="cursor-pointer w-full bg-[#1C1917] text-white text-xs font-semibold uppercase tracking-wider py-2.5 rounded-[20px] hover:bg-stone-800 transition-colors"
                >
                  Add to Bag
                </button>
                <button
                  phx-click="remove_from_wishlist"
                  phx-value-product_id={item_product_id(item)}
                  class="cursor-pointer w-full text-xs text-[#44403C] hover:text-rose-600 transition-colors py-1"
                >
                  Remove
                </button>
              </div>
            </div>
          </div>
        </div>

        <%!-- Empty State --%>
        <div :if={@wishlist == []} class="text-center py-24">
          <svg
            class="w-20 h-20 mx-auto text-stone-300 mb-6"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
            />
          </svg>
          <h2 class="text-2xl font-semibold text-[#1C1917] mb-2">Your wishlist is empty</h2>
          <p class="text-[#44403C] text-sm mb-8">Save items you love to find them later</p>
          <a
            href={"/s/#{@store.slug}/products"}
            class="inline-block cursor-pointer bg-[#1C1917] text-white text-xs font-semibold uppercase tracking-wider px-8 py-3 rounded-[20px] hover:bg-stone-800 transition-colors"
          >
            Browse Products
          </a>
        </div>
      </div>
    </div>
    """
  end

  # -- Data Loading --

  defp load_wishlist(socket) do
    case socket.assigns.current_customer do
      nil ->
        socket
        |> assign(:wishlist, Map.get(socket.assigns, :wishlist, []))
        |> assign(:wishlisted_product_ids, MapSet.new())

      customer ->
        store = socket.assigns.store
        {:ok, items} = Emakola.Customers.list_wishlist(customer.id, store.id)

        wishlisted_ids =
          items
          |> Enum.map(& &1.product_id)
          |> MapSet.new()

        socket
        |> assign(:wishlist, items)
        |> assign(:wishlisted_product_ids, wishlisted_ids)
    end
  end

  defp resolve_customer(session, store) do
    case Map.get(session, "customer_id") do
      nil ->
        nil

      customer_id ->
        case Emakola.Customers.get_customer_by_id(customer_id) do
          {:ok, customer} when customer.store_id == store.id -> customer
          _ -> nil
        end
    end
  end

  # -- Item accessors (handle both DB-backed WishlistItem and guest maps) --

  defp item_product_id(%{product_id: id}), do: id
  defp item_product_id(%{product: %{id: id}}), do: id

  defp item_title(%{product: %{title: title}}), do: title
  defp item_title(%{title: title}), do: title

  defp item_image(%{product: product}) when is_map(product) do
    StorefrontComponents.first_image(product)
  end

  defp item_image(%{image_url: url}), do: url

  defp format_item_price(%{product: %{min_price: price}}, store) when not is_nil(price) do
    Currency.format_price(price, store.currency)
  end

  defp format_item_price(%{price: price}, store) when is_integer(price) do
    Currency.format_price(price, store.currency)
  end

  defp format_item_price(_, _store), do: ""

  defp item_stock_status(%{product: %{variants: variants}}) when is_list(variants) do
    total_stock = Enum.reduce(variants, 0, fn v, acc -> acc + (v.stock_quantity || 0) end)

    cond do
      total_stock == 0 -> "Out of stock"
      total_stock <= 3 -> "Low stock"
      true -> "In stock"
    end
  end

  defp item_stock_status(_), do: nil

  defp stock_status_class("Out of stock"), do: "text-red-600 font-medium"
  defp stock_status_class("Low stock"), do: "text-amber-600 font-medium"
  defp stock_status_class(_), do: "text-green-600"

  # -- Helpers --

  defp wishlist_count_text(0), do: "0 saved items"
  defp wishlist_count_text(1), do: "1 saved item"
  defp wishlist_count_text(n), do: "#{n} saved items"
end
