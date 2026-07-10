defmodule Emakola.Suppliers.ResellerListingVariant do
  @moduledoc "Maps one offer variant to its reseller-owned purchasable variant."

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("reseller_listing_variants")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:listing_id, :uuid, allow_nil?: false, public?: true)
    attribute(:offer_variant_id, :uuid, allow_nil?: false, public?: true)
    attribute(:reseller_variant_id, :uuid, allow_nil?: false, public?: true)
    attribute(:retail_price, :integer, allow_nil?: false, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :listing, Emakola.Suppliers.ResellerListing do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :offer_variant, Emakola.Suppliers.SupplierOfferVariant do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :reseller_variant, Emakola.Catalog.Variant do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_listing_offer_variant, [:listing_id, :offer_variant_id])
    identity(:unique_reseller_variant, [:reseller_variant_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:listing_id, :offer_variant_id, :reseller_variant_id, :retail_price])
    end

    update :record_price do
      require_atomic?(false)
      accept([:retail_price])
    end
  end
end
