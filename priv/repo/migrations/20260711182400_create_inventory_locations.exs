defmodule Emakola.Repo.Migrations.CreateInventoryLocations do
  @moduledoc """
  Physical stock locations per store (shop, market stall, warehouse).
  Exactly one default per store — enforced by a partial unique index.
  """

  use Ecto.Migration

  def change do
    create table(:inventory_locations, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :store_id,
        references(:stores, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:name, :text, null: false)
      add(:default, :boolean, null: false, default: false)
      add(:active, :boolean, null: false, default: true)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:inventory_locations, [:store_id, :name]))

    create(
      unique_index(:inventory_locations, [:store_id],
        where: "\"default\" = true",
        name: :inventory_locations_one_default_per_store_index
      )
    )
  end
end
