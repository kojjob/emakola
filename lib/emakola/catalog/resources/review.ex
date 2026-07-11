defmodule Emakola.Catalog.Review do
  @moduledoc """
  Review resource — customer product reviews with eligibility checks.

  A customer may leave one review per product, and only if they have a delivered
  order containing that product. Reviews can be published or hidden by merchants.

  Storefront callers must use `:list_published_by_product`; the default `:read`
  may include moderation state and is reserved for internal or authorized
  administration loads.
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

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

    # Customer-uploaded photos attached to this review. Optional.
    # Each entry: %{"url" => ..., "thumbnail_url" => ..., "alt" => ...}
    # PDP renders a 4-up gallery beneath the review text when present.
    # Phase 3 of social media integration plan.
    attribute :images, {:array, :map} do
      default([])
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

    belongs_to :store, Emakola.Stores.Store do
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
    # Reads are public — storefront renders reviews without an actor.
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    # Merchant actors: verify store membership for writes
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
      accept([:store_id, :product_id, :customer_id, :order_id, :rating, :title, :body, :images])
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

    read :list_published_by_product do
      argument(:product_id, :uuid, allow_nil?: false)

      filter(expr(product_id == ^arg(:product_id) and status == :published))

      prepare(build(sort: [inserted_at: :desc], load: [:customer]))
    end

    read :list_admin do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:status, :atom, allow_nil?: true)

      filter(
        expr(
          store_id == ^arg(:store_id) and
            (is_nil(^arg(:status)) or status == ^arg(:status))
        )
      )

      prepare(build(sort: [inserted_at: :desc], load: [:product, :customer]))
    end

    read :get_by_store do
      get?(true)
      argument(:id, :uuid, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(id == ^arg(:id) and store_id == ^arg(:store_id)))
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
      Emakola.Orders.PurchaseVerifier.has_delivered_order?(store_id, product_id, customer_id)
    end
  end
end
