defmodule Emakola.Suppliers.SupplierOffer do
  @moduledoc """
  Commercial sharing terms for an existing wholesaler-owned catalog product.

  Product content remains in `Catalog.Product`; variant prices and availability
  remain in `Catalog.Variant`. This resource adds only network-specific terms.
  User-facing access is mediated by `Emakola.Suppliers.Offers`.
  """

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("supplier_offers")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:wholesaler_store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:source_product_id, :uuid, allow_nil?: false, public?: true)

    attribute :status, :atom do
      constraints(one_of: [:draft, :published, :paused, :archived])
      default(:draft)
      allow_nil?(false)
      public?(true)
    end

    attribute :earning_model, :atom do
      constraints(one_of: [:markup, :fixed_commission])
      allow_nil?(false)
      public?(true)
    end

    attribute(:delivery_areas, {:array, :string}, allow_nil?: false, default: [], public?: true)
    attribute(:return_terms, :string, public?: true)
    attribute(:published_at, :utc_datetime_usec, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :wholesaler_store, Emakola.Stores.Store do
      source_attribute(:wholesaler_store_id)
      define_attribute?(false)
      public?(true)
    end

    belongs_to :source_product, Emakola.Catalog.Product do
      source_attribute(:source_product_id)
      define_attribute?(false)
      public?(true)
    end

    has_many :offer_variants, Emakola.Suppliers.SupplierOfferVariant do
      destination_attribute(:offer_id)
      public?(true)
    end
  end

  identities do
    identity(:unique_product_offer, [:wholesaler_store_id, :source_product_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create_draft do
      accept([
        :wholesaler_store_id,
        :source_product_id,
        :earning_model,
        :delivery_areas,
        :return_terms
      ])
    end

    update :publish do
      require_atomic?(false)
      accept([])
      validate({Emakola.Validations.StatusGuard, from: [:draft, :paused]})
      change(set_attribute(:status, :published))
      change(set_attribute(:published_at, &DateTime.utc_now/0))
    end

    update :pause do
      require_atomic?(false)
      accept([])
      validate({Emakola.Validations.StatusGuard, from: [:published]})
      change(set_attribute(:status, :paused))
    end

    update :archive do
      require_atomic?(false)
      accept([])
      validate({Emakola.Validations.StatusGuard, from: [:draft, :published, :paused]})
      change(set_attribute(:status, :archived))
    end

    read :owned_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(wholesaler_store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc], load: [:source_product, :offer_variants]))
    end
  end
end
