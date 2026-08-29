defmodule EmakolaWeb.Supplier.ActionLive do
  @moduledoc """
  What a dropship supplier sees when they open the link the merchant sent them.

  The audience is the constraint. This is a local wholesaler on a cheap Android
  phone, often on a slow connection, and often not a confident reader. So:
  product photographs lead, quantities are large numerals, every button is full
  width with an icon, and no label runs past three words.

  ## What the page will and will not show

  **No money, ever.** `cost_price` is what the merchant pays and `unit_price` is
  what the buyer paid; either one on a link that gets forwarded around WhatsApp
  hands the merchant's margin to strangers.

  **The address is staged.** Before accepting, the supplier sees only the town —
  enough to judge whether they can deliver there. The buyer's name, street and
  phone appear only after they commit. A forwarded pre-accept link therefore
  leaks almost nothing. After accepting it does show the address to whoever
  holds the link, which is accepted: the supplier has to be able to forward it
  to their own dispatch rider.

  ## Defensive posture

  There is no catch-all `handle_event/3` anywhere in this codebase, so an
  unmatched event crashes the page. The realistic way that happens here is a
  missing form key, not a forged event name — hence `Map.get/3` rather than a
  destructuring head, and no `phx-change` on the tracking form.

  Every mutation re-verifies the token from scratch rather than trusting the
  assigns the button came from, so a stale tab acting on a fulfilment the
  merchant cancelled a minute ago gets a plain sentence and the correct screen.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Suppliers.SupplierAction

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      socket
      |> assign(
        token: token,
        error: nil,
        tracking_form: to_form(%{"tracking_number" => ""}, as: :shipment),
        confirming_decline: false
      )
      |> resolve()

    {:ok, socket}
  end

  @impl true
  def handle_event("accept", _params, socket) do
    run(socket, &SupplierAction.accept/1)
  end

  def handle_event("decline", _params, socket) do
    run(socket, &SupplierAction.decline(&1, :out_of_stock))
  end

  def handle_event("mark_sent", params, socket) do
    tracking = params |> Map.get("shipment", %{}) |> Map.get("tracking_number", "")

    run(socket, &SupplierAction.mark_sent(&1, tracking))
  end

  def handle_event("confirm_decline", _params, socket) do
    {:noreply, assign(socket, confirming_decline: true)}
  end

  def handle_event("cancel_decline", _params, socket) do
    {:noreply, assign(socket, confirming_decline: false)}
  end

  # ── State ───────────────────────────────────────────────────────

  defp run(socket, action) do
    case action.(socket.assigns.token) do
      {:ok, fulfillment} ->
        {:noreply, socket |> assign(error: nil, confirming_decline: false) |> put(fulfillment)}

      {:error, reason} ->
        # The row may have moved under us. Re-resolve rather than rendering the
        # screen the button was drawn on.
        {:noreply, socket |> resolve() |> assign(error: message_for(reason))}
    end
  end

  defp resolve(socket) do
    case SupplierAction.authorize(socket.assigns.token) do
      {:ok, fulfillment} ->
        put(socket, fulfillment)

      {:error, _reason} ->
        assign(socket, screen: :link_dead, fulfillment: nil, page_title: "Order")
    end
  end

  defp put(socket, fulfillment) do
    assign(socket,
      fulfillment: fulfillment,
      screen: screen_for(fulfillment),
      page_title: "Order #{order_number(fulfillment)}"
    )
  end

  defp screen_for(%{status: status, accepted_at: accepted_at}) do
    cond do
      status == :shipped -> :sent
      status == :declined -> :declined
      status in [:delivered, :cancelled] -> :closed
      not is_nil(accepted_at) -> :accepted
      true -> :offer
    end
  end

  # ── Copy ────────────────────────────────────────────────────────

  # Every error the supplier can actually cause, in words they can act on. No
  # codes: the label is for the log, the sentence is for the person.
  defp message_for(:tracking_required), do: "Please add the tracking number."
  defp message_for(:tracking_too_long), do: "That tracking number is too long."
  defp message_for(:rate_limited), do: "Too many taps. Please wait a moment."
  defp message_for(:revoked_token), do: "This link has been replaced."
  defp message_for(:expired_token), do: "This link has expired."
  defp message_for(_reason), do: "This order has changed. See below."

  defp order_number(%{order: %{order_number: number}}) when is_binary(number), do: number
  defp order_number(_fulfillment), do: ""

  defp town(%{order: %{shipping_address: address}}) when is_map(address) do
    address["city"] || address["town"] || address["region"] || "Ghana"
  end

  defp town(_fulfillment), do: "Ghana"

  defp buyer_name(%{order: %{shipping_address: address}}) when is_map(address) do
    address["name"] || address["full_name"] || "Customer"
  end

  defp buyer_name(_fulfillment), do: "Customer"

  defp buyer_phone(%{order: %{shipping_address: address}}) when is_map(address) do
    address["phone"]
  end

  defp buyer_phone(_fulfillment), do: nil

  defp street(%{order: %{shipping_address: address}}) when is_map(address) do
    [address["line_1"], address["line_2"], address["city"], address["region"]]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
  end

  defp street(_fulfillment), do: ""

  defp item_title(%{product_title: title}) when is_binary(title), do: title
  defp item_title(_line_item), do: "Item"

  defp item_image(%{variant: %{product: %{images: [%{url: url} | _]}}}), do: url
  defp item_image(_line_item), do: nil

  defp line_items(%{line_items: items}) when is_list(items), do: items
  defp line_items(_fulfillment), do: []
end
