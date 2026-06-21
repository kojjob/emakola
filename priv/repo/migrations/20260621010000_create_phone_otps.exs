defmodule Emakola.Repo.Migrations.CreatePhoneOtps do
  use Ecto.Migration

  def up do
    create table(:phone_otps, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :phone, :text, null: false
      add :code_hash, :text, null: false
      add :purpose, :text, null: false
      add :store_id, :uuid
      add :expires_at, :utc_datetime_usec, null: false
      add :attempts, :integer, null: false, default: 0
      add :consumed_at, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:phone_otps, [:phone, :purpose])
  end

  def down do
    drop table(:phone_otps)
  end
end
