defmodule Emakola.Accounts.MerchantIdentity do
  @moduledoc """
  Links a `Merchant` to one or more external OAuth identities (Google,
  Facebook, Apple), enabling social login and multiple providers per merchant.

  The schema (uid / strategy / user_id / tokens) is managed entirely by the
  `AshAuthentication.UserIdentity` extension; see
  `priv/repo/migrations/*_create_merchant_identities.exs`.

  ## Why `(strategy, uid)` and not `(user_id, uid, strategy)`

  The old constraint was unique only *within* a user, so one Google account
  could be attached to several merchants — the account-takeover primitive
  behind GHSA-777c-2fxx-qr28. ash_authentication 4.14 drops `user_id` from the
  identity so a provider account belongs to exactly one merchant platform-wide.
  """
  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.UserIdentity]

  postgres do
    table("merchant_identities")
    repo(Emakola.Repo)

    # The extension's identity name is long; Postgres caps identifiers at 63
    # chars, so pin a short index name and mirror it in the migration.
    identity_index_names(unique_on_strategy_and_uid: "merchant_identities_uid_strategy_index")
  end

  user_identity do
    user_resource(Emakola.Accounts.Merchant)
  end
end
