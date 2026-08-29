defmodule Emakola.Conversations.Validations.MessageHasContent do
  @moduledoc """
  A message must carry words, sound, or both.

  `body` became nullable so a voice note needs no typing. Without this, that
  same change would let an empty message through — a row in the thread with
  nothing in it, which the inbox would render as a blank bubble and count as
  unread.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    body = changeset |> Ash.Changeset.get_attribute(:body) |> blank_to_nil()
    attachments = Ash.Changeset.get_attribute(changeset, :attachments) || []

    if is_nil(body) and attachments == [] do
      {:error, field: :body, message: "write something or record something"}
    else
      :ok
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(body) do
    case String.trim(body) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
