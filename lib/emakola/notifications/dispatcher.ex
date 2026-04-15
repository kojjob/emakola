defmodule Emakola.Notifications.Dispatcher do
  @moduledoc """
  Dispatches order lifecycle notifications by enqueuing Oban jobs.

  Called from order status transition actions (inside after_action hooks) or
  from LiveView after a status change. Each event maps to a specific
  notification type sent via the `OrderNotificationWorker`.

  ## Contract

  `dispatch/2` is guaranteed to **never raise**. Callers running inside an
  Ash `after_action` hook can rely on this so that a notification subsystem
  failure does not roll back a successful domain transaction.

  All failures — known error tuples, unknown events, and unexpected
  exceptions — are logged and returned as `{:error, reason}`.

  ## Return values

    * `{:ok, %Oban.Job{}}` — job enqueued successfully
    * `{:error, :unknown_event}` — event not in the valid set
    * `{:error, {:oban_insert_failed, changeset}}` — Oban could not enqueue
    * `{:error, {:dispatch_raised, message}}` — something unexpected raised
  """

  require Logger

  alias Emakola.Notifications.Workers.OrderNotificationWorker

  @valid_events ~w(order_placed order_confirmed order_shipped order_delivered order_cancelled)a

  @doc """
  Dispatch a notification for an order lifecycle event.

  Enqueues an Oban job to send SMS/WhatsApp notifications to the customer and
  merchant, and broadcasts a real-time PubSub event to the store topic.

  ## Parameters
    - `order` — an order struct/map with at least `:id` (and ideally `:store_id`)
    - `event` — one of #{inspect(@valid_events)}
  """
  @spec dispatch(map(), atom()) ::
          {:ok, Oban.Job.t()}
          | {:error,
             :unknown_event
             | :missing_order_id
             | {:oban_insert_failed, any()}
             | {:dispatch_raised, String.t()}}
  def dispatch(order, event) when event in @valid_events do
    do_dispatch(order, event)
  rescue
    exception ->
      Logger.error(
        "[notifications] dispatch raised for #{inspect(event)}: " <>
          Exception.message(exception),
        order_id: Map.get(order || %{}, :id),
        event: event
      )

      {:error, {:dispatch_raised, Exception.message(exception)}}
  end

  def dispatch(_order, event) do
    Logger.warning("[notifications] unknown event: #{inspect(event)}")
    {:error, :unknown_event}
  end

  # ── Internal ──────────────────────────────────────────────────────────

  defp do_dispatch(%{id: order_id} = order, event) when not is_nil(order_id) do
    case enqueue_job(order_id, event) do
      {:ok, job} ->
        maybe_broadcast(order, event)
        {:ok, job}

      {:error, reason} ->
        Logger.error(
          "[notifications] Oban insert failed for #{inspect(event)}: #{inspect(reason)}",
          order_id: order_id,
          event: event
        )

        {:error, {:oban_insert_failed, reason}}
    end
  end

  defp do_dispatch(_order, event) do
    Logger.error("[notifications] cannot dispatch #{inspect(event)}: order has no :id")
    {:error, :missing_order_id}
  end

  defp enqueue_job(order_id, event) do
    %{order_id: order_id, event: Atom.to_string(event)}
    |> OrderNotificationWorker.new(queue: :notifications)
    |> Oban.insert()
  end

  defp maybe_broadcast(%{store_id: store_id} = order, event) when not is_nil(store_id) do
    Phoenix.PubSub.broadcast(
      Emakola.PubSub,
      "store:#{store_id}:orders",
      {:order_event, event, order}
    )
  end

  defp maybe_broadcast(_order, _event), do: :ok
end
