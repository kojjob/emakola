defmodule Emakola.Repo.Migrations.CreateCartItems do
  @moduledoc """
  Moves session carts from node-local ETS to Postgres so the app can
  scale horizontally (any machine can serve any session).

  One row per (session_id, variant_id). Snapshot fields (title, price,
  sku, ...) are denormalized copies taken at add-to-cart time, exactly
  like the old ETS item maps.

  No foreign key on `variant_id` by design: carts may briefly reference
  variants that were deleted after being added, and the ETS store had no
  FK semantics — adding one would change observable behavior.
  """
  use Ecto.Migration

  def change do
    create table(:cart_items, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :session_id, :string, null: false
      add :variant_id, :uuid, null: false
      add :quantity, :integer, null: false, default: 1

      add :product_title, :string
      add :variant_info, :string
      add :unit_price, :integer
      add :sku, :string
      add :image_url, :text

      timestamps(type: :utc_datetime_usec)
    end

    # Also serves session lookups (leading column), so no separate
    # index(:cart_items, [:session_id]) is needed.
    create unique_index(:cart_items, [:session_id, :variant_id])

    # For the expiry cleanup scan (max(updated_at) per session).
    create index(:cart_items, [:updated_at])
  end
end
