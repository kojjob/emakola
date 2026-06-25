defmodule Emakola.Repo.Migrations.AddPayoutTransferReferenceIndex do
  @moduledoc """
  Unique index on payouts.transfer_reference — the DB-level guarantee that one
  gateway transfer reference maps to at most one payout (defense for the
  no-double-pay invariant). Partial (non-null) so unset references don't collide.
  """
  use Ecto.Migration

  def up do
    create unique_index(:payouts, [:transfer_reference],
             where: "transfer_reference IS NOT NULL",
             name: :payouts_transfer_reference_index
           )
  end

  def down do
    drop_if_exists(
      index(:payouts, [:transfer_reference], name: :payouts_transfer_reference_index)
    )
  end
end
