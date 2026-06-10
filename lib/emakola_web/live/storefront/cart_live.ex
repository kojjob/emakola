defmodule EmakolaWeb.Storefront.CartLive do
  @moduledoc """
  Shopping cart page — matches cart.html prototype.

  Features:
  - Page header with item count + continue shopping link
  - Cart items with product image, title, variant details, quantity stepper
  - Order summary panel (sticky on desktop)
  - Empty cart state with CTA
  - Responsive layout: stacked mobile, side-by-side desktop
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore

  @impl true
  def mount(_params, session, socket) do
    store = socket.assigns.store
    cart_session_id = session["cart_session_id"]
    cart = if cart_session_id, do: CartStore.get_cart(cart_session_id), else: []

    categories =
      try do
        Emakola.Catalog.list_root_categories!(store.id)
      rescue
        _ -> []
      end

    recommended_products =
      try do
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:list_by_store_and_status, %{
          store_id: store.id,
          status: :active
        })
        |> Ash.Query.limit(4)
        |> Ash.read!(authorize?: false)
      rescue
        _ -> []
      end

    {:ok,
     socket
     |> assign(:categories, categories)
     |> assign(:cart_session_id, cart_session_id)
     |> assign(:cart, cart)
     |> assign(:recommended_products, recommended_products)
     |> assign(:promo_code, nil)
     |> assign(:promo_error, nil)
     |> assign_totals(cart)
     |> assign(:checking_out, false)
     |> assign(:applied_coupon, nil)
     |> assign(:discount_amount, 0)
     |> assign(:page_title, "Shopping Bag - #{store.name}")}
  end

  @impl true
  def handle_event("update_quantity", %{"index" => index_str, "delta" => delta_str}, socket) do
    index = String.to_integer(index_str)
    delta = String.to_integer(delta_str)
    item = Enum.at(socket.assigns.cart, index)
    new_qty = item.quantity + delta

    if new_qty <= 0 do
      CartStore.remove_item(socket.assigns.cart_session_id, item.variant_id)
    else
      CartStore.update_quantity(socket.assigns.cart_session_id, item.variant_id, min(new_qty, 10))
    end

    {:noreply, reload_cart(socket)}
  end

  @impl true
  def handle_event("update_quantity", %{"index" => index_str, "quantity" => qty_str}, socket) do
    index = String.to_integer(index_str)
    quantity = String.to_integer(qty_str)
    item = Enum.at(socket.assigns.cart, index)

    if item do
      if quantity <= 0 do
        CartStore.remove_item(socket.assigns.cart_session_id, item.variant_id)
      else
        CartStore.update_quantity(socket.assigns.cart_session_id, item.variant_id, quantity)
      end
    end

    {:noreply, reload_cart(socket)}
  end

  @impl true
  def handle_event("remove_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    item = Enum.at(socket.assigns.cart, index)

    if item do
      CartStore.remove_item(socket.assigns.cart_session_id, item.variant_id)
    end

    {:noreply, reload_cart(socket)}
  end

  @impl true
  def handle_event("checkout", _params, socket) do
    if socket.assigns.cart == [] do
      {:noreply, put_flash(socket, :error, "Your cart is empty")}
    else
      {:noreply, push_navigate(socket, to: "/s/#{socket.assigns.store.slug}/checkout")}
    end
  end

  @impl true
  def handle_event("apply_promo", %{"promo" => promo}, socket) do
    promo = String.trim(promo) |> String.upcase()

    if promo == "WELCOME10" do
      {:noreply,
       socket
       |> assign(:promo_code, promo)
       |> assign(:promo_error, nil)
       |> assign_totals(socket.assigns.cart)}
    else
      {:noreply,
       socket
       |> assign(:promo_error, "Invalid promo code. Please try again.")}
    end
  end

  @impl true
  def handle_event("remove_promo", _params, socket) do
    {:noreply,
     socket
     |> assign(:promo_code, nil)
     |> assign(:promo_error, nil)
     |> assign_totals(socket.assigns.cart)}
  end

  @impl true
  def handle_event("update_promo_code", %{"promo_code" => code}, socket) do
    {:noreply, assign(socket, :promo_code, code)}
  end

  @impl true
  def handle_event("apply_coupon", _params, socket) do
    code = String.trim(socket.assigns.promo_code)
    store = socket.assigns.store

    if code == "" do
      {:noreply, assign(socket, :promo_error, "Please enter a coupon code")}
    else
      case Emakola.Marketing.find_coupon_by_code(store.id, code) do
        {:ok, [coupon]} ->
          validate_and_apply_coupon(socket, coupon)

        {:ok, []} ->
          {:noreply, assign(socket, :promo_error, "Invalid coupon code")}

        {:error, _} ->
          {:noreply, assign(socket, :promo_error, "Invalid coupon code")}
      end
    end
  end

  @impl true
  def handle_event("remove_coupon", _params, socket) do
    {:noreply,
     socket
     |> assign(:applied_coupon, nil)
     |> assign(:discount_amount, 0)
     |> assign(:promo_code, "")
     |> assign(:promo_error, nil)}
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :cart) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.Cart.render(assigns)
    end
  end

  # -- Helpers --

  defp reload_cart(socket) do
    cart = CartStore.get_cart(socket.assigns.cart_session_id)
    total = cart_total(cart)

    _discount =
      if socket.assigns[:applied_coupon] do
        calculate_discount(socket.assigns.applied_coupon, total)
      else
        0
      end

    socket
    |> assign(:cart, cart)
    |> assign_totals(cart)
  end

  defp assign_totals(socket, cart) do
    subtotal = cart_total(cart)

    discount =
      if socket.assigns[:promo_code] == "WELCOME10" do
        trunc(subtotal * 0.10)
      else
        0
      end

    taxable = max(0, subtotal - discount)
    tax = trunc(taxable * 0.08)
    total = taxable + tax

    socket
    |> assign(:cart_count, cart_count(cart))
    |> assign(:cart_subtotal, subtotal)
    |> assign(:cart_discount, discount)
    |> assign(:cart_tax, tax)
    |> assign(:cart_total, total)
  end

  defp cart_count(cart) do
    Enum.reduce(cart, 0, fn item, acc -> acc + item.quantity end)
  end

  defp cart_total(cart) do
    Enum.reduce(cart, 0, fn item, acc -> acc + item.unit_price * item.quantity end)
  end

  defp validate_and_apply_coupon(socket, coupon) do
    now = DateTime.utc_now()
    subtotal = socket.assigns.cart_subtotal

    cond do
      not coupon.active ->
        {:noreply, assign(socket, :promo_error, "This coupon is no longer active")}

      coupon.expires_at && DateTime.compare(now, coupon.expires_at) == :gt ->
        {:noreply, assign(socket, :promo_error, "This coupon has expired")}

      coupon.starts_at && DateTime.compare(now, coupon.starts_at) == :lt ->
        {:noreply, assign(socket, :promo_error, "This coupon is not yet valid")}

      coupon.max_uses && coupon.uses_count >= coupon.max_uses ->
        {:noreply, assign(socket, :promo_error, "This coupon has reached its usage limit")}

      coupon.minimum_order_amount && subtotal < coupon.minimum_order_amount ->
        {:noreply, assign(socket, :promo_error, "Order does not meet the minimum amount")}

      true ->
        discount = calculate_discount(coupon, subtotal)

        {:noreply,
         socket
         |> assign(:applied_coupon, coupon)
         |> assign(:discount_amount, discount)
         |> assign(:promo_error, nil)}
    end
  end

  defp calculate_discount(coupon, subtotal) do
    case coupon.discount_type do
      :percentage ->
        raw = div(subtotal * coupon.discount_value, 10_000)
        if coupon.max_discount_amount, do: min(raw, coupon.max_discount_amount), else: raw

      :fixed_amount ->
        min(coupon.discount_value, subtotal)

      :free_shipping ->
        0

      _ ->
        0
    end
  end
end
