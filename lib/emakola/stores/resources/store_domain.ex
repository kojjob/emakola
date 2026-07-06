defmodule Emakola.Stores.StoreDomain do
  @moduledoc """
  Maps a hostname to a store — the lookup that lets a branded host resolve to a
  storefront (`yourshop.makola.io` now via `:subdomain`; `yourshop.com` later
  via `:custom`, Phase 6).

  Deliberately NOT tenant-scoped: this is the table that *resolves* the tenant
  from an incoming host, so it must be queryable before any tenant context
  exists. `host` is globally unique and stored normalized (lowercase).

  By default a domain 301-redirects to the canonical `/s/:slug` subfolder (SEO
  authority consolidation — the Phase 0 strategy). A merchant can flip
  `serve_in_place?` to keep the branded host in the address bar; the page's
  canonical still points at the subfolder.
  """

  use Ash.Resource,
    domain: Emakola.Stores,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("store_domains")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    # Fully-qualified, normalized (lowercase) host, e.g. "ama-kitchen.makola.io".
    attribute :host, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :type, :atom do
      allow_nil?(false)
      default(:subdomain)
      constraints(one_of: [:subdomain, :custom])
      public?(true)
    end

    attribute :status, :atom do
      allow_nil?(false)
      default(:active)
      constraints(one_of: [:pending, :active])
      public?(true)
    end

    # false (default) → 301-redirect this host to /s/:slug.
    # true            → serve the store on this host (canonical → /s/:slug).
    attribute :serve_in_place?, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    attribute :primary?, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    attribute :verified_at, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_host, [:host])
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      source_attribute(:store_id)
      define_attribute?(false)
    end
  end

  policies do
    # Host resolution (the routing plug) reads with authorize?: false.
    # Merchant actors may manage domains for stores they have access to.
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:store_id, :host, :type, :serve_in_place?, :primary?])
      change(Emakola.Stores.Changes.NormalizeHost)
      validate(Emakola.Stores.Validations.ValidStoreHost)
    end

    update :update do
      accept([:serve_in_place?, :primary?])
    end

    read :get_by_host do
      get?(true)
      argument(:host, :string, allow_nil?: false)
      filter(expr(host == ^arg(:host)))
    end

    read :list_for_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
    end
  end
end
