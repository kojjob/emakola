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
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type("store")
  end

  postgres do
    table("stores")
    repo(Emakola.Repo)

    custom_indexes do
      # Every public directory read and the storefront resolver filter on
      # `status`; index it so suspended/archived stores are cheap to exclude.
      index([:status])
    end
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

    # GhanaPost GPS digital address (e.g. GA-183-8164) — optional, normalized
    # and validated by Emakola.Changes.NormalizeDigitalAddress on write.
    attribute :digital_address, :string do
      public?(true)
    end

    # Free-text delivery hint (e.g. "behind Achimota Melcom, blue gate").
    attribute :landmark, :string do
      public?(true)
      constraints(max_length: 200)
    end

    attribute :whatsapp_number, :string do
      public?(true)
    end

    # Social URLs — null for stores that haven't connected the platform.
    # Footers render zero icons when all are nil (same as before).
    attribute :instagram_url, :string do
      public?(true)
    end

    attribute :tiktok_url, :string do
      public?(true)
    end

    attribute :facebook_url, :string do
      public?(true)
    end

    attribute :youtube_url, :string do
      public?(true)
    end

    attribute :x_url, :string do
      public?(true)
    end

    # Set when the merchant connects their WhatsApp Business Catalog.
    # When present, product publish/update events enqueue a mirror sync.
    # Nil = no catalog connected; sync worker skips silently.
    attribute :whatsapp_catalog_id, :string do
      public?(true)
    end

    # Merchant-owned open/closed switch. The merchant flips this themselves
    # (e.g. holiday closure). Distinct from `status` below, which is the
    # PLATFORM's lifecycle control. A store is publicly live only when BOTH
    # agree: `active == true and status == :active` (see `live?/1`).
    attribute :active, :boolean do
      default(true)
      public?(true)
    end

    # Merchant opt-in for TC-2 Buyer Protection (escrow-lite payout hold): off
    # by default. New PayLinks inherit this value at creation unless the
    # merchant explicitly overrides it per link (see `PayLink.protected`).
    # Deliberately opt-in, revisited 2026-08-04. Turning it on does not merely
    # delay a payout: OrderSettlement.prepare/2 returns {:hold, :buyer_protection},
    # which attaches NO merchant gateway share — the whole charge stays in the
    # platform account until release. That makes Makola custodian of the
    # merchant's money between sale and delivery, which is an escrow-shaped
    # arrangement rather than a settings toggle.
    #
    # So the fix for "almost nobody opts in" is to ASK, not to decide for them:
    # see the onboarding prompt. A merchant who turns it on gets the delivery
    # OTP (Orders.CustomerDelivery) as the proof that releases the hold.
    attribute :buyer_protection_enabled, :boolean do
      default(false)
      public?(true)
    end

    # Platform-owned lifecycle state. Merchants cannot change this — only
    # platform staff, via the `:suspend`/`:block`/`:archive`/`:reactivate`
    # actions. `:archived` is the "delete" (hidden forever, row kept, no
    # cascade/purge — restorable since nothing is destroyed).
    attribute :status, :atom do
      allow_nil?(false)
      default(:active)
      public?(true)
      constraints(one_of: [:active, :suspended, :blocked, :archived])
    end

    # What this row IS. `:shop` is a real store with a storefront; a
    # `:affiliate_payout` row is a payout container for an affiliate who has
    # no shop — it exists only because every payout rail here is keyed to a
    # store id, and it must never appear anywhere a shop appears.
    #
    # Explicit rather than leaning on `active: false`: a merchant reopening
    # their shop flips `active`, and a payout container must not become
    # visible by accident.
    attribute :kind, :atom do
      allow_nil?(false)
      default(:shop)
      public?(true)
      constraints(one_of: [:shop, :affiliate_payout])
    end

    # Why the store is in its current non-active status. Surfaced to the
    # merchant on the lockout screen; nil when `:active`.
    attribute :status_reason, :string do
      public?(true)
    end

    # When `status` last changed — denormalized convenience for the admin UI.
    # The append-only platform audit log remains the system of record for the
    # full who/when/why history.
    attribute :status_changed_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :theme_config, :map do
      default(%{})
      public?(true)
    end

    # ── Directory fields (drive `/stores` marketplace) ──

    # Admin pin: forces this store to top of the directory carousel.
    attribute :featured, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    # Manual ordering within featured. Lower numbers appear first.
    # Nil = not in the manual rank; falls back to view_count desc.
    # When the shop entered the featured set. Stamped by FeaturedRanking on
    # feature, cleared on unfeature; rank moves never touch it. Display-only
    # today — it exists so featured tenure is answerable from the day the
    # first shop was featured, not from the day someone asks.
    # ── Directory read cache ──
    # Written only by the featuring worker (and DirectoryCuration), read by
    # the public slot queries so they stay plain indexed column filters. The
    # standing row holds the explanation; these hold the answer.
    #
    # directory_eligible defaults TRUE — fail-open. A fail-closed default
    # would empty the directory between this migration landing and the first
    # worker run: an outage on deploy. The worker only flips it false for
    # stores it has assessed and has evidence against.
    attribute :directory_eligible, :boolean do
      allow_nil?(false)
      default(true)
      public?(false)
    end

    attribute :directory_score, :integer do
      allow_nil?(true)
      public?(false)
    end

    attribute :directory_slot, :atom do
      allow_nil?(true)
      constraints(one_of: [:spotlight, :rising, :editors_pick, :promoted])
      public?(false)
    end

    attribute :featured_at, :utc_datetime_usec do
      allow_nil?(true)
      public?(true)
    end

    attribute :featured_rank, :integer do
      public?(true)
    end

    # Trust badge — admin sets after review.
    attribute :verified, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    # What the badge actually rests on. A badge that does not say what was
    # checked is the placebo pattern; this is what lets the storefront say
    # something different about a store proven by its wallet than about one
    # grandfathered in from the retired national-ID flow.
    #
    #   :retired_document_flow — approved before L.I. 2523; a human looked at
    #                            a Ghana Card image. Never awarded again.
    #   :business_review       — staff checked the shop's business paper (a
    #                            licence or tax receipt). Says nothing about
    #                            who the person is.
    #   :wallet_proof          — the merchant proved control of the payout
    #                            wallet, which the telco KYC'd against a
    #                            Ghana Card.
    #   :nia_biometric         — verified through an accredited NIA IVSP
    #                            partner. Not yet built.
    # When the current basis was stamped. Dates the claim so an approval under
    # the retired Ghana Card flow can lapse rather than stand forever on a
    # check nobody is allowed to repeat. See `Emakola.Stores.TrustBadge`.
    attribute :verified_basis_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :verified_basis, :atom do
      constraints(
        one_of: [:retired_document_flow, :business_review, :wallet_proof, :nia_biometric]
      )

      public?(true)
    end

    # 16:9 banner shown above the card on /stores. Falls back to a
    # theme-color gradient when nil.
    attribute :cover_image_url, :string do
      public?(true)
    end

    # Atomic counter incremented on every storefront page load (debounced
    # per session). Drives the "Most popular" sort.
    attribute :view_count, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    # One-line shop pitch shown above description on the directory card.
    attribute :tagline, :string do
      public?(true)
      constraints(max_length: 140)
    end

    attribute :enabled_product_types, {:array, :atom} do
      public?(true)
      allow_nil?(false)
      default([:physical])

      constraints(
        items: [
          one_of: [
            :physical,
            :digital_download,
            :license_key,
            :streaming,
            :course,
            :auction,
            :print_on_demand
          ]
        ]
      )
    end

    timestamps()
  end

  relationships do
    has_many :store_memberships, Emakola.Accounts.StoreMembership
    has_many :products, Emakola.Catalog.Product

    # ── Directory signal sources ──
    # These exist so the featuring worker can load every merit signal for the
    # whole population in one query. Nothing storefront-facing loads them.
    has_many :orders, Emakola.Orders.Order
    has_many :returns, Emakola.Orders.Return
    has_many :reviews, Emakola.Catalog.Review
    has_many :payments, Emakola.Payments.Payment
    has_many :protection_holds, Emakola.Payments.ProtectionHold
    has_one :payout_account, Emakola.Stores.StorePayoutAccount
    has_one :verification, Emakola.Stores.StoreVerification
  end

  aggregates do
    # Active products count — powers the "86 products" line on the card
    # and the "Most popular" tiebreaker on the main grid sort.
    count :product_count, :products do
      filter(expr(status == :active))
    end

    # The newest photo on an active product — the directory card's fallback
    # when the merchant hasn't set a cover image, so shop cards show real
    # goods instead of a gradient placeholder. Draft products stay invisible.
    first :card_image_url, [:products, :images], :url do
      filter(expr(product.status == :active))
      sort(inserted_at: :desc)
    end

    # The same first image's webp variant, when the processor has made one.
    # Same filter and sort as :card_image_url so both describe one photo.
    first :card_image_medium_url, [:products, :images], :medium_url do
      filter(expr(product.status == :active))
      sort(inserted_at: :desc)
    end

    # ── Directory merit signals ──
    # Inputs to DirectoryScore and DirectoryEligibility, loaded in one shot by
    # the nightly featuring worker. 90-day windows because the directory
    # rewards recent behaviour, not lifetime totals.

    count :delivered_order_count_90d, :orders do
      filter(expr(status == :delivered and inserted_at > ago(90, :day)))
    end

    count :cancelled_order_count_90d, :orders do
      filter(expr(status == :cancelled and inserted_at > ago(90, :day)))
    end

    max(:last_order_at, :orders, :inserted_at)

    max(:last_product_published_at, :products, :published_at)

    count :successful_payment_count_90d, :payments do
      filter(expr(status == :success and inserted_at > ago(90, :day)))
    end

    # :partially_refunded is not a Payment status — partial refunds live in
    # refunded_amount > 0 alongside status: :success, so both shapes count.
    count :refunded_payment_count_90d, :payments do
      filter(expr((status == :refunded or refunded_amount > 0) and inserted_at > ago(90, :day)))
    end

    count :taken_down_product_count_90d, :products do
      filter(expr(moderation_status == :taken_down and moderation_at > ago(90, :day)))
    end

    # Reviews count regardless of :status — a merchant can hide a bad review,
    # and a hidden one-star still counts against merit. verified_purchase is
    # the gate, enforced by PurchaseVerifier plus a unique identity.
    count :verified_review_count, :reviews do
      filter(expr(verified_purchase == true))
    end

    sum :verified_review_rating_sum, :reviews, :rating do
      filter(expr(verified_purchase == true))
    end

    # :changed_mind is deliberately absent — a buyer changing their mind is
    # not the merchant's fault.
    count :merchant_fault_return_count_90d, :returns do
      filter(
        expr(
          reason in [:defective, :wrong_item, :not_as_described] and status == :refunded and
            inserted_at > ago(90, :day)
        )
      )
    end

    count :staff_refunded_hold_count_90d, :protection_holds do
      filter(expr(resolution == :refunded_by_staff and inserted_at > ago(90, :day)))
    end

    exists :payout_verified, :payout_account do
      filter(expr(verification_status == :verified))
    end

    # Reads the real KYC record, never the manual Store.verified boolean an
    # admin can set with no verification behind it.
    exists :kyc_approved, :verification do
      filter(expr(status == :approved))
    end
  end

  identities do
    identity(:unique_slug, [:slug])
  end

  policies do
    # Creates: only an authenticated Merchant actor may create a store. This
    # bypass short-circuits the Merchant-membership read policy below — a
    # brand-new store has no memberships yet, so that policy would otherwise
    # forbid the create. Onboarding creates via `authorize?: false` (guarded by
    # the `is_nil(user)` check in OnboardingLive) and does not rely on this.
    bypass action_type(:create) do
      authorize_if(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
    end

    # Belt-and-braces for `:create` with `authorize?: true`: a nil or
    # non-Merchant (e.g. Customer) actor is explicitly forbidden. This replaces
    # a former blanket `authorize_if(always())` that let any actor create stores.
    policy action_type(:create) do
      forbid_unless(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
      authorize_if(always())
    end

    # System/internal reads with no actor — allow. This covers:
    # - StoreMembership manage_relationship lookups during onboarding (no actor is set)
    # - Storefront slug resolution and pipeline code using authorize?: false
    # All nil-actor callers are trusted internal Elixir code, never raw HTTP actors.
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    # Merchant reads: filtered to stores the actor has a StoreMembership for.
    # The expr adds a SQL EXISTS subquery so a merchant only ever sees their own stores.
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(expr(exists(store_memberships, merchant_id == ^actor(:id))))
    end

    # Customer reads: store metadata is publicly visible — storefronts are public
    # pages and customers browse across the marketplace directory. Sensitive per-tenant
    # data (orders, payments, PII) is row-scoped on those resources, not on Store.
    # The update/destroy policy below still forbids Customer mutations.
    policy actor_attribute_equals(:__struct__, Emakola.Customers.Customer) do
      authorize_if(always())
    end

    # Platform-only actions — callable solely via `authorize?: false` from the
    # platform admin (gated there by :manage_stores) or from storefront system
    # code. Forbidding every actor here means a suspended merchant can't
    # un-suspend themselves by calling :reactivate (etc.) directly, even though
    # the general update policy below would otherwise admit them.
    #
    # The same reasoning covers two actions that are not lifecycle:
    #
    #   :update_directory_meta grants :featured, :featured_rank and the public
    #   :verified badge. A merchant awarding themselves a trust badge shoppers
    #   rely on is the exact shape of thing this block exists to stop.
    #
    #   :increment_view_count looks harmless but :view_count is the tiebreak on
    #   the default featured sort, the whole :popular sort and the :list_featured
    #   order — so a merchant able to call it can climb the directory at will.
    policy action([
             :suspend,
             :block,
             :archive,
             :reactivate,
             :update_directory_meta,
             :set_directory_standing,
             :increment_view_count
           ]) do
      forbid_if(always())
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
      change(Emakola.Stores.Changes.EnsureUniqueSlug)
    end

    # An affiliate's payout container — never a shop. Its own action rather
    # than widening :create to accept `kind`, so a merchant-facing create can
    # never mint one, deliberately or by a stray parameter.
    create :create_payout_container do
      accept([:name, :slug])

      change(set_attribute(:kind, :affiliate_payout))
      change(set_attribute(:active, false))
      change(Emakola.Stores.Changes.EnsureUniqueSlug)
    end

    update :update do
      accept([:name, :currency, :theme_config])
    end

    update :update_settings do
      require_atomic?(false)

      # Scoped to this action rather than the resource: it is the only one that
      # accepts these fields, and a resource-wide validation without `atomic/3`
      # would force every atomic update (update_directory_meta among them) off
      # its fast path.
      #
      # `changing/1` matters as much as the rule. Two live merchants already
      # hold a page link in cover_image_url. Validating an unchanged field
      # would lock them out of their whole settings page — unable to fix a
      # tagline or a phone number because of a URL sitting inside a collapsed
      # <details> they may never have opened. Shoppers are protected from the
      # old value by the render guard (`Emakola.Stores.ImageUrl`); this
      # validation's only job is to stop new ones being written.
      validate({Emakola.Stores.Validations.ImageUrl, attribute: :logo_url},
        where: [changing(:logo_url)]
      )

      validate({Emakola.Stores.Validations.ImageUrl, attribute: :cover_image_url},
        where: [changing(:cover_image_url)]
      )

      accept([
        :name,
        :description,
        :logo_url,
        :cover_image_url,
        :tagline,
        :contact_email,
        :contact_phone,
        :address,
        :city,
        :region,
        :digital_address,
        :landmark,
        :whatsapp_number,
        :instagram_url,
        :tiktok_url,
        :facebook_url,
        :youtube_url,
        :x_url,
        :whatsapp_catalog_id,
        :active,
        :buyer_protection_enabled,
        :theme_config,
        :enabled_product_types
      ])

      change(Emakola.Changes.NormalizeDigitalAddress)
    end

    # ── Lookup read actions ──

    read :get_by_slug do
      argument(:slug, :string, allow_nil?: false)
      filter(expr(slug == ^arg(:slug)))
      get?(true)
    end

    read :list_by_slugs do
      argument(:slugs, {:array, :string}, allow_nil?: false)

      filter(
        expr(active == true and status == :active and kind == :shop and slug in ^arg(:slugs))
      )
    end

    read :list_for_admin do
      argument(:search, :string, default: "")

      filter(
        expr(
          is_nil(^arg(:search)) or ^arg(:search) == "" or
            ilike(name, ^arg(:search)) or ilike(slug, ^arg(:search))
        )
      )

      prepare(build(sort: [inserted_at: :desc]))
    end

    # ── Directory read actions ──

    read :list_active do
      filter(expr(active == true and status == :active and kind == :shop))
      prepare(build(sort: [name: :asc]))
    end

    read :list_featured do
      argument(:limit, :integer, default: 8)
      # directory_eligible is the worker-maintained floor. Fail-open default
      # true, so staff picks show until the worker has evidence otherwise —
      # and "must bar a shop from every featured slot" includes this one.
      filter(
        expr(
          active == true and status == :active and featured == true and kind == :shop and
            directory_eligible == true
        )
      )

      prepare(build(sort: [featured_rank: :asc_nils_last, view_count: :desc]))
      pagination(offset?: true, default_limit: 8, max_page_size: 50, required?: false)
    end

    # ── Worker-assigned slot reads ──
    # Plain indexed column filters over the cache the nightly ranking worker
    # maintains. Empty until the worker has run — callers fall back to the
    # staff-featured list, so a fresh deploy never shows a blank page.

    read :list_spotlight do
      argument(:limit, :integer, default: 6)
      filter(expr(active == true and status == :active and directory_slot == :spotlight))
      prepare(build(sort: [directory_score: :desc_nils_last, name: :asc]))
    end

    read :list_rising do
      argument(:limit, :integer, default: 12)
      filter(expr(active == true and status == :active and directory_slot == :rising))
      prepare(build(sort: [directory_score: :desc_nils_last, name: :asc]))
    end

    # Written in its final form; returns [] until placement is ever sold.
    read :list_promoted do
      argument(:limit, :integer, default: 4)
      filter(expr(active == true and status == :active and directory_slot == :promoted))
      prepare(build(sort: [directory_score: :desc_nils_last, name: :asc]))
    end

    read :list_recent do
      argument(:limit, :integer, default: 6)
      filter(expr(active == true and status == :active and kind == :shop))
      prepare(build(sort: [inserted_at: :desc]))
    end

    # Workhorse for the main grid. Filters by theme (string in
    # theme_config["theme"]), region, and free-text search; sorts by
    # one of: :newest | :name | :popular | :featured.
    read :list_with_filters do
      argument(:theme, :string)
      argument(:region, :string)
      argument(:search, :string)
      argument(:sort, :atom, default: :featured)
      argument(:limit, :integer, default: 12)
      argument(:offset, :integer, default: 0)

      filter(expr(active == true and status == :active and kind == :shop))

      filter(
        expr(
          is_nil(^arg(:region)) or ^arg(:region) == "" or
            region == ^arg(:region)
        )
      )

      filter(
        expr(
          is_nil(^arg(:search)) or ^arg(:search) == "" or
            contains(string_downcase(name), string_downcase(^arg(:search))) or
            (not is_nil(tagline) and
               contains(string_downcase(tagline), string_downcase(^arg(:search)))) or
            (not is_nil(description) and
               contains(string_downcase(description), string_downcase(^arg(:search))))
        )
      )

      filter(
        expr(
          is_nil(^arg(:theme)) or ^arg(:theme) == "" or ^arg(:theme) == "all" or
            fragment("(theme_config ->> 'theme') = ?", ^arg(:theme)) or
            (fragment("(theme_config ->> 'theme')") |> is_nil() and ^arg(:theme) == "market")
        )
      )

      pagination(offset?: true, default_limit: 12, max_page_size: 60, required?: false)

      prepare(fn query, _ ->
        sort =
          case Ash.Query.get_argument(query, :sort) do
            :newest -> [inserted_at: :desc]
            :name -> [name: :asc]
            :popular -> [view_count: :desc, name: :asc]
            _ -> [featured: :desc, featured_rank: :asc_nils_last, view_count: :desc, name: :asc]
          end

        Ash.Query.sort(query, sort)
      end)
    end

    update :update_directory_meta do
      accept([
        :featured,
        :featured_at,
        :featured_rank,
        :verified,
        :verified_basis,
        :verified_basis_at
      ])
    end

    # The ranking worker's cache write. Separate from :update_directory_meta
    # so the worker cannot touch the featured flag and the Directory Studio
    # cannot touch the computed cache by accident.
    update :set_directory_standing do
      accept([:directory_eligible, :directory_score, :directory_slot])
    end

    # ── Platform lifecycle actions ──
    # Called only with `authorize?: false` from the platform admin LiveView,
    # which gates on the `:manage_stores` permission. The write policy above
    # forbids non-Merchant actors, so passing a `%User{}` actor would be
    # FORBIDDEN — `authorize?: false` is mandatory here, not a shortcut.

    update :suspend do
      require_atomic?(false)
      accept([])
      argument(:reason, :string, allow_nil?: false)
      change(set_attribute(:status, :suspended))
      change(set_attribute(:status_reason, arg(:reason)))
      change(Emakola.Stores.Changes.StampStatusChange)
    end

    update :block do
      require_atomic?(false)
      accept([])
      argument(:reason, :string, allow_nil?: false)
      change(set_attribute(:status, :blocked))
      change(set_attribute(:status_reason, arg(:reason)))
      change(Emakola.Stores.Changes.StampStatusChange)
    end

    update :archive do
      require_atomic?(false)
      accept([])
      argument(:reason, :string, allow_nil?: true)
      change(set_attribute(:status, :archived))
      change(set_attribute(:status_reason, arg(:reason)))
      change(Emakola.Stores.Changes.StampStatusChange)
    end

    # Restores a suspended/blocked/archived store to live. Works from any
    # state (incl. un-archiving, since archive keeps the row intact) and is
    # idempotent on an already-active store.
    update :reactivate do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :active))
      change(set_attribute(:status_reason, nil))
      change(Emakola.Stores.Changes.StampStatusChange)
    end

    update :increment_view_count do
      require_atomic?(true)
      accept([])
      change(atomic_update(:view_count, expr(view_count + 1)))
    end
  end

  @doc """
  Returns `true` if the store has opted into selling `product_type` —
  i.e. the type is present in `:enabled_product_types`. Use this to gate
  the merchant admin's type picker, the storefront's checkout flow, and
  any feature flag that branches on product type.
  """
  @spec accepts?(%{:enabled_product_types => [atom()], optional(any()) => any()}, atom()) ::
          boolean()
  def accepts?(%{enabled_product_types: types}, product_type)
      when is_list(types) and is_atom(product_type) do
    product_type in types
  end

  @doc """
  Returns `true` only when the store is publicly live — the merchant has it
  open (`active == true`) AND the platform has not suspended/blocked/archived
  it (`status == :active`). Used by the storefront resolver, the host plug,
  and the merchant-admin lockout hook to gate access in-memory on an
  already-loaded struct.
  """
  @spec live?(%{:active => boolean(), :status => atom(), optional(any()) => any()}) :: boolean()
  def live?(%{active: true, status: :active}), do: true
  def live?(_), do: false
end
