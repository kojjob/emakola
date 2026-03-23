defmodule Emakola.Catalog.OptionValue do
  @moduledoc """
  Specific choice for an option type — e.g., "Small", "Red", "Cotton".

  OptionValues are linked to Variants via the VariantOptionValue join resource.
  A variant for a "Blue Large T-Shirt" would reference the "Blue" OptionValue
  from the "Color" OptionType and "Large" from "Size".

  Multi-tenancy: store_id denormalized from parent option type's product.
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("option_values")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :option_type_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :value, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 100)
    end

    attribute :position, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :option_type, Emakola.Catalog.OptionType do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_type_value, [:option_type_id, :value])
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
      accept([:value, :position, :option_type_id, :store_id])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :value})
    end

    update :update do
      require_atomic?(false)
      accept([:value, :position])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :value})
    end
  end
end
