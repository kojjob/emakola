defmodule Emakola.Catalog.Changes.ClearSupplierSyncPause do
  @moduledoc """
  When a caller changes `available` through the general `:update` action —
  i.e. NOT through `SupplierStockSyncWorker`'s dedicated `:sync_availability`
  action — clear `supplier_sync_paused_at`. Touching the toggle, in either
  direction, reclaims ownership of `available` from the sync worker: a
  merchant turning a dropshipped variant off is a deliberate decision the
  next supplier restock must not silently override, and turning it back on
  clears any stale "sync turned this off" marker so future sync decisions
  start clean.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :available) do
      Ash.Changeset.force_change_attribute(changeset, :supplier_sync_paused_at, nil)
    else
      changeset
    end
  end
end
