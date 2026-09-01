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

  # ── TC-2 buyer protection lifecycle templates ───────────────────
  # Both buyer-facing messages embed a SIGNED tracking link
  # (`EmakolaWeb.TrackingTokens.sign_order_tracking/1`) so the buyer can act
  # on `TrackingLive` (confirm receipt / file a complaint) from the link
  # alone, without signing in.

  def protection_held_sms(order, store) do
    "Your payment for order #{order.order_number} from #{store.name} is safely held " <>
      "until you confirm delivery. Track & confirm here: #{protection_tracking_url(store, order)}"
  end

  def protection_delivery_nudge_sms(order, store) do
    release_days = Emakola.Payments.Workers.ProtectionSweepWorker.release_days()

    "Your order #{order.order_number} from #{store.name} has been delivered! " <>
      "Please confirm receipt — the payment releases automatically in #{Emakola.Plural.count(release_days, "day")} if we " <>
      "don't hear from you. Confirm here: #{protection_tracking_url(store, order)}"
  end

  # ── TC-3 susu lay-away lifecycle templates (Task 8) ─────────────
  # Pre-completion buyer/merchant messages are PLAN-based (no order exists
  # yet — see `Emakola.Notifications.Dispatcher.dispatch_susu/2`'s
  # moduledoc). Buyer-facing ones embed the SIGNED susu-plan link
  # (`EmakolaWeb.SusuTokens.sign_susu_plan/1`), the exact URL shape
  # `EmakolaWeb.Storefront.SusuLinkLive.send_resend_sms/2` already builds,
  # so the buyer can pay a chunk / edit delivery / cancel from the link
  # alone. `:susu_completed` / `:susu_merchant_completed` are order-based
  # (the plan's order exists by the time they fire) and live with the
  # other order templates below.

  def susu_activated_sms(plan, store) do
    "Your susu plan at #{store.name} is now active! First payment received — " <>
      "#{currency_symbol(store.currency || "GHS")}#{format_amount(plan.contributed_amount)} of " <>
      "#{currency_symbol(store.currency || "GHS")}#{format_amount(plan.total_amount)} paid. " <>
      "Track your progress and pay your next chunk here: #{susu_plan_url(plan)}"
  end

  def susu_chunk_received_sms(plan, store) do
    "Chunk received for your susu plan at #{store.name}! " <>
      "#{currency_symbol(store.currency || "GHS")}#{format_amount(plan.contributed_amount)} of " <>
      "#{currency_symbol(store.currency || "GHS")}#{format_amount(plan.total_amount)} paid so far. " <>
      "Track your progress here: #{susu_plan_url(plan)}"
  end

  def susu_nudge_sms(plan, store) do
    "It's been a week since your last susu payment at #{store.name}. You still owe " <>
      "#{currency_symbol(store.currency || "GHS")}#{format_amount(plan.total_amount - plan.contributed_amount)}. " <>
      "Pay your next chunk here: #{susu_plan_url(plan)}"
  end

  def susu_deadline_warning_sms(plan, store) do
    days = deadline_days_left(plan)

    "Reminder: your susu plan at #{store.name} deadline is in #{pluralize_days(days)}! You still owe " <>
      "#{currency_symbol(store.currency || "GHS")}#{format_amount(plan.total_amount - plan.contributed_amount)}. " <>
      "Pay now: #{susu_plan_url(plan)}"
  end

  # `refunded_amount` is the sum of the plan's actual `:success` payments —
  # NOT `plan.contributed_amount`, which is 0 on the insufficient-stock
  # path (the activating chunk's payment succeeded at the gateway but was
  # flagged for refund instead of counted — see `SusuChunks.confirm_chunk/1`
  # — so it never incremented `contributed_amount`) even though real money
  # is being refunded. The caller (`SusuNotificationWorker`) computes this
  # from the payments table so the SMS never claims GH₵0.00 was refunded
  # when it wasn't.
  def susu_refunded_sms(_plan, store, refunded_amount) do
    "Your susu plan at #{store.name} has ended. Your contributions " <>
      "(#{currency_symbol(store.currency || "GHS")}#{format_amount(refunded_amount)}) are being refunded " <>
      "to your mobile money account."
  end

  def susu_merchant_activated_sms(plan, store) do
    "A susu plan (#{plan.code}) at #{store.name} is now active — the buyer made their first " <>
      "payment of #{currency_symbol(store.currency || "GHS")}#{format_amount(plan.contributed_amount)}. " <>
      "Check your dashboard for details."
  end

  def susu_merchant_expired_sms(plan, store) do
    "A susu plan (#{plan.code}) at #{store.name} ended without completing — any contributions are " <>
      "being refunded to the buyer. Check your dashboard for details."
  end

  def susu_completed_sms(order, store) do
    "Your susu plan is complete! Order #{order.order_number} from #{store.name} has been created. " <>
      "Track & confirm delivery here: #{protection_tracking_url(store, order)}"
  end

  def susu_merchant_completed_sms(order, store) do
    "A susu plan completed! Order #{order.order_number} at #{store.name} has been created — " <>
      "check your dashboard for payout details."
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

  def payout_paid_merchant_sms(payout, store) do
    "#{store.name}: you've received #{currency_symbol(payout.currency)}#{format_amount(payout.amount)} from Makola. Payout complete."
  end

  # ── Earnings-accrued template (money-surfaces PR-2 Task 3) ─────
  # `source_description` and `momo_ready?` are precomputed by
  # `EarningsNotificationWorker` (source store name vs. "your sale"; whether
  # `PayoutService.momo_destination?/1` is true) — this template just
  # composes strings, no cross-context calls.

  def earnings_accrued_sms(store, net_amount, source_description, momo_ready?) do
    base =
      "#{store.name}: you earned #{currency_symbol(store.currency || "GHS")}#{format_amount(net_amount)} " <>
        "from #{source_description}. Check your dashboard for details."

    if momo_ready? do
      base
    else
      base <> " Add your mobile money number to get paid out: #{admin_url("/admin/payouts")}"
    end
  end

  def protection_released_merchant_sms(order, store) do
    "Payment for order #{order.order_number} has been released to you. " <>
      "Check your #{store.name} dashboard for payout details."
  end

  def protection_complaint_merchant_sms(order, store) do
    "A buyer filed a complaint on order #{order.order_number}. The payment stays " <>
      "held while it's reviewed — check your #{store.name} dashboard for details."
  end

  # ── WhatsApp template names ────────────────────────────────────

  def whatsapp_template_for(:order_placed), do: "order_placed"
  def whatsapp_template_for(:order_confirmed), do: "order_confirmed"
  def whatsapp_template_for(:order_shipped), do: "order_shipped"
  def whatsapp_template_for(:order_delivered), do: "order_delivered"
  def whatsapp_template_for(:order_cancelled), do: "order_cancelled"
  def whatsapp_template_for(:supply_connection), do: "supply_connection_update"

  def whatsapp_params(order, store) do
    %{
      order_number: order.order_number,
      store_name: store.name,
      total: format_amount(order.total),
      currency: order.currency
    }
  end

  # ── Supplier-facing templates ──────────────────────────────────

  # The old copy ended "Reply to confirm and share a tracking number." Nothing
  # reads replies — there is no inbound WhatsApp or SMS webhook anywhere in the
  # app, only Paystack, Hubtel and SplitPay — so a supplier who followed that
  # instruction was talking into a void. The link is the thing that actually
  # works.
  def supplier_fulfillment_sms(order, supplier, line_items, action_url \\ nil) do
    base =
      "Makola.io order #{order.order_number} for #{supplier.name}: " <>
        "Please ship #{items_summary(line_items)} " <>
        "to #{format_address(Map.get(order, :shipping_address))}."

    if is_binary(action_url) and action_url != "" do
      base <> " Confirm or say no stock here: " <> action_url
    else
      base
    end
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

    "Low stock alert: #{product_title} (#{sku_display}) has only #{Emakola.Plural.count(stock_quantity, "unit")} left. " <>
      "Restock soon! - #{store_name}"
  end

  def low_stock_digest_sms(count, store_name) do
    "#{Emakola.Plural.count(count, "item")} #{if count == 1, do: "is", else: "are"} running low on stock at #{store_name}. " <>
      "Check your dashboard for details."
  end

  # ── Connection notification templates ────────────────────────────

  def connection_sms(:requested, counterparty, :wants_to_stock) do
    "#{counterparty} wants to stock your products. Review the request on your Partners page: #{admin_url(destination_path(:requested))}"
  end

  def connection_sms(:requested, counterparty, :wants_to_supply) do
    "#{counterparty} wants to supply you products. Review the request on your Partners page: #{admin_url(destination_path(:requested))}"
  end

  def connection_sms(:approved, counterparty, _direction) do
    "#{counterparty} approved your connection. Wholesale pricing is now visible on your Browse Suppliers page: #{admin_url(destination_path(:approved))}"
  end

  def connection_sms(:rejected, counterparty, _direction) do
    "#{counterparty} declined your connection request. You can browse other suppliers on your Browse Suppliers page: #{admin_url(destination_path(:rejected))}"
  end

  def connection_push(:requested, counterparty, :wants_to_stock),
    do: %{title: "New supply request", body: "#{counterparty} wants to stock your products."}

  def connection_push(:requested, counterparty, :wants_to_supply),
    do: %{title: "New supply request", body: "#{counterparty} wants to supply you products."}

  def connection_push(:approved, counterparty, _direction),
    do: %{
      title: "Connection approved",
      body: "#{counterparty} approved your connection — wholesale pricing is unlocked."
    }

  def connection_push(:rejected, counterparty, _direction),
    do: %{title: "Connection declined", body: "#{counterparty} declined your connection request."}

  def connection_whatsapp_params(event, counterparty, direction) do
    %{
      counterparty: counterparty,
      event: connection_event_phrase(event, direction),
      url: admin_url(destination_path(event))
    }
  end

  defp connection_event_phrase(:requested, :wants_to_stock), do: "sent you a new supply request"
  defp connection_event_phrase(:requested, :wants_to_supply), do: "offered to supply you products"
  defp connection_event_phrase(:approved, _direction), do: "approved your request"
  defp connection_event_phrase(:rejected, _direction), do: "declined your request"

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
    major = minor_units |> div(100) |> Emakola.Money.group_thousands()
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
    "#{Emakola.Plural.count(length(items), "item")} | "
  end

  defp item_count_segment(_), do: ""

  defp storefront_tracking_url(store, order) do
    EmakolaWeb.SEO.Canonical.path(store, "/track/#{order.order_number}")
  end

  # Buyer-authorization token bound to this order (TC-2), appended so the
  # tracking link itself lets an anonymous buyer confirm receipt / file a
  # complaint on `TrackingLive` — see `EmakolaWeb.TrackingTokens`.
  defp protection_tracking_url(store, order) do
    token = EmakolaWeb.TrackingTokens.sign_order_tracking(order.id)
    "#{storefront_tracking_url(store, order)}?t=#{token}"
  end

  # Buyer-authorization token bound to this susu plan, appended so the
  # signed link lets an anonymous buyer pay a chunk / edit delivery / cancel
  # from the link alone (`EmakolaWeb.Storefront.SusuLinkLive`). Mirrors
  # `EmakolaWeb.Storefront.SusuLinkLive.send_resend_sms/2`'s exact URL shape
  # (apex `/susu/:code` route, not the store-slug-scoped tracking path).
  defp susu_plan_url(plan) do
    token = EmakolaWeb.SusuTokens.sign_susu_plan(plan.id)
    "#{EmakolaWeb.Endpoint.url()}/susu/#{plan.code}?t=#{token}"
  end

  # Recomputed from the plan's own `deadline` at render time (not stashed at
  # enqueue time) so a delayed Oban run still reports an accurate count.
  # Floored at 0 — `susu_deadline_warning_sms/2` is only ever called for a
  # deadline still in the future (see `SusuNudgeWorker`'s guard), but this
  # keeps the copy sane even if that guard is ever loosened.
  defp deadline_days_left(plan) do
    max(DateTime.diff(plan.deadline, DateTime.utc_now(), :day), 0)
  end

  defp pluralize_days(1), do: "1 day"
  defp pluralize_days(days), do: "#{days} days"

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

  defp admin_url(path) do
    host = storefront_host()
    "https://#{host}#{path}"
  end

  defp destination_path(:requested), do: "/admin/settings/supply-network"
  defp destination_path(_), do: "/admin/supply/catalog"
end
