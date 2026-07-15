defmodule Emakola.Repo.Migrations.AddPaymentSplitUniqueAllocation do
  @moduledoc """
  One split per (payment, role, supplier, credit agreement).

  `record_splits!/2` had no idempotency key and the table no constraint, so a
  checkout retry after a partial failure could double-record an allocation —
  and every revenue number the platform reports is a sum over this table.

  NULLS NOT DISTINCT (PostgreSQL 15+; prod is 17, dev 16) because supplier_id
  and credit_agreement_id are nil for most roles: two `:platform` rows for the
  same payment must collide, and under default NULL semantics they would not.

  Hand-written: `mix ash.codegen` is unusable in this repo (missing resource
  snapshots make it emit create-table for ~20 existing tables). Index name
  matches the AshPostgres identity convention for `identity :unique_allocation`.
  """
  use Ecto.Migration

  def up do
    execute("""
    CREATE UNIQUE INDEX payment_splits_unique_allocation_index
    ON payment_splits (payment_id, role, supplier_id, credit_agreement_id)
    NULLS NOT DISTINCT
    """)
  end

  def down do
    execute("DROP INDEX payment_splits_unique_allocation_index")
  end
end
