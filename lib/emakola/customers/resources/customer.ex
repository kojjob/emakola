defmodule Emakola.Customers.Customer do
  @moduledoc """
  Customer resource — store-scoped customer accounts.

  Each store maintains its own customer list. The same email can exist across
  different stores but must be unique within a single store.

  Used for order attribution, repeat-purchase tracking, and customer communications.
  """

  use Ash.Resource,
    domain: Emakola.Customers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("customers")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :email, :ci_string do
      allow_nil?(false)
      public?(true)
    end

    attribute :name, :string do
      public?(true)
    end

    attribute :phone, :string do
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end

    has_many :orders, Emakola.Orders.Order
  end

  aggregates do
    count(:order_count, :orders)
  end

  identities do
    identity(:unique_store_email, [:store_id, :email])
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:email, :name, :phone, :store_id])
    end

    update :update do
      accept([:name, :phone])
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, inserted_at: :desc)
      end)
    end

    read :search do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:query, :string, allow_nil?: false)

      prepare(Emakola.Customers.Preparations.SearchCustomers)
    end

    read :get_by_id do
      get?(true)
      argument(:id, :uuid, allow_nil?: false)

      filter(expr(id == ^arg(:id)))
    end
  end
end
