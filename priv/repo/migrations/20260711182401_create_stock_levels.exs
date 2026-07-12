defmodule Emakola.Repo.Migrations.CreateStockLevels do
  @moduledoc """
  Per-location stock for a variant. The variant's `stock_quantity` remains
  the denormalized total; the Inventory context keeps them equal in one
  transaction. Same non-negative CHECK discipline as `variants`.
  """

  use Ecto.Migration

  def up do
    create table(:stock_levels, primary_key: false) do
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

      add(:quantity, :bigint, null: false, default: 0)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:stock_levels, [:variant_id, :location_id]))
    create(index(:stock_levels, [:store_id]))
    create(index(:stock_levels, [:location_id]))

    execute("""
    ALTER TABLE stock_levels ADD CONSTRAINT stock_level_non_negative CHECK (quantity >= 0)
    """)
  end

  def down do
    drop(table(:stock_levels))
  end
end
