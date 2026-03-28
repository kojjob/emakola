defmodule Emakola.Repo.Migrations.CreateReturns do
  use Ecto.Migration

  def change do
    create table(:returns, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :order_id, references(:orders, type: :uuid, on_delete: :delete_all), null: false
      add :customer_id, references(:customers, type: :uuid, on_delete: :nilify_all)
      add :status, :string, null: false, default: "requested"
      add :reason, :string, null: false
      add :reason_detail, :string
      add :admin_notes, :string
      add :refund_amount, :integer
      add :currency, :string, null: false, default: "GHS"

      timestamps()
    end

    create unique_index(:returns, [:order_id])
    create index(:returns, [:store_id])
    create index(:returns, [:store_id, :status])
  end
end
