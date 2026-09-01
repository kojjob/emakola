defmodule Emakola.Repo.Migrations.RenameQuarantinedAtToDocumentsPurgedAt do
  @moduledoc """
  `quarantined_at` promised a private vault that does not exist: the only
  bucket is public bucket-wide, and Tigris ignores per-object ACLs under it, so
  "quarantine" only ever renamed the exposure. Under L.I. 2523 retention is the
  offence, so the tool now deletes, and the column says so.

  A separate migration rather than an edit to 20260830161600, which may already
  have run on a developer's database.
  """
  use Ecto.Migration

  def change do
    rename table(:store_verifications), :quarantined_at, to: :documents_purged_at
  end
end
