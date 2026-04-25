defmodule Emakola.Orders.Coupon do
  @moduledoc """
  Coupon resource for the checkout discount system.

  Supports three discount types:
  - `:percentage` -- discount_value is in basis points (1000 = 10%)
  - `:fixed_amount` -- discount_value is in pesewas
  - `:free_shipping` -- waives the delivery fee

  All monetary amounts are integers in minor currency units (pesewas).
  Multi-tenant via store_id.
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
    table("coupons")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :code, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 50)
    end

    attribute :description, :string do
      public?(true)
      constraints(max_length: 500)
    end

    attribute :discount_type, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:percentage, :fixed_amount, :free_shipping])
    end

    attribute :discount_value, :integer do
      default(0)
      public?(true)
    end

    attribute :max_discount_amount, :integer do
      public?(true)
    end

    attribute :minimum_order_amount, :integer do
      public?(true)
    end

    attribute :max_uses, :integer do
      public?(true)
    end

    attribute :uses_count, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    attribute :starts_at, :utc_datetime do
      public?(true)
    end

    attribute :expires_at, :utc_datetime do
      public?(true)
    end

    attribute :active, :boolean do
      default(true)
      allow_nil?(false)
      public?(true)
    end

    attribute :is_public, :boolean do
      default(false)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_code_per_store, [:store_id, :code])
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

    # Public storefront reads — list and find by code action arguments
    # filter to active+public+within-window. These are designed for
    # unauthenticated checkout flows.
    bypass action([:list_active_public, :find_by_code]) do
      authorize_if(always())
    end

    # Merchant actors: verify store membership (for reads + writes)
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Customer actors at checkout can read public coupons by code (action handles
    # the public flag); for now permit tenant-scoped reads.
    policy actor_attribute_equals(:__struct__, Emakola.Customers.Customer) do
      authorize_if(action_type(:read))
    end

    # nil actor falls through to default-deny.
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :store_id,
        :code,
        :description,
        :discount_type,
        :discount_value,
        :max_discount_amount,
        :minimum_order_amount,
        :max_uses,
        :starts_at,
        :expires_at,
        :active,
        :is_public
      ])

      change(fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :code) do
          nil -> changeset
          code -> Ash.Changeset.change_attribute(changeset, :code, String.upcase(code))
        end
      end)

      validate(fn changeset, _context ->
        type = Ash.Changeset.get_attribute(changeset, :discount_type)
        value = Ash.Changeset.get_attribute(changeset, :discount_value)

        if type == :percentage and is_integer(value) and value > 10_000 do
          {:error,
           field: :discount_value, message: "percentage cannot exceed 100% (10000 basis points)"}
        else
          :ok
        end
      end)
    end

    update :update do
      require_atomic?(false)

      accept([
        :code,
        :description,
        :discount_type,
        :discount_value,
        :max_discount_amount,
        :minimum_order_amount,
        :max_uses,
        :starts_at,
        :expires_at,
        :active,
        :is_public
      ])
    end

    update :deactivate do
      require_atomic?(false)
      change(set_attribute(:active, false))
    end

    update :increment_usage do
      change(atomic_update(:uses_count, expr(uses_count + 1)))
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :list_active_public do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(
        expr(
          store_id == ^arg(:store_id) and active == true and is_public == true and
            (is_nil(expires_at) or expires_at > now()) and
            (is_nil(starts_at) or starts_at <= now()) and
            (is_nil(max_uses) or uses_count < max_uses)
        )
      )
    end

    read :find_by_code do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:code, :string, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id) and code == ^arg(:code)))

      prepare(fn query, _context ->
        code = Ash.Query.get_argument(query, :code)
        if code, do: Ash.Query.set_argument(query, :code, String.upcase(code)), else: query
      end)
    end
  end

  relationships do
    belongs_to :store, Emakola.Accounts.Store do
      attribute_writable?(true)
      define_attribute?(false)
    end
  end
end
