defmodule Emakola.Repo.Migrations.AddStoreIdToCartItems do
  @moduledoc """
  Scopes session carts by store so a single browser session keeps a separate
  cart per store it visits (the multi-tenant pattern every other resource
  already follows). Previously carts were keyed by `session_id` alone, so
  items added across different storefronts merged into one shared cart.

  The unique key moves from `(session_id, variant_id)` to
  `(session_id, store_id, variant_id)`, which `CartStore.add_item/3`'s upsert
  relies on. Existing rows predate per-store scoping and can't be assigned a
  store, so they are cleared — cart contents are ephemeral session data.
  """
  use Ecto.Migration

  def up do
    execute("DELETE FROM cart_items")

    alter table(:cart_items) do
      add :store_id, :uuid, null: false
    end

    drop unique_index(:cart_items, [:session_id, :variant_id])
    create unique_index(:cart_items, [:session_id, :store_id, :variant_id])
  end

  def down do
    execute("DELETE FROM cart_items")

    drop unique_index(:cart_items, [:session_id, :store_id, :variant_id])

    alter table(:cart_items) do
      remove :store_id
    end

    create unique_index(:cart_items, [:session_id, :variant_id])
  end
end
