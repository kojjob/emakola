defmodule Emakola.Notifications.Workers.PushNotificationWorker do
  @moduledoc """
  Sends an FCM push to every device token registered for the order's store
  when a new order is placed. Idempotent: Oban uniqueness dedupes per
  order+event for 10 minutes (same window as OrderNotificationWorker), and
  re-delivery of a push is harmless. Dead tokens (FCM UNREGISTERED) are
  pruned so the registry self-heals; transient errors are logged and
  skipped (no retry storm — the next order pushes again).
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 600, keys: [:order_id, :event]]

  require Logger

  alias Emakola.Notifications.DeviceToken
  alias Emakola.Notifications.Templates

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id, "event" => "order_placed"}}) do
    case Ash.get(Emakola.Orders.Order, order_id, authorize?: false) do
      {:ok, order} ->
        order.store_id
        |> device_tokens_for_store()
        |> Enum.each(&deliver(&1, order))

        :ok

      {:error, _} ->
        Logger.warning("[PushNotificationWorker] order not found: #{order_id}")
        {:error, :order_not_found}
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("[PushNotificationWorker] unsupported args: #{inspect(args)}")
    :ok
  end

  # ── Private ─────────────────────────────────────────────────────

  defp device_tokens_for_store(store_id) do
    DeviceToken
    |> Ash.Query.for_read(:for_store)
    |> Ash.read!(authorize?: false, tenant: store_id)
  end

  defp deliver(device_token, order) do
    notification = %{
      title: "New order #{order.order_number}",
      body: push_body(order),
      data: %{"type" => "order_placed", "order_id" => order.id}
    }

    case push_provider().send_push(device_token.token, notification) do
      {:ok, _} ->
        :ok

      {:error, :unregistered} ->
        Logger.info("[PushNotificationWorker] pruning unregistered device token")
        Ash.destroy!(device_token, authorize?: false, tenant: device_token.store_id)

      {:error, reason} ->
        Logger.error("[PushNotificationWorker] push failed: #{inspect(reason)}")
        :ok
    end
  end

  defp push_body(order) do
    currency = order.currency || "GHS"
    amount = Templates.format_amount(order.total || 0)
    "#{currency} #{amount} — tap to view"
  end

  defp push_provider do
    Application.get_env(:emakola, :push_provider, Emakola.Notifications.Providers.LogPush)
  end
end
