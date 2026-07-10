defmodule Emakola.Suppliers.SalesShareConversion do
  @moduledoc "A confirmed order attributed exactly once to an Earn sales share."

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_sales_share_conversions")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:share_id, :uuid, allow_nil?: false, public?: true)
    attribute(:order_id, :uuid, allow_nil?: false, public?: true)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:revenue, :integer, allow_nil?: false, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :share, Emakola.Suppliers.SalesShare do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :order, Emakola.Orders.Order do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_order, [:order_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :record do
      accept([:share_id, :order_id, :store_id, :revenue])
      upsert?(true)
      upsert_identity(:unique_order)
      upsert_fields([])
    end
  end
end
