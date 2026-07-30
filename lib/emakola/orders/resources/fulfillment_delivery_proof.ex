defmodule Emakola.Orders.FulfillmentDeliveryProof do
  @moduledoc "A short-lived, attempt-capped customer OTP proving physical delivery."

  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("fulfillment_delivery_proofs")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:fulfillment_id, :uuid, allow_nil?: false, public?: true)
    attribute(:code_hash, :string, allow_nil?: false, sensitive?: true, public?: false)
    attribute(:expires_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:attempts, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:sent_to, :string, allow_nil?: false, public?: true)
    attribute(:verified_at, :utc_datetime_usec, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :fulfillment, Emakola.Orders.Fulfillment do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_fulfillment, [:fulfillment_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :issue do
      accept([:fulfillment_id, :code_hash, :expires_at, :sent_to])
    end

    update :reissue do
      require_atomic?(false)
      accept([:code_hash, :expires_at, :sent_to])
      change(set_attribute(:attempts, 0))
      change(set_attribute(:verified_at, nil))
    end

    update :record_attempt do
      require_atomic?(true)
      change(atomic_update(:attempts, expr(attempts + 1)))
    end

    update :verify do
      require_atomic?(false)
      accept([])
      change(set_attribute(:verified_at, &DateTime.utc_now/0))
      change(Emakola.Orders.Changes.ReleaseProtectionHoldOnVerify)
    end
  end
end
