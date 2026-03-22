defmodule Emakola.Notifications.Workers.OrderNotificationWorker do
  @moduledoc """
  Oban worker that sends email notifications for order lifecycle events.

  Loads the order (with customer and store associations), then sends
  the appropriate email notification to the customer.

  SMS and WhatsApp notifications will be added when those provider
  integrations are implemented.

  This worker is idempotent — re-running with the same args will
  simply re-send the notification without side effects beyond
  duplicate messages.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 60, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Emails.{OrderEmail, ShippingEmail}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id, "event" => event_string}}) do
    event = String.to_existing_atom(event_string)

    with {:ok, order} <- load_order(order_id),
         {:ok, store} <- load_store(order.store_id),
         customer <- load_customer(order.customer_id) do
      # Send customer email if they have an email address
      if customer && customer.email do
        send_customer_email(order, store, customer, event)
      else
        Logger.info(
          "[OrderNotificationWorker] No customer email for order #{order_id}, skipping email notification"
        )
      end

      # TODO: Send SMS/WhatsApp when provider integrations are implemented
      # if customer && customer.phone do
      #   send_customer_sms(order, store, customer, event)
      #   send_customer_whatsapp(order, store, customer, event)
      # end

      :ok
    else
      {:error, reason} ->
        Logger.error(
          "[OrderNotificationWorker] Failed to process notification for order #{order_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # ── Email sending ──────────────────────────────────────────────

  defp send_customer_email(order, store, customer, event)
       when event in [:order_placed, :order_confirmed] do
    email = OrderEmail.order_confirmation(order, customer, store)

    case Emakola.Mailer.deliver(email) do
      {:ok, _} ->
        Logger.info(
          "[OrderNotificationWorker] Order confirmation email sent for order #{order.id}"
        )

      {:error, reason} ->
        Logger.error(
          "[OrderNotificationWorker] Failed to send email for order #{order.id}: #{inspect(reason)}"
        )
    end
  end

  defp send_customer_email(order, store, customer, :order_shipped) do
    tracking_info = %{
      carrier: nil,
      tracking_number: nil,
      tracking_url: nil,
      estimated_delivery: nil
    }

    email = ShippingEmail.order_shipped(order, customer, store, tracking_info)

    case Emakola.Mailer.deliver(email) do
      {:ok, _} ->
        Logger.info("[OrderNotificationWorker] Shipping email sent for order #{order.id}")

      {:error, reason} ->
        Logger.error(
          "[OrderNotificationWorker] Failed to send shipping email for order #{order.id}: #{inspect(reason)}"
        )
    end
  end

  defp send_customer_email(_order, _store, _customer, _event), do: :ok

  # ── Data loading ───────────────────────────────────────────────

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
    Emakola.Accounts.Store
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
end
