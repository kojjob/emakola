defmodule Emakola.Repo.Migrations.RenameSupplierOfferVariantsUniqueIndex do
  use Ecto.Migration

  # Mirrors bf1ba49f: AshPostgres reports identity violations cleanly only when
  # the index name matches the identity-derived name. This index kept Ecto's
  # default name, so duplicate add_variant calls surfaced as a raw
  # Ecto.ConstraintError (wrapped in Ash.Error.Unknown) instead of a mapped
  # Ash.Error.Invalid.
  def up do
    execute("""
    ALTER INDEX supplier_offer_variants_offer_id_source_variant_id_index
    RENAME TO supplier_offer_variants_unique_offer_variant_index
    """)
  end

  def down do
    execute("""
    ALTER INDEX supplier_offer_variants_unique_offer_variant_index
    RENAME TO supplier_offer_variants_offer_id_source_variant_id_index
    """)
  end
end
