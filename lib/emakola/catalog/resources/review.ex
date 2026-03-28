defmodule Emakola.Catalog.Review do
  @moduledoc """
  Review resource — customer product reviews with eligibility checks.

  A customer may leave one review per product, and only if they have a delivered
  order containing that product. Reviews can be published or hidden by merchants.
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query

  postgres do
    table("reviews")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :product_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :customer_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :order_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :rating, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 1, max: 5)
    end

    attribute :title, :string do
      public?(true)
      constraints(max_length: 100)
    end

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 2000)
    end

    attribute :status, :atom do
      constraints(one_of: [:published, :hidden])
      default(:published)
      allow_nil?(false)
      public?(true)
    end

    attribute :verified_purchase, :boolean do
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

    belongs_to :customer, Emakola.Customers.Customer do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :order, Emakola.Orders.Order do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_customer_product_review, [:store_id, :product_id, :customer_id])
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    bypass always() do
      authorize_unless(actor_present())
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  validations do
    validate(compare(:rating, greater_than_or_equal_to: 1), message: "must be at least 1")
    validate(compare(:rating, less_than_or_equal_to: 5), message: "must be at most 5")
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :product_id, :customer_id, :order_id, :rating, :title, :body])
      change(set_attribute(:verified_purchase, true))
      change(set_attribute(:status, :published))
    end

    update :hide do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :hidden))
    end

    update :unhide do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :published))
    end
  end

  @doc """
  Checks if a customer is eligible to review a product.
  Returns `{:ok, order_id}` if eligible, `{:error, reason}` otherwise.
  """
  def eligible?(store_id, product_id, customer_id) do
    existing =
      __MODULE__
      |> Ash.Query.filter(
        store_id == ^store_id and product_id == ^product_id and customer_id == ^customer_id
      )
      |> Ash.count!(authorize?: false)

    if existing > 0 do
      {:error, :already_reviewed}
    else
      variant_ids =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(product_id == ^product_id and store_id == ^store_id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)

      if variant_ids == [] do
        {:error, :not_eligible}
      else
        delivered_order =
          Emakola.Orders.Order
          |> Ash.Query.filter(
            store_id == ^store_id and customer_id == ^customer_id and status == :delivered
          )
          |> Ash.read!(authorize?: false)
          |> Enum.find(fn order ->
            Emakola.Orders.LineItem
            |> Ash.Query.filter(order_id == ^order.id)
            |> Ash.read!(authorize?: false)
            |> Enum.any?(fn li -> li.variant_id in variant_ids end)
          end)

        case delivered_order do
          nil -> {:error, :not_eligible}
          order -> {:ok, order.id}
        end
      end
    end
  end
end
