defmodule Emakola.Suppliers.Supplier do
  @moduledoc """
  Supplier resource representing a third-party source for dropshipped products.

  Each store manages its own suppliers. Payment details (MoMo number, bank info)
  are stored as a free-form map. Suppliers are unique per store by name.
  """

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("suppliers")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :contact_phone, :string do
      public?(true)
    end

    attribute :whatsapp_number, :string do
      public?(true)
    end

    attribute :contact_email, :string do
      public?(true)
    end

    attribute :payment_details, :map do
      public?(true)
    end

    attribute :notes, :string do
      public?(true)
    end

    attribute :active, :boolean do
      default(true)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_store_supplier_name, [:store_id, :name])
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      attribute_writable?(true)
      define_attribute?(false)
      source_attribute(:store_id)
    end

    has_many :supplier_ledger_entries, Emakola.Suppliers.SupplierLedgerEntry
  end

  aggregates do
    sum :outstanding_balance, :supplier_ledger_entries, :amount_owed do
      filter(expr(status == :owed))
      default(0)
    end
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

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
      accept([
        :store_id,
        :name,
        :contact_phone,
        :whatsapp_number,
        :contact_email,
        :payment_details,
        :notes,
        :active
      ])
    end

    update :update do
      accept([
        :name,
        :contact_phone,
        :whatsapp_number,
        :contact_email,
        :payment_details,
        :notes,
        :active
      ])
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [name: :asc]))
    end
  end
end
