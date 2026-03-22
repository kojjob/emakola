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
    "Your order #{order.order_number} from #{store.name} has been confirmed. " <>
      "Total: #{currency_symbol(order.currency)}#{format_amount(order.total)}. Thank you!"
  end

  def order_shipped_sms(order, store) do
    "Your order #{order.order_number} from #{store.name} has been shipped! " <>
      "Track your delivery status."
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

  defp currency_symbol("GHS"), do: "GH\u20B5"
  defp currency_symbol("NGN"), do: "\u20A6"
  defp currency_symbol("USD"), do: "$"
  defp currency_symbol(_), do: ""
end
