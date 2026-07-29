defmodule Emakola.Repo.Migrations.AddMerchantSessionsValidFrom do
  @moduledoc """
  Adds `merchants.sessions_valid_from` — the cutoff that invalidates browser
  session tokens issued before it (see `Emakola.Accounts.revoke_all_sessions_for/1`).

  Hand-written: `mix ash.codegen` is unusable in this repo (it aborts on the
  pre-existing `:unique_payment` identity, which needs an
  `identity_wheres_to_sql` entry). Same recovery pattern as the neighbouring
  migrations.

  Nullable with no default on purpose: NULL means "no reset has happened, every
  existing session stays valid", so deploying this does not sign anyone out.
  """

  use Ecto.Migration

  def up do
    alter table(:merchants) do
      add :sessions_valid_from, :utc_datetime
    end
  end

  def down do
    alter table(:merchants) do
      remove :sessions_valid_from
    end
  end
end
