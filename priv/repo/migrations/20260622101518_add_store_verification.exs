defmodule Emakola.Repo.Migrations.AddStoreVerification do
  @moduledoc """
  Per-store KYC submissions (`store_verifications`): status + fields + private
  document storage keys + review notes, one row per store.
  """

  use Ecto.Migration

  def up do
    create table(:store_verifications, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :store_id,
          references(:stores,
            column: :id,
            name: "store_verifications_store_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :status, :text, null: false, default: "pending"
      add :business_name, :text, null: false
      add :id_type, :text, null: false
      add :id_number, :text, null: false
      add :id_document_key, :text, null: false
      add :business_doc_key, :text
      add :review_reason, :text
      add :submitted_at, :utc_datetime_usec
      add :reviewed_at, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:store_verifications, [:store_id],
             name: "store_verifications_unique_store_verification_index"
           )
  end

  def down do
    drop constraint(:store_verifications, "store_verifications_store_id_fkey")

    drop_if_exists unique_index(:store_verifications, [:store_id],
                     name: "store_verifications_unique_store_verification_index"
                   )

    drop table(:store_verifications)
  end
end
