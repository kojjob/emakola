defmodule Emakola.Catalog.Category do
  @moduledoc """
  Product category with unlimited nesting via self-referencing parent_id.

  Categories organize products in a store's catalog. The hierarchy is unlimited —
  a building materials merchant can have Materials → Cement → Dangote Cement,
  while a fashion merchant has Clothing → Men's → Shirts.

  Multi-tenancy: scoped to store_id. All queries must include store context.
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("categories")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :description, :string do
      public?(true)
    end

    attribute :parent_id, :uuid do
      public?(true)
    end

    attribute :position, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :parent, Emakola.Catalog.Category do
      define_attribute?(false)
      public?(true)
      source_attribute(:parent_id)
      destination_attribute(:id)
    end

    has_many :children, Emakola.Catalog.Category do
      destination_attribute(:parent_id)
    end
  end

  identities do
    identity(:unique_store_slug, [:store_id, :slug])
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
      accept([:name, :description, :parent_id, :position, :store_id])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :name})
      change(Emakola.Catalog.Changes.GenerateSlug)
    end

    update :update do
      require_atomic?(false)
      accept([:name, :description, :parent_id, :position])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :name})
      validate(Emakola.Catalog.Validations.NoSelfParent)
      change(Emakola.Catalog.Changes.GenerateSlug)
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, position: :asc)
      end)
    end

    read :list_roots do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id) and is_nil(parent_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, position: :asc)
      end)
    end

    read :list_children do
      argument(:parent_id, :uuid, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(parent_id == ^arg(:parent_id) and store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, position: :asc)
      end)
    end
  end
end
