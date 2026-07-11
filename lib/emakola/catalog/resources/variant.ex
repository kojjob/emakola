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

    attribute :track_inventory, :boolean do
      default(true)
      allow_nil?(false)
      public?(true)
    end

    attribute :weight_grams, :integer do
      public?(true)
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
        :available
      ])

      change(Emakola.Catalog.Changes.UntrackDropshippedInventory)

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

      prepare(build(sort: [stock_quantity: :asc], load: [:product, :supplier]))
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
end
