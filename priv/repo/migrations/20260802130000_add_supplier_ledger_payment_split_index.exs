defmodule Emakola.Repo.Migrations.AddSupplierLedgerPaymentSplitIndex do
  @moduledoc """
  Indexes supplier_ledger_entries.payment_split_id.

  This column (added in AddPayoutBasisAndSupplierLedgerSettlementSource)
  became a webhook-path query key in Phase 2: `by_payment_split` looks up a
  ledger entry by its claiming split on every settlement webhook, and that
  scan was unindexed.

  Hand-written: mix ash.codegen is unusable in this repo.
  """
  use Ecto.Migration

  def change do
    create(index(:supplier_ledger_entries, [:payment_split_id]))
  end
end
