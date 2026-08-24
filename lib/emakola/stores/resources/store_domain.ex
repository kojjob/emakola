defmodule Emakola.Stores.StoreDomain do
  @moduledoc """
  Maps a hostname to a store — the lookup that lets a branded host resolve to a
  storefront (`yourshop.makola.io` now via `:subdomain`; `yourshop.com` later
  via `:custom`, Phase 6).

  Deliberately NOT tenant-scoped: this is the table that *resolves* the tenant
  from an incoming host, so it must be queryable before any tenant context
  exists. `host` is globally unique and stored normalized (lowercase).

  A `:subdomain` row 301-redirects to the canonical `/s/:slug` subfolder by
  default; a merchant can flip `serve_in_place?` to keep the branded host in
  the address bar.

  A `:custom` row behaves differently on purpose. It always serves in place,
  and once it is `:active` and `primary?` it *becomes* the store's canonical
  URL — reversing the Phase 0 stance that authority always consolidates on the
  subfolder. A merchant paying for their own domain and still seeing the
  platform host in Google is the feature not working.

  ## Lifecycle

  `:subdomain` rows are created `:active` and stay there. A `:custom` row walks
  a state machine, and `status`/`verified_at` are never in an `accept` list —
  each transition is its own action:

      :pending    merchant submitted; awaiting staff review
        |  request_domain_verification (staff)
      :verifying  certificate requested, DNS being polled
        |  mark_domain_active (worker, once Fly reports "Ready")
      :active     serving
        |  expire_store_domain (sweeper timeout, or staff revoke)
      :expired    terminal; releases the host for someone else to claim
  """

  use Ash.Resource,
    domain: Emakola.Stores,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("store_domains")
    repo(Emakola.Repo)

    identity_wheres_to_sql(
      unique_host: "status != 'expired'",
      one_primary_per_store: "\"primary?\" = TRUE"
    )
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
      constraints(one_of: [:pending, :verifying, :active, :expired])
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

    # The last thing we heard from Fly, or why the domain was expired. Shown to
    # both the merchant and platform staff, so keep it readable.
    attribute :status_reason, :string do
      public?(true)
    end

    # When verification started — the expiry clock. `updated_at` cannot serve:
    # every certificate poll rewrites it.
    attribute :verifying_since, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  identities do
    # Scoped to non-expired rows so an abandoned claim stops holding a hostname
    # hostage — without this, one merchant claiming `nike.com` locks it forever.
    identity(:unique_host, [:host], where: expr(status != :expired))

    identity(:one_primary_per_store, [:store_id], where: expr(primary? == true))
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

  changes do
    # Global, not per action: every transition must drop the cached host and the
    # store's cached primary host, and a new action must not be able to forget.
    change(Emakola.Stores.Changes.InvalidateDomainCache, on: [:create, :update, :destroy])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:store_id, :host, :type, :serve_in_place?, :primary?])
      change(Emakola.Stores.Changes.NormalizeHost)
      validate(Emakola.Stores.Validations.ValidStoreHost)
    end

    update :update do
      # SafePrimaryDomain has to read changeset.data to know the row's current
      # status, which an atomic update cannot provide.
      require_atomic?(false)
      accept([:serve_in_place?, :primary?])
      validate(Emakola.Stores.Validations.SafePrimaryDomain)
    end

    # ---- custom-domain lifecycle -------------------------------------------
    # `status` and `verified_at` are deliberately absent from every accept list.
    # The only way to move a domain is through one of these named transitions.

    create :claim_custom do
      accept([:store_id, :host])
      # Domains.claim/3 wraps an apex claim + its www sibling in one
      # transaction. The cache hook is clear-only and claim/3 clears again
      # after the real commit, so the nested-hook warning is noise here.
      change(set_context(%{warn_on_transaction_hooks?: false}))
      change(set_attribute(:type, :custom))
      change(set_attribute(:status, :pending))
      # Structural half of the self-301 fix: a custom domain never redirects,
      # so it can never redirect to its own canonical.
      change(set_attribute(:serve_in_place?, true))
      change(set_attribute(:primary?, false))
      change(Emakola.Stores.Changes.NormalizeHost)
      validate(Emakola.Stores.Validations.ValidStoreHost)
    end

    # The automatic `www.` sibling for an apex claim. Redirects to the primary,
    # so a merchant who wires only the apex does not end up with a dead `www.`.
    create :claim_custom_alias do
      accept([:store_id, :host])
      # Domains.claim/3 wraps an apex claim + its www sibling in one
      # transaction. The cache hook is clear-only and claim/3 clears again
      # after the real commit, so the nested-hook warning is noise here.
      change(set_context(%{warn_on_transaction_hooks?: false}))
      change(set_attribute(:type, :custom))
      change(set_attribute(:status, :pending))
      change(set_attribute(:serve_in_place?, false))
      change(set_attribute(:primary?, false))
      change(Emakola.Stores.Changes.NormalizeHost)
      validate(Emakola.Stores.Validations.ValidStoreHost)
    end

    update :request_verification do
      require_atomic?(false)
      accept([])
      validate({Emakola.Stores.Validations.DomainStatusIn, from: [:pending]})
      change(set_attribute(:status, :verifying))
      change(set_attribute(:verifying_since, &DateTime.utc_now/0))
      change(set_attribute(:status_reason, nil))
    end

    update :record_check do
      require_atomic?(false)
      accept([])
      argument(:message, :string, allow_nil?: true)
      change(set_attribute(:status_reason, arg(:message)))
    end

    update :mark_active do
      require_atomic?(false)
      accept([])
      validate({Emakola.Stores.Validations.DomainStatusIn, from: [:verifying]})
      change(set_attribute(:status, :active))
      change(set_attribute(:verified_at, &DateTime.utc_now/0))
      change(set_attribute(:status_reason, nil))
    end

    update :expire do
      require_atomic?(false)
      accept([])
      argument(:reason, :string, allow_nil?: false)
      change(set_attribute(:status, :expired))
      change(set_attribute(:status_reason, arg(:reason)))
      # Both must be cleared: canonical reads primary?, and a stale verified_at
      # would let a re-activation skip verification.
      change(set_attribute(:primary?, false))
      change(set_attribute(:verified_at, nil))
    end

    update :make_primary do
      require_atomic?(false)
      accept([])
      validate({Emakola.Stores.Validations.DomainStatusIn, from: [:active]})
      change(Emakola.Stores.Changes.DemoteSiblingPrimaries)
      change(set_attribute(:primary?, true))
    end

    # Internal, used only by DemoteSiblingPrimaries. Skips SafePrimaryDomain,
    # which exists to stop a merchant promoting a dead host — never demotion.
    update :demote_primary do
      require_atomic?(false)
      accept([])
      # Runs inside make_primary's transaction. The cache hook is clear-only,
      # and make_primary's own hook clears the same keys at the real commit.
      change(set_context(%{warn_on_transaction_hooks?: false}))
      change(set_attribute(:primary?, false))
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

    read :list_verifying do
      filter(expr(type == :custom and status == :verifying))
      prepare(build(sort: [verifying_since: :asc]))
    end

    read :list_custom_for_review do
      argument(:status, :atom, allow_nil?: true)

      filter(expr(type == :custom and (is_nil(^arg(:status)) or status == ^arg(:status))))
      prepare(build(sort: [inserted_at: :asc], load: [:store]))
    end

    # The canonical lookup: only a live, primary, custom host may replace the
    # platform URL for a store.
    read :get_primary_by_slug do
      get?(true)
      argument(:slug, :string, allow_nil?: false)

      filter(
        expr(
          type == :custom and status == :active and primary? == true and
            store.slug == ^arg(:slug)
        )
      )
    end
  end
end
