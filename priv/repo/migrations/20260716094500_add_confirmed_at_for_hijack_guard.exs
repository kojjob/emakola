defmodule Emakola.Repo.Migrations.AddConfirmedAtForHijackGuard do
  @moduledoc """
  confirmed_at on merchants and customers, for the confirmation add-on that
  arms prevent_hijacking? on the OAuth strategies.

  merchants.confirmed_at already exists (created with the accounts table in
  20260319171152, unused until now), so both ADDs are IF NOT EXISTS.

  EXISTING accounts are backfilled as confirmed (confirmed_at = inserted_at):
  they predate the confirmation flow and have been operating normally — prod
  has real merchants — and leaving them unconfirmed would silently block them
  from ever linking a social login. Grandfathering is the correct default;
  the guard's job is to protect accounts created AFTER an attacker could
  register someone else's email.

  Hand-written: `mix ash.codegen` is unusable in this repo (snapshot drift).
  """
  use Ecto.Migration

  def up do
    execute("ALTER TABLE merchants ADD COLUMN IF NOT EXISTS confirmed_at timestamp")
    execute("ALTER TABLE customers ADD COLUMN IF NOT EXISTS confirmed_at timestamp")

    execute("UPDATE merchants SET confirmed_at = inserted_at WHERE confirmed_at IS NULL")
    execute("UPDATE customers SET confirmed_at = inserted_at WHERE confirmed_at IS NULL")
  end

  def down do
    # merchants.confirmed_at predates this migration (20260319171152); only
    # the customers column is ours to remove.
    execute("ALTER TABLE customers DROP COLUMN IF EXISTS confirmed_at")
    execute("UPDATE merchants SET confirmed_at = NULL")
  end
end
