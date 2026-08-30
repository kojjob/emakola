defmodule Emakola.Repo.Migrations.AddCampaigns do
  @moduledoc """
  Merchant SMS campaigns.

  Hand-written rather than generated: 38 of this repo's resources have never
  had a committed snapshot, so `mix ash.codegen` emits `create table` for all
  of them and the migration fails on any database where they already exist.
  """

  use Ecto.Migration

  def up do
    create table(:campaigns, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)

      add(:store_id, references(:stores, column: :id, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:name, :text, null: false)
      add(:channel, :text, null: false, default: "sms")
      add(:body, :text, null: false)
      add(:status, :text, null: false, default: "draft")
      add(:audience_size, :bigint, null: false, default: 0)
      add(:sent_count, :bigint, null: false, default: 0)
      add(:failed_count, :bigint, null: false, default: 0)
      add(:sent_at, :utc_datetime_usec)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    # The admin lists a store's campaigns newest-first on every page load.
    create(index(:campaigns, [:store_id, "inserted_at DESC"]))

    create table(:campaign_recipients, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)

      add(
        :campaign_id,
        references(:campaigns, column: :id, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :customer_id,
        references(:customers, column: :id, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:phone, :text, null: false)
      add(:status, :text, null: false, default: "pending")
      add(:error, :text)
      add(:sent_at, :utc_datetime_usec)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    # The claim that makes an Oban retry safe instead of a second SMS charge.
    create(
      unique_index(:campaign_recipients, [:campaign_id, :customer_id],
        name: "campaign_recipients_unique_attempt_index"
      )
    )

    create(index(:campaign_recipients, [:campaign_id, :status]))

    alter table(:customers) do
      add(:marketing_opt_out_at, :utc_datetime_usec)
    end
  end

  def down do
    alter table(:customers) do
      remove(:marketing_opt_out_at)
    end

    drop(table(:campaign_recipients))
    drop(table(:campaigns))
  end
end
