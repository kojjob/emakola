defmodule Emakola.Catalog.Changes.UntrackDropshippedInventory do
  @moduledoc """
  Ash change that keeps `track_inventory` consistent with a variant's
  dropship status. Runs on both `:create` and `:update`.

  The resulting `supplier_id` is read via `Ash.Changeset.get_attribute/2`,
  which falls back to the persisted value on update when the attribute isn't
  being changed.

    * Supplier present (`supplier_id` non-nil) → force `track_inventory: false`.
      A dropshipped variant is fulfilled by the supplier, so the merchant does
      not manage numeric stock for it — availability is driven by the
      `available` flag instead.

    * Supplier de-linked on update (`supplier_id` set to nil but the original
      record had a supplier) → force `track_inventory: true`, since the variant
      is now own-stock and stock must be tracked again.

    * Otherwise (own-stock variant that never had a supplier) → leave the
      changeset untouched, respecting whatever the caller set. This preserves a
      deliberately untracked own-stock variant (e.g. digital/made-to-order).
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    cond do
      not is_nil(Ash.Changeset.get_attribute(changeset, :supplier_id)) ->
        Ash.Changeset.force_change_attribute(changeset, :track_inventory, false)

      changeset.action_type == :update and not is_nil(changeset.data.supplier_id) ->
        Ash.Changeset.force_change_attribute(changeset, :track_inventory, true)

      true ->
        changeset
    end
  end
end
