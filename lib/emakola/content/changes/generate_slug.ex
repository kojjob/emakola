defmodule Emakola.Content.Changes.GenerateSlug do
  @moduledoc """
  Ash change that auto-generates a URL-safe slug from the post title.

  Strips non-alphanumeric characters, replaces whitespace with hyphens,
  and truncates to 255 characters.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :title) do
      nil ->
        changeset

      title when is_binary(title) ->
        slug =
          title
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9\s-]/, "")
          |> String.replace(~r/[\s]+/, "-")
          |> String.trim("-")
          |> String.slice(0, 255)

        if slug == "" do
          changeset
        else
          Ash.Changeset.force_change_attribute(changeset, :slug, slug)
        end

      _ ->
        changeset
    end
  end
end
