defmodule Emakola.Repo.Migrations.AddFulfillments do
  @moduledoc """
  Phase 2 of the dropshipping feature.

  Creates the `fulfillments` table — per-supplier (or merchant-owned) shipment
  groups within an order — and links line items to a fulfillment via a nullable
  `fulfillment_id`. Also snapshots the supplier `cost_price` on each line item
  at order time for downstream payout reconciliation.

  A fulfillment with a `supplier_id` is a dropship group; a nil supplier_id is
  the merchant's own-stock group.
  """
  use Ecto.Migration

  def change do
    create table(:fulfillments, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :store_id,
          references(:stores, type: :uuid, on_delete: :delete_all),
          null: false

      add :order_id,
          references(:orders, type: :uuid, on_delete: :delete_all),
          null: false

      add :supplier_id,
          references(:suppliers, type: :uuid, on_delete: :nilify_all)

      add :status, :string, null: false, default: "pending"
      add :tracking_number, :string
      add :notified_at, :utc_datetime_usec
      add :notified_via, :string

      timestamps(type: :utc_datetime_usec)
    end

    alter table(:line_items) do
      add :fulfillment_id,
          references(:fulfillments, type: :uuid, on_delete: :nilify_all)

      add :cost_price, :integer
    end

    create index(:fulfillments, [:order_id])
    create index(:fulfillments, [:supplier_id])
    create index(:fulfillments, [:store_id])
    create index(:line_items, [:fulfillment_id])
  end
end
