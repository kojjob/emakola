defmodule Emakola.Cart.CartItem do
  @moduledoc """
  Ecto schema for a single session cart line (`cart_items` table).

  This is deliberately a plain Ecto schema, not an Ash resource: carts are
  ephemeral, session-keyed infrastructure (the Postgres replacement for the
  old `:cart_store` ETS table), not tenant domain data. They carry no
  authorization policies and are only ever accessed through
  `Emakola.Cart.CartStore`.

  Carts are scoped by `store_id` as well as `session_id`: one browser session
  keeps a separate cart per store it visits, so items added across different
  storefronts never merge.

  One row per `(session_id, store_id, variant_id)` — enforced by a unique index
  and relied on by `CartStore.add_item/3`'s upsert. Snapshot fields
  (`product_title`, `unit_price`, ...) are denormalized copies taken at
  add-to-cart time. There is intentionally no foreign key on `variant_id`
  (carts may briefly reference deleted variants, matching ETS semantics).
  """
  use Ecto.Schema

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "cart_items" do
    field :session_id, :string
    field :store_id, Ecto.UUID
    field :variant_id, Ecto.UUID
    field :quantity, :integer, default: 1
    field :product_title, :string
    field :variant_info, :string
    field :unit_price, :integer
    field :sku, :string
    field :image_url, :string

    timestamps(type: :utc_datetime_usec)
  end
end
