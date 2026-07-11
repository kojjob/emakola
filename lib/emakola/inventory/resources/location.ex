defmodule Emakola.Inventory.Location do
  @moduledoc """
  A physical stock location for a store (shop, market stall, warehouse).
  Exactly one default per store; the default receives storefront sales
  first and seeds lazily-created stock levels.

  Service-funnel resource: policies forbid direct access — all reads and
  writes go through `Emakola.Inventory`, which authorizes via store
  membership.
  """

  use Ash.Resource,
    domain: Emakola.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("inventory_locations")
    repo(Emakola.Repo)
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 120, trim?: true, allow_empty?: false)
    end

    attribute(:default, :boolean, allow_nil?: false, default: false, public?: true)
    attribute(:active, :boolean, allow_nil?: false, default: true, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_name_per_store, [:store_id, :name])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :name, :default, :active])
    end

    update :rename do
      accept([:name])
    end

    update :set_default do
      accept([])
      change(set_attribute(:default, true))
    end

    update :clear_default do
      accept([])
      change(set_attribute(:default, false))
    end

    update :deactivate do
      accept([])
      validate(attribute_equals(:default, false))
      change(set_attribute(:active, false))
    end

    update :reactivate do
      accept([])
      change(set_attribute(:active, true))
    end
  end
end
