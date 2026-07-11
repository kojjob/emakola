defmodule Emakola.Repo.Migrations.CreateInventoryEligibilityReservations do
  use Ecto.Migration

  def change do
    create table(:earn_inventory_eligibility_policies, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :supplier_store_id, references(:stores, type: :uuid, on_delete: :delete_all),
        null: false

      add :offer_variant_id,
          references(:supplier_offer_variants, type: :uuid, on_delete: :delete_all), null: false

      add :minimum_tier, :string, null: false
      add :max_quantity_per_reseller, :integer, null: false
      add :reservation_hours, :integer, null: false
      add :reason_code, :string, null: false
      add :active, :boolean, null: false, default: true
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:earn_inventory_eligibility_policies, [:offer_variant_id])

    create constraint(:earn_inventory_eligibility_policies, :inventory_policy_tier_valid,
             check: "minimum_tier IN ('starter', 'reliable', 'proven')"
           )

    create constraint(:earn_inventory_eligibility_policies, :inventory_policy_limits_valid,
             check:
               "max_quantity_per_reseller > 0 AND reservation_hours > 0 AND reservation_hours <= 720"
           )

    create table(:earn_inventory_reservations, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :policy_id,
          references(:earn_inventory_eligibility_policies, type: :uuid, on_delete: :restrict),
          null: false

      add :passport_id, references(:earn_commerce_passports, type: :uuid, on_delete: :restrict),
        null: false

      add :supplier_store_id, references(:stores, type: :uuid, on_delete: :restrict), null: false
      add :reseller_store_id, references(:stores, type: :uuid, on_delete: :restrict), null: false

      add :offer_variant_id,
          references(:supplier_offer_variants, type: :uuid, on_delete: :restrict), null: false

      add :source_variant_id, references(:variants, type: :uuid, on_delete: :restrict),
        null: false

      add :quantity, :integer, null: false
      add :consumed_quantity, :integer, null: false, default: 0
      add :status, :string, null: false, default: "active"
      add :eligibility_snapshot, :map, null: false, default: %{}
      add :reason_code, :string, null: false
      add :reserved_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :released_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create index(:earn_inventory_reservations, [:reseller_store_id, :status])
    create index(:earn_inventory_reservations, [:source_variant_id, :status])

    create constraint(:earn_inventory_reservations, :inventory_reservation_quantity_valid,
             check: "quantity > 0 AND consumed_quantity >= 0 AND consumed_quantity <= quantity"
           )

    create constraint(:earn_inventory_reservations, :inventory_reservation_status_valid,
             check: "status IN ('active', 'consumed', 'released', 'expired')"
           )
  end
end
