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

    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_customer_product_store, [:customer_id, :product_id, :store_id])
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
          |> Ash.read!()

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
             |> Ash.read_one() do
          {:ok, nil} ->
            {:ok, nil}

          {:ok, item} ->
            Ash.destroy!(item)
            {:ok, item}

          error ->
            error
        end
      end)
    end
  end
end
