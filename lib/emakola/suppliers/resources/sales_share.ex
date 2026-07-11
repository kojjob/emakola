defmodule Emakola.Suppliers.SalesShare do
  @moduledoc "A channel-specific tracked product link in a reseller's Earn sales kit."

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_sales_shares")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:listing_id, :uuid, allow_nil?: false, public?: true)
    attribute(:product_id, :uuid, allow_nil?: false, public?: true)
    attribute(:token, :string, allow_nil?: false, public?: true)

    attribute :channel, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:whatsapp, :facebook, :copy_link])
    end

    attribute(:click_count, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:share_count, :integer, allow_nil?: false, default: 0, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :listing, Emakola.Suppliers.ResellerListing do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :product, Emakola.Catalog.Product do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    has_many :conversions, Emakola.Suppliers.SalesShareConversion do
      destination_attribute(:share_id)
      public?(true)
    end
  end

  aggregates do
    count(:order_count, :conversions)
    sum(:revenue, :conversions, :revenue, default: 0)
  end

  identities do
    identity(:unique_token, [:token])
    identity(:unique_listing_channel, [:listing_id, :channel])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :listing_id, :product_id, :token, :channel])
    end

    update :record_click do
      require_atomic?(true)
      change(atomic_update(:click_count, expr(click_count + 1)))
    end

    update :record_share do
      require_atomic?(true)
      change(atomic_update(:share_count, expr(share_count + 1)))
    end
  end
end
