defmodule Emakola.Repo.Migrations.AddMessageAttachments do
  @moduledoc """
  Lets a message be a recording instead of typing.

  The point of the feature: a merchant who does not read or write fluently can
  still hold a conversation. That means `body` can no longer be `NOT NULL` —
  a voice note has no words. A message with neither words nor sound is still
  nothing, and the resource refuses it.

  `attachments` is a jsonb array of maps, the same shape `Catalog.Review.images`
  already uses, rather than a table: an attachment has no identity of its own,
  is never queried across messages, and dies with the message it belongs to.

  `posted_by_staff_id` records who actually typed, which is unrelated to voice
  but shares this table's only migration. Under impersonation `AssignDefaults`
  puts the impersonated merchant in `current_merchant` and the real staff user
  in `impersonator`, so today a staff member writes as the merchant with no
  trace of who it really was.
  """

  use Ecto.Migration

  def up do
    alter table(:conversation_messages) do
      modify(:body, :text, null: true)
      add(:attachments, :map, null: false, default: fragment("'[]'::jsonb"))
      add(:posted_by_staff_id, :uuid)
    end
  end

  def down do
    # Voice-only messages have no words to restore, so they cannot survive a
    # NOT NULL body. Deleted rather than given invented text.
    execute("DELETE FROM conversation_messages WHERE body IS NULL")

    alter table(:conversation_messages) do
      modify(:body, :text, null: false)
      remove(:attachments)
      remove(:posted_by_staff_id)
    end
  end
end
