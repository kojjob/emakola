defmodule Emakola.Customers.Address do
  @moduledoc """
  Customer address — structured address records for reuse across orders.

  Addresses belong to a customer and store. A customer can have multiple
  addresses with one marked as default. When checking out, the default
  address is used if no shipping address is explicitly provided.

  Multi-tenancy: scoped to store_id (denormalized from customer).
  """

  use Ash.Resource,
    domain: Emakola.Customers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("addresses")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :customer_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :label, :string do
      public?(true)
    end

    attribute :first_name, :string do
      public?(true)
    end

    attribute :last_name, :string do
      public?(true)
    end

    attribute :line_1, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :line_2, :string do
      public?(true)
    end

    attribute :city, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :region, :string do
      public?(true)
    end

    attribute :country, :string do
      default("GH")
      allow_nil?(false)
      public?(true)
    end

    attribute :postal_code, :string do
      public?(true)
    end

    attribute :phone, :string do
      public?(true)
    end

    attribute :is_default, :boolean do
      default(false)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :customer, Emakola.Customers.Customer do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end
  end

  policies do
    # Creates are permissive (callers ensure store_id is valid)
    bypass action_type(:create) do
      authorize_if(always())
    end

    # Generic actions (action :name) — internal helpers, no policy
    bypass action_type(:action) do
      authorize_if(always())
    end

    # Merchant actors: verify store membership (for reads + writes)
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Customer actors: row-scoped reads — only their own addresses within their store.
    policy actor_attribute_equals(:__struct__, Emakola.Customers.Customer) do
      authorize_if(expr(customer_id == ^actor(:id) and store_id == ^actor(:store_id)))
    end

    # nil actor on writes falls through to default-deny. System code must
    # opt in with `authorize?: false`.
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :customer_id,
        :store_id,
        :label,
        :first_name,
        :last_name,
        :line_1,
        :line_2,
        :city,
        :region,
        :country,
        :postal_code,
        :phone
      ])
    end

    update :update do
      require_atomic?(false)

      accept([
        :label,
        :first_name,
        :last_name,
        :line_1,
        :line_2,
        :city,
        :region,
        :country,
        :postal_code,
        :phone
      ])
    end

    # Internal action used only by SetDefaultAddress — not exposed via domain API
    update :toggle_default do
      require_atomic?(false)
      accept([:is_default])
    end

    action :list_by_customer, {:array, :struct} do
      constraints(items: [instance_of: __MODULE__])

      argument :customer_id, :uuid do
        allow_nil?(false)
      end

      argument :store_id, :uuid do
        allow_nil?(false)
      end

      run(fn input, _context ->
        require Ash.Query

        results =
          __MODULE__
          |> Ash.Query.filter(
            customer_id == ^input.arguments.customer_id and
              store_id == ^input.arguments.store_id
          )
          |> Ash.read!(authorize?: false)

        {:ok, results}
      end)
    end

    action :set_as_default, :struct do
      constraints(instance_of: __MODULE__)

      argument :address_id, :uuid do
        allow_nil?(false)
      end

      run(Emakola.Customers.Actions.SetDefaultAddress)
    end
  end
end
