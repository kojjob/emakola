defmodule Emakola.Suppliers.InventoryReservation do
  @moduledoc "Atomic stock hold granted from a transparent commerce-passport eligibility rule."
  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_inventory_reservations")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:policy_id, :uuid, allow_nil?: false, public?: true)
    attribute(:passport_id, :uuid, allow_nil?: false, public?: true)
    attribute(:supplier_store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:reseller_store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:offer_variant_id, :uuid, allow_nil?: false, public?: true)
    attribute(:source_variant_id, :uuid, allow_nil?: false, public?: true)
    attribute(:quantity, :integer, allow_nil?: false, public?: true)
    attribute(:consumed_quantity, :integer, allow_nil?: false, default: 0, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :active,
      public?: true,
      constraints: [one_of: [:active, :consumed, :released, :expired]]
    )

    attribute(:eligibility_snapshot, :map, allow_nil?: false, default: %{}, public?: true)
    attribute(:reason_code, :string, allow_nil?: false, public?: true)
    attribute(:reserved_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:expires_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:released_at, :utc_datetime_usec, public?: true)
    timestamps()
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create(:create,
      accept: [
        :policy_id,
        :passport_id,
        :supplier_store_id,
        :reseller_store_id,
        :offer_variant_id,
        :source_variant_id,
        :quantity,
        :eligibility_snapshot,
        :reason_code,
        :reserved_at,
        :expires_at
      ]
    )

    update :release do
      require_atomic?(false)
      accept([:status])
      change(set_attribute(:released_at, &DateTime.utc_now/0))
    end

    update :record_consumption do
      require_atomic?(false)
      accept([:consumed_quantity, :status])
    end
  end
end
