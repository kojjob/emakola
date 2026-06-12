defmodule Emakola.Notifications.DeviceToken do
  @moduledoc """
  FCM registration token for a merchant's mobile device. One row per device
  token; re-registration upserts (devices are shared and change owners).
  Flutter's firebase_messaging issues FCM tokens on both Android and iOS,
  so this is FCM-only — `platform` is informational.
  """

  use Ash.Resource,
    domain: Emakola.Notifications,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("device_tokens")
    repo(Emakola.Repo)
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
      public?(true)
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
      accept([:platform, :token])

      upsert?(true)
      upsert_identity(:unique_token)
      upsert_fields([:merchant_id, :platform, :last_seen_at, :store_id])

      change(relate_actor(:merchant))
      change(set_attribute(:last_seen_at, &DateTime.utc_now/0))
    end

    destroy :destroy do
      primary?(true)
      require_atomic?(false)
    end

    read :for_store do
      description("All device tokens for a store — used by the push worker (authorize?: false).")
    end
  end
end
