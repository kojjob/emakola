defmodule Emakola.Catalog.VariantOptionValue do
  @moduledoc """
  Join resource linking Variants to OptionValues.

  A "Blue Large T-Shirt" variant would have two VariantOptionValue records:
  one linking to the "Blue" OptionValue and one linking to "Large".

  Multi-tenancy: store_id denormalized from variant.
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("variant_option_values")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :variant_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :option_value_id, :uuid do
      allow_nil?(false)
      public?(true)
    end
  end

  relationships do
    belongs_to :variant, Emakola.Catalog.Variant do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :option_value, Emakola.Catalog.OptionValue do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_variant_option_value, [:variant_id, :option_value_id])
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Internal/system calls (nil actor) are allowed
    bypass always() do
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
      accept([:variant_id, :option_value_id, :store_id])
    end
  end
end
