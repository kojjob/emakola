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

  require Logger

  # Dispatches an order lifecycle notification and logs any failure without
  # raising. This runs inside the Ash transaction via after_action; a raise
  # here would roll back the successful status update, so we must never
  # propagate notification errors to the caller.
  @doc false
  def dispatch_notification(order, event) do
    case Emakola.Notifications.Dispatcher.dispatch(order, event) do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "[orders] #{inspect(event)} notification dispatch failed: #{inspect(reason)}",
          order_id: order.id,
          store_id: Map.get(order, :store_id),
          event: event
        )

        :ok
    end
  end

  # Returns the IDs of pending supplier-owned fulfillments for `order`.
  # Used by the :confirm after_action to pass the IDs to the Notifications
  # Dispatcher so it does not need to query back into Orders.
  @doc false
  def load_pending_supplier_ids(order) do
    case Ash.load(order, :fulfillments, authorize?: false) do
      {:ok, loaded} ->
        loaded.fulfillments
        |> Enum.filter(fn f -> not is_nil(f.supplier_id) and f.status == :pending end)
        |> Enum.map(& &1.id)

      _ ->
        []
    end
  end

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

    has_many :line_items, Emakola.Orders.LineItem

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

    routes do
      base("/orders")

      # index: returns list; filter[status]=confirmed maps to the public status
      # attribute via ash_json_api's default derive_filter? behavior.
      # derive_sort?: false — no arbitrary column sorts from the mobile client.
      index(:api_list, derive_sort?: false)

      # get: fetches a single order by primary key from the URL :id segment.
      get(:api_get)
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

      change(fn changeset, _context ->
        date = Date.utc_today() |> Calendar.strftime("%Y%m%d")

        # Cryptographically random 6-char suffix. 4 random bytes →
        # base32 → keep first 6 alphanumerics. Collision space is
        # ~1 billion per (store_id, date), so practical collision rate
        # is ~0% under any realistic order volume.
        random =
          :crypto.strong_rand_bytes(4)
          |> Base.encode32(padding: false, case: :upper)
          |> binary_part(0, 6)

        order_number = "ORD-#{date}-#{random}"
        Ash.Changeset.force_change_attribute(changeset, :order_number, order_number)
      end)
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

      change(set_attribute(:status, :confirmed))

      change(
        after_action(fn _changeset, order, _context ->
          dispatch_notification(order, :order_confirmed)
          pending_supplier_ids = load_pending_supplier_ids(order)

          Emakola.Notifications.Dispatcher.dispatch_supplier_fulfillments(
            order.id,
            pending_supplier_ids
          )

          {:ok, order}
        end)
      )

      change(Emakola.Orders.Changes.EnqueueFulfillment)
    end

    update :start_processing do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:confirmed], message: "can only start processing from confirmed"}
      )

      change(set_attribute(:status, :processing))
    end

    update :mark_shipped do
      require_atomic?(false)
      accept([:tracking_number])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:processing], message: "can only mark as shipped from processing"}
      )

      change(set_attribute(:status, :shipped))

      change(
        after_action(fn _changeset, order, _context ->
          dispatch_notification(order, :order_shipped)
          {:ok, order}
        end)
      )
    end

    update :mark_delivered do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:shipped], message: "can only mark as delivered from shipped"}
      )

      change(set_attribute(:status, :delivered))

      change(
        after_action(fn _changeset, order, _context ->
          dispatch_notification(order, :order_delivered)
          {:ok, order}
        end)
      )
    end

    update :cancel do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending, :confirmed, :processing, :shipped],
         message: "can only cancel an active order (not delivered or already cancelled)"}
      )

      change(set_attribute(:status, :cancelled))

      change(
        after_action(fn _changeset, order, _context ->
          dispatch_notification(order, :order_cancelled)
          {:ok, order}
        end)
      )
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
