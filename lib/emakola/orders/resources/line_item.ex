defmodule Emakola.Orders.LineItem do
  @moduledoc """
  Line item resource — individual items within an order.

  Snapshots the variant's price, product title, and SKU at order time so the
  order record remains accurate even if the product/variant changes later.

  All monetary amounts are integers in minor currency units (pesewas/kobo).
  """

  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("line_items")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :order_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :variant_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :product_title, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :variant_sku, :string do
      public?(true)
      constraints(max_length: 255)
    end

    attribute :unit_price, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :quantity, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :line_total, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :fulfillment_id, :uuid do
      public?(true)
    end

    # Supplier cost snapshot at order time (minor units). Nil for own-stock.
    attribute :cost_price, :integer do
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :order, Emakola.Orders.Order do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :variant, Emakola.Catalog.Variant do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :fulfillment, Emakola.Orders.Fulfillment do
      define_attribute?(false)
      public?(true)
    end
  end

  policies do
    # Generic actions (action :name) — internal helpers, no policy
    bypass action_type(:action) do
      authorize_if(always())
    end

    # Creates require Merchant with store access. CheckoutService creates
    # line items without an actor and opts in via `authorize?: false`.
    policy action_type(:create) do
      forbid_unless(actor_present())
      forbid_unless(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Merchant actors: verify store membership (for reads + writes)
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Customer actors: tenant-scoped reads only.
    policy actor_attribute_equals(:__struct__, Emakola.Customers.Customer) do
      authorize_if(action_type(:read))
    end

    # nil actor falls through to default-deny.
  end

  validations do
    validate(compare(:quantity, greater_than: 0),
      message: "must be greater than 0"
    )
  end

  actions do
    defaults([:read])

    create :create do
      accept([:order_id, :store_id, :variant_id, :quantity, :fulfillment_id])

      change(fn changeset, _context ->
        variant_id = Ash.Changeset.get_attribute(changeset, :variant_id)

        case Ash.get(Emakola.Catalog.Variant, variant_id, load: [:product]) do
          {:ok, variant} ->
            quantity = Ash.Changeset.get_attribute(changeset, :quantity)
            line_total = variant.price * (quantity || 0)

            changeset
            |> Ash.Changeset.force_change_attribute(:product_title, variant.product.title)
            |> Ash.Changeset.force_change_attribute(:variant_sku, variant.sku)
            |> Ash.Changeset.force_change_attribute(:unit_price, variant.price)
            |> Ash.Changeset.force_change_attribute(:line_total, line_total)
            |> Ash.Changeset.force_change_attribute(:cost_price, variant.cost_price)

          {:error, _} ->
            Ash.Changeset.add_error(changeset,
              field: :variant_id,
              message: "variant not found"
            )
        end
      end)
    end
  end
end
