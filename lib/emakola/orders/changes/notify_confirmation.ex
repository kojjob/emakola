defmodule Emakola.Orders.Changes.NotifyConfirmation do
  @moduledoc """
  Ash resource change for the `:confirm` transition's post-commit fanout:
  the `:order_confirmed` lifecycle notification, Earn sales-share conversion
  attribution, and supplier fulfillment notifications.

  Like the other notification changes, failures are logged rather than
  raised — none of this fanout may roll back a confirmed order.
  """

  use Ash.Resource.Change

  require Logger

  alias Emakola.Orders.Changes.NotifyStatusChange

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, order ->
      NotifyStatusChange.dispatch(order, :order_confirmed)
      Emakola.Suppliers.SalesSharing.record_conversion(order)

      Emakola.Notifications.Dispatcher.dispatch_supplier_fulfillments(
        order.id,
        pending_supplier_ids(order)
      )

      {:ok, order}
    end)
  end

  # IDs of pending supplier-owned fulfillments, passed to the Dispatcher so
  # it does not need to query back into Orders.
  defp pending_supplier_ids(order) do
    case Ash.load(order, :fulfillments, authorize?: false) do
      {:ok, loaded} ->
        loaded.fulfillments
        |> Enum.filter(fn f -> not is_nil(f.supplier_id) and f.status == :pending end)
        |> Enum.map(& &1.id)

      {:error, reason} ->
        Logger.error(
          "[orders] loading fulfillments for supplier notification failed: #{inspect(reason)}",
          order_id: order.id
        )

        []
    end
  end
end
