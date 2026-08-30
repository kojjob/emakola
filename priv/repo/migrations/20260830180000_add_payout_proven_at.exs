defmodule Emakola.Repo.Migrations.AddPayoutProvenAt do
  @moduledoc """
  Records when a merchant proved they control their payout wallet by answering
  a one-time code sent to it.

  This is how Makola establishes identity now that L.I. 2523 has retired the
  Ghana Card flow: the telco already KYC'd the wallet against a Ghana Card, so
  proving control of the wallet inherits that verification.

  Deliberately separate from `verification_status`, which records only that the
  gateway accepted a subaccount.

  Hand-written: `mix ash.codegen` sweeps unrelated stale snapshots here.
  """

  use Ecto.Migration

  def up do
    alter table(:store_payout_accounts) do
      add :payout_proven_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:store_payout_accounts) do
      remove :payout_proven_at
    end
  end
end
