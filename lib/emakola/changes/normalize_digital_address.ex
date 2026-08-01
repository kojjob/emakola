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

  Gated on `Ash.Changeset.fetch_change/2` — only present when *this*
  update's input actually set `:digital_address` — rather than
  `get_attribute/2`, which falls back to `changeset.data` (whatever struct
  the caller passed into `for_update/3`) when the attribute isn't part of
  the input. `update_settings` is called from several LiveViews
  (settings/onboarding/design/theme), each of which may be holding its own,
  possibly-stale, copy of the `Store` struct. Deriving from `changeset.data`
  unconditionally means an unrelated-field save re-runs normalize on
  whatever value that stale struct happens to carry and force-writes the
  result back — a silent side effect on a column the caller never touched.
  For an already-canonical value this is usually a no-op (`force_change_
  attribute/3` skips the write when the forced value equals `changeset.
  data`'s own value for that attribute), but it stops being a no-op the
  moment the stale struct's value isn't already in the exact form
  `normalize/1` produces — e.g. a row written before this feature existed,
  or by a backfill/import script — at which point the unrelated save
  silently rewrites it.
  """

  use Ash.Resource.Change

  alias Emakola.GhanaDigitalAddress

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_change(changeset, :digital_address) do
      {:ok, value} when is_binary(value) ->
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
