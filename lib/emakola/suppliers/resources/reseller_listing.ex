defmodule Emakola.Suppliers.ResellerListing do
  @moduledoc "Maps a shared offer to the reseller-owned catalog product created from it."

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("reseller_listings")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:offer_id, :uuid, allow_nil?: false, public?: true)
    attribute(:reseller_store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:reseller_product_id, :uuid, allow_nil?: false, public?: true)
    attribute(:supplier_id, :uuid, allow_nil?: false, public?: true)

    attribute :status, :atom do
      constraints(one_of: [:active, :paused, :removed])
      default(:active)
      allow_nil?(false)
      public?(true)
    end

    attribute(:synced_at, :utc_datetime_usec, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :offer, Emakola.Suppliers.SupplierOffer do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :reseller_product, Emakola.Catalog.Product do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :supplier, Emakola.Suppliers.Supplier do
      define_attribute?(false)
      public?(true)
    end

    has_many :listing_variants, Emakola.Suppliers.ResellerListingVariant do
      destination_attribute(:listing_id)
      public?(true)
    end

    has_many :listing_images, Emakola.Suppliers.ResellerListingImage do
      destination_attribute(:listing_id)
      public?(true)
    end
  end

  identities do
    identity(:unique_offer_reseller, [:offer_id, :reseller_store_id])
    identity(:unique_reseller_product, [:reseller_product_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:offer_id, :reseller_store_id, :reseller_product_id, :supplier_id, :synced_at])
    end

    update :record_sync do
      require_atomic?(false)
      accept([])
      change(set_attribute(:synced_at, &DateTime.utc_now/0))
    end

    update :pause do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :paused))
      change(set_attribute(:synced_at, &DateTime.utc_now/0))
    end

    update :activate do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :active))
      change(set_attribute(:synced_at, &DateTime.utc_now/0))
    end

    read :for_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(reseller_store_id == ^arg(:store_id)))

      prepare(
        build(sort: [inserted_at: :desc], load: [:offer, :reseller_product, :listing_variants])
      )
    end
  end
end
