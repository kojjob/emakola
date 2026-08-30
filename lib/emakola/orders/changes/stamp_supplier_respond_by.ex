defmodule Emakola.Orders.Changes.StampSupplierRespondBy do
  @moduledoc """
  Starts the SLA clock on an order's supplier fulfillments at `:confirm`.

  Runs BEFORE `NotifyConfirmation` in the action's change list, so the clock
  exists before the message goes out: a supplier who replies instantly must
  have something to stop.

  Deliberately not folded into `NotifyConfirmation`, even though that module
  already loads the fulfillments. Its contract is "log the failure, never raise"
  — correct for a notification, wrong for this. A swallowed stamping failure is
  a fulfilment with no clock at all, which is precisely the silence this change
  exists to end.

  One bulk statement, no load, no N+1. The `:start_sla_clock` action carries
  `is_nil(respond_by)` in its WHERE, so a manual confirm landing after a webhook
  confirm cannot push an already-set deadline later.
  """

  use Ash.Resource.Change

  require Ash.Query
  require Logger

  alias Emakola.Orders.Fulfillment
  alias Emakola.Orders.Workers.SupplierSlaWorker

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, order ->
      stamp(order)
      {:ok, order}
    end)
  end

  defp stamp(order) do
    deadline = DateTime.add(DateTime.utc_now(), SupplierSlaWorker.respond_hours(), :hour)

    Fulfillment
    |> Ash.Query.filter(
      order_id == ^order.id and not is_nil(supplier_id) and is_nil(respond_by) and
        status == :pending
    )
    |> Ash.bulk_update(:start_sla_clock, %{respond_by: deadline},
      authorize?: false,
      return_errors?: true,
      strategy: [:stream]
    )
    |> case do
      %Ash.BulkResult{status: :success} ->
        :ok

      result ->
        Logger.error(
          "[stamp_supplier_respond_by] could not stamp order #{order.id}: #{inspect(result)}"
        )

        :ok
    end
  rescue
    exception ->
      Logger.error(
        "[stamp_supplier_respond_by] raised for order #{order.id}: #{Exception.message(exception)}"
      )

      :ok
  end
end
