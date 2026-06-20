defmodule Emakola.Stores.Changes.EnsureUniqueSlug do
  @moduledoc """
  Ash change that guarantees a globally-unique Store slug by appending a numeric
  suffix (`-2`, `-3`, …) when the base slug is already taken.

  Without it, onboarding dead-ends the moment a chosen store name slugifies to
  one that already exists — the `:unique_slug` identity rejects the insert with
  "slug: has already been taken". Two shops may share a display name; they just
  need distinct slugs (and therefore subdomains).

  Runs in a `before_action` hook so the lookup happens inside the create
  transaction, narrowing the window for a concurrent collision. The `:unique_slug`
  identity (and its DB index) remains the final backstop for that rare race.
  """

  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &ensure_unique_slug/1)
  end

  defp ensure_unique_slug(changeset) do
    case Ash.Changeset.get_attribute(changeset, :slug) do
      slug when is_binary(slug) and slug != "" ->
        Ash.Changeset.force_change_attribute(changeset, :slug, unique_slug(slug))

      _ ->
        changeset
    end
  end

  defp unique_slug(base) do
    taken = taken_slugs(base)

    if base in taken do
      Stream.iterate(2, &(&1 + 1))
      |> Enum.find_value(fn n ->
        candidate = "#{base}-#{n}"
        if candidate not in taken, do: candidate
      end)
    else
      base
    end
  end

  # Existing slugs equal to `base` or shaped like `base-<suffix>`, fetched in one
  # query so the first free numeric suffix can be chosen without N round-trips.
  defp taken_slugs(base) do
    Emakola.Stores.Store
    |> Ash.Query.filter(slug == ^base or like(slug, ^(base <> "-%")))
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.slug)
  end
end
