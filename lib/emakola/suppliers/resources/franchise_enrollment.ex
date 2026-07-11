defmodule Emakola.Suppliers.FranchiseEnrollment do
  @moduledoc "A reseller's explicit acceptance and supplier approval for a micro-franchise package."
  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_franchise_enrollments")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:package_id, :uuid, allow_nil?: false, public?: true)
    attribute(:reseller_store_id, :uuid, allow_nil?: false, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :applied,
      public?: true,
      constraints: [one_of: [:applied, :approved, :declined, :suspended, :ended]]
    )

    attribute(:terms_accepted_at, :utc_datetime_usec, public?: true)
    attribute(:approved_at, :utc_datetime_usec, public?: true)

    attribute(:activated_listing_ids, {:array, :uuid},
      allow_nil?: false,
      default: [],
      public?: true
    )

    timestamps()
  end

  relationships do
    belongs_to :package, Emakola.Suppliers.FranchisePackage do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :reseller_store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_package_reseller, [:package_id, :reseller_store_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :apply do
      accept([:package_id, :reseller_store_id, :terms_accepted_at])
    end

    update :approve do
      require_atomic?(false)
      accept([:activated_listing_ids])
      validate(attribute_equals(:status, :applied))
      change(set_attribute(:status, :approved))
      change(set_attribute(:approved_at, &DateTime.utc_now/0))
    end

    update :decline do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :applied))
      change(set_attribute(:status, :declined))
    end
  end
end
