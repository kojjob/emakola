defmodule Emakola.Repo.Migrations.CreateWishlistItems do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:wishlist_items, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :customer_id, references(:customers, type: :uuid, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :uuid, on_delete: :delete_all), null: false
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:wishlist_items, [:customer_id, :product_id, :store_id])
    create index(:wishlist_items, [:customer_id, :store_id])
    create index(:wishlist_items, [:product_id])
  end
end
