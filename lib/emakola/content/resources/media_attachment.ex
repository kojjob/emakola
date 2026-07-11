defmodule Emakola.Content.MediaAttachment do
  @moduledoc """
  Media attachment resource for the Content domain.

  Supports image, video, and audio attachments linked to posts or
  standalone within a store. Includes AI-generated alt text support.
  """

  use Ash.Resource,
    domain: Emakola.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("media_attachments")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :post_id, :uuid do
      public?(true)
    end

    attribute :type, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:image, :video, :audio])
    end

    attribute :url, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :filename, :string do
      public?(true)
    end

    attribute :alt_text, :string do
      public?(true)
    end

    attribute :caption, :string do
      public?(true)
    end

    attribute :position, :integer do
      default(0)
      public?(true)
    end

    attribute :ai_alt_text, :string do
      public?(true)
    end

    attribute :file_size, :integer do
      public?(true)
    end

    attribute :content_type, :string do
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :post, Emakola.Content.Post do
      define_attribute?(false)
      public?(true)
    end
  end

  policies do
    # Reads are public — storefront renders post media without an actor.
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
        :post_id,
        :type,
        :url,
        :filename,
        :alt_text,
        :caption,
        :position,
        :ai_alt_text,
        :file_size,
        :content_type
      ])
    end

    update :update do
      accept([:alt_text, :caption, :position, :ai_alt_text])
    end

    read :list_by_post do
      argument(:post_id, :uuid, allow_nil?: false)

      filter(expr(post_id == ^arg(:post_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, position: :asc)
      end)
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, inserted_at: :desc)
      end)
    end
  end
end
