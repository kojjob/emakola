defmodule Emakola.Catalog.Variant do
  @moduledoc """
  Product variant — holds price, SKU, and stock quantity.

  In the Shopify-style model, every product has at least one variant. The variant
  is the purchasable unit. A "Blue Large T-Shirt" is a variant of the "T-Shirt" product.

  Price is stored as integer in minor currency units (pesewas for GHS, kobo for NGN).
  The store's currency attribute determines interpretation. No floats ever.

  Stock: atomic increment/decrement via adjust_stock action. Database CHECK constraint
  prevents negative stock under concurrent access.

  Multi-tenancy: store_id denormalized from parent product.

  Public exposure is through an active product's scoped storefront action;
  callers must not treat the default `:read` as a public catalog endpoint.
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type("variant")
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("variants")
    repo(Emakola.Repo)

    custom_statements do
      statement :stock_non_negative do
        up("ALTER TABLE variants ADD CONSTRAINT stock_non_negative CHECK (stock_quantity >= 0)")
        down("ALTER TABLE variants DROP CONSTRAINT IF EXISTS stock_non_negative")
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :product_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :sku, :string do
      public?(true)
      constraints(max_length: 255)
    end

    attribute :price, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :compare_at_price, :integer do
      public?(true)
    end

    attribute :stock_quantity, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    # Stamped by LowStockAlertWorker when this variant is included in a
    # low-stock digest; cleared when stock recovers. Alert on the drop, not
    # on every morning the state persists.
    attribute :low_stock_alerted_at, :utc_datetime_usec do
      allow_nil?(true)
      public?(false)
    end

    attribute :track_inventory, :boolean do
      default(true)
      allow_nil?(false)
      public?(true)
    end

    attribute :weight_grams, :integer do
      public?(true)
      constraints(min: 0)
    end

    attribute :barcode, :string do
      public?(true)
      constraints(max_length: 255)
    end

    attribute :position, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    attribute :low_stock_alerted, :boolean do
      default(false)
      allow_nil?(false)
      public?(true)
    end

    attribute :cost_price, :integer do
      public?(true)
    end

    attribute :available, :boolean do
      default(true)
      allow_nil?(false)
      public?(true)
    end

    # Non-nil only while `available: false` was set by
    # `SupplierStockSyncWorker`'s `:sync_availability` action — see that
    # action and `Emakola.Catalog.Changes.ClearSupplierSyncPause`.
    attribute :supplier_sync_paused_at, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :product, Emakola.Catalog.Product do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :supplier, Emakola.Suppliers.Supplier do
      attribute_writable?(true)
      public?(true)
    end
  end

  identities do
    identity(:unique_store_sku, [:store_id, :sku])
  end

  policies do
    # Reads are public — storefront renders variant prices/stock without an actor.
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    # Merchant actors: verify store membership for writes
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  validations do
    validate(compare(:price, greater_than: 0),
      message: "must be greater than 0"
    )

    validate(compare(:stock_quantity, greater_than_or_equal_to: 0),
      message: "must be non-negative"
    )
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :price,
        :sku,
        :stock_quantity,
        :compare_at_price,
        :weight_grams,
        :barcode,
        :track_inventory,
        :position,
        :product_id,
        :store_id,
        :supplier_id,
        :cost_price,
        :available,
        :supplier_sync_paused_at
      ])

      change(Emakola.Catalog.Changes.UntrackDropshippedInventory)
      # After the dropship change on purpose: that one re-tracks a variant when
      # its supplier is de-linked, which must not resurrect tracking on a file.
      change(Emakola.Catalog.Changes.UntrackDigitalInventory)

      validate(fn changeset, _context ->
        price = Ash.Changeset.get_attribute(changeset, :price)
        compare = Ash.Changeset.get_attribute(changeset, :compare_at_price)

        if compare && price && compare <= price do
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :compare_at_price,
             message: "must be greater than price"
           )}
        else
          :ok
        end
      end)
    end

    update :update do
      require_atomic?(false)

      accept([
        :price,
        :sku,
        :stock_quantity,
        :compare_at_price,
        :weight_grams,
        :barcode,
        :track_inventory,
        :position,
        :supplier_id,
        :cost_price,
        :available
      ])

      change(Emakola.Catalog.Changes.UntrackDropshippedInventory)
      change(Emakola.Catalog.Changes.UntrackDigitalInventory)
      change(Emakola.Catalog.Changes.EnqueueSupplierStockSync)
      change(Emakola.Catalog.Changes.ClearSupplierSyncPause)

      validate(fn changeset, _context ->
        price =
          Ash.Changeset.get_attribute(changeset, :price)

        compare =
          Ash.Changeset.get_attribute(changeset, :compare_at_price)

        if compare && price && compare <= price do
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :compare_at_price,
             message: "must be greater than price"
           )}
        else
          :ok
        end
      end)
    end

    update :adjust_stock do
      accept([])

      argument(:delta, :integer, allow_nil?: false)

      change(atomic_update(:stock_quantity, expr(stock_quantity + ^arg(:delta))))
    end

    update :restock do
      require_atomic?(false)
      accept([])

      argument(:delta, :integer, allow_nil?: false)

      change(fn changeset, _context ->
        delta = Ash.Changeset.get_argument(changeset, :delta)
        current_stock = Ash.Changeset.get_attribute(changeset, :stock_quantity)
        new_stock = current_stock + delta

        changeset = Ash.Changeset.force_change_attribute(changeset, :stock_quantity, new_stock)

        # Reset alert flag when restocked above threshold
        if new_stock >= 10 do
          Ash.Changeset.force_change_attribute(changeset, :low_stock_alerted, false)
        else
          changeset
        end
      end)

      change(Emakola.Catalog.Changes.EnqueueSupplierStockSync)
    end

    # The ONLY path `SupplierStockSyncWorker` uses to write availability —
    # never `:update`. Stamps `supplier_sync_paused_at` when turning off (so
    # a later restock knows the sync, not a reseller, caused the off) and
    # clears it when turning on.
    update :sync_availability do
      require_atomic?(false)
      accept([])

      argument(:available, :boolean, allow_nil?: false)

      change(fn changeset, _context ->
        available = Ash.Changeset.get_argument(changeset, :available)

        changeset
        |> Ash.Changeset.force_change_attribute(:available, available)
        |> Ash.Changeset.force_change_attribute(
          :supplier_sync_paused_at,
          if(available, do: nil, else: DateTime.utc_now())
        )
      end)

      change(Emakola.Catalog.Changes.EnqueueSupplierStockSync)
    end

    update :set_low_stock_alerted do
      require_atomic?(false)
      accept([])
      change(set_attribute(:low_stock_alerted, true))
    end

    update :clear_low_stock_alerted do
      require_atomic?(false)
      accept([])
      change(set_attribute(:low_stock_alerted, false))
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [stock_quantity: :asc], load: [:product]))
    end

    read :list_admin do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))

      prepare(build(sort: [stock_quantity: :asc], load: [:supplier, product: [:images]]))
    end

    read :by_stock_range do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:min, :integer, allow_nil?: true)
      argument(:max, :integer, allow_nil?: true)

      filter(
        expr(
          store_id == ^arg(:store_id) and
            (is_nil(^arg(:min)) or stock_quantity >= ^arg(:min)) and
            (is_nil(^arg(:max)) or stock_quantity <= ^arg(:max))
        )
      )
    end

    read :low_stock do
      argument(:threshold, :integer, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)

      filter(
        expr(
          stock_quantity < ^arg(:threshold) and
            track_inventory == true and
            store_id == ^arg(:store_id)
        )
      )
    end
  end

  @doc """
  The single source of truth for whether a variant can be purchased right now.

  An untracked variant (`track_inventory: false` — own-stock made-to-order,
  digital goods, or supplier-fulfilled dropship) is always purchasable. A
  tracked variant is purchasable only while it holds at least `qty` in stock.

  Used by every storefront add-to-cart gate and by checkout stock validation,
  so the rule lives in exactly one place.
  """
  def in_stock?(variant, qty \\ 1) do
    not variant.track_inventory or variant.stock_quantity >= qty
  end

  @doc """
  A variant the shopper has actually landed on which has run out.

  `nil` means the options are not chosen yet, which is not the same thing as
  sold out — themes offer a back-in-stock nudge for one and a "select options"
  button for the other.
  """
  def sold_out?(nil), do: false
  def sold_out?(variant), do: not in_stock?(variant)
end
