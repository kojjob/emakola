defmodule Emakola.Repo.Migrations.CreateReviews do
  use Ecto.Migration

  def change do
    create table(:reviews, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :uuid, on_delete: :delete_all), null: false
      add :customer_id, references(:customers, type: :uuid, on_delete: :delete_all), null: false
      add :order_id, references(:orders, type: :uuid, on_delete: :delete_all), null: false
      add :rating, :integer, null: false
      add :title, :string, size: 100
      add :body, :string, size: 2000, null: false
      add :status, :string, null: false, default: "published"
      add :verified_purchase, :boolean, null: false, default: true

      timestamps()
    end

    create unique_index(:reviews, [:store_id, :product_id, :customer_id])
    create index(:reviews, [:product_id, :status])
    create index(:reviews, [:store_id])
  end
end
