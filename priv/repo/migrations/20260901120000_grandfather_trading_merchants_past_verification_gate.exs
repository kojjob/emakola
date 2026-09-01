defmodule Emakola.Repo.Migrations.GrandfatherTradingMerchantsPastVerificationGate do
  @moduledoc """
  Verifies merchants who were already trading, before the gate reaches them.

  Access is now gated on `confirmed_at`. Every merchant who signed up while
  production ran on a dead mail key has it nil, so the deploy that ships the
  gate would bounce them to /auth/verify and lock them out of their own shop.

  This runs in the release command — `fly.toml` calls `/app/bin/migrate`
  before the new version takes traffic — so the window between "gate is live"
  and "the people it should not apply to are exempt" is closed rather than
  merely short. Doing it by hand afterwards leaves every existing merchant
  locked out for as long as it takes somebody to remember.

  Same rule as `Emakola.Accounts.VerificationBackfill`, expressed in SQL
  because a migration cannot rely on the app being started: a merchant who
  belongs to a store holding a product or an order is grandfathered. A
  merchant with no store and no trade is left unverified — that is the
  junk-signup bucket the gate exists for.

  Idempotent by construction: it only touches rows where confirmed_at is null.
  """
  use Ecto.Migration

  def up do
    execute("""
    UPDATE merchants
       SET confirmed_at = NOW(), updated_at = NOW()
     WHERE confirmed_at IS NULL
       AND id IN (
         SELECT sm.merchant_id
           FROM store_memberships sm
          WHERE sm.store_id IN (SELECT DISTINCT store_id FROM products)
             OR sm.store_id IN (SELECT DISTINCT store_id FROM orders)
       )
    """)
  end

  def down do
    # Deliberately irreversible. Rolling back would un-verify merchants who may
    # since have verified for real, locking out people this migration was
    # written to protect.
    :ok
  end
end
