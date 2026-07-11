defmodule Emakola.Suppliers.GroupBuyCampaign do
  @moduledoc "A threshold-based partner-product campaign with explicit deadline and refund deadline."

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_group_buy_campaigns")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:listing_id, :uuid, allow_nil?: false, public?: true)
    attribute(:listing_variant_id, :uuid, allow_nil?: false, public?: true)
    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:threshold_quantity, :integer, allow_nil?: false, public?: true)
    attribute(:committed_quantity, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:unit_price, :integer, allow_nil?: false, public?: true)
    attribute(:deadline, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:refund_deadline, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:terms, :map, allow_nil?: false, default: %{}, public?: true)

    attribute :status, :atom do
      allow_nil?(false)
      default(:draft)
      public?(true)
      constraints(one_of: [:draft, :open, :funded, :fulfilled, :cancelled, :refunded])
    end

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

    belongs_to :listing_variant, Emakola.Suppliers.ResellerListingVariant do
      define_attribute?(false)
      public?(true)
    end

    has_many :commitments, Emakola.Suppliers.GroupBuyCommitment do
      destination_attribute(:campaign_id)
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
        :listing_variant_id,
        :title,
        :threshold_quantity,
        :unit_price,
        :deadline,
        :refund_deadline,
        :terms
      ])

      validate(compare(:threshold_quantity, greater_than: 1))
      validate(compare(:unit_price, greater_than: 0))
    end

    read :for_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc], load: [:listing, :commitments]))
    end

    update :open do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :draft))
      change(set_attribute(:status, :open))
    end

    update :record_paid_quantity do
      require_atomic?(true)
      argument(:quantity, :integer, allow_nil?: false)
      change(atomic_update(:committed_quantity, expr(committed_quantity + ^arg(:quantity))))
    end

    update :mark_funded do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :funded))
    end

    update :cancel do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :cancelled))
    end

    update :mark_refunded do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :refunded))
    end

    update :mark_fulfilled do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :funded))
      change(set_attribute(:status, :fulfilled))
    end
  end
end
