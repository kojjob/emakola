defmodule Emakola.Content.Post do
  @moduledoc """
  Post resource for the Content domain.

  Supports blog posts, pages, recipes, and guides. Posts can be store-scoped
  (tenant content) or platform-level (nil store_id). Includes slug generation,
  publish/archive lifecycle, SEO fields, and view counting.

  Status lifecycle: draft → published → archived
  AI-generated content starts as: ai_draft → published → archived
  """

  use Ash.Resource,
    domain: Emakola.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("posts")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      public?(true)
    end

    attribute :author_id, :uuid do
      public?(true)
    end

    attribute :type, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:blog_post, :page, :recipe, :guide])
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

    attribute :body, :string do
      public?(true)
    end

    attribute :excerpt, :string do
      public?(true)
      constraints(max_length: 500)
    end

    attribute :featured_image_url, :string do
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

    attribute :status, :atom do
      constraints(one_of: [:draft, :ai_draft, :published, :archived])
      default(:draft)
      allow_nil?(false)
      public?(true)
    end

    attribute :published_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :tags, {:array, :string} do
      default([])
      public?(true)
    end

    attribute :ai_generated, :boolean do
      default(false)
      public?(true)
    end

    attribute :view_count, :integer do
      default(0)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :author, Emakola.Accounts.Merchant do
      define_attribute?(false)
      public?(true)
    end

    has_many :media_attachments, Emakola.Content.MediaAttachment
    has_one :recipe_meta, Emakola.Content.RecipeMeta
  end

  identities do
    identity(:unique_store_slug_type, [:store_id, :slug, :type])
  end

  policies do
    # Reads are public — storefront renders blog/recipe posts without an actor.
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

    create :create do
      accept([
        :store_id,
        :author_id,
        :type,
        :title,
        :body,
        :excerpt,
        :featured_image_url,
        :seo_title,
        :seo_description,
        :tags,
        :ai_generated
      ])

      change(Emakola.Content.Changes.GenerateSlug)
    end

    # AI-drafted posts (SEO Phase 3b): land as :ai_draft (not public, distinct
    # from human :draft) and flagged ai_generated, so the admin can surface
    # "AI suggestions awaiting review". A human publishes before anything goes live.
    create :create_ai_draft do
      accept([
        :store_id,
        :author_id,
        :type,
        :title,
        :body,
        :excerpt,
        :featured_image_url,
        :seo_title,
        :seo_description,
        :tags
      ])

      change(set_attribute(:status, :ai_draft))
      change(set_attribute(:ai_generated, true))
      change(Emakola.Content.Changes.GenerateSlug)
    end

    update :update do
      require_atomic?(false)

      accept([
        :title,
        :body,
        :excerpt,
        :featured_image_url,
        :seo_title,
        :seo_description,
        :tags
      ])

      change(Emakola.Content.Changes.GenerateSlug)
    end

    update :publish do
      require_atomic?(false)
      accept([])

      change(set_attribute(:status, :published))

      change(fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :published_at) do
          nil -> Ash.Changeset.change_attribute(changeset, :published_at, DateTime.utc_now())
          _ -> changeset
        end
      end)
    end

    update :archive do
      require_atomic?(false)
      accept([])

      change(set_attribute(:status, :archived))
    end

    update :increment_views do
      accept([])

      change(atomic_update(:view_count, expr(view_count + 1)))
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, inserted_at: :desc)
      end)
    end

    read :list_admin do
      argument(:store_id, :uuid, allow_nil?: false)

      argument(:type, :atom,
        allow_nil?: true,
        constraints: [one_of: [:blog_post, :page, :recipe, :guide]]
      )

      argument(:status, :atom,
        allow_nil?: true,
        constraints: [one_of: [:draft, :ai_draft, :published, :archived]]
      )

      filter(
        expr(
          store_id == ^arg(:store_id) and
            (is_nil(^arg(:type)) or type == ^arg(:type)) and
            (is_nil(^arg(:status)) or status == ^arg(:status))
        )
      )

      prepare(build(sort: [inserted_at: :desc]))
    end

    read :get_for_admin do
      get?(true)
      argument(:id, :uuid, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(id == ^arg(:id) and store_id == ^arg(:store_id)))
    end

    read :list_published do
      argument(:store_id, :uuid)
      argument(:type, :atom, constraints: [one_of: [:blog_post, :page, :recipe, :guide]])
      argument(:exclude_id, :uuid, allow_nil?: true)

      filter(expr(status == :published))

      prepare(fn query, _context ->
        query
        |> then(fn q ->
          case Ash.Query.get_argument(q, :store_id) do
            nil -> q
            store_id -> Ash.Query.filter(q, store_id == ^store_id)
          end
        end)
        |> then(fn q ->
          case Ash.Query.get_argument(q, :type) do
            nil -> q
            type -> Ash.Query.filter(q, type == ^type)
          end
        end)
        |> then(fn q ->
          case Ash.Query.get_argument(q, :exclude_id) do
            nil -> q
            excl_id -> Ash.Query.filter(q, id != ^excl_id)
          end
        end)
        |> Ash.Query.sort(published_at: :desc)
      end)
    end

    read :get_by_slug do
      argument(:slug, :string, allow_nil?: false)
      argument(:store_id, :uuid)
      argument(:type, :atom, constraints: [one_of: [:blog_post, :page, :recipe, :guide]])

      get?(true)

      filter(expr(slug == ^arg(:slug)))

      prepare(fn query, _context ->
        query
        |> then(fn q ->
          case Ash.Query.get_argument(q, :store_id) do
            nil -> q
            store_id -> Ash.Query.filter(q, store_id == ^store_id)
          end
        end)
        |> then(fn q ->
          case Ash.Query.get_argument(q, :type) do
            nil -> q
            type -> Ash.Query.filter(q, type == ^type)
          end
        end)
      end)
    end
  end
end
