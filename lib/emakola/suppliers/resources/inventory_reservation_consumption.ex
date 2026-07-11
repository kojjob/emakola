defmodule Emakola.Suppliers.InventoryReservationConsumption do
  @moduledoc "Idempotency ledger tying held inventory to a paid order line."
  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_inventory_reservation_consumptions")
    repo(Emakola.Repo)
    identity_index_names(unique_reservation_line: "inv_res_consumption_res_line_idx")
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:reservation_id, :uuid, allow_nil?: false, public?: true)
    attribute(:order_id, :uuid, allow_nil?: false, public?: true)
    attribute(:line_item_id, :uuid, allow_nil?: false, public?: true)
    attribute(:quantity, :integer, allow_nil?: false, public?: true)
    attribute(:consumed_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    timestamps()
  end

  identities do
    identity(:unique_reservation_line, [:reservation_id, :line_item_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])
    create(:create, accept: [:reservation_id, :order_id, :line_item_id, :quantity, :consumed_at])
  end
end
