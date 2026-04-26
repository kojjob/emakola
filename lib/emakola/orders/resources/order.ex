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
    authorizers: [Ash.Policy.Authorizer]

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
      constraints(max_length: 5_000)
    end

    attribute :tracking_number, :string do
      public?(true)
      constraints(max_length: 100)
    end

    attribute :shipping_address, :map do
      public?(true)
    end

    attribute :billing_address, :map do
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :customer, Emakola.Customers.Customer do
      define_attribute?(false)
      public?(true)
    end

    has_many :line_items, Emakola.Orders.LineItem

    belongs_to :coupon, Emakola.Marketing.Coupon do
      attribute_writable?(true)
      public?(true)
    end
  end

  identities do
    identity(:unique_store_order_number, [:store_id, :order_number])
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

    # Customer actors: tenant-scoped reads (row scoping by customer_id is a follow-up)
    policy actor_attribute_equals(:__struct__, Emakola.Customers.Customer) do
      authorize_if(action_type(:read))
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
        :coupon_id
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
    # Emakola.Orders.Validations.StatusGuard for docs.

    update :confirm do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Orders.Validations.StatusGuard,
         from: [:pending], message: "can only confirm a pending order"}
      )

      change(set_attribute(:status, :confirmed))

      change(
        after_action(fn _changeset, order, _context ->
          dispatch_notification(order, :order_confirmed)
          {:ok, order}
        end)
      )
    end

    update :start_processing do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Orders.Validations.StatusGuard,
         from: [:confirmed], message: "can only start processing from confirmed"}
      )

      change(set_attribute(:status, :processing))
    end

    update :mark_shipped do
      require_atomic?(false)
      accept([:tracking_number])

      validate(
        {Emakola.Orders.Validations.StatusGuard,
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
        {Emakola.Orders.Validations.StatusGuard,
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
        {Emakola.Orders.Validations.StatusGuard,
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
  end
end
