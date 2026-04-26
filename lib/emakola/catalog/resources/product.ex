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
      constraints(max_length: 255)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :description, :string do
      public?(true)
      constraints(max_length: 5_000)
    end

    attribute :status, :atom do
      constraints(one_of: [:draft, :active, :archived])
      default(:draft)
      allow_nil?(false)
      public?(true)
    end

    attribute :seo_title, :string do
      public?(true)
      constraints(max_length: 255)
    end

    attribute :seo_description, :string do
      public?(true)
      constraints(max_length: 1_000)
    end

    attribute :tags, {:array, :string} do
      default([])
      public?(true)
      constraints(items: [max_length: 100])
    end

    attribute :published_at, :utc_datetime_usec do
      public?(true)
    end

    # Counter incremented when a customer taps a button on the product's
    # share_strip (Phase 1). Displayed on the PDP as social proof
    # ("1.2K shares") once > 0. Phase 3 of social media integration plan.
    attribute :share_count, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
      constraints(min: 0)
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

    has_many :variants, Emakola.Catalog.Variant
    has_many :images, Emakola.Catalog.Image
    has_many :reviews, Emakola.Catalog.Review
  end

  aggregates do
    count(:variant_count, :variants)
    min(:min_price, :variants, :price)
    max(:max_price, :variants, :price)

    count :review_count, :reviews do
      filter(expr(status == :published))
    end

    avg :avg_rating, :reviews, :rating do
      filter(expr(status == :published))
    end
  end

  identities do
    identity(:unique_store_slug, [:store_id, :slug])
  end

  policies do
    # Reads are always allowed (storefront + internal)
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
      accept([:title, :description, :category_id, :tags, :seo_title, :seo_description, :store_id])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :title})
      change({Emakola.Catalog.Changes.GenerateSlug, from: :title})
      change({Emakola.Catalog.Changes.SyncToWhatsappCatalog, action: :upsert})
    end

    update :update do
      require_atomic?(false)
      accept([:title, :description, :category_id, :tags, :seo_title, :seo_description])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :title})
      change({Emakola.Catalog.Changes.GenerateSlug, from: :title})
      change({Emakola.Catalog.Changes.SyncToWhatsappCatalog, action: :upsert})
    end

    update :archive do
      require_atomic?(false)
      accept([])

      change(set_attribute(:status, :archived))
      change({Emakola.Catalog.Changes.SyncToWhatsappCatalog, action: :delete})
    end

    update :activate do
      require_atomic?(false)
      accept([])

      validate(Emakola.Catalog.Validations.HasVariants)
      change(set_attribute(:status, :active))
      change(set_attribute(:published_at, &DateTime.utc_now/0))
      change({Emakola.Catalog.Changes.SyncToWhatsappCatalog, action: :upsert})
    end

    # Atomic increment of share_count, fired by the storefront PDP when a
    # customer taps a button on the share_strip. No actor required — this
    # is a public/anonymous action driven by storefront UI. Idempotency
    # is intentionally NOT enforced; double-counted shares are acceptable
    # noise compared to the cost of dedupe infrastructure.
    update :increment_share_count do
      require_atomic?(true)
      accept([])
      change(atomic_update(:share_count, expr(share_count + 1)))
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

      prepare(build(load: [:min_price, :max_price, :images]))
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.load([:min_price, :max_price, :images, :variant_count])
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
        query
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.load([
          :min_price,
          :max_price,
          :images,
          :variant_count,
          :review_count,
          :avg_rating
        ])
      end)
    end

    read :list_by_category do
      argument(:category_id, :uuid, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(category_id == ^arg(:category_id) and store_id == ^arg(:store_id)))
      prepare(build(load: [:min_price, :max_price, :images, :variant_count]))
    end
  end
end
