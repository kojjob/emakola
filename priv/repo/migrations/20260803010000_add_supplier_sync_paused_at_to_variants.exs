defmodule Emakola.Repo.Migrations.AddSupplierSyncPausedAtToVariants do
  @moduledoc """
  Nullable `supplier_sync_paused_at` on `variants`, timestamping when
  `SupplierStockSyncWorker` — not a merchant — is the one that turned a
  reseller's imported variant `available: false` (Task 2 round 2,
  supplier-stock-truth; product ruling: a supplier restock may only
  re-enable a variant the sync itself turned off — a reseller's own
  deliberate `available: false` must stick until the reseller re-enables
  it). No index: read one row at a time (the mapped reseller variant),
  never filtered or sorted on.

  Hand-written: `mix ash.codegen` is unusable in this repo (crashes on an
  unrelated `PreorderDeposit` identity while snapshotting the whole app),
  same as prior single-column additions.
  """

  use Ecto.Migration

  def up do
    alter table(:variants) do
      add :supplier_sync_paused_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:variants) do
      remove :supplier_sync_paused_at
    end
  end
end
