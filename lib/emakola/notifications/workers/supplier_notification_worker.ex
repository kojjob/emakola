defmodule Emakola.Notifications.Workers.SupplierNotificationWorker do
  @moduledoc """
  Oban worker that notifies a dropship supplier about a fulfillment they
  are responsible for.

  Loads the fulfillment (with supplier, line_items, and order), picks the
  best contact channel (WhatsApp preferred, then SMS), sends the supplier
  the items to ship and the customer ship-to address, and transitions the
  fulfillment from `:pending` to `:notified`.

  This worker is idempotent — re-running for an already-notified fulfillment
  simply re-sends the message (acceptable for SMS/WhatsApp) without attempting
  an illegal status transition. Merchant-owned groups (`supplier_id` nil) are
  skipped: there is no external supplier to notify.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 600, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Templates

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"fulfillment_id" => fulfillment_id}}) do
    with {:ok, fulfillment} <- load_fulfillment(fulfillment_id) do
      cond do
        fulfillment.status == :cancelled ->
          Logger.info(
            "[SupplierNotificationWorker] Fulfillment #{fulfillment_id} was cancelled, skipping notification"
          )

          :ok

        is_nil(fulfillment.supplier_id) ->
          Logger.info(
            "[SupplierNotificationWorker] Fulfillment #{fulfillment_id} is a merchant group, nothing to send"
          )

          :ok

        true ->
          notify_supplier(fulfillment)
      end
    else
      {:error, reason} ->
        Logger.error(
          "[SupplierNotificationWorker] Failed to process fulfillment #{fulfillment_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # ── Private ─────────────────────────────────────────────────────

  defp load_fulfillment(fulfillment_id) do
    Emakola.Orders.Fulfillment
    |> Ash.Query.filter(id == ^fulfillment_id)
    |> Ash.Query.load([:supplier, :line_items, :order])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :fulfillment_not_found}
      {:ok, fulfillment} -> {:ok, fulfillment}
      {:error, reason} -> {:error, reason}
    end
  end

  defp notify_supplier(fulfillment) do
    supplier = fulfillment.supplier
    order = fulfillment.order
    line_items = fulfillment.line_items

    cond do
      supplier.whatsapp_number ->
        case whatsapp_provider().send_message(
               supplier.whatsapp_number,
               Templates.supplier_fulfillment_whatsapp_template(),
               Templates.supplier_fulfillment_whatsapp_params(order, supplier, line_items),
               store_id: fulfillment.store_id
             ) do
          {:ok, _} -> maybe_mark_notified(fulfillment, :whatsapp)
          {:error, reason} -> {:error, reason}
        end

      supplier.contact_phone ->
        case sms_provider().send_sms(
               supplier.contact_phone,
               Templates.supplier_fulfillment_sms(order, supplier, line_items),
               store_id: fulfillment.store_id
             ) do
          {:ok, _} -> maybe_mark_notified(fulfillment, :sms)
          {:error, reason} -> {:error, reason}
        end

      true ->
        Logger.info(
          "[SupplierNotificationWorker] Supplier #{supplier.id} has no contact info, manual fallback needed"
        )

        :ok
    end
  end

  # Transition pending -> notified after a successful send. A re-send of an
  # already-notified fulfillment must NOT attempt the transition again.
  defp maybe_mark_notified(%{status: :pending} = fulfillment, channel) do
    fulfillment
    |> Ash.Changeset.for_update(:mark_notified, %{notified_via: channel})
    |> Ash.update(authorize?: false)
    |> case do
      {:ok, _updated} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "[SupplierNotificationWorker] Failed to mark fulfillment #{fulfillment.id} notified: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp maybe_mark_notified(_fulfillment, _channel), do: :ok

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
