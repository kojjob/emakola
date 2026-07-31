defmodule Emakola.Repo.Migrations.AddSusuPlanIdIndexToOrders do
  @moduledoc """
  Adds the index that was never created for `orders.susu_plan_id` (the
  column itself was added in 20260731114148_add_susu_plans.exs) —
  flagged unindexed in TC-3's final review, AND the only thing preventing
  two concurrent completions of the same plan from creating two orders was
  the application-level `FOR UPDATE` plan lock + `existing_order/1` read in
  `Emakola.Orders.SusuCompletion.complete/1` — no DB-level constraint
  backed it up.

  UNIQUE + partial (`WHERE susu_plan_id IS NOT NULL`) rather than a plain
  index — mirrors `20260711160212_add_unique_open_credit_agreement_index.exs`'s
  "unique among a filtered subset" precedent, gives `existing_order/1`'s
  hot-path lookup a real index, AND makes "one order per plan" a
  database-enforced guarantee rather than relying solely on the plan-row
  lock.

  Hand-written: `mix ash_postgres.generate_migrations` is unusable in this
  repo (see prior migrations' identical note, e.g.
  20260730150000_add_pay_link_id_index_to_orders.exs).
  """

  use Ecto.Migration

  def up do
    create(
      unique_index(:orders, [:susu_plan_id],
        where: "susu_plan_id IS NOT NULL",
        name: :orders_susu_plan_id_index
      )
    )
  end

  def down do
    drop_if_exists index(:orders, [:susu_plan_id], name: :orders_susu_plan_id_index)
  end
end
