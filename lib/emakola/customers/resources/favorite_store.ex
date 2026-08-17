defmodule Emakola.Customers.FavoriteStore do
  @moduledoc """
  FavoriteStore — a customer's ♡ on a store from the public /stores
  marketplace directory.

  Cross-tenant by design: the same customer record may favorite multiple
  stores, so this resource has no `multitenancy` block. The composite
  identity `(customer_id, store_id)` keeps duplicates impossible while
  still allowing upserts on repeated taps of the heart toggle.

  Authorization: read/create/destroy require an actor whose `:id` matches
  `customer_id`. System code can opt out with `authorize?: false`.
  """

  use Ash.Resource,
    domain: Emakola.Customers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("customer_favorite_stores")
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

  identities do
    identity(:unique_customer_store, [:customer_id, :store_id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:customer_id, :store_id])
      upsert?(true)
      upsert_identity(:unique_customer_store)
    end

    read :list_for_customer do
      argument(:customer_id, :uuid, allow_nil?: false)

      filter(expr(customer_id == ^arg(:customer_id)))

      prepare(build(load: [store: [:card_image_url]], sort: [inserted_at: :desc]))
    end
  end

  policies do
    # Read / destroy: actor's :id must match the row's customer_id
    policy action_type([:read, :destroy]) do
      forbid_unless(actor_present())
      authorize_if(expr(customer_id == ^actor(:id)))
    end

    # Create: filter expressions can't reference the not-yet-created row, so
    # check the inbound attribute against the actor with a custom check.
    policy action_type(:create) do
      forbid_unless(actor_present())
      authorize_if(Emakola.Customers.Checks.FavoriteStoreOwnedByActor)
    end
  end
end
