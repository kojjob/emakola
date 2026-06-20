defmodule Emakola.Accounts.MerchantIdentity do
  @moduledoc """
  Links a `Merchant` to one or more external OAuth identities (Google,
  Facebook, Apple), enabling social login and multiple providers per merchant.

  The schema (uid / strategy / user_id / tokens + the `[user_id, uid, strategy]`
  unique identity) is managed entirely by the `AshAuthentication.UserIdentity`
  extension; see `priv/repo/migrations/*_create_merchant_identities.exs`.
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
    identity_index_names(
      unique_on_strategy_and_uid_and_user_id: "merchant_identities_uid_strategy_index"
    )
  end

  user_identity do
    user_resource(Emakola.Accounts.Merchant)
  end
end
