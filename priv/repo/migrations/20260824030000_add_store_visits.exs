defmodule Emakola.Repo.Migrations.AddStoreVisits do
  @moduledoc """
  Storefront traffic, so reports can carry an honest conversion rate again.

  Hand-written and deliberately narrow. No IP, no user-agent: counting visitors
  does not require identifying them.
  """

  use Ecto.Migration

  def up do
    create table(:store_visits, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)

      add(
        :store_id,
        references(:stores, column: :id, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:visitor_hash, :text, null: false)
      add(:source, :text, null: false, default: "direct")
      add(:occurred_at, :utc_datetime_usec, null: false)
      add(:inserted_at, :utc_datetime_usec, null: false, default: fragment("now()"))
    end

    # Every read is "this store, this window", so the composite order matters
    # more than two separate indexes would.
    create(index(:store_visits, [:store_id, :occurred_at]))

    # Distinct-visitor counts group on the hash within that same window.
    create(index(:store_visits, [:store_id, :visitor_hash, :occurred_at]))
  end

  def down do
    drop(table(:store_visits))
  end
end
