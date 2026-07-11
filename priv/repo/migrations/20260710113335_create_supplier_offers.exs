defmodule Emakola.Repo.Migrations.CreateSupplierOffers do
  use Ecto.Migration

  def change do
    create table(:supplier_offers, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :wholesaler_store_id, references(:stores, type: :uuid, on_delete: :delete_all),
        null: false

      add :source_product_id, references(:products, type: :uuid, on_delete: :delete_all),
        null: false

      add :status, :text, null: false, default: "draft"
      add :earning_model, :text, null: false
      add :delivery_areas, {:array, :text}, null: false, default: []
      add :return_terms, :text
      add :published_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:supplier_offers, [:wholesaler_store_id, :source_product_id])
    create index(:supplier_offers, [:status, :wholesaler_store_id])

    create constraint(:supplier_offers, :supplier_offers_status_valid,
             check: "status IN ('draft', 'published', 'paused', 'archived')"
           )

    create constraint(:supplier_offers, :supplier_offers_earning_model_valid,
             check: "earning_model IN ('markup', 'fixed_commission')"
           )

    create table(:supplier_offer_variants, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :offer_id, references(:supplier_offers, type: :uuid, on_delete: :delete_all),
        null: false

      add :wholesaler_store_id, references(:stores, type: :uuid, on_delete: :delete_all),
        null: false

      add :source_variant_id, references(:variants, type: :uuid, on_delete: :delete_all),
        null: false

      add :supplier_price, :bigint, null: false
      add :suggested_retail_price, :bigint, null: false
      add :max_retail_price, :bigint
      add :fixed_commission_amount, :bigint
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:supplier_offer_variants, [:offer_id, :source_variant_id])
    create index(:supplier_offer_variants, [:wholesaler_store_id])

    create constraint(:supplier_offer_variants, :supplier_offer_variant_prices_positive,
             check: "supplier_price > 0 AND suggested_retail_price > 0"
           )

    create constraint(:supplier_offer_variants, :supplier_offer_variant_price_order,
             check:
               "suggested_retail_price >= supplier_price AND (max_retail_price IS NULL OR max_retail_price >= suggested_retail_price)"
           )

    create constraint(:supplier_offer_variants, :supplier_offer_variant_commission_positive,
             check: "fixed_commission_amount IS NULL OR fixed_commission_amount > 0"
           )
  end
end
