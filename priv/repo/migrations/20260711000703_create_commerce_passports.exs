defmodule Emakola.Repo.Migrations.CreateCommercePassports do
  use Ecto.Migration

  def change do
    create table(:earn_commerce_passports, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :score, :integer, null: false, default: 500
      add :tier, :string, null: false, default: "starter"
      add :metrics, :map, null: false, default: %{}
      add :computed_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:earn_commerce_passports, [:store_id])

    create constraint(:earn_commerce_passports, :commerce_passport_score_valid,
             check: "score >= 0 AND score <= 1000"
           )

    create constraint(:earn_commerce_passports, :commerce_passport_tier_valid,
             check: "tier IN ('starter', 'reliable', 'proven')"
           )

    create table(:earn_reputation_signals, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :passport_id, references(:earn_commerce_passports, type: :uuid, on_delete: :delete_all),
        null: false

      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :value, :integer, null: false
      add :impact, :integer, null: false
      add :reason_code, :string, null: false
      add :evidence, :map, null: false, default: %{}
      add :source_fingerprint, :string, null: false
      add :status, :string, null: false, default: "active"
      add :observed_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :corrected_at, :utc_datetime_usec
      add :correction_reason, :text
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:earn_reputation_signals, [:passport_id, :source_fingerprint])
    create index(:earn_reputation_signals, [:store_id, :status])

    create constraint(:earn_reputation_signals, :reputation_signal_status_valid,
             check: "status IN ('active', 'appealed', 'corrected', 'expired')"
           )

    create table(:earn_reputation_appeals, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :signal_id, references(:earn_reputation_signals, type: :uuid, on_delete: :delete_all),
        null: false

      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :merchant_id, references(:merchants, type: :uuid, on_delete: :restrict), null: false
      add :reason, :text, null: false
      add :status, :string, null: false, default: "open"
      add :resolution, :text
      add :resolved_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:earn_reputation_appeals, [:signal_id, :merchant_id],
             where: "status = 'open'",
             name: :one_open_reputation_appeal_per_merchant
           )

    create index(:earn_reputation_appeals, [:store_id, :status])

    create constraint(:earn_reputation_appeals, :reputation_appeal_status_valid,
             check: "status IN ('open', 'upheld', 'denied', 'withdrawn')"
           )
  end
end
