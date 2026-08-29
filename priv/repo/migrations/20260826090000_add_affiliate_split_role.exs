defmodule Emakola.Repo.Migrations.AddAffiliateSplitRole do
  @moduledoc """
  Lets a payment split pay an affiliate.

  The `role` column is plain text with no check constraint, so adding
  `:affiliate` to the resource's `one_of` needed no migration. `affiliate_id`
  does: it joins the `unique_allocation` discriminators, and without it two
  affiliates on one payment would collide and the second would be silently
  dropped instead of paid.

  Hand-written like the other affiliate migrations — `mix ash.codegen` emits
  `create table` for the 38 resources here that have no committed snapshot.
  """

  use Ecto.Migration

  def up do
    alter table(:payment_splits) do
      add(:affiliate_id, references(:affiliates, column: :id, type: :uuid, on_delete: :restrict))
    end

    # Rebuilt to include affiliate_id. NULLS NOT DISTINCT so the existing
    # roles keep colliding on their own discriminators exactly as before —
    # nils_distinct?(false) on the resource side.
    drop_if_exists(
      unique_index(
        :payment_splits,
        [:payment_id, :role, :supplier_id, :credit_agreement_id],
        name: "payment_splits_unique_allocation_index"
      )
    )

    create(
      unique_index(
        :payment_splits,
        [:payment_id, :role, :supplier_id, :credit_agreement_id, :affiliate_id],
        name: "payment_splits_unique_allocation_index",
        nulls_distinct: false
      )
    )

    # Every affiliate earnings read filters on this.
    create(index(:payment_splits, [:affiliate_id]))
  end

  def down do
    drop_if_exists(
      unique_index(
        :payment_splits,
        [:payment_id, :role, :supplier_id, :credit_agreement_id, :affiliate_id],
        name: "payment_splits_unique_allocation_index"
      )
    )

    alter table(:payment_splits) do
      remove(:affiliate_id)
    end

    create(
      unique_index(
        :payment_splits,
        [:payment_id, :role, :supplier_id, :credit_agreement_id],
        name: "payment_splits_unique_allocation_index",
        nulls_distinct: false
      )
    )
  end
end
