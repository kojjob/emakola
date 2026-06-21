defmodule Emakola.Notifications.Templates do
  @moduledoc """
  SMS and WhatsApp message templates for order lifecycle notifications.

  All monetary amounts are expected as integers in minor currency units
  (pesewas for GHS, kobo for NGN). Formatting to human-readable form
  happens here at the presentation boundary.
  """

  # ── Customer-facing templates ──────────────────────────────────

  def order_placed_sms(order, store) do
    "Your order #{order.order_number} from #{store.name} has been placed. " <>
      "Total: #{currency_symbol(order.currency)}#{format_amount(order.total)}. " <>
      "We'll notify you when it's confirmed!"
  end

  def order_confirmed_sms(order, store) do
    item_count_text = item_count_segment(Map.get(order, :line_items))

    "Receipt: Order #{order.order_number} from #{store.name}. " <>
      item_count_text <>
      "Total: #{currency_symbol(order.currency)}#{format_amount(order.total)}. Payment confirmed!"
  end

  def order_shipped_sms(order, store) do
    tracking_url = Map.get(order, :tracking_url)

    tracking_line =
      if tracking_url do
        " Track here: #{tracking_url}"
      else
        " Track at: #{storefront_tracking_url(store, order)}"
      end

    "Your order #{order.order_number} from #{store.name} has been shipped!" <>
      tracking_line
  end

  def order_delivered_sms(order, store) do
    "Your order #{order.order_number} from #{store.name} has been delivered. " <>
      "Thank you for shopping with us!"
  end

  def order_cancelled_sms(order, store) do
    "Your order #{order.order_number} from #{store.name} has been cancelled. " <>
      "If you have questions, please contact the store."
  end

  # ── Merchant-facing templates ──────────────────────────────────

  def new_order_merchant_sms(order, store) do
    "New order #{order.order_number}! " <>
      "Amount: #{currency_symbol(order.currency)}#{format_amount(order.total)}. " <>
      "Log in to #{store.name} dashboard to process."
  end

  def order_cancelled_merchant_sms(order, store) do
    "Order #{order.order_number} has been cancelled. " <>
      "Amount: #{currency_symbol(order.currency)}#{format_amount(order.total)}. " <>
      "Check #{store.name} dashboard for details."
  end

  # ── WhatsApp template names ────────────────────────────────────

  def whatsapp_template_for(:order_placed), do: "order_placed"
  def whatsapp_template_for(:order_confirmed), do: "order_confirmed"
  def whatsapp_template_for(:order_shipped), do: "order_shipped"
  def whatsapp_template_for(:order_delivered), do: "order_delivered"
  def whatsapp_template_for(:order_cancelled), do: "order_cancelled"

  def whatsapp_params(order, store) do
    %{
      order_number: order.order_number,
      store_name: store.name,
      total: format_amount(order.total),
      currency: order.currency
    }
  end

  # ── Supplier-facing templates ──────────────────────────────────

  def supplier_fulfillment_sms(order, supplier, line_items) do
    "Makola order #{order.order_number} for #{supplier.name}: " <>
      "Please ship #{items_summary(line_items)} " <>
      "to #{format_address(Map.get(order, :shipping_address))}. " <>
      "Reply to confirm and share a tracking number."
  end

  def supplier_fulfillment_whatsapp_template, do: "supplier_fulfillment"

  def supplier_fulfillment_whatsapp_params(order, supplier, line_items) do
    %{
      order_number: order.order_number,
      supplier_name: supplier.name,
      items: items_summary(line_items),
      ship_to: format_address(Map.get(order, :shipping_address))
    }
  end

  # ── Low-stock alert templates ────────────────────────────────

  def low_stock_realtime_sms(product_title, sku, stock_quantity, store_name) do
    sku_display = sku || "N/A"

    "Low stock alert: #{product_title} (#{sku_display}) has only #{stock_quantity} units left. " <>
      "Restock soon! - #{store_name}"
  end

  def low_stock_digest_sms(count, store_name) do
    "#{count} items are running low on stock at #{store_name}. " <>
      "Check your dashboard for details."
  end

  # ── Formatting helpers ─────────────────────────────────────────

  @doc """
  Formats an integer amount in minor units (pesewas/kobo) to a
  human-readable string with two decimal places.

  ## Examples

      iex> Emakola.Notifications.Templates.format_amount(50000)
      "500.00"

      iex> Emakola.Notifications.Templates.format_amount(199)
      "1.99"

      iex> Emakola.Notifications.Templates.format_amount(5)
      "0.05"
  """
  def format_amount(minor_units) when is_integer(minor_units) do
    major = div(minor_units, 100)
    minor = rem(minor_units, 100)
    "#{major}.#{String.pad_leading(Integer.to_string(minor), 2, "0")}"
  end

  defp items_summary(line_items) when is_list(line_items) and line_items != [] do
    line_items
    |> Enum.map_join(", ", fn item -> "#{item.quantity}x #{item.product_title}" end)
  end

  defp items_summary(_), do: "(no items)"

  # Formats an order's shipping_address map (string keys: "line_1", "city",
  # "region") into a one-line, comma-joined string. nil → fallback text.
  defp format_address(nil), do: "(no address provided)"

  defp format_address(address) when is_map(address) do
    ["line_1", "city", "region"]
    |> Enum.map(fn key -> Map.get(address, key) end)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> case do
      [] -> "(no address provided)"
      parts -> Enum.join(parts, ", ")
    end
  end

  defp item_count_segment([_ | _] = items) do
    "#{length(items)} item(s) | "
  end

  defp item_count_segment(_), do: ""

  defp storefront_tracking_url(store, order) do
    host = storefront_host()
    "https://#{host}/@#{store.slug}/track/#{order.order_number}"
  end

  defp storefront_host do
    case Application.get_env(:emakola, EmakolaWeb.Endpoint)[:url][:host] do
      nil -> "emakola.com"
      host -> host
    end
  end

  defp currency_symbol("GHS"), do: "GH\u20B5"
  defp currency_symbol("NGN"), do: "\u20A6"
  defp currency_symbol("USD"), do: "$"
  defp currency_symbol(_), do: ""
end
