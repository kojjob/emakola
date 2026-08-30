defmodule Emakola.Stores.Validations.ImageUrl do
  @moduledoc """
  Insists that a picture field holds a link to a picture.

  Store settings offers "Or paste a picture link" for a merchant whose image
  already lives on a CDN. The input is `type="url"`, which asks only that the
  text be a URL — so two live merchants pasted their Instagram profile and
  their website into `cover_image_url`, and the marketplace rendered each one
  as a broken image on /stores for every shopper who scrolled past.

  The rule itself lives in `Emakola.Stores.ImageUrl`, shared with the
  directory's render guard. It deliberately rejects placeholder services
  (`placehold.co/96x96`) too: they have no extension, and a generated grey
  box is not a shop photo.

  Blank passes. Both fields are optional, and the marketplace already falls
  back to a product photo and then a gradient.
  """

  use Ash.Resource.Validation

  alias Emakola.Stores.ImageUrl

  @impl true
  def init(opts) do
    case opts[:attribute] do
      nil -> {:error, "must supply :attribute"}
      attribute when is_atom(attribute) -> {:ok, opts}
      other -> {:error, "expected an atom for :attribute, got #{inspect(other)}"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    attribute = opts[:attribute]

    case Ash.Changeset.get_attribute(changeset, attribute) do
      blank when blank in [nil, ""] -> :ok
      value -> if ImageUrl.image_url?(value), do: :ok, else: error(attribute)
    end
  end

  # Plain words, no jargon: many Makola merchants do not read fluently, and
  # "invalid URI" tells them nothing they can act on.
  defp error(attribute) do
    {:error,
     Ash.Error.Changes.InvalidAttribute.exception(
       field: attribute,
       message: "must be a link to a picture ending in .jpg, .png or .webp"
     )}
  end
end
