defmodule Emakola.Suppliers.SupplierLedgerEntry do
  @moduledoc """
  Payout ledger entry recording what a store owes a supplier for a single
  dropship fulfillment.

  One entry is created per supplier fulfillment at checkout, capturing the
  total supplier cost (`amount_owed`, minor units). Entries start `:owed` and
  transition to `:paid` once the merchant settles with the supplier. Entries
  are financial records — there is no destroy action.
  """

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("supplier_ledger_entries")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :supplier_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :fulfillment_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :amount_owed, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 0)
    end

    attribute :status, :atom do
      constraints(one_of: [:owed, :paid])
      default(:owed)
      allow_nil?(false)
      public?(true)
    end

    attribute :paid_at, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_fulfillment_ledger, [:fulfillment_id])
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      source_attribute(:store_id)
    end

    belongs_to :supplier, Emakola.Suppliers.Supplier do
      define_attribute?(false)
      source_attribute(:supplier_id)
    end

    belongs_to :fulfillment, Emakola.Orders.Fulfillment do
      define_attribute?(false)
      source_attribute(:fulfillment_id)
    end
  end

  policies do
    # Internal/system calls (nil actor) are allowed
    bypass always() do
      authorize_unless(actor_present())
    end

    # Merchant actors: verify store membership for writes
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :supplier_id, :fulfillment_id, :amount_owed, :status])
    end

    update :mark_paid do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Orders.Validations.StatusGuard,
         from: [:owed], message: "only an owed entry can be marked paid"}
      )

      change(set_attribute(:status, :paid))
      change(set_attribute(:paid_at, &DateTime.utc_now/0))
    end

    read :list_by_supplier do
      argument(:supplier_id, :uuid, allow_nil?: false)

      filter(expr(supplier_id == ^arg(:supplier_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end
  end
end
