defmodule Emakola.Catalog.Validations.MaxValue do
  @moduledoc """
  Validates that a numeric attribute does not exceed a maximum value.

  ## Options

    * `:attribute` - The attribute to validate (required)
    * `:max` - The maximum allowed value (required)
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, opts, _context) do
    attribute = opts[:attribute]
    max = opts[:max]
    value = Ash.Changeset.get_attribute(changeset, attribute)

    cond do
      is_nil(value) ->
        :ok

      value <= max ->
        :ok

      true ->
        {:error,
         Ash.Error.Changes.InvalidAttribute.exception(
           field: attribute,
           message: "must be at most #{max}"
         )}
    end
  end
end
