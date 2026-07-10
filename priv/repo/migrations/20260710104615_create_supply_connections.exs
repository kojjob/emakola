defmodule Emakola.Repo.Migrations.CreateSupplyConnections do
  use Ecto.Migration

  def change do
    create table(:supply_connections, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :wholesaler_store_id,
          references(:stores, type: :uuid, on_delete: :restrict),
          null: false

      add :reseller_store_id,
          references(:stores, type: :uuid, on_delete: :restrict),
          null: false

      add :requested_by_store_id,
          references(:stores, type: :uuid, on_delete: :restrict),
          null: false

      add :status, :text, null: false, default: "pending"
      add :status_reason, :text
      add :terms, :map, null: false, default: %{}
      add :approved_at, :utc_datetime_usec
      add :status_changed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:supply_connections, [:wholesaler_store_id, :reseller_store_id],
             name: :supply_connections_unique_store_pair_index
           )

    create index(:supply_connections, [:wholesaler_store_id, :status])
    create index(:supply_connections, [:reseller_store_id, :status])

    create constraint(:supply_connections, :different_supply_connection_stores,
             check: "wholesaler_store_id <> reseller_store_id"
           )
  end
end
