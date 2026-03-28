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

    belongs_to :coupon, Emakola.Orders.Coupon do
      attribute_writable?(true)
      public?(true)
    end
  end

  identities do
    identity(:unique_store_order_number, [:store_id, :order_number])
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Internal/system calls (nil actor) are allowed
    bypass always() do
      authorize_unless(actor_present())
    end

    # Merchant actors: verify store membership for writes
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
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

        random =
          for(_ <- 1..6, into: "", do: <<Enum.random(~c"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")>>)

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

    update :confirm do
      require_atomic?(false)
      accept([])

      validate(fn changeset, _context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status == :pending do
          :ok
        else
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :status,
             message: "can only confirm a pending order"
           )}
        end
      end)

      change(set_attribute(:status, :confirmed))

      change(
        after_action(fn _changeset, order, _context ->
          try do
            Emakola.Notifications.Dispatcher.dispatch(order, :order_confirmed)
          rescue
            _ -> :ok
          end

          {:ok, order}
        end)
      )
    end

    update :start_processing do
      require_atomic?(false)
      accept([])

      validate(fn changeset, _context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status == :confirmed do
          :ok
        else
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :status,
             message: "can only start processing from confirmed"
           )}
        end
      end)

      change(set_attribute(:status, :processing))
    end

    update :mark_shipped do
      require_atomic?(false)
      accept([:tracking_number])

      validate(fn changeset, _context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status == :processing do
          :ok
        else
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :status,
             message: "can only mark as shipped from processing"
           )}
        end
      end)

      change(set_attribute(:status, :shipped))

      change(
        after_action(fn _changeset, order, _context ->
          try do
            Emakola.Notifications.Dispatcher.dispatch(order, :order_shipped)
          rescue
            _ -> :ok
          end

          {:ok, order}
        end)
      )
    end

    update :mark_delivered do
      require_atomic?(false)
      accept([])

      validate(fn changeset, _context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status == :shipped do
          :ok
        else
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :status,
             message: "can only mark as delivered from shipped"
           )}
        end
      end)

      change(set_attribute(:status, :delivered))

      change(
        after_action(fn _changeset, order, _context ->
          try do
            Emakola.Notifications.Dispatcher.dispatch(order, :order_delivered)
          rescue
            _ -> :ok
          end

          {:ok, order}
        end)
      )
    end

    update :cancel do
      require_atomic?(false)
      accept([])

      validate(fn changeset, _context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status in [:pending, :confirmed, :processing, :shipped] do
          :ok
        else
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :status,
             message: "can only cancel an active order (not delivered or already cancelled)"
           )}
        end
      end)

      change(set_attribute(:status, :cancelled))

      change(
        after_action(fn _changeset, order, _context ->
          try do
            Emakola.Notifications.Dispatcher.dispatch(order, :order_cancelled)
          rescue
            _ -> :ok
          end

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
