defmodule Emakola.Orders.Return do
  @moduledoc """
  Return resource for the order return/refund flow.

  Tracks return requests from customers through the lifecycle:
  requested -> approved -> refunded
  requested -> denied

  All monetary amounts are integers in minor currency units (pesewas).
  Multi-tenant via store_id. One return per order (unique identity on order_id).
  """

  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

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
    belongs_to :store, Emakola.Accounts.Store do
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
      accept([:admin_notes, :refund_amount])

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
  end
end
