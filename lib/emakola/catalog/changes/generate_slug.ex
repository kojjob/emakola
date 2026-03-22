defmodule Emakola.Catalog.Changes.GenerateSlug do
  @moduledoc """
  Ash change that auto-generates a URL-safe slug from a source attribute.

  Uses Slugify for Unicode-aware slug generation (handles Akan, Hausa, Yoruba names).
  Strips leading/trailing hyphens and collapses multiple hyphens.

  ## Options

    * `:from` - The source attribute to generate the slug from (default: `:name`)
    * `:to` - The target attribute to write the slug to (default: `:slug`)
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    source = opts[:from] || :name
    target = opts[:to] || :slug

    case Ash.Changeset.get_attribute(changeset, source) do
      nil ->
        changeset

      value when is_binary(value) ->
        slug = generate_slug(value)

        if slug == "" do
          changeset
        else
          Ash.Changeset.force_change_attribute(changeset, target, slug)
        end

      _ ->
        changeset
    end
  end

  defp generate_slug(text) do
    text
    |> String.trim()
    |> Slug.slugify()
    |> case do
      nil -> ""
      slug -> slug
    end
  end
end
