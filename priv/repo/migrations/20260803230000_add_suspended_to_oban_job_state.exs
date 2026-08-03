defmodule Emakola.Repo.Migrations.AddSuspendedToObanJobState do
  @moduledoc """
  Adds the `suspended` value to `oban_job_state` on databases that predate it.

  Databases created before the Oban v14 schema (and upgraded via a versioned
  `Oban.Migrations.up/1` that considered itself already current) can carry an
  enum without `suspended` while `schema_migrations` claims v14 ran. Any
  `unique: [states: :incomplete]` insert then fails with
  `invalid input value for enum oban_job_state: "suspended"` — silently, if the
  caller rescues. `SupplierStockSyncWorker` uses that group deliberately (its
  states must exclude `:completed`), so the value has to exist.

  `ADD VALUE IF NOT EXISTS` is a no-op where it already exists, and cannot run
  inside a transaction — hence `@disable_ddl_transaction`.
  """
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    execute("ALTER TYPE oban_job_state ADD VALUE IF NOT EXISTS 'suspended' BEFORE 'scheduled'")
  end

  # Postgres cannot drop a value from an enum type.
  def down, do: :ok
end
