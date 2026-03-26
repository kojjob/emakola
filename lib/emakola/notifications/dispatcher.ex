defmodule Emakola.Notifications.Dispatcher do
  @moduledoc """
  Dispatches order lifecycle notifications by enqueuing Oban jobs.

  Called from order status transition actions or LiveView after status change.
  Each event maps to a specific notification type sent via the
  OrderNotificationWorker.
  """

  alias Emakola.Notifications.Workers.OrderNotificationWorker

  @valid_events ~w(order_placed order_confirmed order_shipped order_delivered order_cancelled)a

  @doc """
  Dispatch a notification for an order lifecycle event.

  Enqueues an Oban job to send SMS/WhatsApp notifications to the
  customer and merchant.

  ## Parameters
    - `order` — the Order struct (must have :id)
    - `event` — one of #{inspect(@valid_events)}

  ## Returns
    - `{:ok, %Oban.Job{}}` on successful enqueue
    - `{:error, :unknown_event}` for unrecognized events
  """
  def dispatch(%{id: order_id, store_id: store_id} = order, event)
      when event in @valid_events do
    result =
      %{order_id: order_id, event: Atom.to_string(event)}
      |> OrderNotificationWorker.new(queue: :notifications)
      |> Oban.insert()

    # Broadcast for real-time merchant dashboard updates
    Phoenix.PubSub.broadcast(
      Emakola.PubSub,
      "store:#{store_id}:orders",
      {:order_event, event, order}
    )

    result
  end

  def dispatch(%{id: order_id} = order, event) when event in @valid_events do
    result =
      %{order_id: order_id, event: Atom.to_string(event)}
      |> OrderNotificationWorker.new(queue: :notifications)
      |> Oban.insert()

    # Broadcast if store_id is available
    if store_id = Map.get(order, :store_id) do
      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        "store:#{store_id}:orders",
        {:order_event, event, order}
      )
    end

    result
  end

  def dispatch(_order, _event) do
    {:error, :unknown_event}
  end
end
