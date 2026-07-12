defmodule Emakola.Repo.Migrations.CreateStockMovements do
  @moduledoc """
  Insert-only ledger of every stock change: the merchant's "why did stock
  change" answer, and the audit trail for multi-location transfers.
  """

  use Ecto.Migration

  def change do
    create table(:stock_movements, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :store_id,
        references(:stores, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :variant_id,
        references(:variants, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :location_id,
        references(:inventory_locations, type: :uuid, on_delete: :restrict),
        null: false
      )

      add(:delta, :bigint, null: false)
      add(:reason, :text, null: false)
      add(:order_id, :uuid)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:stock_movements, [:store_id, :variant_id, :inserted_at]))
    create(index(:stock_movements, [:order_id]))
  end
end
