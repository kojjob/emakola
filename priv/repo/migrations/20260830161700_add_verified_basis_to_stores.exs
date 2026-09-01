defmodule Emakola.Repo.Migrations.AddVerifiedBasisToStores do
  @moduledoc """
  Records what a store's trust badge actually rests on.

  Every store currently carrying `verified: true` earned it under the retired
  national-ID flow — a human looked at a Ghana Card image, which L.I. 2523 has
  since made an offence. Those merchants keep their badge (they did nothing
  wrong), but the basis is now stamped so the storefront can stop claiming the
  same thing about them as about a store that proved its payout wallet.

  Hand-written: `mix ash.codegen` sweeps unrelated stale snapshots here.
  """

  use Ecto.Migration

  def up do
    alter table(:stores) do
      add :verified_basis, :text
    end

    execute """
    UPDATE stores
    SET verified_basis = 'retired_document_flow'
    WHERE verified = true AND verified_basis IS NULL
    """
  end

  def down do
    alter table(:stores) do
      remove :verified_basis
    end
  end
end
