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

    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end

    has_many :option_values, Emakola.Catalog.OptionValue
  end

  identities do
    identity(:unique_product_name, [:product_id, :name])
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    bypass actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    policy always() do
      forbid_unless(actor_present())
    end
  end

  actions do
    defaults([:read, :destroy])

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
