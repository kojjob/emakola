defmodule Emakola.Repo.Migrations.AddPayoutsStoreIdIndex do
  @moduledoc """
  `payouts` only indexed `transfer_reference` — every per-store payout lookup
  (finance page, payout history) filtered on an unindexed `store_id`. One row
  per approval, so a plain (non-concurrent) index is fine.
  """
  use Ecto.Migration

  def change do
    create index(:payouts, [:store_id])
  end
end
