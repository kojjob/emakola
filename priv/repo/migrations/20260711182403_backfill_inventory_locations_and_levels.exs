defmodule Emakola.Repo.Migrations.BackfillInventoryLocationsAndLevels do
  @moduledoc """
  Seeds every existing store with a default "Main" location and every
  tracked variant with one stock level equal to its current
  `stock_quantity`, so the total==sum(levels) invariant holds from the
  first multi-location write. Stores/variants created afterwards are
  covered by the context's lazy seeding.
  """

  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO inventory_locations (id, store_id, name, "default", active, inserted_at, updated_at)
    SELECT gen_random_uuid(), s.id, 'Main', true, true, now(), now()
    FROM stores s
    WHERE NOT EXISTS (
      SELECT 1 FROM inventory_locations l WHERE l.store_id = s.id AND l."default" = true
    )
    """)

    execute("""
    INSERT INTO stock_levels (id, store_id, variant_id, location_id, quantity, inserted_at, updated_at)
    SELECT gen_random_uuid(), v.store_id, v.id, l.id, GREATEST(v.stock_quantity, 0), now(), now()
    FROM variants v
    JOIN inventory_locations l ON l.store_id = v.store_id AND l."default" = true
    WHERE v.track_inventory = true
      AND NOT EXISTS (
        SELECT 1 FROM stock_levels sl WHERE sl.variant_id = v.id AND sl.location_id = l.id
      )
    """)
  end

  def down do
    # Data-only backfill; the table-creating migrations' downs remove the
    # rows with the tables. Deleting here keeps a standalone rollback clean.
    execute("DELETE FROM stock_levels")
    execute("DELETE FROM inventory_locations")
  end
end
