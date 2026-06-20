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

  The suffixed slug is kept within the `:slug` attribute's `max_length`: a forced
  change is still constraint-validated, so without trimming, suffixing a near-max
  base would fail the insert — re-introducing the onboarding dead-end this change
  exists to remove.
  """

  use Ash.Resource.Change

  require Ash.Query

  # Mirrors the Store `:slug` attribute's max_length. force_change_attribute
  # values are still validated, so the suffix must not push the slug past this.
  @max_slug_length 255
  # Room reserved for the "-N" suffix (covers up to "-99999").
  @suffix_reserve 6

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
    if taken?(base) do
      # Trim the base so "<stem>-<n>" never exceeds the column's max_length. A
      # short base (the normal case) is left untouched: stem == base.
      stem = String.slice(base, 0, @max_slug_length - @suffix_reserve)
      taken = suffixed_slugs(stem)

      Stream.iterate(2, &(&1 + 1))
      |> Enum.find_value(fn n ->
        candidate = "#{stem}-#{n}"
        if candidate not in taken, do: candidate
      end)
    else
      base
    end
  end

  defp taken?(slug) do
    Emakola.Stores.Store
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end

  # Existing slugs shaped like `stem-<suffix>`, fetched in one query so the first
  # free numeric suffix can be chosen without N round-trips.
  defp suffixed_slugs(stem) do
    Emakola.Stores.Store
    |> Ash.Query.filter(like(slug, ^(stem <> "-%")))
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.slug)
  end
end
