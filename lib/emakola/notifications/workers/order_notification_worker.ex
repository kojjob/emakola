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

  alias Emakola.Notifications.Templates
  alias Emakola.Notifications.Emails.DeliveryEmail
  alias Emakola.Notifications.Emails.OrderEmail
  alias Emakola.Notifications.Emails.ShippingEmail

  # TC-2 buyer protection lifecycle events (Task 10) join the existing order
  # events on each side: `:protection_held`/`:protection_delivery_nudge` are
  # buyer-only (no merchant SMS — mirrors :order_shipped/:order_confirmed/
  # :order_delivered), `:protection_released`/`:protection_complaint` are
  # merchant-only (no customer SMS/WhatsApp/email at all).
  @buyer_events ~w(
    order_placed order_confirmed order_shipped order_delivered order_cancelled
    protection_held protection_delivery_nudge
  )a
  @merchant_events ~w(order_placed order_cancelled protection_released protection_complaint)a

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
          :protection_complaint
        ],
        :order_placed
      )

    with {:ok, order} <- load_order(order_id),
         {:ok, store} <- load_store(order.store_id),
         customer <- load_customer(order.customer_id) do
      if event in @buyer_events do
        # Send customer notification if they have a phone number
        if customer && customer.phone do
          send_customer_sms(order, store, customer, event)
          send_customer_whatsapp(order, store, customer, event)
        else
          Logger.info(
            "[OrderNotificationWorker] No customer phone for order #{order_id}, skipping customer notification"
          )
        end

        # Send customer email if they have an email address
        if customer && customer.email do
          send_customer_email(order, store, customer, event)
        end
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

  defp send_customer_sms(order, store, customer, event) do
    message = customer_sms_template(order, store, event)
    sms_provider().send_sms(customer.phone, message, store_id: order.store_id)
  end

  # No approved WhatsApp Business template exists for these events yet — SMS
  # only (the tracking link body doesn't fit a templated-params WhatsApp
  # message anyway).
  defp send_customer_whatsapp(_order, _store, _customer, event)
       when event in [:protection_held, :protection_delivery_nudge] do
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
