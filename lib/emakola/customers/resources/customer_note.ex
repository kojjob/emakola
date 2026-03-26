defmodule Emakola.Customers.CustomerNote do
  @moduledoc """
  Merchant-added notes about a customer.

  Notes track observations, preferences, or special instructions about
  a customer. The author_id references the merchant user who created
  the note; it is nullable for system-generated notes.

  Multi-tenancy: scoped to store_id (denormalized from customer).
  """

  use Ash.Resource,
    domain: Emakola.Customers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("customer_notes")
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

    attribute :author_id, :uuid do
      public?(true)
    end

    attribute :content, :string do
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

    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :author, Emakola.Accounts.Merchant do
      define_attribute?(false)
      public?(true)
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
    defaults([:read, :destroy])

    create :create do
      accept([:customer_id, :store_id, :author_id, :content])
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
          |> Ash.Query.sort(inserted_at: :desc)
          |> Ash.read!()

        {:ok, results}
      end)
    end
  end
end
