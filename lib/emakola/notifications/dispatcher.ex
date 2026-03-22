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
  def dispatch(%{id: order_id}, event) when event in @valid_events do
    %{order_id: order_id, event: Atom.to_string(event)}
    |> OrderNotificationWorker.new(queue: :notifications)
    |> Oban.insert()
  end

  def dispatch(_order, _event) do
    {:error, :unknown_event}
  end
end
