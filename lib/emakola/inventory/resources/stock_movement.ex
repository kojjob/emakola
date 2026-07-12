defmodule Emakola.Inventory.StockMovement do
  @moduledoc """
  Insert-only ledger of every stock change — the merchant's "why did
  stock change" answer. One row per (variant, location, delta) with a
  reason, and the order id for sales.
  """

  use Ash.Resource,
    domain: Emakola.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("stock_movements")
    repo(Emakola.Repo)
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:variant_id, :uuid, allow_nil?: false, public?: true)
    attribute(:location_id, :uuid, allow_nil?: false, public?: true)
    attribute(:delta, :integer, allow_nil?: false, public?: true)

    attribute :reason, :atom do
      allow_nil?(false)
      public?(true)

      constraints(
        one_of: [
          :sale,
          :restock,
          :adjustment,
          :reservation_hold,
          :reservation_release,
          :transfer_in,
          :transfer_out,
          :import
        ]
      )
    end

    attribute(:order_id, :uuid, public?: true)

    create_timestamp(:inserted_at)
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :variant_id, :location_id, :delta, :reason, :order_id])
    end
  end
end
