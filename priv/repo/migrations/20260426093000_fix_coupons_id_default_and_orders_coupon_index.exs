defmodule Emakola.Repo.Migrations.FixCouponsIdDefaultAndOrdersCouponIndex do
  @moduledoc """
  Two corrections to the coupon-related schema:

  1. `coupons.id` had no `DEFAULT gen_random_uuid()` (the original
     migration `20260326012545_add_coupons_and_order_fields.exs` declared
     `add :id, :uuid, primary_key: true` without a default). All other
     UUID PKs in the schema use `gen_random_uuid()`. Without the
     default, raw SQL inserts (or any path that doesn't go through Ash)
     would fail with `null value in column "id"`.

  2. `orders.coupon_id` is a foreign key (`references(:coupons, ...)`)
     but had no index. Postgres does not auto-index FKs; lookups by
     coupon and the cascade on `nilify_all` both scan the full
     `orders` table. As order volume grows, every coupon delete or
     coupon-filtered query gets slower.

  Both fixes are forward-only — the historical migration is already
  in production, we don't rewrite it.
  """

  use Ecto.Migration

  def up do
    execute("ALTER TABLE coupons ALTER COLUMN id SET DEFAULT gen_random_uuid()")
    create_if_not_exists index(:orders, [:coupon_id])
  end

  def down do
    drop_if_exists index(:orders, [:coupon_id])
    execute("ALTER TABLE coupons ALTER COLUMN id DROP DEFAULT")
  end
end
