defmodule Emakola.Conversations.Validations.AttachmentsAreOurs do
  @moduledoc """
  An attachment must have a url, and that url must be one of ours.

  These render straight into an `<audio src>`, so an arbitrary host would be
  someone else's server playing through our page — and a redirect away from a
  chat is a phishing surface, not just a broken player.

  `Emakola.Storage.trusted_media_url?/1` is the same gate the storefront uses
  for review photos and page media, so there is one answer to "is this ours"
  rather than a second one drifting here.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.get_attribute(:attachments)
    |> Kernel.||([])
    |> Enum.reduce_while(:ok, fn attachment, :ok ->
      case check(attachment) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp check(%{"url" => url}) when is_binary(url) and url != "" do
    if Emakola.Storage.trusted_media_url?(url) do
      :ok
    else
      {:error, field: :attachments, message: "attachment must be stored by Makola"}
    end
  end

  defp check(_attachment) do
    {:error, field: :attachments, message: "attachment needs a url"}
  end
end
