defmodule Emakola.Repo.Migrations.AddPaymentSplitProtectedDispatchFee do
  @moduledoc """
  Hand-written: `mix ash.codegen` is unusable in this repo — it bundles
  unrelated snapshot drift for dozens of resources whose
  `priv/resource_snapshots` have never been fully tracked (see the earlier
  migrations tagged the same way, most recently
  `20260724220952_add_return_refund_dispatch_fee`). This is the single
  additive hunk that generation would have produced for `payment_splits`.

  Records the dispatch fee withheld from a split's reversible refund base,
  frozen at the first reversal so later refund events cannot re-derive it
  from fulfillment/return state that has since moved.

  Additive, defaulted and nullable-free, so it is safe on a live table and
  reversible.
  """

  use Ecto.Migration

  def up do
    alter table(:payment_splits) do
      add :protected_dispatch_fee, :bigint, null: false, default: 0
    end
  end

  def down do
    alter table(:payment_splits) do
      remove :protected_dispatch_fee
    end
  end
end
