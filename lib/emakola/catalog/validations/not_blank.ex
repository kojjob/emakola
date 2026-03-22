defmodule Emakola.Catalog.Validations.NotBlank do
  @moduledoc """
  Validates that a string attribute is not blank (empty or whitespace-only).

  Ash's `allow_nil? false` prevents nil values, but doesn't catch "" or "   ".
  This validation fills that gap.

  ## Options

    * `:attribute` - The attribute to validate (required)
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, opts, _context) do
    attribute = opts[:attribute]
    value = Ash.Changeset.get_attribute(changeset, attribute)

    case value do
      nil ->
        :ok

      val when is_binary(val) ->
        if String.trim(val) == "" do
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: attribute,
             message: "must not be blank"
           )}
        else
          :ok
        end

      _ ->
        :ok
    end
  end
end
