defmodule Emakola.Catalog.Product do
  @moduledoc """
  Product resource — the container in the Shopify-style variant model.

  Every product has at least one variant that holds price/SKU/stock. The product
  itself holds title, description, SEO fields, tags, and status. Products belong
  to a store (multi-tenant) and optionally to a category.

  Status lifecycle: draft → active (requires variants) → archived → draft
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("products")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :category_id, :uuid do
      public?(true)
    end

    attribute :title, :string do
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

    attribute :status, :atom do
      constraints(one_of: [:draft, :active, :archived])
      default(:draft)
      allow_nil?(false)
      public?(true)
    end

    attribute :seo_title, :string do
      public?(true)
    end

    attribute :seo_description, :string do
      public?(true)
    end

    attribute :tags, {:array, :string} do
      default([])
      public?(true)
    end

    attribute :published_at, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :category, Emakola.Catalog.Category do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_store_slug, [:store_id, :slug])
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:title, :description, :category_id, :tags, :seo_title, :seo_description, :store_id])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :title})
      change({Emakola.Catalog.Changes.GenerateSlug, from: :title})
    end

    update :update do
      require_atomic?(false)
      accept([:title, :description, :category_id, :tags, :seo_title, :seo_description])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :title})
      change({Emakola.Catalog.Changes.GenerateSlug, from: :title})
    end

    update :archive do
      require_atomic?(false)
      accept([])

      change(set_attribute(:status, :archived))
    end

    update :activate do
      require_atomic?(false)
      accept([])

      validate(Emakola.Catalog.Validations.HasVariants)
      change(set_attribute(:status, :active))
      change(set_attribute(:published_at, &DateTime.utc_now/0))
    end

    read :search do
      argument(:query, :string, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)

      filter(
        expr(
          store_id == ^arg(:store_id) and
            contains(fragment("lower(?)", title), fragment("lower(?)", ^arg(:query)))
        )
      )
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, inserted_at: :desc)
      end)
    end

    read :list_by_store_and_status do
      argument(:store_id, :uuid, allow_nil?: false)

      argument(:status, :atom,
        allow_nil?: false,
        constraints: [one_of: [:draft, :active, :archived]]
      )

      filter(expr(store_id == ^arg(:store_id) and status == ^arg(:status)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, inserted_at: :desc)
      end)
    end

    read :list_by_category do
      argument(:category_id, :uuid, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(category_id == ^arg(:category_id) and store_id == ^arg(:store_id)))
    end
  end
end
