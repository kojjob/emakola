defmodule Emakola.Suppliers.SupplyConnection do
  @moduledoc """
  A consented wholesaler↔reseller relationship for Makola Earn.

  Mutations are intentionally system-only at the resource policy layer. The
  public `Emakola.Suppliers.Network` service verifies that the acting merchant
  belongs to the correct initiating or counterparty store before calling them.
  """

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("supply_connections")
    repo(Emakola.Repo)

    check_constraints do
      check_constraint(:wholesaler_store_id,
        name: "different_supply_connection_stores",
        message: "wholesaler and reseller must be different stores"
      )
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:wholesaler_store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:reseller_store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:requested_by_store_id, :uuid, allow_nil?: false, public?: true)

    attribute :status, :atom do
      constraints(one_of: [:pending, :active, :rejected, :suspended, :terminated])
      allow_nil?(false)
      default(:pending)
      public?(true)
    end

    attribute(:status_reason, :string, public?: true)
    attribute(:terms, :map, allow_nil?: false, default: %{}, public?: true)
    attribute(:approved_at, :utc_datetime_usec, public?: true)
    attribute(:status_changed_at, :utc_datetime_usec, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :wholesaler_store, Emakola.Stores.Store do
      source_attribute(:wholesaler_store_id)
      define_attribute?(false)
      public?(true)
    end

    belongs_to :reseller_store, Emakola.Stores.Store do
      source_attribute(:reseller_store_id)
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_store_pair, [:wholesaler_store_id, :reseller_store_id])
  end

  policies do
    # All user-facing access goes through Suppliers.Network, which verifies
    # membership for both reads and writes before using authorize?: false.
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :request do
      accept([:wholesaler_store_id, :reseller_store_id, :requested_by_store_id, :terms])
    end

    update :approve do
      require_atomic?(false)
      accept([])
      validate({Emakola.Validations.StatusGuard, from: [:pending]})
      change(set_attribute(:status, :active))
      change(set_attribute(:approved_at, &DateTime.utc_now/0))
      change(set_attribute(:status_changed_at, &DateTime.utc_now/0))
    end

    update :reject do
      require_atomic?(false)
      accept([:status_reason])
      validate({Emakola.Validations.StatusGuard, from: [:pending]})
      change(set_attribute(:status, :rejected))
      change(set_attribute(:status_changed_at, &DateTime.utc_now/0))
    end

    update :suspend do
      require_atomic?(false)
      accept([:status_reason])
      validate({Emakola.Validations.StatusGuard, from: [:active]})
      change(set_attribute(:status, :suspended))
      change(set_attribute(:status_changed_at, &DateTime.utc_now/0))
    end

    update :reactivate do
      require_atomic?(false)
      accept([])
      validate({Emakola.Validations.StatusGuard, from: [:suspended]})
      change(set_attribute(:status, :active))
      change(set_attribute(:status_reason, nil))
      change(set_attribute(:status_changed_at, &DateTime.utc_now/0))
    end

    update :terminate do
      require_atomic?(false)
      accept([:status_reason])
      validate({Emakola.Validations.StatusGuard, from: [:pending, :active, :suspended]})
      change(set_attribute(:status, :terminated))
      change(set_attribute(:status_changed_at, &DateTime.utc_now/0))
    end

    read :for_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(wholesaler_store_id == ^arg(:store_id) or reseller_store_id == ^arg(:store_id)))

      prepare(build(sort: [inserted_at: :desc]))
    end
  end
end
