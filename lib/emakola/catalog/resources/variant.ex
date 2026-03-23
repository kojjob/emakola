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
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

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

    timestamps()
  end

  relationships do
    belongs_to :product, Emakola.Catalog.Product do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_store_sku, [:store_id, :sku])
  end

  policies do
    policy always() do
      authorize_if(always())
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
        :store_id
      ])

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
        :position
      ])

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
end
