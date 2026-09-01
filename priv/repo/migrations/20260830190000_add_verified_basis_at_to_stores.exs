defmodule Emakola.Repo.Migrations.AddVerifiedBasisAtToStores do
  @moduledoc """
  Dates a store's trust basis so it can lapse.

  Approvals under the retired Ghana Card flow rest on a check L.I. 2523 has
  made an offence to repeat. Without a timestamp they would stand forever on
  evidence nobody can refresh.

  Backfilled to `now()` rather than to the original approval date on purpose:
  merchants keep the badge they have today and get the full grace window from
  the day this ships, instead of losing it retroactively for an approval that
  was lawful when it was made.

  Hand-written: `mix ash.codegen` sweeps unrelated stale snapshots here.
  """

  use Ecto.Migration

  def up do
    alter table(:stores) do
      add :verified_basis_at, :utc_datetime_usec
    end

    execute """
    UPDATE stores
    SET verified_basis_at = (now() AT TIME ZONE 'utc')
    WHERE verified = true AND verified_basis IS NOT NULL AND verified_basis_at IS NULL
    """
  end

  def down do
    alter table(:stores) do
      remove :verified_basis_at
    end
  end
end
