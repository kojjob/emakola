defmodule Emakola.Repo.Migrations.AddAffiliateProgrammes do
  @moduledoc """
  A merchant's affiliate programme, and the per-product links it mints.

  Hand-written for the same reason as the other affiliate migrations: 38
  resources here have never had a committed snapshot, so `mix ash.codegen`
  emits `create table` for all of them.
  """

  use Ecto.Migration

  def up do
    create table(:affiliate_programmes, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)

      add(:store_id, references(:stores, column: :id, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:commission_bps, :bigint, null: false)
      add(:active, :boolean, null: false, default: true)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create(
      unique_index(:affiliate_programmes, [:store_id],
        name: "affiliate_programmes_one_per_store_index"
      )
    )

    create table(:affiliate_links, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)

      add(
        :affiliate_id,
        references(:affiliates, column: :id, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:store_id, references(:stores, column: :id, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:product_id, references(:products, column: :id, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:token, :text, null: false)
      add(:click_count, :bigint, null: false, default: 0)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    # One link per affiliate per product, so an affiliate cannot split their
    # own attribution across two rows by asking twice.
    create(
      unique_index(:affiliate_links, [:affiliate_id, :store_id, :product_id],
        name: "affiliate_links_one_per_product_index"
      )
    )

    # The token is the lookup key on every click and every checkout.
    create(unique_index(:affiliate_links, [:token], name: "affiliate_links_unique_token_index"))
  end

  def down do
    drop(table(:affiliate_links))
    drop(table(:affiliate_programmes))
  end
end
