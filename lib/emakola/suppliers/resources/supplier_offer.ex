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

    # Supplier-quoted dispatch fee per delivery area, integer pesewas.
    attribute(:dispatch_fees, :map, allow_nil?: false, default: %{}, public?: true)

    # What THIS supplier will honour back to the reseller on these goods.
    #
    # `return_terms` has always existed here and was never shown to anyone: the
    # PDP loads this very offer to print "Fulfilled by verified partner X" and
    # then discards everything but the name. These terms are the supplier's
    # commitment, not a promise to the shopper — the merchant is the seller of
    # record, so what a customer is quoted is the merchant's own policy
    # (`Emakola.Stores.StorePageContent`).
    #
    # They are surfaced to the MERCHANT in the supply network, so a merchant who
    # offers a 30-day return on goods a supplier only takes back for 7 is
    # absorbing that difference knowingly rather than blind.
    attribute(:return_terms, :string, public?: true)

    attribute :returns_window_days, :integer do
      constraints(min: 0)
      public?(true)
    end

    attribute :warranty_months, :integer do
      constraints(min: 0)
      public?(true)
    end

    attribute(:warranty_terms, :string, public?: true)
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
        :dispatch_fees,
        :return_terms,
        :returns_window_days,
        :warranty_months,
        :warranty_terms
      ])
    end

    # A supplier revising what they will honour. Kept separate from the status
    # transitions above so terms can be corrected on a live offer without
    # unpublishing it — the resellers carrying these goods need the current
    # terms, not the ones the offer launched with.
    update :update_terms do
      require_atomic?(false)

      accept([
        :delivery_areas,
        :dispatch_fees,
        :return_terms,
        :returns_window_days,
        :warranty_months,
        :warranty_terms
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

      prepare(
        build(
          sort: [inserted_at: :desc],
          load: [source_product: :images, offer_variants: :source_variant]
        )
      )
    end
  end

  validations do
    validate(Emakola.Suppliers.Validations.DispatchFees)
  end
end
