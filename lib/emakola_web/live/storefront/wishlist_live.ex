defmodule EmakolaWeb.Storefront.WishlistLive do
  @moduledoc """
  Wishlist page — displays saved/wishlisted products stored in LiveView assigns.
  Supports add to bag, remove, and empty state with CTA.

  Wishlist is session-scoped (stored in LiveView assigns). In the future,
  this can be backed by a persistent store for logged-in customers.
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
         |> assign(:wishlist, [])
         |> assign(:flash_bag, nil)
         |> assign(:page_title, "My Wishlist - #{store.name}")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("add_to_wishlist", params, socket) do
    item = %{
      product_id: params["product_id"],
      title: params["title"],
      price: String.to_integer(params["price"]),
      image_url: params["image_url"]
    }

    wishlist = socket.assigns.wishlist

    # Don't add duplicates
    unless Enum.any?(wishlist, &(&1.product_id == item.product_id)) do
      {:noreply, assign(socket, :wishlist, wishlist ++ [item])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_from_wishlist", %{"product_id" => product_id}, socket) do
    wishlist = Enum.reject(socket.assigns.wishlist, &(&1.product_id == product_id))
    {:noreply, assign(socket, :wishlist, wishlist)}
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
                src={item.image_url}
                alt={item.title}
                class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                loading="lazy"
              />
              <button
                phx-click="remove_from_wishlist"
                phx-value-product_id={item.product_id}
                class="absolute top-3 right-3 cursor-pointer w-9 h-9 rounded-full bg-white/90 backdrop-blur-sm flex items-center justify-center hover:bg-white transition-colors shadow-sm"
                aria-label="Remove from wishlist"
              >
                <svg class="w-5 h-5 text-rose-500" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M11.645 20.91l-.007-.003-.022-.012a15.247 15.247 0 01-.383-.218 25.18 25.18 0 01-4.244-3.17C4.688 15.36 2.25 12.174 2.25 8.25 2.25 5.322 4.714 3 7.688 3A5.5 5.5 0 0112 5.052 5.5 5.5 0 0116.313 3c2.973 0 5.437 2.322 5.437 5.25 0 3.925-2.438 7.111-4.739 9.256a25.175 25.175 0 01-4.244 3.17 15.247 15.247 0 01-.383.219l-.022.012-.007.004-.003.001a.752.752 0 01-.704 0l-.003-.001z" />
                </svg>
              </button>
            </div>
            <div class="px-1">
              <h3 class="text-sm font-medium text-[#1C1917] truncate">{item.title}</h3>
              <p class="text-sm font-semibold text-[#1C1917] mt-1">
                {Currency.format_price(item.price, @store.currency)}
              </p>
              <div class="mt-3 space-y-2">
                <button
                  phx-click="add_to_bag"
                  phx-value-product_id={item.product_id}
                  class="cursor-pointer w-full bg-[#1C1917] text-white text-xs font-semibold uppercase tracking-wider py-2.5 rounded-[20px] hover:bg-stone-800 transition-colors"
                >
                  Add to Bag
                </button>
                <button
                  phx-click="remove_from_wishlist"
                  phx-value-product_id={item.product_id}
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
            Start Shopping
          </a>
        </div>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp wishlist_count_text(0), do: "0 saved items"
  defp wishlist_count_text(1), do: "1 saved item"
  defp wishlist_count_text(n), do: "#{n} saved items"
end
