defmodule Emakola.Repo.Migrations.CreateResellerListings do
  use Ecto.Migration

  def change do
    create table(:reseller_listings, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :offer_id, references(:supplier_offers, type: :uuid, on_delete: :delete_all),
        null: false

      add :reseller_store_id, references(:stores, type: :uuid, on_delete: :delete_all),
        null: false

      add :reseller_product_id, references(:products, type: :uuid, on_delete: :delete_all),
        null: false

      add :supplier_id, references(:suppliers, type: :uuid, on_delete: :restrict), null: false
      add :status, :text, null: false, default: "active"
      add :synced_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:reseller_listings, [:offer_id, :reseller_store_id])
    create unique_index(:reseller_listings, [:reseller_product_id])
    create index(:reseller_listings, [:reseller_store_id, :status])

    create constraint(:reseller_listings, :reseller_listing_status_valid,
             check: "status IN ('active', 'paused', 'removed')"
           )

    create table(:reseller_listing_variants, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :listing_id, references(:reseller_listings, type: :uuid, on_delete: :delete_all),
        null: false

      add :offer_variant_id,
          references(:supplier_offer_variants, type: :uuid, on_delete: :restrict), null: false

      add :reseller_variant_id, references(:variants, type: :uuid, on_delete: :delete_all),
        null: false

      add :retail_price, :bigint, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:reseller_listing_variants, [:listing_id, :offer_variant_id])
    create unique_index(:reseller_listing_variants, [:reseller_variant_id])

    create constraint(:reseller_listing_variants, :reseller_listing_retail_price_positive,
             check: "retail_price > 0"
           )
  end
end
