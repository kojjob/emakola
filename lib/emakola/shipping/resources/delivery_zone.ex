defmodule Emakola.Shipping.DeliveryZone do
  @moduledoc """
  Delivery zone resource representing geographic delivery areas with fees.

  Each store defines its own delivery zones with pricing in minor currency
  units (pesewas for GHS, kobo for NGN). Zones are unique per store by name.
  """

  use Ash.Resource,
    domain: Emakola.Shipping,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("delivery_zones")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :fee, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 0)
    end

    attribute :estimated_days, :integer do
      default(1)
      public?(true)
    end

    attribute :active, :boolean do
      default(true)
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_store_name, [:store_id, :name])
  end

  relationships do
    belongs_to :store, Emakola.Accounts.Store do
      attribute_writable?(true)
      define_attribute?(false)
      source_attribute(:store_id)
    end
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Internal/system calls (nil actor) are allowed
    bypass always() do
      authorize_unless(actor_present())
    end

    # Merchant actors: verify store membership for writes
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:store_id, :name, :fee, :estimated_days, :active])
    end

    update :update do
      accept([:name, :fee, :estimated_days, :active])
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))
    end
  end
end
