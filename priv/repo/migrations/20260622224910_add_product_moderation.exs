defmodule Emakola.Repo.Migrations.AddProductModeration do
  @moduledoc """
  Platform content-moderation fields on products: `moderation_status`
  (ok/taken_down), `moderation_reason`, `moderation_at`. The NOT NULL default
  `ok` backfills existing rows. Indexed because every storefront product read
  now filters on it.
  """

  use Ecto.Migration

  def up do
    alter table(:products) do
      add :moderation_status, :text, null: false, default: "ok"
      add :moderation_reason, :text
      add :moderation_at, :utc_datetime_usec
    end

    create index(:products, [:moderation_status])
  end

  def down do
    drop_if_exists index(:products, [:moderation_status])

    alter table(:products) do
      remove :moderation_at
      remove :moderation_reason
      remove :moderation_status
    end
  end
end
