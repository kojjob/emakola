defmodule Emakola.Customers.NewsletterSubscriber do
  @moduledoc """
  Newsletter subscriber — an email captured from a storefront newsletter form.

  Each store maintains its own subscriber list; the same email can exist
  across different stores. The combination of store_id and email must be
  unique, and subscribing is an upsert so re-subscribing an existing email
  is idempotent.

  Multi-tenancy: scoped to store_id.
  """

  use Ash.Resource,
    domain: Emakola.Customers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @email_format ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("newsletter_subscribers")
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
      constraints(max_length: 320, match: @email_format)
    end

    attribute :subscribed_at, :utc_datetime_usec do
      allow_nil?(false)
      default(&DateTime.utc_now/0)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_store_email, [:store_id, :email])
  end

  policies do
    # Creates are permissive (storefront visitors subscribe anonymously;
    # callers ensure store_id comes from the resolved store)
    bypass action_type(:create) do
      authorize_if(always())
    end

    # Merchant actors: verify store membership (for reads)
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # nil actor falls through to default-deny.
  end

  actions do
    defaults([:read, :destroy])

    create :subscribe do
      accept([:email, :store_id])

      upsert?(true)
      upsert_identity(:unique_store_email)
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [subscribed_at: :desc]))
    end
  end
end
