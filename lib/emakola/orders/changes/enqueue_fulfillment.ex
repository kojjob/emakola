defmodule Emakola.Orders.Changes.EnqueueFulfillment do
  @moduledoc """
  Ash resource change that enqueues `Emakola.Workers.FulfillmentWorker` after
  an order is confirmed.

  Extracting the enqueue into a named Change module removes the compile-time
  dependency from `Emakola.Orders.Order` directly to
  `Emakola.Workers.FulfillmentWorker`. The resource now depends only on this
  module (within the Orders context), and this module depends on the worker.

  Like the inline after_action it replaces, failures are logged rather than
  raised so that a transient Oban error never rolls back a successful
  :confirm transition.
  """

  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, order ->
      case %{order_id: order.id}
           |> Emakola.Workers.FulfillmentWorker.new()
           |> Oban.insert() do
        {:ok, _job} ->
          {:ok, order}

        {:error, reason} ->
          Logger.error(
            "[orders] fulfillment enqueue failed: #{inspect(reason)}",
            order_id: order.id
          )

          {:ok, order}
      end
    end)
  end
end
