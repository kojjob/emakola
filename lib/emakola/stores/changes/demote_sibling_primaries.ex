defmodule Emakola.Stores.Changes.DemoteSiblingPrimaries do
  @moduledoc """
  Clears `primary?` on the store's other domains so exactly one survives.

  Runs in `before_action` — the partial unique index on `(store_id) WHERE
  primary?` rejects the write if the old primary is still standing when the new
  one is promoted, so demote must happen first.
  """

  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      %{store_id: store_id, id: id} = changeset.data

      Emakola.Stores.StoreDomain
      |> Ash.Query.filter(store_id == ^store_id and primary? == true and id != ^id)
      |> Ash.read!(authorize?: false)
      |> Enum.each(&Ash.update!(&1, %{}, action: :demote_primary, authorize?: false))

      changeset
    end)
  end
end
