defmodule Emakola.Repo.Migrations.AddSupplierOfferVariantSourceVariantIndex do
  @moduledoc """
  Plain index on `supplier_offer_variants.source_variant_id`, backing
  `SupplierStockSyncWorker`'s lookup of every offer variant tied to a given
  source variant (Task 2, supplier-stock-truth). The existing unique index is
  `(offer_id, source_variant_id)` — offer_id-leading, so it can't serve a
  source_variant_id-only lookup without a full index scan.

  Hand-written: `mix ash_postgres.generate_migrations` is unusable in this
  repo (crashes on an unrelated `PreorderDeposit` identity while
  snapshotting the whole app), same as prior single-column/index additions
  (see 20260730150000_add_pay_link_id_index_to_orders.exs).
  """

  use Ecto.Migration

  def up do
    create index(:supplier_offer_variants, [:source_variant_id])
  end

  def down do
    drop_if_exists index(:supplier_offer_variants, [:source_variant_id])
  end
end
