defmodule Emakola.Repo.Migrations.CreateCustomerFavoriteStores do
  @moduledoc """
  Creates `customer_favorite_stores` — the join row that records when a
  customer has favorited (♡) a store from the public /stores marketplace
  directory.

  Cross-tenant by design: a single customer record can favorite multiple
  stores, so this resource has no `store_id`-based multitenancy attribute
  on its row scope (the `store_id` column here is the *target* of the
  favorite, not a tenant scope).
  """
  use Ecto.Migration

  def change do
    create table(:customer_favorite_stores, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :customer_id, references(:customers, type: :uuid, on_delete: :delete_all), null: false
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:customer_favorite_stores, [:customer_id, :store_id])
    create index(:customer_favorite_stores, [:customer_id])
    create index(:customer_favorite_stores, [:store_id])
  end
end
