defmodule Emakola.Stores.Changes.NormalizeHost do
  @moduledoc """
  Ash change that normalizes a `StoreDomain` host before persisting: trims
  surrounding whitespace and downcases it.

  Hostnames are case-insensitive, so storing a single canonical (lowercase)
  form keeps the `host` unique index and the `get_by_host` lookup consistent
  regardless of how a merchant typed it.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :host) do
      host when is_binary(host) ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :host,
          host |> String.trim() |> String.downcase()
        )

      _ ->
        changeset
    end
  end
end
