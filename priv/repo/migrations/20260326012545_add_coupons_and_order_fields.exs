defmodule Emakola.Repo.Migrations.AddCouponsAndOrderFields do
  use Ecto.Migration

  def change do
    create table(:coupons, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :code, :string, null: false
      add :description, :string
      add :discount_type, :string, null: false
      add :discount_value, :integer, default: 0
      add :max_discount_amount, :integer
      add :minimum_order_amount, :integer
      add :max_uses, :integer
      add :uses_count, :integer, default: 0, null: false
      add :starts_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :active, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:coupons, [:store_id, :code])
    create index(:coupons, [:store_id])

    alter table(:orders) do
      add :coupon_id, references(:coupons, type: :uuid, on_delete: :nilify_all)
      add :delivery_fee, :integer, default: 0
      add :discount_amount, :integer, default: 0
    end
  end
end
