defmodule Emakola.Repo.Migrations.AddDispatchFeeSnapshots do
  use Ecto.Migration

  # Snapshot of the supplier dispatch fee charged at checkout, integer
  # pesewas. Lives on the fulfillment (one per supplier per order) with the
  # order-level sum denormalized for totals math and display.
  def change do
    alter table(:fulfillments) do
      add :dispatch_fee, :integer, null: false, default: 0
    end

    alter table(:orders) do
      add :dispatch_fee_total, :integer, null: false, default: 0
    end
  end
end
