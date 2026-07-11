defmodule Emakola.Suppliers.ContentDraft do
  @moduledoc "Merchant-reviewable content generated only from an approved supplier fact snapshot."

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_content_drafts")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:listing_id, :uuid, allow_nil?: false, public?: true)

    attribute :kind, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:sales_kit, :product_page, :short_video, :faq])
    end

    attribute(:locale, :string, allow_nil?: false, default: "en-GH", public?: true)

    attribute :status, :atom do
      allow_nil?(false)
      default(:draft)
      public?(true)
      constraints(one_of: [:draft, :approved, :rejected, :stale])
    end

    attribute(:source_facts, :map, allow_nil?: false, default: %{}, public?: true)
    attribute(:source_facts_hash, :string, allow_nil?: false, public?: true)
    attribute(:content, :map, allow_nil?: false, default: %{}, public?: true)
    attribute(:generator, :string, allow_nil?: false, default: "deterministic", public?: true)
    attribute(:approved_at, :utc_datetime_usec, public?: true)
    attribute(:approved_by_id, :uuid, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :listing, Emakola.Suppliers.ResellerListing do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :approved_by, Emakola.Accounts.Merchant do
      source_attribute(:approved_by_id)
      define_attribute?(false)
      public?(true)
    end
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :store_id,
        :listing_id,
        :kind,
        :locale,
        :source_facts,
        :source_facts_hash,
        :content,
        :generator
      ])
    end

    read :for_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc], load: [:listing]))
    end

    update :approve do
      require_atomic?(false)
      accept([:approved_by_id])
      validate(attribute_equals(:status, :draft))
      change(set_attribute(:status, :approved))
      change(set_attribute(:approved_at, &DateTime.utc_now/0))
    end

    update :reject do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :draft))
      change(set_attribute(:status, :rejected))
    end

    update :mark_stale do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :stale))
    end
  end
end
