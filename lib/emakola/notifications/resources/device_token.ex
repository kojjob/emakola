defmodule Emakola.Notifications.DeviceToken do
  @moduledoc """
  FCM registration token for a merchant's mobile device. One row per device
  token; re-registration upserts (devices are shared and change owners).
  Flutter's firebase_messaging issues FCM tokens on both Android and iOS,
  so this is FCM-only — `platform` is informational.

  Tokens migrate across stores: `store_id` is included in `upsert_fields` and
  the `unique_token` identity is scoped `all_tenants?: true`, so a device token
  can be re-claimed by whichever merchant last registers it, even across stores.
  """

  use Ash.Resource,
    domain: Emakola.Notifications,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("device_tokens")
    repo(Emakola.Repo)

    custom_indexes do
      index([:merchant_id])
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  json_api do
    type("device_token")

    routes do
      base("/device_tokens")

      post(:register)
      delete(:destroy)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
    end

    attribute :platform, :atom do
      constraints(one_of: [:android, :ios])
      allow_nil?(false)
      public?(true)
    end

    attribute :token, :string do
      allow_nil?(false)
      sensitive?(true)
      constraints(max_length: 4096)
    end

    attribute(:last_seen_at, :utc_datetime_usec, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :merchant, Emakola.Accounts.Merchant do
      allow_nil?(false)
    end
  end

  identities do
    identity(:unique_token, [:token], all_tenants?: true)
  end

  policies do
    # Merchant actors with membership in the tenant store may register/read.
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Destroy additionally requires owning the token row.
    policy action_type(:destroy) do
      authorize_if(expr(merchant_id == ^actor(:id)))
    end
  end

  actions do
    defaults([:read])

    create :register do
      accept([:platform])

      # The token remains a public action input for the mobile JSON:API, but is
      # private on the resource so create responses and generic projections do
      # not echo a durable push credential back to clients.
      argument :token, :string do
        allow_nil?(false)
        sensitive?(true)
        constraints(max_length: 4096)
      end

      upsert?(true)
      upsert_identity(:unique_token)
      upsert_fields([:merchant_id, :platform, :last_seen_at, :store_id])

      change(set_attribute(:token, arg(:token)))
      change(relate_actor(:merchant))
      change(set_attribute(:last_seen_at, &DateTime.utc_now/0))
    end

    destroy :destroy do
      primary?(true)
      require_atomic?(false)
    end

    read :for_store do
      description("""
      All device tokens for a store — used by the push worker (authorize?: false).

      CALLERS MUST pass a tenant (Ash.Query.set_tenant/2 or the :tenant option).
      With global?(true), an authorize?: false read without a tenant returns
      every store's tokens across all tenants, which is never the intent here.
      """)
    end
  end
end
