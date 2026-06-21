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

    attribute :active, :boolean do
      default(true)
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
    attribute :featured_rank, :integer do
      public?(true)
    end

    # Trust badge — admin sets after KYC / catalog review.
    attribute :verified, :boolean do
      allow_nil?(false)
      default(false)
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
  end

  aggregates do
    # Active products count — powers the "86 products" line on the card
    # and the "Most popular" tiebreaker on the main grid sort.
    count :product_count, :products do
      filter(expr(status == :active))
    end
  end

  identities do
    identity(:unique_slug, [:slug])
  end

  policies do
    # Creates are open (onboarding creates stores without an actor).
    bypass action_type(:create) do
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

    update :update do
      accept([:name, :currency, :theme_config])
    end

    update :update_settings do
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
        :whatsapp_number,
        :instagram_url,
        :tiktok_url,
        :facebook_url,
        :youtube_url,
        :x_url,
        :whatsapp_catalog_id,
        :active,
        :theme_config,
        :enabled_product_types
      ])
    end

    # ── Lookup read actions ──

    read :get_by_slug do
      argument(:slug, :string, allow_nil?: false)
      filter(expr(slug == ^arg(:slug)))
      get?(true)
    end

    read :list_by_slugs do
      argument(:slugs, {:array, :string}, allow_nil?: false)
      filter(expr(active == true and slug in ^arg(:slugs)))
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
      filter(expr(active == true))
      prepare(build(sort: [name: :asc]))
    end

    read :list_featured do
      argument(:limit, :integer, default: 8)
      filter(expr(active == true and featured == true))
      prepare(build(sort: [featured_rank: :asc_nils_last, view_count: :desc]))
      pagination(offset?: true, default_limit: 8, max_page_size: 50, required?: false)
    end

    read :list_recent do
      argument(:limit, :integer, default: 6)
      filter(expr(active == true))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :list_editor_picks do
      filter(expr(active == true and not is_nil(featured_rank) and featured_rank <= 6))
      prepare(build(sort: [featured_rank: :asc]))
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

      filter(expr(active == true))

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
      accept([:featured, :featured_rank, :verified])
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
end
