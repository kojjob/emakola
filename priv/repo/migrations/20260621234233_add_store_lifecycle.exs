defmodule Emakola.Repo.Migrations.AddStoreLifecycle do
  @moduledoc """
  Adds the platform-owned store lifecycle: a `status` enum
  (active/suspended/blocked/archived) plus `status_reason` and
  `status_changed_at`. The NOT NULL `default("active")` backfills existing
  rows. Indexed because every public directory read and the storefront
  resolver filter on `status`.
  """

  use Ecto.Migration

  def up do
    alter table(:stores) do
      add :status, :text, null: false, default: "active"
      add :status_reason, :text
      add :status_changed_at, :utc_datetime_usec
    end

    create index(:stores, [:status])
  end

  def down do
    drop_if_exists index(:stores, [:status])

    alter table(:stores) do
      remove :status_changed_at
      remove :status_reason
      remove :status
    end
  end
end
