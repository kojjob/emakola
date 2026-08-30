defmodule Emakola.Repo.Migrations.RetireNationalIdFields do
  @moduledoc """
  Retires the national-ID columns on store_verifications.

  L.I. 2523 (in force 9 June 2026) makes it an offence for an organisation to
  request, retain, reproduce or visually inspect a Ghana Card for identity
  verification. The columns are kept — historic rows are the audit trail for
  submissions taken under the retired flow — but made nullable so no new
  submission has to carry one.

  `quarantined_at` records when a retired ID document was moved to the private
  vault pending deletion.

  Hand-written deliberately: `mix ash.codegen` sweeps unrelated stale snapshots
  into one migration here, including a destructive `remove :user_id` on
  notifications whose real migration already exists (20260826120000).
  """

  use Ecto.Migration

  def up do
    alter table(:store_verifications) do
      add :quarantined_at, :utc_datetime_usec

      modify :id_type, :text, null: true
      modify :id_number, :text, null: true
      modify :id_document_key, :text, null: true
    end
  end

  def down do
    alter table(:store_verifications) do
      modify :id_document_key, :text, null: false
      modify :id_number, :text, null: false
      modify :id_type, :text, null: false

      remove :quarantined_at
    end
  end
end
