defmodule Emakola.Catalog.Product do
  @moduledoc """
  Product resource — the container in the Shopify-style variant model.

  Every product has at least one variant that holds price/SKU/stock. The product
  itself holds title, description, SEO fields, tags, and status. Products belong
  to a store (multi-tenant) and optionally to a category.

  Status lifecycle: draft → active (requires variants) → archived → draft

  Public callers must use `:public_list`, `:public_get`, or another explicitly
  scoped read action. The default `:read` exists for internal relationship and
  authorized administration loads and is not a storefront API.
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type("product")
    includes(variants: [], images: [])

    routes do
      base("/products")
      index(:public_list)
      get(:public_get)
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("products")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :category_id, :uuid do
      public?(true)
    end

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :description, :string do
      public?(true)
      constraints(max_length: 5_000)
    end

    attribute :status, :atom do
      constraints(one_of: [:draft, :active, :archived])
      default(:draft)
      allow_nil?(false)
      public?(true)
    end

    # Platform-owned content-moderation control, separate from the merchant's
    # `status` so a merchant can't reverse a takedown. A product is shown to
    # customers only when `status == :active AND moderation_status == :ok`.
    # Set solely by platform staff via the :take_down/:reinstate actions.
    attribute :moderation_status, :atom do
      constraints(one_of: [:ok, :taken_down])
      default(:ok)
      allow_nil?(false)
      public?(true)
    end

    attribute :moderation_reason, :string do
      public?(true)
      constraints(max_length: 1_000)
    end

    attribute :moderation_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :product_type, :atom do
      constraints(
        one_of: [
          :physical,
          :digital_download,
          :license_key,
          :streaming,
          :course,
          :auction,
          :print_on_demand
        ]
      )

      default(:physical)
      allow_nil?(false)
      public?(true)
    end

    attribute :seo_title, :string do
      public?(true)
      constraints(max_length: 255)
    end

    attribute :seo_description, :string do
      public?(true)
      constraints(max_length: 1_000)
    end

    attribute :tags, {:array, :string} do
      default([])
      public?(true)
      constraints(items: [max_length: 100])
    end

    attribute :published_at, :utc_datetime_usec do
      public?(true)
    end

    # Counter incremented when a customer taps a button on the product's
    # share_strip (Phase 1). Displayed on the PDP as social proof
    # ("1.2K shares") once > 0. Phase 3 of social media integration plan.
    attribute :share_count, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
      constraints(min: 0)
    end

    attribute :snap_verified, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :category, Emakola.Catalog.Category do
      define_attribute?(false)
      public?(true)
    end

    # Both carry the order the merchant arranged, and both are read
    # positionally: the product page takes its default variant with
    # `List.first/1` and opens its gallery on `Enum.at(images, 0)`. Without a
    # sort that was whatever order Postgres returned, so the price, stock badge
    # and SKU a shopper met on first load could change between requests.
    # `inserted_at` breaks ties, because position defaults to the same value
    # for every row until a merchant reorders them.
    has_many :variants, Emakola.Catalog.Variant do
      public?(true)
      sort(position: :asc, inserted_at: :asc)
    end

    has_many :images, Emakola.Catalog.Image do
      public?(true)
      sort(position: :asc, inserted_at: :asc)
    end

    has_many :reviews, Emakola.Catalog.Review
    has_many :digital_files, Emakola.Catalog.DigitalFile
  end

  aggregates do
    count(:variant_count, :variants)

    sum :total_stock, :variants, :stock_quantity do
      public?(true)
    end

    # Distinguishes "no stock left" from "stock is the supplier's to hold":
    # a dropship listing has track_inventory false on every variant.
    count :tracked_variant_count, :variants do
      public?(true)
      filter(expr(track_inventory == true))
    end

    min :min_price, :variants, :price do
      public?(true)
    end

    max :max_price, :variants, :price do
      public?(true)
    end

    count :review_count, :reviews do
      filter(expr(status == :published))
    end

    avg :avg_rating, :reviews, :rating do
      filter(expr(status == :published))
    end
  end

  identities do
    identity(:unique_store_slug, [:store_id, :slug])
  end

  policies do
    # Reads are public — storefront renders products without an actor.
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    # Platform moderation actions are platform-only — callable solely via
    # `authorize?: false` from the moderation queue. Forbidding every actor
    # means a merchant can't reverse a takedown, even though the merchant
    # write policy below would otherwise admit the update.
    # Same applies to :set_snap_verified — badge integrity requires system-only writes.
    policy action([:take_down, :reinstate, :set_snap_verified]) do
      forbid_if(always())
    end

    # Merchant actors: verify store membership for writes
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :public_list do
      description("""
      Public storefront product list — active only, tenant-scoped, newest first.
      SECURITY: Product is global?(true) multitenant. A call WITHOUT `tenant:` set
      returns EVERY store's active products (no store_id filter). The public shop
      API MUST set the Ash tenant (PublicStoreTenant plug) before invoking this —
      fail-closed if the store slug is unknown; never call tenantless.
      """)

      filter(expr(status == :active))
      prepare(build(sort: [inserted_at: :desc], load: [:min_price, :max_price, :images]))
      pagination(keyset?: true, countable: true, default_limit: 20)
    end

    read :public_get do
      description("""
      Public storefront product fetch — active only, by primary key.
      SECURITY: Product is global?(true) multitenant. A call WITHOUT `tenant:` set
      returns EVERY store's active products (no store_id filter). The public shop
      API MUST set the Ash tenant (PublicStoreTenant plug) before invoking this —
      fail-closed if the store slug is unknown; never call tenantless.
      """)

      get?(true)
      filter(expr(status == :active))
      prepare(build(load: [:variants, :images, :min_price, :max_price]))
    end

    create :create do
      accept([
        :title,
        :description,
        :category_id,
        :tags,
        :seo_title,
        :seo_description,
        :store_id,
        :product_type
      ])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :title})
      validate(Emakola.Catalog.Validations.ProductTypeAcceptedByStore)
      change({Emakola.Catalog.Changes.GenerateSlug, from: :title})
      change({Emakola.Catalog.Changes.SyncToWhatsappCatalog, action: :upsert})
    end

    update :update do
      require_atomic?(false)

      accept([
        :title,
        :description,
        :category_id,
        :tags,
        :seo_title,
        :seo_description,
        :product_type
      ])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :title})
      validate(Emakola.Catalog.Validations.ProductTypeAcceptedByStore)
      change({Emakola.Catalog.Changes.GenerateSlug, from: :title})
      change(Emakola.Catalog.Changes.UntrackVariantsOnTypeChange)
      change({Emakola.Catalog.Changes.SyncToWhatsappCatalog, action: :upsert})
    end

    update :archive do
      require_atomic?(false)
      accept([])

      change(set_attribute(:status, :archived))
      change({Emakola.Catalog.Changes.SyncToWhatsappCatalog, action: :delete})
    end

    update :activate do
      require_atomic?(false)
      accept([])

      validate(Emakola.Catalog.Validations.HasVariants)
      change(set_attribute(:status, :active))
      change(set_attribute(:published_at, &DateTime.utc_now/0))
      change({Emakola.Catalog.Changes.SyncToWhatsappCatalog, action: :upsert})
    end

    # ── Platform content-moderation actions ──
    # Platform-only: called with `authorize?: false` from the moderation queue
    # (gated there by :manage_stores). The policy below forbids every actor, so a
    # merchant cannot reverse a takedown.
    update :take_down do
      require_atomic?(false)
      accept([])
      argument(:reason, :string, allow_nil?: false)
      change(set_attribute(:moderation_status, :taken_down))
      change(set_attribute(:moderation_reason, arg(:reason)))
      change(set_attribute(:moderation_at, &DateTime.utc_now/0))
    end

    update :reinstate do
      require_atomic?(false)
      accept([])
      change(set_attribute(:moderation_status, :ok))
      change(set_attribute(:moderation_reason, nil))
      change(set_attribute(:moderation_at, &DateTime.utc_now/0))
    end

    # Atomic increment of share_count, fired by the storefront PDP when a
    # customer taps a button on the share_strip. No actor required — this
    # is a public/anonymous action driven by storefront UI. Idempotency
    # is intentionally NOT enforced; double-counted shares are acceptable
    # noise compared to the cost of dedupe infrastructure.
    update :increment_share_count do
      require_atomic?(true)
      accept([])
      change(atomic_update(:share_count, expr(share_count + 1)))
    end

    update :set_snap_verified do
      require_atomic?(false)
      accept([:snap_verified])
    end

    read :search do
      argument(:query, :string, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)

      argument(:status, :atom,
        allow_nil?: true,
        constraints: [one_of: [:draft, :active, :archived]]
      )

      filter(
        expr(
          store_id == ^arg(:store_id) and
            contains(fragment("lower(?)", title), fragment("lower(?)", ^arg(:query))) and
            moderation_status == :ok and
            (is_nil(^arg(:status)) or status == ^arg(:status))
        )
      )

      prepare(build(load: [:min_price, :max_price, :images]))
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.load([:min_price, :max_price, :images, :variant_count])
      end)
    end

    read :get_by_store do
      get?(true)
      argument(:id, :uuid, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(id == ^arg(:id) and store_id == ^arg(:store_id)))
    end

    read :list_by_store_and_status do
      argument(:store_id, :uuid, allow_nil?: false)

      argument(:status, :atom,
        allow_nil?: false,
        constraints: [one_of: [:draft, :active, :archived]]
      )

      filter(
        expr(store_id == ^arg(:store_id) and status == ^arg(:status) and moderation_status == :ok)
      )

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.load([
          :min_price,
          :max_price,
          :images,
          :variant_count,
          :review_count,
          :avg_rating
        ])
      end)
    end

    read :get_by_slug do
      get?(true)
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:slug, :string, allow_nil?: false)

      filter(
        expr(
          store_id == ^arg(:store_id) and slug == ^arg(:slug) and status == :active and
            moderation_status == :ok
        )
      )

      prepare(
        build(load: [:variants, :images, :min_price, :max_price, :avg_rating, :review_count])
      )
    end

    read :get_active_by_id do
      get?(true)
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:id, :uuid, allow_nil?: false)

      filter(
        expr(
          store_id == ^arg(:store_id) and id == ^arg(:id) and status == :active and
            moderation_status == :ok
        )
      )
    end

    read :list_related do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:product_id, :uuid, allow_nil?: false)

      filter(
        expr(
          store_id == ^arg(:store_id) and status == :active and moderation_status == :ok and
            id != ^arg(:product_id)
        )
      )

      prepare(build(load: [:images, :min_price, :max_price]))
    end

    read :list_by_category do
      argument(:category_id, :uuid, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)

      argument(:status, :atom,
        allow_nil?: true,
        constraints: [one_of: [:draft, :active, :archived]]
      )

      filter(
        expr(
          category_id == ^arg(:category_id) and store_id == ^arg(:store_id) and
            moderation_status == :ok and
            (is_nil(^arg(:status)) or status == ^arg(:status))
        )
      )

      prepare(build(load: [:min_price, :max_price, :images, :variant_count]))
    end

    read :list_admin do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:search, :string, allow_nil?: true)

      argument(:status, :atom,
        allow_nil?: true,
        constraints: [one_of: [:draft, :active, :archived]]
      )

      filter(
        expr(
          store_id == ^arg(:store_id) and
            (is_nil(^arg(:search)) or
               contains(fragment("lower(?)", title), fragment("lower(?)", ^arg(:search)))) and
            (is_nil(^arg(:status)) or status == ^arg(:status))
        )
      )

      prepare(
        build(
          sort: [inserted_at: :desc],
          load: [
            :variant_count,
            :min_price,
            :max_price,
            :total_stock,
            :tracked_variant_count,
            :images
          ]
        )
      )
    end

    # Cross-store read for the platform moderation queue (global; called with
    # authorize?: false). Search by title/slug; optional moderation filter.
    read :list_for_moderation do
      argument(:search, :string, allow_nil?: true)

      argument(:moderation, :atom, allow_nil?: true, constraints: [one_of: [:ok, :taken_down]])

      filter(
        expr(
          (is_nil(^arg(:search)) or ^arg(:search) == "" or
             contains(fragment("lower(?)", title), fragment("lower(?)", ^arg(:search))) or
             contains(fragment("lower(?)", slug), fragment("lower(?)", ^arg(:search)))) and
            (is_nil(^arg(:moderation)) or moderation_status == ^arg(:moderation))
        )
      )

      prepare(build(sort: [inserted_at: :desc], load: [:store, :images, :min_price]))
    end
  end

  @doc """
  Whether a line of this product needs a delivery address and a shipping fee.

  `product_type` is the single source of truth — there is deliberately no
  `requires_shipping` boolean, which would be duplicate state able to drift
  from it.

  The polarity is a blacklist on purpose: a product type added later without
  touching this function is treated as shipping. That over-collects an
  address, which is recoverable, rather than silently shipping a physical
  good with no delivery fee, which is not.
  """
  @spec requires_shipping?(t() | atom()) :: boolean()
  # Plain-map pattern, NOT %__MODULE__{}. The Dockerfile pins Elixir 1.18.3
  # while CI and local run 1.20.x, and on 1.18.3 a %__MODULE__{} pattern inside
  # an Ash resource expands before Spark has defined the struct — so it
  # compiles everywhere except the release image. Matching the shape avoids the
  # struct expansion entirely and behaves identically.
  def requires_shipping?(%{product_type: type}), do: requires_shipping?(type)
  def requires_shipping?(:digital_download), do: false
  def requires_shipping?(type) when is_atom(type), do: true

  @doc """
  The product types a merchant may actually choose in the admin.

  Deliberately narrower than the `:product_type` attribute's `one_of`
  constraint. The other five types exist and route through
  `Emakola.Fulfillment.Dispatcher`, but none has a working delivery path, so
  offering them would sell a promise the platform cannot keep. Do not collapse
  the two lists — `Emakola.Fulfillment.Dispatcher.supported_types/0` is
  asserted to equal `one_of` exactly, so trimming the constraint breaks
  routing.
  """
  @spec sellable_types() :: [atom()]
  def sellable_types, do: [:physical, :digital_download]
end
