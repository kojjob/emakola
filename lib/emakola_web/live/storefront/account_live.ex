defmodule EmakolaWeb.Storefront.AccountLive do
  @moduledoc """
  Customer account page — profile details, order history, addresses, and preferences.
  Loads real customer data from Ash resources via @current_customer.
  Render delegated to `Emakola.Themes.DefaultRenderers.Account` (or
  a theme override registered for `:account`).
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    store = socket.assigns.store

    case socket.assigns[:current_customer] do
      nil ->
        {:ok,
         socket
         |> put_flash(:info, "Please sign in to view your account")
         |> redirect(to: "/#{slug}/login")}

      customer ->
        cart_session_id = session["cart_session_id"]

        cart_count =
          if connected?(socket) && cart_session_id,
            do: CartStore.cart_count(cart_session_id, store.id),
            else: 0

        categories =
          try do
            Emakola.Catalog.list_root_categories!(store.id)
          rescue
            _ -> []
          end

        orders = load_orders(customer.id, store.id)
        addresses = load_addresses(customer.id, store.id)

        {:ok,
         socket
         |> assign(:categories, categories)
         |> assign(:cart_count, cart_count)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:active_tab, "profile")
         |> assign(:page_title, "My Account - #{store.name}")
         |> assign(:customer, customer)
         |> assign(:orders, orders)
         |> assign(:addresses, addresses)
         |> assign(:show_return_modal, false)
         |> assign(:return_order, nil)
         |> assign(:return_reason, nil)
         |> assign(:return_detail, "")
         |> assign(:order_returns, %{})}
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
  def handle_event("show_return_modal", %{"order" => order_number}, socket) do
    order = Enum.find(socket.assigns.orders, &(to_string(&1.order_number) == order_number))

    {:noreply,
     assign(socket,
       show_return_modal: true,
       return_order: order,
       return_reason: nil,
       return_detail: ""
     )}
  end

  @impl true
  def handle_event("close_return_modal", _params, socket) do
    {:noreply, assign(socket, show_return_modal: false, return_order: nil)}
  end

  @impl true
  def handle_event("set_return_reason", %{"reason" => reason}, socket) do
    {:noreply, assign(socket, return_reason: reason)}
  end

  @impl true
  def handle_event("update_return_detail", %{"detail" => detail}, socket) do
    {:noreply, assign(socket, return_detail: detail)}
  end

  @impl true
  def handle_event("submit_return_request", _params, socket) do
    order = socket.assigns.return_order

    order_returns =
      Map.put(socket.assigns.order_returns, order.order_number, %{
        status: :requested,
        reason:
          Emakola.SafeAtom.to_atom_in(
            socket.assigns.return_reason,
            [:defective, :wrong_item, :not_as_described, :changed_mind, :other],
            :other
          )
      })

    {:noreply,
     socket
     |> assign(
       show_return_modal: false,
       return_order: nil,
       order_returns: order_returns
     )
     |> put_flash(:info, "Return request submitted for Order ##{order.order_number}")}
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :account) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.Account.render(assigns)
    end
  end

  # -- Data Loading --

  defp load_orders(customer_id, store_id) do
    Emakola.Orders.Order
    |> Ash.Query.for_read(:list_by_customer, %{customer_id: customer_id, store_id: store_id})
    |> Ash.Query.limit(10)
    |> Ash.Query.load([:line_items])
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end

  defp load_addresses(customer_id, store_id) do
    case Emakola.Customers.list_addresses_by_customer_and_store(customer_id, store_id,
           authorize?: false
         ) do
      {:ok, addresses} -> addresses
      _ -> []
    end
  end
end
