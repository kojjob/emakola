defmodule EmakolaWeb.Storefront.WishlistLive do
  @moduledoc """
  Wishlist page — displays saved/wishlisted products.

  For logged-in customers (`@current_customer` is not nil): loads from the DB
  and persists add/remove operations to the wishlist_items table.

  For guests: keeps session-based behavior as a fallback and shows a
  "Sign in to save your wishlist" prompt.
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.NoIndex, :default}

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver
  alias EmakolaWeb.Storefront.QuickAdd

  @impl true
  def mount(_params, session, socket) do
    slug = socket.assigns.store.slug

    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        # The ResolveCustomer on_mount hook already resolved the customer from
        # the customer_token session — just scope it to THIS store. (Re-reading
        # the session here read a "customer_id" key the storefront live_session
        # never forwards, so the authenticated path was always nil.)
        customer = store_customer(socket.assigns[:current_customer], store)

        # The page never read the shopper's cart session and hardcoded the count
        # to 0, so the header's cart badge read empty here even with a full cart
        # — and "Add to Bag" had no cart to add to.
        cart_session_id = session["cart_session_id"]

        socket =
          socket
          |> assign(:store, store)
          |> assign(:current_customer, customer)
          |> assign(:categories, [])
          |> assign(:cart_session_id, cart_session_id)
          |> assign(:cart_count, CartStore.cart_count(cart_session_id, store.id))
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
          price: parse_price(params["price"]),
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

        # Only wishlist a real, customer-visible product of THIS store — the
        # product_id is client-supplied, so a crafted event must not persist a
        # foreign or hidden product reference.
        case Emakola.Catalog.get_active_product(store.id, params["product_id"], authorize?: false) do
          {:ok, _product} ->
            Emakola.Customers.add_to_wishlist(
              %{
                customer_id: customer.id,
                product_id: params["product_id"],
                store_id: store.id
              },
              authorize?: false
            )

            {:noreply, load_wishlist(socket)}

          _ ->
            {:noreply, socket}
        end
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

  # This matched the event, threw the product id away, and told the shopper
  # "Added to bag" without ever touching the cart. The toast only shows now when
  # something actually landed in the cart — QuickAdd assigns :cart_count on
  # success and flashes an error otherwise (out of stock, no variant).
  @impl true
  def handle_event("add_to_bag", %{"product_id" => product_id}, socket) do
    before = socket.assigns.cart_count
    {:noreply, socket} = QuickAdd.add_to_cart(socket, product_id)

    if socket.assigns.cart_count > before do
      Process.send_after(self(), :clear_flash_bag, 2000)
      {:noreply, assign(socket, :flash_bag, "Added to bag")}
    else
      {:noreply, socket}
    end
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

  # Only treat the hook-resolved customer as signed in when they belong to the
  # store being viewed (a customer is per-store); otherwise fall back to guest.
  defp store_customer(%{store_id: sid} = customer, %{id: sid}), do: customer
  defp store_customer(_customer, _store), do: nil

  # The price arrives from a client event; default to 0 on bad/absent input
  # rather than crashing the LiveView.
  defp parse_price(price) do
    case Integer.parse(to_string(price)) do
      {n, _} -> n
      :error -> 0
    end
  end

  # -- Item accessors (handle both DB-backed WishlistItem and guest maps) --
end
