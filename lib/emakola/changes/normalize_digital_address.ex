defmodule Emakola.Changes.NormalizeDigitalAddress do
  @moduledoc """
  Shared Ash change for a resource's `:digital_address` attribute: normalizes
  it via `Emakola.GhanaDigitalAddress.normalize/1` and adds a validation
  error when `Emakola.GhanaDigitalAddress.valid?/1` rejects the normalized
  value.

  Attached to `Customers.Address`'s `:create`/`:update` actions and
  `Stores.Store`'s `:update_settings` action — both resources carry the same
  optional GhanaPost digital-address field and want identical
  normalize+validate behavior for it. Blank input is always valid (see
  `GhanaDigitalAddress`'s moduledoc).
  """

  use Ash.Resource.Change

  alias Emakola.GhanaDigitalAddress

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :digital_address) do
      value when is_binary(value) ->
        normalized = GhanaDigitalAddress.normalize(value)

        changeset
        |> Ash.Changeset.force_change_attribute(:digital_address, normalized)
        |> validate(normalized)

      _ ->
        changeset
    end
  end

  defp validate(changeset, normalized) do
    if GhanaDigitalAddress.valid?(normalized) do
      changeset
    else
      Ash.Changeset.add_error(
        changeset,
        Ash.Error.Changes.InvalidAttribute.exception(
          field: :digital_address,
          message: "Check the digital address — it looks like GA-183-8164"
        )
      )
    end
  end
end
