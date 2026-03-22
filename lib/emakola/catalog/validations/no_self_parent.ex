defmodule Emakola.Catalog.Validations.NoSelfParent do
  @moduledoc """
  Validates that a category's parent_id does not reference itself.

  This prevents the simplest form of circular reference: A → A.
  Deeper circular detection (A → B → A) would require a recursive query
  and can be added as a future enhancement.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    parent_id = Ash.Changeset.get_attribute(changeset, :parent_id)
    record_id = Ash.Changeset.get_data(changeset, :id)

    if parent_id && parent_id == record_id do
      {:error,
       Ash.Error.Changes.InvalidAttribute.exception(
         field: :parent_id,
         message: "a category cannot be its own parent"
       )}
    else
      :ok
    end
  end
end
