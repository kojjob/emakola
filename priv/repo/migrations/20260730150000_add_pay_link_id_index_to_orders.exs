defmodule Emakola.Repo.Migrations.AddPayLinkIdIndexToOrders do
  @moduledoc """
  Plain index on `orders.pay_link_id`, backing the new `paid_orders_count`
  aggregate on `Emakola.Orders.PayLink` (counts orders filtered by
  `pay_link_id`) — flagged unindexed in Task 3's review.

  Hand-written: `mix ash_postgres.generate_migrations` is unusable in this
  repo (crashes on an unrelated `PreorderDeposit` identity while
  snapshotting the whole app), same as prior single-column/index additions
  (see 20260730132507_add_pay_link_claimed_order_id.exs).
  """

  use Ecto.Migration

  def up do
    create index(:orders, [:pay_link_id])
  end

  def down do
    drop_if_exists index(:orders, [:pay_link_id])
  end
end
