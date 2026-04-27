defmodule Emakola.Repo.Migrations.AddLineItemsStoreIdFk do
  @moduledoc """
  `line_items.store_id` is `not null` and indexed but has no FK constraint
  to `stores(id)` — meaning a store could be deleted while line items
  still reference it, leaving orphan rows that crash the order detail
  page when it tries to load the store.

  `line_items.order_id` and `line_items.variant_id` already have FK
  constraints (with `on_delete: :delete_all` and `on_delete: :nothing`
  respectively). This migration adds the missing one.

  Uses `validate: false` then `validate constraint` so the ALTER TABLE
  doesn't take an exclusive lock on `line_items` for the duration of
  the validation scan — important for production tables of any size.
  """
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Step 1: Add the constraint as `NOT VALID` — fast, only locks for
    # the metadata change. New writes are checked but existing rows
    # are not scanned.
    execute("""
    ALTER TABLE line_items
    ADD CONSTRAINT line_items_store_id_fkey
    FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE RESTRICT
    NOT VALID
    """)

    # Step 2: Validate existing rows in a separate statement that takes
    # only a SHARE UPDATE EXCLUSIVE lock (concurrent reads + writes
    # still work). If any orphan rows exist this will fail loudly.
    execute("ALTER TABLE line_items VALIDATE CONSTRAINT line_items_store_id_fkey")
  end

  def down do
    execute("ALTER TABLE line_items DROP CONSTRAINT IF EXISTS line_items_store_id_fkey")
  end
end
