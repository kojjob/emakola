defmodule Emakola.Stores.StorePayoutAccount do
  @moduledoc """
  A store's payout identity for trustless dropship settlement (SP1).

  Holds the gateway subaccount a payment split routes this store's money to,
  plus whether that destination has been verified. One per store.

  Deliberately a separate resource rather than columns on `Store`: the `Store`
  read policy is effectively public (storefront code reads it with no actor),
  so payout details live here under merchant-only policies instead.
  """

  use Ash.Resource,
    domain: Emakola.Stores,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("store_payout_accounts")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :payout_provider, :atom do
      allow_nil?(false)
      default(:paystack)
      constraints(one_of: [:paystack])
      public?(true)
    end

    # The gateway subaccount code money is settled to. Nil until the subaccount
    # has been created at the gateway.
    attribute :subaccount_code, :string do
      sensitive?(true)
    end

    # MoMo / bank details captured during onboarding.
    attribute :payout_destination, :map do
      sensitive?(true)
    end

    attribute :verification_status, :atom do
      allow_nil?(false)
      default(:unverified)
      constraints(one_of: [:unverified, :verified])
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_store_payout, [:store_id])
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      source_attribute(:store_id)
      define_attribute?(false)
    end
  end

  policies do
    # System/internal code (checkout, settlement) uses authorize?: false.
    # Merchant actors must have access to the owning store.
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :payout_provider, :payout_destination])
    end

    update :update do
      accept([:payout_destination])
    end

    # Records the subaccount returned by the gateway and marks the account
    # verified — the gateway validates the destination when creating it.
    update :record_subaccount do
      accept([:subaccount_code])
      change(set_attribute(:verification_status, :verified))
    end

    read :get_by_store do
      get?(true)
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
    end
  end
end
