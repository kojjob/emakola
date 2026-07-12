defmodule Emakola.Inventory.StockLevel do
  @moduledoc """
  Per-location stock for a variant. `variant.stock_quantity` stays the
  denormalized total — `Emakola.Inventory` adjusts a level and the total
  in one transaction, so total == sum(levels) always holds.

  Service-funnel resource: direct access is forbidden; the atomic
  `:adjust` mirrors the variant's, backed by the same non-negative
  DB CHECK (`stock_level_non_negative`).
  """

  use Ash.Resource,
    domain: Emakola.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("stock_levels")
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
    attribute(:variant_id, :uuid, allow_nil?: false, public?: true)
    attribute(:location_id, :uuid, allow_nil?: false, public?: true)

    attribute :quantity, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
      constraints(min: 0)
    end

    timestamps()
  end

  relationships do
    belongs_to :variant, Emakola.Catalog.Variant do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :location, Emakola.Inventory.Location do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_variant_location, [:variant_id, :location_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :variant_id, :location_id, :quantity])
    end

    update :adjust do
      accept([])
      argument(:delta, :integer, allow_nil?: false)
      change(atomic_update(:quantity, expr(quantity + ^arg(:delta))))
    end
  end
end
