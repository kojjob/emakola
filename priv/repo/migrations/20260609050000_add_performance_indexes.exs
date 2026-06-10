defmodule Emakola.Repo.Migrations.AddPerformanceIndexes do
  @moduledoc """
  Adds composite indexes identified in the performance audit:

  - `fulfillments (store_id, status)` — covers admin queries filtering pending
    / shipped fulfillments for a store.
  - `digital_files (product_id, is_preview)` — covers list_paid_files/2 in the
    digital download pipeline which filters `WHERE product_id = $1 AND is_preview = false`.
  - `posts (store_id, status, type)` — covers list_published which filters on
    `status = 'published' AND store_id = $1 AND type = $2`. The composite
    eliminates a multi-index merge scan.

  All three use `concurrently: true` so they can be applied to tables with
  existing data without locking. `@disable_ddl_transaction` and
  `@disable_migration_lock` are required by Postgres for concurrent builds.
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(index(:fulfillments, [:store_id, :status], concurrently: true))

    create_if_not_exists(index(:digital_files, [:product_id, :is_preview], concurrently: true))

    create_if_not_exists(index(:posts, [:store_id, :status, :type], concurrently: true))
  end
end
