defmodule Emakola.Customers.WishlistItem do
  @moduledoc """
  Wishlist item — a customer's saved/favorited product.

  Each item tracks which product a customer has saved to their wishlist.
  The combination of customer_id, product_id, and store_id must be unique
  to prevent duplicate saves.

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
    table("wishlist_items")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :customer_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :product_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :store_id, :uuid do
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

    belongs_to :product, Emakola.Catalog.Product do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_customer_product_store, [:customer_id, :product_id, :store_id])
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

    # Customer actors: scoped by tenant via multitenancy attribute.
    policy actor_attribute_equals(:__struct__, Emakola.Customers.Customer) do
      authorize_if(always())
    end

    # nil actor falls through to default-deny.
  end

  actions do
    defaults([:read, :destroy])

    create :add do
      accept([:customer_id, :product_id, :store_id])

      upsert?(true)
      upsert_identity(:unique_customer_product_store)
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
          |> Ash.Query.load(product: [:min_price, :max_price, :images, :variants])
          |> Ash.read!(authorize?: false)

        {:ok, results}
      end)
    end

    action :remove, :struct do
      constraints(instance_of: __MODULE__)

      argument :customer_id, :uuid do
        allow_nil?(false)
      end

      argument :product_id, :uuid do
        allow_nil?(false)
      end

      argument :store_id, :uuid do
        allow_nil?(false)
      end

      run(fn input, _context ->
        require Ash.Query

        case __MODULE__
             |> Ash.Query.filter(
               customer_id == ^input.arguments.customer_id and
                 product_id == ^input.arguments.product_id and
                 store_id == ^input.arguments.store_id
             )
             |> Ash.read_one(authorize?: false) do
          {:ok, nil} ->
            {:ok, nil}

          {:ok, item} ->
            Ash.destroy!(item, authorize?: false)
            {:ok, item}

          error ->
            error
        end
      end)
    end
  end
end
