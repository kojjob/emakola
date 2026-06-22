defmodule EmakolaWeb.Storefront.WishlistLive do
  @moduledoc """
  Wishlist page — displays saved/wishlisted products.

  For logged-in customers (`@current_customer` is not nil): loads from the DB
  and persists add/remove operations to the wishlist_items table.

  For guests: keeps session-based behavior as a fallback and shows a
  "Sign in to save your wishlist" prompt.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.StoreResolver

  @impl true
  def mount(_params, session, socket) do
    slug = socket.assigns.store.slug

    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        customer = resolve_customer(session, store)

        socket =
          socket
          |> assign(:store, store)
          |> assign(:current_customer, customer)
          |> assign(:categories, [])
          |> assign(:cart_count, 0)
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

        Emakola.Customers.add_to_wishlist(
          %{
            customer_id: customer.id,
            product_id: params["product_id"],
            store_id: store.id
          },
          authorize?: false
        )

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
          Emakola.Customers.remove_from_wishlist(customer.id, product_id, store.id,
            authorize?: false
          )
        else
          Emakola.Customers.add_to_wishlist(
            %{
              customer_id: customer.id,
              product_id: product_id,
              store_id: store.id
            },
            authorize?: false
          )
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

        Emakola.Customers.remove_from_wishlist(customer.id, product_id, store.id,
          authorize?: false
        )

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
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :wishlist) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.Wishlist.render(assigns)
    end
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
end
