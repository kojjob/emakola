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

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("delivery_zones")
    repo(Emakola.Repo)

    custom_indexes do
      # Belt to OneCatchAllPerStore's braces: two concurrent saves cannot
      # both become the catch-all.
      index([:store_id],
        unique: true,
        where: "fallback = true",
        name: "delivery_zones_one_catch_all_per_store_index"
      )
    end
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

    # Single free-shipping threshold (merchandise subtotal, in pesewas). A
    # tier ladder can replace this if merchants ask for multiple thresholds.
    attribute :free_above_pesewas, :integer do
      public?(true)
      constraints(min: 0)
    end

    # Optional per-kg surcharge (pesewas) added on top of the base fee.
    attribute :per_kg_fee_pesewas, :integer do
      public?(true)
      constraints(min: 0)
    end

    attribute :active, :boolean do
      default(true)
      public?(true)
    end

    # The zone that takes any region no other zone names. Zones match by
    # name, so without one a buyer from an unnamed region falls to
    # checkout's hard-coded default fee. One per store, and only while
    # active.
    attribute :fallback, :boolean do
      default(false)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  validations do
    validate(Emakola.Shipping.Validations.OneCatchAllPerStore, on: [:create, :update])
  end

  identities do
    identity(:unique_store_name, [:store_id, :name])
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      attribute_writable?(true)
      define_attribute?(false)
      source_attribute(:store_id)
    end
  end

  policies do
    # Reads are public — storefront displays delivery zones during checkout.
    bypass action_type(:read) do
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
      accept([
        :store_id,
        :name,
        :fee,
        :estimated_days,
        :active,
        :fallback,
        :free_above_pesewas,
        :per_kg_fee_pesewas
      ])
    end

    update :update do
      require_atomic?(false)

      accept([
        :name,
        :fee,
        :estimated_days,
        :active,
        :fallback,
        :free_above_pesewas,
        :per_kg_fee_pesewas
      ])
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))
    end

    read :list_active_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id) and active == true))
    end
  end
end
