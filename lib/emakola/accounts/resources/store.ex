defmodule Emakola.Accounts.Store do
  @moduledoc """
  Store resource — the multi-tenant anchor for Emakola.

  Every merchant can own/manage one or more stores. All ecommerce resources
  (products, orders, payments) are scoped to a store via store_id.

  This is a minimal stub created during Phase 0 cleanup. It will be expanded
  in Step 1.5 with full attributes (domain, timezone, etc.), actions, and
  validations.
  """

  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("stores")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :currency, :string do
      allow_nil?(false)
      default("GHS")
      public?(true)
      constraints(max_length: 3)
    end

    timestamps()
  end

  relationships do
    has_many :store_memberships, Emakola.Accounts.StoreMembership
  end

  identities do
    identity(:unique_slug, [:slug])
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :slug, :currency])
    end

    update :update do
      accept([:name, :currency])
    end
  end
end
