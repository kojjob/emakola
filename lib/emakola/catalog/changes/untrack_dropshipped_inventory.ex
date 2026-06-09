defmodule Emakola.Catalog.Changes.UntrackDropshippedInventory do
  @moduledoc """
  Ash change that forces `track_inventory` to `false` when a variant is linked
  to a supplier (i.e. it is dropshipped).

  A dropshipped variant is fulfilled by the supplier, so the merchant does not
  manage numeric stock for it — availability is controlled by the `available`
  flag instead. This change runs on both create and update: whenever
  `supplier_id` is present in the changeset, tracking is turned off regardless
  of what the caller passed.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :supplier_id) do
      nil -> changeset
      _supplier_id -> Ash.Changeset.force_change_attribute(changeset, :track_inventory, false)
    end
  end
end
