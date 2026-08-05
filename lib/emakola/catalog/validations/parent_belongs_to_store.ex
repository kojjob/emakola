defmodule Emakola.Catalog.Validations.ParentBelongsToStore do
  @moduledoc """
  Ensures a category hierarchy never crosses store boundaries.

  The database foreign key can prove that a parent exists, but it cannot prove
  that the parent belongs to the same store. This validation runs for both
  creates and updates so every write path, including internal callers that
  bypass authorization, preserves tenant isolation.
  """

  use Ash.Resource.Validation

  alias Emakola.Catalog.Category

  @impl true
  def validate(changeset, _opts, _context) do
    parent_id = Ash.Changeset.get_attribute(changeset, :parent_id)
    store_id = Ash.Changeset.get_attribute(changeset, :store_id)

    validate_parent(parent_id, store_id)
  end

  defp validate_parent(nil, _store_id), do: :ok
  defp validate_parent(_parent_id, nil), do: :ok

  defp validate_parent(parent_id, store_id) do
    case Ash.get(Category, parent_id, authorize?: false) do
      {:ok, %{store_id: ^store_id}} ->
        :ok

      _other ->
        {:error,
         Ash.Error.Changes.InvalidAttribute.exception(
           field: :parent_id,
           message: "must belong to the same store"
         )}
    end
  end
end
