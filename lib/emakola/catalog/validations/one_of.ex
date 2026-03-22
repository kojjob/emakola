defmodule Emakola.Catalog.Validations.OneOf do
  @moduledoc """
  Validates that an attribute value is one of the allowed values.

  ## Options

    * `:attribute` - The attribute to validate (required)
    * `:values` - List of allowed values (required)
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, opts, _context) do
    attribute = opts[:attribute]
    allowed_values = opts[:values]
    value = Ash.Changeset.get_attribute(changeset, attribute)

    cond do
      is_nil(value) ->
        :ok

      value in allowed_values ->
        :ok

      true ->
        {:error,
         Ash.Error.Changes.InvalidAttribute.exception(
           field: attribute,
           message: "must be one of: #{Enum.join(allowed_values, ", ")}"
         )}
    end
  end
end
