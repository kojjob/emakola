defmodule Emakola.Customers.CustomerIdentity do
  @moduledoc """
  Links a per-store `Customer` to the social accounts they sign in with.

  ## Why this is per-store and `MerchantIdentity` is not

  A merchant identity is unique on `(strategy, uid)` platform-wide: one Google
  account, one Makola merchant, which is what GHSA-777c-2fxx-qr28 is about.

  A shopper is the opposite. The same person signing in with the same Google
  account at *Kente Kingdom* and at *Accra Fresh* is two different customers —
  separate carts, separate orders, separate stores. A global unique index would
  make the second shop's sign-in collide with the first.

  Ash resolves this: an identity on a multitenant resource defaults to
  `all_tenants?: false`, so the extension's `(uid, strategy)` identity becomes
  `(store_id, uid, strategy)` in the generated index. The tenant is threaded
  through by `AshAuthentication.UserIdentity.Actions.upsert/3`, which passes
  `tenant:` from the calling changeset.

  ## What storing this buys

  Matching a returning shopper by email alone is the unsafe pattern the advisory
  describes — an email is not a stable identifier and providers let people change
  theirs. `iss`/`sub` is stable, so this is what lets a customer keep their
  account across an email change, and link more than one provider later.
  """
  use Ash.Resource,
    domain: Emakola.Customers,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.UserIdentity]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("customer_identities")
    repo(Emakola.Repo)

    # Pinned: the extension's derived name exceeds Postgres's 63-char cap.
    # Mirrored in the migration.
    identity_index_names(unique_on_strategy_and_uid: "customer_identities_uid_strategy_index")

    references do
      reference(:user, on_delete: :delete)
    end
  end

  user_identity do
    user_resource(Emakola.Customers.Customer)
  end

  attributes do
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
  end
end
