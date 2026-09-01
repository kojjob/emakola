defmodule Emakola.Repo.Migrations.AddDeliveryZoneFallback do
  @moduledoc """
  One delivery zone per store may be the catch-all for regions no other
  zone names. The partial unique index keeps it to one even under
  concurrent saves.
  """

  use Ecto.Migration

  def up do
    alter table(:delivery_zones) do
      add :fallback, :boolean, null: false, default: false
    end

    create unique_index(:delivery_zones, [:store_id],
             where: "fallback = true",
             name: "delivery_zones_one_catch_all_per_store_index"
           )
  end

  def down do
    drop_if_exists unique_index(:delivery_zones, [:store_id],
                     name: "delivery_zones_one_catch_all_per_store_index"
                   )

    alter table(:delivery_zones) do
      remove :fallback
    end
  end
end
