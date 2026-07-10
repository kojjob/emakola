defmodule Emakola.Orders.Fulfillment do
  @moduledoc """
  Fulfillment resource — a per-supplier (or merchant-owned) shipment group
  within an order.

  When a cart mixes items from multiple dropship suppliers and the merchant's
  own stock, checkout splits the order into one fulfillment per distinct
  `supplier_id` (plus one merchant-owned group where `supplier_id` is nil).
  Each fulfillment tracks its own status lifecycle and tracking number.

  Statuses: pending -> notified -> shipped -> delivered, with cancel allowed
  from any non-terminal state.
  """

  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("fulfillments")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :order_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    # nil supplier_id denotes the merchant-fulfilled (own-stock) group.
    attribute :supplier_id, :uuid do
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :notified, :shipped, :delivered, :cancelled])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :tracking_number, :string do
      public?(true)
      constraints(max_length: 100)
    end

    attribute :notified_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :notified_via, :atom do
      constraints(one_of: [:whatsapp, :sms, :manual])
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :order, Emakola.Orders.Order do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :supplier, Emakola.Suppliers.Supplier do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    has_many :line_items, Emakola.Orders.LineItem

    has_one :delivery_proof, Emakola.Orders.FulfillmentDeliveryProof do
      destination_attribute(:fulfillment_id)
      public?(true)
    end
  end

  policies do
    # Generic actions (action :name) — internal helpers, no policy
    bypass action_type(:action) do
      authorize_if(always())
    end

    # Creates require Merchant with store access. CheckoutService creates
    # fulfillments without an actor and opts in via `authorize?: false`.
    policy action_type(:create) do
      forbid_unless(actor_present())
      forbid_unless(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Merchant actors: verify store membership (for reads + writes)
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Customer actors: row-scoped reads — only fulfillments for their own orders within their store.
    policy actor_attribute_equals(:__struct__, Emakola.Customers.Customer) do
      authorize_if(
        expr(exists(order, customer_id == ^actor(:id)) and store_id == ^actor(:store_id))
      )
    end

    # nil actor falls through to default-deny.
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :order_id, :supplier_id, :status])
    end

    # ── Status transitions ──
    # Uses the reusable StatusGuard validation. See
    # Emakola.Validations.StatusGuard for docs.

    update :mark_notified do
      require_atomic?(false)
      accept([:notified_via])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending], message: "can only notify a pending fulfillment"}
      )

      change(set_attribute(:status, :notified))
      change(set_attribute(:notified_at, &DateTime.utc_now/0))
    end

    update :mark_shipped do
      require_atomic?(false)
      accept([:tracking_number])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending, :notified], message: "can only ship a pending or notified fulfillment"}
      )

      change(set_attribute(:status, :shipped))
    end

    update :mark_delivered do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:shipped], message: "can only mark as delivered from shipped"}
      )

      change(set_attribute(:status, :delivered))
    end

    update :cancel do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending, :notified, :shipped],
         message: "can only cancel an active fulfillment (not delivered or already cancelled)"}
      )

      change(set_attribute(:status, :cancelled))
    end

    read :list_by_order do
      argument(:order_id, :uuid, allow_nil?: false)

      filter(expr(order_id == ^arg(:order_id)))

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.Query.load([:supplier, :line_items])
      end)
    end
  end
end
