defmodule Emakola.Stores.Store do
  @moduledoc """
  Store resource — the multi-tenant anchor for Emakola.

  Every merchant can own/manage one or more stores. All ecommerce
  resources (products, orders, payments) are scoped to a store via
  `store_id`.

  Moved from `Emakola.Accounts.Store` to `Emakola.Stores.Store` on
  2026-04-26 — Stores has its own bounded context, distinct from
  user/merchant authentication. `StoreMembership` (the merchant↔store
  bridge) stays in `Accounts`.
  """

  use Ash.Resource,
    domain: Emakola.Stores,
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

    attribute :description, :string do
      public?(true)
    end

    attribute :logo_url, :string do
      public?(true)
    end

    attribute :contact_email, :string do
      public?(true)
    end

    attribute :contact_phone, :string do
      public?(true)
    end

    attribute :address, :string do
      public?(true)
    end

    attribute :city, :string do
      public?(true)
    end

    attribute :region, :string do
      public?(true)
    end

    attribute :whatsapp_number, :string do
      public?(true)
    end

    attribute :active, :boolean do
      default(true)
      public?(true)
    end

    attribute :theme_config, :map do
      default(%{})
      public?(true)
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
    # Reads are open (needed for storefront resolution, internal lookups)
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Creates are open (onboarding creates stores)
    bypass action_type(:create) do
      authorize_if(always())
    end

    # Writes (update, destroy): nil actor → deny; non-Merchant → deny;
    # Merchant must have store access. System code uses `authorize?: false`.
    policy action_type([:update, :destroy]) do
      forbid_unless(actor_present())
      forbid_unless(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :slug, :currency])
    end

    update :update do
      accept([:name, :currency, :theme_config])
    end

    update :update_settings do
      accept([
        :name,
        :description,
        :logo_url,
        :contact_email,
        :contact_phone,
        :address,
        :city,
        :region,
        :whatsapp_number,
        :active,
        :theme_config
      ])
    end
  end
end
