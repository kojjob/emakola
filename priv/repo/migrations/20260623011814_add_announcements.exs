defmodule Emakola.Repo.Migrations.AddAnnouncements do
  @moduledoc """
  Creates the platform broadcast announcement tables.

  Trimmed from `mix ash.codegen add_announcements` output, which also bundled
  unrelated snapshot drift for other resources (merchants/customers indexes,
  merchant_identities, phone_otps) — those belong to other features and were
  removed here.
  """

  use Ecto.Migration

  def up do
    create table(:announcements, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :title, :text, null: false
      add :body, :text, null: false
      add :severity, :text, null: false, default: "info"
      add :channels, {:array, :text}, null: false
      add :audience, :text, null: false, default: "all"
      add :publish_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec
      add :status, :text, null: false, default: "scheduled"

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create table(:announcement_dismissals, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :announcement_id, :uuid, null: false
      add :merchant_id, :uuid, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:announcement_dismissals, [:announcement_id, :merchant_id],
             name: "announcement_dismissals_unique_dismissal_index"
           )
  end

  def down do
    drop_if_exists unique_index(:announcement_dismissals, [:announcement_id, :merchant_id],
                     name: "announcement_dismissals_unique_dismissal_index"
                   )

    drop table(:announcement_dismissals)
    drop table(:announcements)
  end
end
