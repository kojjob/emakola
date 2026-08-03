defmodule Emakola.Catalog.Changes.EnqueueSupplierStockSync do
  @moduledoc """
  After a variant update that changed `stock_quantity`, `available`, or
  `track_inventory`, enqueue supplier-stock sync so mapped reseller listings
  follow. Cheap no-op in the worker for variants that back no offers.
  """
  use Ash.Resource.Change

  @watched [:stock_quantity, :available, :track_inventory]

  @impl true
  def change(changeset, _opts, _context) do
    if Enum.any?(@watched, &Ash.Changeset.changing_attribute?(changeset, &1)) do
      Ash.Changeset.after_action(changeset, fn _changeset, variant ->
        Emakola.Suppliers.Workers.SupplierStockSyncWorker.enqueue(variant.id)
        {:ok, variant}
      end)
    else
      changeset
    end
  end
end
