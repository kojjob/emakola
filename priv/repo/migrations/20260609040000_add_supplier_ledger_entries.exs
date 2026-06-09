defmodule Emakola.Repo.Migrations.AddSupplierLedgerEntries do
  @moduledoc """
  Phase 4 of the dropshipping feature.

  Creates the `supplier_ledger_entries` table — the payout ledger recording
  what a store owes each supplier for a dropship fulfillment. One entry per
  fulfillment (enforced by a unique index); entries start `owed` and move to
  `paid` once the merchant settles. Financial records, never destroyed.
  """
  use Ecto.Migration

  def change do
    create table(:supplier_ledger_entries, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :store_id,
          references(:stores, type: :uuid, on_delete: :delete_all),
          null: false

      add :supplier_id,
          references(:suppliers, type: :uuid, on_delete: :delete_all),
          null: false

      add :fulfillment_id,
          references(:fulfillments, type: :uuid, on_delete: :delete_all),
          null: false

      add :amount_owed, :integer, null: false
      add :status, :string, null: false, default: "owed"
      add :paid_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:supplier_ledger_entries, [:fulfillment_id],
             name: "supplier_ledger_entries_unique_fulfillment_ledger_index"
           )

    create index(:supplier_ledger_entries, [:supplier_id])
    create index(:supplier_ledger_entries, [:store_id])
  end
end
