defmodule Emakola.Repo.Migrations.RenameSupplierOffersUniqueIndex do
  use Ecto.Migration

  # AshPostgres reports identity violations cleanly only when the index name
  # matches the identity-derived name. The original index kept Ecto's default
  # name, so duplicate-offer inserts surfaced as raw ConstraintErrors.
  def up do
    execute("""
    ALTER INDEX supplier_offers_wholesaler_store_id_source_product_id_index
    RENAME TO supplier_offers_unique_product_offer_index
    """)
  end

  def down do
    execute("""
    ALTER INDEX supplier_offers_unique_product_offer_index
    RENAME TO supplier_offers_wholesaler_store_id_source_product_id_index
    """)
  end
end
