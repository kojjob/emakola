defmodule Emakola.Orders.Changes.NotifyStatusChange do
  @moduledoc """
  Ash resource change that dispatches an order lifecycle notification after a
  status transition commits.

      change({Emakola.Orders.Changes.NotifyStatusChange, event: :order_shipped})

  Runs inside the Ash transaction via after_action; a raise here would roll
  back the successful status update, so dispatch failures are logged and
  swallowed — a notification must never undo a state change.
  """

  use Ash.Resource.Change

  require Logger

  @impl true
  def init(opts) do
    if is_atom(opts[:event]) and not is_nil(opts[:event]) do
      {:ok, opts}
    else
      {:error, "NotifyStatusChange requires an :event atom option"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    event = opts[:event]

    Ash.Changeset.after_action(changeset, fn _changeset, order ->
      dispatch(order, event)
      {:ok, order}
    end)
  end

  @doc "Dispatches a lifecycle notification, logging (never raising) on failure."
  def dispatch(order, event) do
    case Emakola.Notifications.Dispatcher.dispatch(order, event) do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "[orders] #{inspect(event)} notification dispatch failed: #{inspect(reason)}",
          order_id: order.id,
          store_id: Map.get(order, :store_id),
          event: event
        )

        :ok
    end
  end
end
