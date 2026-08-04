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
  alias Emakola.Security.SecretStorage

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

    case SecretStorage.device_token(device_token) do
      {:ok, token} when is_binary(token) ->
        deliver_to_provider(token, notification, device_token, order)

      {:error, _reason} ->
        Logger.error("[PushNotificationWorker] encrypted device token is unavailable",
          order_id: order.id,
          store_id: order.store_id,
          device_token_id: device_token.id
        )

        :ok

      _other ->
        :ok
    end
  end

  defp deliver_to_provider(token, notification, device_token, order) do
    case push_provider().send_push(token, notification) do
      {:ok, _} ->
        :ok

      {:error, :unregistered} ->
        Logger.info("[PushNotificationWorker] pruning unregistered device token",
          order_id: order.id,
          store_id: order.store_id
        )

        prune(device_token)

      {:error, reason} ->
        Logger.error("[PushNotificationWorker] push failed: #{inspect(reason)}",
          order_id: order.id,
          store_id: order.store_id
        )

        :ok
    end
  end

  # A concurrent job (two near-simultaneous orders share dead tokens) or the
  # device re-registering may have deleted the row already — that's success,
  # not a failure worth crashing the remaining fan-out for.
  defp prune(device_token) do
    case Ash.destroy(device_token, authorize?: false, tenant: device_token.store_id) do
      :ok ->
        :ok

      {:error, reason} ->
        if stale_or_not_found?(reason) do
          :ok
        else
          Logger.error("[PushNotificationWorker] prune failed: #{inspect(reason)}",
            store_id: device_token.store_id
          )

          :ok
        end
    end
  end

  defp stale_or_not_found?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.StaleRecord{} -> true
      %Ash.Error.Query.NotFound{} -> true
      _ -> false
    end)
  end

  defp stale_or_not_found?(_reason), do: false

  defp push_body(order) do
    currency = order.currency || "GHS"
    amount = Templates.format_amount(order.total || 0)
    "#{currency} #{amount} — tap to view"
  end

  defp push_provider do
    Application.get_env(:emakola, :push_provider, Emakola.Notifications.Providers.LogPush)
  end
end
