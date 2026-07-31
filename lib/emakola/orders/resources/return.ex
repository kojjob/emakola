defmodule Emakola.Orders.Return do
  @moduledoc """
  Return resource for the order return/refund flow.

  Tracks return requests from customers through the lifecycle:
  requested -> approved -> refunded
  requested -> denied
  denied -> requested (`:reopen`, platform-staff only — TC-2 Task 12: a
  buyer complaint can escalate a merchant-denied return into the
  buyer-protection queue's staff-refund path; called with `authorize?:
  false` from `EmakolaWeb.Platform.ProtectionLive`, same posture as this
  resource's other transitions)

  All monetary amounts are integers in minor currency units (pesewas).
  Multi-tenant via store_id. One return per order (unique identity on order_id).
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
    table("returns")
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

    attribute :customer_id, :uuid do
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:requested, :approved, :denied, :refunded])
      default(:requested)
      allow_nil?(false)
      public?(true)
    end

    attribute :reason, :atom do
      constraints(one_of: [:defective, :wrong_item, :not_as_described, :changed_mind, :other])
      allow_nil?(false)
      public?(true)
    end

    attribute :reason_detail, :string do
      public?(true)
      constraints(max_length: 2_000)
    end

    attribute :admin_notes, :string do
      public?(true)
      constraints(max_length: 2_000)
    end

    attribute :refund_amount, :integer do
      public?(true)
    end

    attribute :refund_dispatch_fee?, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    attribute :currency, :string do
      default("GHS")
      allow_nil?(false)
      public?(true)
      constraints(max_length: 3)
    end

    timestamps()
  end

  identities do
    identity(:unique_return_per_order, [:order_id])
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :order, Emakola.Orders.Order do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :customer, Emakola.Customers.Customer do
      define_attribute?(false)
      public?(true)
    end
  end

  policies do
    # Creates are permissive (callers ensure store_id is valid)
    bypass action_type(:create) do
      authorize_if(always())
    end

    # Generic actions (action :name) — internal helpers, no policy
    bypass action_type(:action) do
      authorize_if(always())
    end

    # Merchant actors: verify store membership (for reads + writes)
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Customer actors: row-scoped reads — only their own returns within their store.
    policy actor_attribute_equals(:__struct__, Emakola.Customers.Customer) do
      authorize_if(expr(customer_id == ^actor(:id) and store_id == ^actor(:store_id)))
    end

    # nil actor falls through to default-deny.
  end

  actions do
    defaults([:read])

    create :request_return do
      accept([
        :store_id,
        :order_id,
        :customer_id,
        :reason,
        :reason_detail,
        :currency
      ])
    end

    update :approve do
      require_atomic?(false)
      accept([:admin_notes, :refund_amount, :refund_dispatch_fee?])

      validate(fn changeset, _context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status == :requested do
          :ok
        else
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :status,
             message: "can only approve a requested return"
           )}
        end
      end)

      change(set_attribute(:status, :approved))
    end

    update :deny do
      require_atomic?(false)
      accept([:admin_notes])

      validate(fn changeset, _context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status == :requested do
          :ok
        else
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :status,
             message: "can only deny a requested return"
           )}
        end
      end)

      change(set_attribute(:status, :denied))
    end

    # Escalation path (TC-2 Task 12): a merchant denial isn't necessarily the
    # last word — a buyer complaint can freeze a protection hold on the same
    # order, and staff need a way to move the return forward again to refund
    # through the normal RefundService path. Same validate+change shape as
    # :deny/:approve/:mark_refunded above.
    update :reopen do
      require_atomic?(false)
      accept([])

      validate(fn changeset, _context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status == :denied do
          :ok
        else
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :status,
             message: "can only reopen a denied return"
           )}
        end
      end)

      change(set_attribute(:status, :requested))
    end

    update :mark_refunded do
      require_atomic?(false)
      accept([])

      validate(fn changeset, _context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status == :approved do
          :ok
        else
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :status,
             message: "can only mark as refunded from approved"
           )}
        end
      end)

      change(set_attribute(:status, :refunded))
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :get_by_order do
      argument(:order_id, :uuid, allow_nil?: false)
      filter(expr(order_id == ^arg(:order_id)))
    end

    # Every return the customer has requested in this store, in one query — the
    # account page shows the status against each order it lists.
    read :list_by_customer do
      argument(:customer_id, :uuid, allow_nil?: false)
      filter(expr(customer_id == ^arg(:customer_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end
  end
end
