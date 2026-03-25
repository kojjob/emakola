defmodule Emakola.Accounts.StoreMembership do
  @moduledoc """
  Join resource between Merchant and Store.

  Tracks which merchants belong to which stores and their role within each store.
  This is the ecommerce equivalent of Organisation + Membership.
  """

  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("store_memberships")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :role, :atom do
      constraints(one_of: [:owner, :admin, :staff])
      default(:staff)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :merchant, Emakola.Accounts.Merchant do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Accounts.Store do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_merchant_store, [:merchant_id, :store_id])
  end

  policies do
    # Reads are open (needed for auth flow, internal lookups)
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Creates are open (onboarding creates memberships)
    bypass action_type(:create) do
      authorize_if(always())
    end

    # Role changes and deletes require an authenticated actor
    policy action_type([:update, :destroy]) do
      authorize_unless(actor_present())
      authorize_if(actor_present())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:role])

      argument(:merchant_id, :uuid, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)

      change(manage_relationship(:merchant_id, :merchant, type: :append))
      change(manage_relationship(:store_id, :store, type: :append))
    end

    update :change_role do
      accept([:role])
    end
  end
end
