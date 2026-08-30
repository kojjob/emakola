defmodule Emakola.Stores.ImageUrl do
  @moduledoc """
  Whether a string is a link to a picture.

  One predicate, two jobs. `Validations.ImageUrl` uses it to stop a page link
  reaching a picture field, and the directory's card helpers use it to refuse
  to render one that is already there — two live merchants pasted their
  Instagram profile and their website into `cover_image_url` before the
  validation existed, and every shopper on /stores saw a broken image.

  Validation alone would not be enough anyway: product photo URLs reach the
  same `<img>` tags by a different road, and a store row written before this
  module existed is not re-validated by being read.

  Accepted when the **path** ends in an image extension and the value is
  either an http(s) URL with a host, or a root-relative path — the app writes
  `/uploads/stores/.../photo.jpg` when files live on local disk rather than
  object storage, and those are real pictures.

  The query string is ignored — a CDN link often carries `?w=800` — and the
  extension is the only signal available without fetching the thing, which
  neither a validation nor a render may do.
  """

  @extensions ~w(.jpg .jpeg .png .webp .gif .avif)

  @doc """
  True when `value` is a usable link to a picture.

  Blank, non-binary, non-http and extension-less values are all false, so a
  caller can pipe anything through this and get a safe answer.
  """
  @spec image_url?(term()) :: boolean()
  def image_url?(value) when is_binary(value) do
    trimmed = String.trim(value)
    uri = URI.parse(trimmed)

    image_path?(uri.path) and
      cond do
        uri.scheme in ["http", "https"] ->
          is_binary(uri.host) and uri.host != ""

        # Root-relative, and not the protocol-relative `//host/path` form,
        # which is a remote URL wearing a local path's clothes.
        is_nil(uri.scheme) ->
          String.starts_with?(trimmed, "/") and not String.starts_with?(trimmed, "//")

        true ->
          false
      end
  end

  def image_url?(_value), do: false

  @doc "The first value in `candidates` that is a link to a picture, else nil."
  @spec first_image([term()]) :: String.t() | nil
  def first_image(candidates) when is_list(candidates) do
    Enum.find(candidates, &image_url?/1)
  end

  defp image_path?(path) when is_binary(path) do
    downcased = String.downcase(path)
    Enum.any?(@extensions, &String.ends_with?(downcased, &1))
  end

  defp image_path?(_path), do: false
end
