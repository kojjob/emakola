defmodule Emakola.Repo.Migrations.AddAffiliates do
  @moduledoc """
  Affiliate identity, plus `stores.kind`.

  `kind` distinguishes a real shop from an affiliate's payout container — a
  store row that exists only because every payout rail is keyed to a store id.
  Existing rows are all shops, so the default backfills them correctly.

  Hand-written: 38 resources in this repo have never had a committed
  snapshot, so `mix ash.codegen` emits `create table` for all of them.
  """

  use Ecto.Migration

  def up do
    alter table(:stores) do
      add(:kind, :text, null: false, default: "shop")
    end

    create table(:affiliates, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add(:phone, :text, null: false)
      add(:name, :text, null: false)
      add(:momo_number, :text, null: false)
      add(:momo_provider, :text, null: false)

      add(
        :payout_store_id,
        references(:stores, column: :id, type: :uuid, on_delete: :restrict),
        null: false
      )

      add(:status, :text, null: false, default: "active")

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    # One person, one account, one balance — the phone is stored E.164 so a
    # local and an international spelling collide here rather than becoming
    # two affiliates.
    create(unique_index(:affiliates, [:phone], name: "affiliates_unique_phone_index"))

    # on_delete: :restrict above is deliberate: deleting a store that is
    # somebody's payout container would orphan their earnings.
    create(index(:affiliates, [:payout_store_id]))
  end

  def down do
    drop(table(:affiliates))

    alter table(:stores) do
      remove(:kind)
    end
  end
end
