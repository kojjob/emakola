defmodule Emakola.Repo.Migrations.AddPayoutBasisAndSupplierLedgerSettlementSource do
  @moduledoc """
  Phase-1 schema for the Phase-2 internal payout engine (spec 2026-08-02):

  * payouts.basis — :payments (legacy: claims Payment rows) vs :allocations
    (internal: claims PaymentSplit rows). Default keeps every existing payout.
  * supplier_ledger_entries.settlement_source + payment_split_id — lets a
    wholesaler obligation be claimed by the platform settlement instead of
    the manual "mark paid" flow, so the same debt never exists twice.

  Hand-written: mix ash.codegen is unusable in this repo.
  """
  use Ecto.Migration

  def change do
    alter table(:payouts) do
      add(:basis, :text, null: false, default: "payments")
    end

    alter table(:supplier_ledger_entries) do
      add(:settlement_source, :text, null: false, default: "manual")
      add(:payment_split_id, :uuid)
    end
  end
end
