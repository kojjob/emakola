defmodule Emakola.Billing.Plan do
  use Ash.Resource,
    domain: Emakola.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("plans")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :stripe_product_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :stripe_price_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :price_cents, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute :interval, :atom do
      constraints(one_of: [:monthly, :yearly])
      default(:monthly)
      allow_nil?(false)
      public?(true)
    end

    attribute :features, {:array, :string} do
      default([])
      public?(true)
    end

    attribute(:max_seats, :integer, default: 5, public?: true)
    attribute(:max_agents, :integer, default: 3, public?: true)
    attribute(:max_api_calls_per_month, :integer, default: 1000, public?: true)

    attribute(:active, :boolean, default: true, public?: true)
    attribute(:sort_order, :integer, default: 0, public?: true)

    timestamps()
  end

  identities do
    identity(:unique_stripe_product, [:stripe_product_id])
    identity(:unique_slug, [:slug])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :name,
        :slug,
        :stripe_product_id,
        :stripe_price_id,
        :price_cents,
        :interval,
        :features,
        :max_seats,
        :max_agents,
        :max_api_calls_per_month,
        :active,
        :sort_order
      ])
    end

    update :update do
      accept([
        :name,
        :price_cents,
        :features,
        :max_seats,
        :max_agents,
        :max_api_calls_per_month,
        :active,
        :sort_order
      ])
    end
  end
end
