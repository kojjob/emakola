defmodule Emakola.Repo.Migrations.AddPhoneVerifiedAtToMerchants do
  @moduledoc """
  Records when a merchant's phone was proven by a one-time code.

  PhoneAuth already proved phones, but the result lived only as an ephemeral
  socket assign — nothing durable said "this number was answered". Backfills
  merchants who registered through the phone flow, which is OTP-gated by
  definition.

  Hand-written: `mix ash.codegen` sweeps unrelated stale snapshots here.
  """

  use Ecto.Migration

  def up do
    alter table(:merchants) do
      add :phone_verified_at, :utc_datetime_usec
    end

    # A merchant with a phone and a confirmation stamp reached it through the
    # OTP registration path; nothing else sets both.
    execute """
    UPDATE merchants
    SET phone_verified_at = confirmed_at
    WHERE phone IS NOT NULL AND confirmed_at IS NOT NULL AND hashed_password IS NULL
    """
  end

  def down do
    alter table(:merchants) do
      remove :phone_verified_at
    end
  end
end
