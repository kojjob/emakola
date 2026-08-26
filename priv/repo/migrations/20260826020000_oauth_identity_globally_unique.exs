defmodule Emakola.Repo.Migrations.OauthIdentityGloballyUnique do
  @moduledoc """
  GHSA-777c-2fxx-qr28 — a provider account may belong to only one merchant.

  The old index was unique on `(user_id, uid, strategy)`: unique only *within* a
  user, so the same Google account could be linked to several merchants. That is
  the account-takeover primitive the advisory describes, and ash_authentication
  4.14 drops `user_id` from the identity to close it.

  Safe to run: social login has never been enabled in production
  (no GOOGLE_/FACEBOOK_/APPLE_ secrets are set), so merchant_identities is
  empty and there are no duplicates to reconcile. Were there any, this would
  fail loudly rather than silently keep the weaker constraint — which is the
  behaviour we want from a security migration.
  """
  use Ecto.Migration

  def up do
    # Drop BY NAME. The index carries a pinned name (Postgres caps identifiers
    # at 63 chars and the extension's derived one is longer), so dropping by
    # column list targets a name that does not exist and silently no-ops.
    drop_if_exists(
      index(:merchant_identities, [:user_id, :uid, :strategy],
        name: "merchant_identities_uid_strategy_index"
      )
    )

    create(
      unique_index(:merchant_identities, [:strategy, :uid],
        name: "merchant_identities_uid_strategy_index"
      )
    )
  end

  def down do
    drop_if_exists(
      index(:merchant_identities, [:strategy, :uid],
        name: "merchant_identities_uid_strategy_index"
      )
    )

    create(
      unique_index(:merchant_identities, [:user_id, :uid, :strategy],
        name: "merchant_identities_uid_strategy_index"
      )
    )
  end
end
