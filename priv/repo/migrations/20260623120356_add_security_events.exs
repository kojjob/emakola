defmodule Emakola.Repo.Migrations.AddSecurityEvents do
  @moduledoc """
  Creates the security_events table (abuse/security event log).

  Trimmed from `mix ash.codegen add_security_events`, which also bundled unrelated
  snapshot drift (merchants/customers indexes, merchant_identities, phone_otps) —
  those belong to other features and were removed here.
  """

  use Ecto.Migration

  def up do
    create table(:security_events, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :event_type, :text, null: false
      add :subject_type, :text, null: false, default: "anonymous"
      add :identifier, :text
      add :ip, :text
      add :path, :text
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:security_events, [:event_type])
    create index(:security_events, [:ip])
    create index(:security_events, [:inserted_at])
  end

  def down do
    drop_if_exists index(:security_events, [:inserted_at])
    drop_if_exists index(:security_events, [:ip])
    drop_if_exists index(:security_events, [:event_type])
    drop table(:security_events)
  end
end
