defmodule Emakola.Catalog.OptionType do
  @moduledoc """
  Named product option — e.g., "Size", "Color", "Material".

  Each product can have at most 3 option types (matching Shopify's limit).
  OptionValues belong to an OptionType and represent the specific choices
  (e.g., "Small", "Medium", "Large" for Size).

  Multi-tenancy: store_id denormalized from parent product.
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("option_types")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :product_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :position, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :product, Emakola.Catalog.Product do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    has_many :option_values, Emakola.Catalog.OptionValue
  end

  identities do
    identity(:unique_product_name, [:product_id, :name])
  end

  policies do
    # Reads are public — storefront accesses option types without an actor.
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

    read :list_by_product do
      argument(:product_id, :uuid, allow_nil?: false)

      filter(expr(product_id == ^arg(:product_id)))

      prepare(build(sort: [position: :asc], load: [:option_values]))
    end

    create :create do
      accept([:name, :position, :product_id, :store_id])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :name})
      validate(Emakola.Catalog.Validations.MaxOptionTypes)
    end

    update :update do
      require_atomic?(false)
      accept([:name, :position])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :name})
    end
  end
end
