defmodule Emakola.Notifications.Workers.OrderNotificationWorker do
  @moduledoc """
  Oban worker that sends SMS and WhatsApp notifications for order
  lifecycle events.

  Loads the order (with customer and store associations), then sends
  the appropriate notification to the customer and/or merchant.

  This worker is idempotent — re-running with the same args will
  simply re-send the notification without side effects beyond
  duplicate messages (which is acceptable for SMS/WhatsApp).
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    # 10-minute dedup window. The previous 60-second value was tuned
    # for retry storms but missed the more common case: webhook
    # processors that re-fire the same lifecycle event minutes apart
    # (gateway retries are typically ~3 min, ~6 min, ~10 min). 600s
    # absorbs all three without sending duplicate SMS to the customer.
    unique: [period: 600, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Reach
  alias Emakola.Notifications.Templates
  alias Emakola.Notifications.Emails.DeliveryEmail
  alias Emakola.Notifications.Emails.OrderEmail
  alias Emakola.Notifications.Emails.ShippingEmail

  # TC-2 buyer protection lifecycle events (Task 10) join the existing order
  # events on each side: `:protection_held`/`:protection_delivery_nudge` are
  # buyer-only (no merchant SMS — mirrors :order_shipped/:order_confirmed/
  # :order_delivered), `:protection_released`/`:protection_complaint` are
  # merchant-only (no customer SMS/WhatsApp/email at all).
  # TC-3 susu completion events (Task 8) join the same two lists: by the
  # time either fires the plan's order already exists (`SusuCompletion.
  # complete/1` dispatches them right after confirming it), so they're
  # genuinely order-based — unlike the plan-based pre-completion susu
  # events, which route through `SusuNotificationWorker` instead (see
  # `Emakola.Notifications.Dispatcher`'s "Susu coupling" moduledoc section).
  # `:susu_completed` is buyer-only (SMS with the same signed tracking link
  # `:protection_held` uses — susu bypasses `ensure_hold`, so this is the
  # buyer's only route to a tracking link); `:susu_merchant_completed` is
  # merchant-only, mirroring the `:protection_released`/`:protection_complaint` split.
  @buyer_events ~w(
    order_placed order_confirmed order_shipped order_delivered order_cancelled
    protection_held protection_delivery_nudge susu_completed
  )a
  @merchant_events ~w(
    order_placed order_cancelled protection_released protection_complaint
    susu_merchant_completed
  )a

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id, "event" => event_string}}) do
    event =
      Emakola.SafeAtom.to_atom_in(
        event_string,
        [
          :order_placed,
          :order_confirmed,
          :order_shipped,
          :order_delivered,
          :order_cancelled,
          :protection_held,
          :protection_delivery_nudge,
          :protection_released,
          :protection_complaint,
          :susu_completed,
          :susu_merchant_completed
        ],
        :order_placed
      )

    with {:ok, order} <- load_order(order_id),
         {:ok, store} <- load_store(order.store_id),
         customer <- load_customer(order.customer_id) do
      if event in @buyer_events do
        notify_customer(order, store, customer, event)
      end

      # Send merchant notification for relevant events
      if event in @merchant_events do
        send_merchant_sms(order, store, event)
      end

      :ok
    else
      {:error, reason} ->
        Logger.error(
          "[OrderNotificationWorker] Failed to process notification for order #{order_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # ── Private ─────────────────────────────────────────────────────

  defp load_order(order_id) do
    Emakola.Orders.Order
    |> Ash.Query.filter(id == ^order_id)
    |> Ash.Query.load([:line_items])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :order_not_found}
      {:ok, order} -> {:ok, order}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_store(store_id) do
    Emakola.Stores.Store
    |> Ash.Query.filter(id == ^store_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :store_not_found}
      {:ok, store} -> {:ok, store}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_customer(nil), do: nil

  defp load_customer(customer_id) do
    case Emakola.Customers.Customer
         |> Ash.Query.filter(id == ^customer_id)
         |> Ash.read_one(authorize?: false) do
      {:ok, customer} -> customer
      _ -> nil
    end
  end

  # One place decides which channels can reach this buyer. Reach answers
  # phone-first (whatsapp → sms → email) and treats a blank contact detail as
  # absent, so no caller re-implements "do they have a phone" slightly
  # differently. Both phone channels are still used where both are possible —
  # see the note in Notifications.Reach about cost if that ever changes.
  defp notify_customer(order, store, customer, event) do
    case customer && Reach.channels_for(customer, :transactional) do
      nil ->
        :ok

      [] ->
        Logger.info(
          "[OrderNotificationWorker] No way to reach the customer for order " <>
            "#{order.id} — no phone and no email"
        )

      channels ->
        Enum.each(channels, &deliver(&1, order, store, customer, event))
    end
  end

  defp deliver(:sms, order, store, customer, event),
    do: send_customer_sms(order, store, customer, event)

  defp deliver(:whatsapp, order, store, customer, event),
    do: send_customer_whatsapp(order, store, customer, event)

  defp deliver(:email, order, store, customer, event),
    do: send_customer_email(order, store, customer, event)

  defp send_customer_sms(order, store, customer, event) do
    message = customer_sms_template(order, store, event)
    sms_provider().send_sms(customer.phone, message, store_id: order.store_id)
  end

  # No approved WhatsApp Business template exists for these events yet — SMS
  # only (the tracking link body doesn't fit a templated-params WhatsApp
  # message anyway).
  defp send_customer_whatsapp(_order, _store, _customer, event)
       when event in [:protection_held, :protection_delivery_nudge, :susu_completed] do
    :ok
  end

  defp send_customer_whatsapp(order, store, customer, event) do
    template = Templates.whatsapp_template_for(event)
    params = Templates.whatsapp_params(order, store)
    whatsapp_provider().send_message(customer.phone, template, params, store_id: order.store_id)
  end

  defp send_customer_email(order, store, customer, :order_placed) do
    OrderEmail.order_confirmation(order, customer, store)
    |> Emakola.Mailer.deliver()
  end

  defp send_customer_email(order, store, customer, :order_confirmed) do
    OrderEmail.order_confirmation(order, customer, store)
    |> Emakola.Mailer.deliver()
  end

  defp send_customer_email(order, store, customer, :order_shipped) do
    tracking_info = %{
      carrier: Map.get(order, :shipping_carrier, nil),
      tracking_number: Map.get(order, :tracking_number, nil),
      tracking_url: Map.get(order, :tracking_url, nil),
      estimated_delivery: Map.get(order, :estimated_delivery, nil)
    }

    ShippingEmail.order_shipped(order, customer, store, tracking_info)
    |> Emakola.Mailer.deliver()
  end

  defp send_customer_email(order, store, customer, :order_delivered) do
    DeliveryEmail.order_delivered(order, customer, store)
    |> Emakola.Mailer.deliver()
  end

  defp send_customer_email(_order, _store, _customer, _event) do
    Logger.info("[OrderNotificationWorker] No email template for event, skipping email")
    :ok
  end

  defp send_merchant_sms(order, store, :order_placed) do
    message = Templates.new_order_merchant_sms(order, store)

    if store.contact_phone do
      sms_provider().send_sms(store.contact_phone, message, store_id: order.store_id)
    else
      Logger.info(
        "[OrderNotificationWorker] No contact_phone for store #{store.id}, skipping merchant SMS"
      )
    end
  end

  defp send_merchant_sms(order, store, :order_cancelled) do
    message = Templates.order_cancelled_merchant_sms(order, store)

    if store.contact_phone do
      sms_provider().send_sms(store.contact_phone, message, store_id: order.store_id)
    else
      Logger.info(
        "[OrderNotificationWorker] No contact_phone for store #{store.id}, skipping merchant SMS"
      )
    end
  end

  defp send_merchant_sms(order, store, :protection_released) do
    message = Templates.protection_released_merchant_sms(order, store)

    if store.contact_phone do
      sms_provider().send_sms(store.contact_phone, message, store_id: order.store_id)
    else
      Logger.info(
        "[OrderNotificationWorker] No contact_phone for store #{store.id}, skipping merchant SMS"
      )
    end
  end

  defp send_merchant_sms(order, store, :protection_complaint) do
    message = Templates.protection_complaint_merchant_sms(order, store)

    if store.contact_phone do
      sms_provider().send_sms(store.contact_phone, message, store_id: order.store_id)
    else
      Logger.info(
        "[OrderNotificationWorker] No contact_phone for store #{store.id}, skipping merchant SMS"
      )
    end
  end

  defp send_merchant_sms(order, store, :susu_merchant_completed) do
    message = Templates.susu_merchant_completed_sms(order, store)

    if store.contact_phone do
      sms_provider().send_sms(store.contact_phone, message, store_id: order.store_id)
    else
      Logger.info(
        "[OrderNotificationWorker] No contact_phone for store #{store.id}, skipping merchant SMS"
      )
    end
  end

  defp customer_sms_template(order, store, :order_placed),
    do: Templates.order_placed_sms(order, store)

  defp customer_sms_template(order, store, :order_confirmed),
    do: Templates.order_confirmed_sms(order, store)

  defp customer_sms_template(order, store, :order_shipped),
    do: Templates.order_shipped_sms(order, store)

  defp customer_sms_template(order, store, :order_delivered),
    do: Templates.order_delivered_sms(order, store)

  defp customer_sms_template(order, store, :order_cancelled),
    do: Templates.order_cancelled_sms(order, store)

  defp customer_sms_template(order, store, :protection_held),
    do: Templates.protection_held_sms(order, store)

  defp customer_sms_template(order, store, :protection_delivery_nudge),
    do: Templates.protection_delivery_nudge_sms(order, store)

  defp customer_sms_template(order, store, :susu_completed),
    do: Templates.susu_completed_sms(order, store)

  defp sms_provider do
    Application.get_env(
      :emakola,
      :sms_provider,
      Emakola.Notifications.Providers.LogSMS
    )
  end

  defp whatsapp_provider do
    Application.get_env(
      :emakola,
      :whatsapp_provider,
      Emakola.Notifications.Providers.LogWhatsApp
    )
  end
end
