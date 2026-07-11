defmodule Emakola.Suppliers.InventoryEligibilityPolicy do
  @moduledoc "Supplier-authored, public eligibility rule for reserving a specific offer variant."
  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_inventory_eligibility_policies")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:supplier_store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:offer_variant_id, :uuid, allow_nil?: false, public?: true)

    attribute(:minimum_tier, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:starter, :reliable, :proven]]
    )

    attribute(:max_quantity_per_reseller, :integer, allow_nil?: false, public?: true)
    attribute(:reservation_hours, :integer, allow_nil?: false, public?: true)
    attribute(:reason_code, :string, allow_nil?: false, public?: true)
    attribute(:active, :boolean, allow_nil?: false, default: true, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :offer_variant, Emakola.Suppliers.SupplierOfferVariant do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_offer_variant, [:offer_variant_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create(:create,
      accept: [
        :supplier_store_id,
        :offer_variant_id,
        :minimum_tier,
        :max_quantity_per_reseller,
        :reservation_hours,
        :reason_code
      ]
    )

    update(:update,
      accept: [
        :minimum_tier,
        :max_quantity_per_reseller,
        :reservation_hours,
        :reason_code,
        :active
      ],
      require_atomic?: false
    )
  end
end
