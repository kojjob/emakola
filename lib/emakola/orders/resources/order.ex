defmodule Emakola.Orders.Order do
  @moduledoc """
  Order resource — the core of the commerce transaction.

  Orders are multi-tenant via store_id. Each order has an auto-generated order_number
  in the format ORD-YYYYMMDD-XXXXXX. Status follows a simple lifecycle:
  pending -> confirmed -> processing -> shipped -> delivered
  pending -> cancelled

  All monetary amounts are integers in minor currency units (pesewas/kobo).
  """

  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("orders")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :customer_id, :uuid do
      public?(true)
    end

    attribute :pay_link_id, :uuid do
      public?(true)
    end

    attribute :susu_plan_id, :uuid do
      public?(true)
    end

    attribute :order_number, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 50)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :confirmed, :processing, :shipped, :delivered, :cancelled])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :subtotal, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    attribute :total, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    attribute :delivery_fee, :integer do
      default(0)
      public?(true)
    end

    attribute :discount_amount, :integer do
      default(0)
      public?(true)
    end

    # Sum of the per-supplier dispatch fees snapshotted onto this order's
    # fulfillments at checkout (see Fulfillment.dispatch_fee). Included once
    # in `total`; never recomputed from live offer terms.
    attribute(:dispatch_fee_total, :integer, allow_nil?: false, default: 0, public?: true)

    attribute :currency, :string do
      default("GHS")
      allow_nil?(false)
      public?(true)
      constraints(max_length: 3)
    end

    attribute :notes, :string do
      public?(true)
      filterable?(false)
      constraints(max_length: 5_000)
    end

    attribute :tracking_number, :string do
      public?(true)
      constraints(max_length: 100)
    end

    attribute :shipping_address, :map do
      public?(true)
      filterable?(false)
    end

    attribute :billing_address, :map do
      public?(true)
      filterable?(false)
    end

    # UTM and click-source attribution captured during the customer's
    # session. Populated by EmakolaWeb.Plugs.UtmCapture during checkout.
    # Defaults to %{} so legacy rows are valid and downstream rendering
    # can pattern-match safely.
    attribute :attribution, :map do
      public?(true)
      filterable?(false)
      default(%{})
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :customer, Emakola.Customers.Customer do
      define_attribute?(false)
      public?(true)
    end

    has_many :line_items, Emakola.Orders.LineItem do
      public?(true)
    end

    has_many :fulfillments, Emakola.Orders.Fulfillment

    belongs_to :coupon, Emakola.Marketing.Coupon do
      attribute_writable?(true)
      public?(true)
    end
  end

  calculations do
    # Additive: derives an aggregate status from per-supplier fulfillments
    # without modifying the stored `status` attribute. Nil for legacy orders
    # that have no fulfillments.
    calculate(
      :fulfillment_status,
      :atom,
      Emakola.Orders.Calculations.FulfillmentStatus
    )

    # Additive: gross margin (minor units) summed from line items, treating
    # nil cost_price (own-stock) as zero cost. Zero for orders with no items.
    calculate(
      :margin,
      :integer,
      Emakola.Orders.Calculations.Margin
    )
  end

  identities do
    identity(:unique_store_order_number, [:store_id, :order_number])
  end

  json_api do
    type("order")
    includes(line_items: [])

    routes do
      base("/orders")

      # index: returns list; filter[status]=confirmed maps to the public status
      # attribute via ash_json_api's default derive_filter? behavior.
      # derive_sort?: false — no arbitrary column sorts from the mobile client.
      index(:api_list, derive_sort?: false)

      # get: fetches a single order by primary key from the URL :id segment.
      get(:api_get)

      patch(:confirm, route: "/:id/confirm")
      patch(:start_processing, route: "/:id/start_processing")
      patch(:mark_shipped, route: "/:id/mark_shipped")
      patch(:mark_delivered, route: "/:id/mark_delivered")
      patch(:cancel, route: "/:id/cancel")
    end
  end

  policies do
    # Generic actions (action :name) — internal helpers, no policy
    bypass action_type(:action) do
      authorize_if(always())
    end

    # Creates require Merchant with store access. CheckoutService and
    # webhook handlers create orders without an actor and opt in via
    # `authorize?: false` explicitly.
    policy action_type(:create) do
      forbid_unless(actor_present())
      forbid_unless(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Merchant actors: verify store membership (for reads + writes)
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Customer actors: row-scoped reads — only their own orders within their store.
    policy actor_attribute_equals(:__struct__, Emakola.Customers.Customer) do
      authorize_if(expr(customer_id == ^actor(:id) and store_id == ^actor(:store_id)))
    end

    # nil actor falls through to default-deny. System code uses `authorize?: false`.
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :store_id,
        :customer_id,
        :pay_link_id,
        :susu_plan_id,
        :notes,
        :shipping_address,
        :billing_address,
        :subtotal,
        :total,
        :currency,
        :delivery_fee,
        :discount_amount,
        :coupon_id,
        :attribution
      ])

      change(Emakola.Orders.Changes.GenerateOrderNumber)
    end

    update :update do
      require_atomic?(false)

      accept([
        :subtotal,
        :total,
        :notes,
        :shipping_address,
        :billing_address,
        :delivery_fee,
        :discount_amount,
        :dispatch_fee_total,
        :coupon_id
      ])
    end

    # ── Status transitions ──
    # Uses the reusable StatusGuard validation. See
    # Emakola.Validations.StatusGuard for docs.

    update :confirm do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending], message: "can only confirm a pending order"}
      )

      # Atomic counterpart to the guard above — see RequireStatusIn.
      change({Emakola.Orders.Changes.RequireStatusIn, from: [:pending]})

      change(set_attribute(:status, :confirmed))

      change(Emakola.Orders.Changes.NotifyConfirmation)

      change(Emakola.Orders.Changes.EnqueueFulfillment)

      # Stock is decremented only now — on confirmed payment — not at checkout,
      # so abandoned/unpaid orders never bleed inventory.
      change(Emakola.Orders.Changes.DecrementStock)
    end

    update :start_processing do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:confirmed], message: "can only start processing from confirmed"}
      )

      # Atomic counterpart to the guard above — see RequireStatusIn.
      change({Emakola.Orders.Changes.RequireStatusIn, from: [:confirmed]})

      change(set_attribute(:status, :processing))
    end

    update :mark_shipped do
      require_atomic?(false)
      accept([:tracking_number])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:processing], message: "can only mark as shipped from processing"}
      )

      # Atomic counterpart to the guard above — see RequireStatusIn.
      change({Emakola.Orders.Changes.RequireStatusIn, from: [:processing]})

      change(set_attribute(:status, :shipped))
      change({Emakola.Orders.Changes.NotifyStatusChange, event: :order_shipped})
    end

    update :mark_delivered do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:shipped], message: "can only mark as delivered from shipped"}
      )

      # Atomic counterpart to the guard above — see RequireStatusIn.
      change({Emakola.Orders.Changes.RequireStatusIn, from: [:shipped]})

      change(set_attribute(:status, :delivered))
      change({Emakola.Orders.Changes.NotifyStatusChange, event: :order_delivered})
    end

    update :cancel do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending, :confirmed, :processing, :shipped],
         message: "can only cancel an active order (not delivered or already cancelled)"}
      )

      # Atomic counterpart to the guard above — see RequireStatusIn.
      change(
        {Emakola.Orders.Changes.RequireStatusIn,
         from: [:pending, :confirmed, :processing, :shipped]}
      )

      change(set_attribute(:status, :cancelled))
      change({Emakola.Orders.Changes.NotifyStatusChange, event: :order_cancelled})
    end

    update :update_notes do
      require_atomic?(false)
      accept([:notes])
    end

    read :get_by_id do
      argument(:id, :uuid, allow_nil?: false)

      filter(expr(id == ^arg(:id)))

      prepare(fn query, _context ->
        Ash.Query.load(query, [:line_items, :customer])
      end)
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.load([:customer])
      end)
    end

    read :list_by_status do
      argument(:store_id, :uuid, allow_nil?: false)

      argument(:status, :atom,
        allow_nil?: false,
        constraints: [
          one_of: [:pending, :confirmed, :processing, :shipped, :delivered, :cancelled]
        ]
      )

      filter(expr(store_id == ^arg(:store_id) and status == ^arg(:status)))

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.load([:customer])
      end)
    end

    read :list_admin do
      argument(:store_id, :uuid, allow_nil?: false)

      argument(:status, :atom,
        allow_nil?: true,
        constraints: [
          one_of: [:pending, :confirmed, :processing, :shipped, :delivered, :cancelled]
        ]
      )

      argument(:search, :string, allow_nil?: true)

      filter(
        expr(
          store_id == ^arg(:store_id) and
            (is_nil(^arg(:status)) or status == ^arg(:status)) and
            (is_nil(^arg(:search)) or contains(order_number, ^arg(:search)))
        )
      )

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.load([:customer])
      end)
    end

    read :get_for_admin do
      get?(true)
      argument(:id, :uuid, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(id == ^arg(:id) and store_id == ^arg(:store_id)))
    end

    read :list_by_customer do
      argument(:customer_id, :uuid, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(customer_id == ^arg(:customer_id) and store_id == ^arg(:store_id)))
      prepare(fn query, _ -> Ash.Query.sort(query, inserted_at: :desc) end)
    end

    read :get_by_order_number do
      argument(:order_number, :string, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(order_number == ^arg(:order_number) and store_id == ^arg(:store_id)))
    end

    read :by_store_non_cancelled_in_period do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:from, :utc_datetime, allow_nil?: false)
      argument(:to, :utc_datetime, allow_nil?: false)

      filter(
        expr(
          store_id == ^arg(:store_id) and
            status != :cancelled and
            inserted_at >= ^arg(:from) and
            inserted_at < ^arg(:to)
        )
      )
    end

    # Mobile API — list orders for the authenticated merchant's store.
    # filter[status]=confirmed is handled by ash_json_api's derive_filter?
    # on the public status attribute (no action argument required).
    read :api_list do
      description("Mobile API order list — tenant-scoped, newest first.")

      prepare(fn query, _context ->
        Ash.Query.sort(query, inserted_at: :desc)
      end)

      pagination(keyset?: true, countable: true, default_limit: 25)
    end

    # Mobile API — fetch a single order by primary key.
    # ash_json_api routes to this via the :id path segment using Ash.get!.
    read :api_get do
      description("Mobile API order get by primary key.")
      get?(true)
    end
  end
end
