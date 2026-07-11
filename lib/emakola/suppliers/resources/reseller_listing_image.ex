defmodule Emakola.Suppliers.ResellerListingImage do
  @moduledoc "Tracks independent reseller-owned copies of supplier product images."

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("reseller_listing_images")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:listing_id, :uuid, allow_nil?: false, public?: true)
    attribute(:source_image_id, :uuid, allow_nil?: false, public?: true)
    attribute(:reseller_image_id, :uuid, public?: true)
    attribute(:storage_key, :string, allow_nil?: false, public?: true)
    attribute(:failure_reason, :string, public?: true)

    attribute :status, :atom do
      constraints(one_of: [:pending, :completed, :failed])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :listing, Emakola.Suppliers.ResellerListing do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :source_image, Emakola.Catalog.Image do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :reseller_image, Emakola.Catalog.Image do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_listing_source, [:listing_id, :source_image_id])
    identity(:unique_reseller_image, [:reseller_image_id], nils_distinct?: true)
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:listing_id, :source_image_id, :storage_key])
    end

    update :complete do
      require_atomic?(false)
      accept([:reseller_image_id])
      change(set_attribute(:status, :completed))
      change(set_attribute(:failure_reason, nil))
    end

    update :fail do
      require_atomic?(false)
      accept([:failure_reason])
      change(set_attribute(:status, :failed))
    end
  end
end
