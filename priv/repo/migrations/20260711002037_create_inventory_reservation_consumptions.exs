defmodule Emakola.Repo.Migrations.CreateInventoryReservationConsumptions do
  use Ecto.Migration

  def change do
    create table(:earn_inventory_reservation_consumptions, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :reservation_id,
          references(:earn_inventory_reservations, type: :uuid, on_delete: :restrict), null: false

      add :order_id, references(:orders, type: :uuid, on_delete: :restrict), null: false
      add :line_item_id, references(:line_items, type: :uuid, on_delete: :restrict), null: false
      add :quantity, :integer, null: false
      add :consumed_at, :utc_datetime_usec, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :earn_inventory_reservation_consumptions,
             [:reservation_id, :line_item_id],
             name: :inv_res_consumption_res_line_idx
           )

    create index(:earn_inventory_reservation_consumptions, [:order_id])

    create constraint(
             :earn_inventory_reservation_consumptions,
             :reservation_consumption_quantity_valid,
             check: "quantity > 0"
           )
  end
end
