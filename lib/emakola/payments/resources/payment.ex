defmodule Emakola.Payments.Payment do
  @moduledoc """
  Payment resource — tracks payment transactions across gateways.

  All monetary amounts are integers in minor currency units (pesewas for GHS, kobo for NGN).
  Payments are multi-tenant via store_id.

  Status lifecycle: pending -> success | failed
                    success -> refunded
  """

  use Ash.Resource,
    domain: Emakola.Payments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("payments")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :order_id, :uuid do
      public?(true)
    end

    attribute :amount, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :currency, :string do
      default("GHS")
      allow_nil?(false)
      public?(true)
      constraints(max_length: 3)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :success, :failed, :refunded])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :gateway, :atom do
      constraints(one_of: [:paystack, :hubtel])
      allow_nil?(false)
      public?(true)
    end

    attribute :gateway_reference, :string do
      public?(true)
      constraints(max_length: 255)
    end

    attribute :gateway_response, :map do
      public?(true)
    end

    attribute :customer_email, :string do
      public?(true)
      constraints(max_length: 320)
    end

    attribute :metadata, :map do
      default(%{})
      public?(true)
    end

    attribute :refunded_amount, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
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
  end

  identities do
    identity(:unique_gateway_reference, [:gateway_reference])
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
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

    # Customer actors have no direct read grant on Payment — gateway_response and
    # gateway_reference contain sensitive provider data. All storefront payment
    # lookups use authorize?: false + explicit filters.

    # nil actor falls through to default-deny. Webhook handlers and gateway
    # callbacks use `authorize?: false` since the request originates from the
    # gateway, not an authenticated user.
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :store_id,
        :order_id,
        :amount,
        :currency,
        :gateway,
        :gateway_reference,
        :gateway_response,
        :customer_email,
        :metadata
      ])
    end

    update :update do
      require_atomic?(false)
      accept([:gateway_response, :metadata])
    end

    update :mark_success do
      require_atomic?(false)
      accept([:gateway_response])

      change(set_attribute(:status, :success))
    end

    update :mark_failed do
      require_atomic?(false)
      accept([:gateway_response])

      change(set_attribute(:status, :failed))
    end

    update :mark_refunded do
      require_atomic?(false)
      accept([:refunded_amount])

      validate attribute_equals(:status, :success) do
        message("can only refund a successful payment")
      end

      validate({Emakola.Payments.Validations.RefundAmountNotExceeded, []})

      change(set_attribute(:status, :refunded))
    end

    read :by_gateway_reference do
      argument(:gateway_reference, :string, allow_nil?: false)

      filter(expr(gateway_reference == ^arg(:gateway_reference)))
    end

    read :by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        Ash.Query.sort(query, inserted_at: :desc)
      end)
    end

    read :by_store_with_status do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:status, :atom, allow_nil?: true)

      filter(
        expr(
          store_id == ^arg(:store_id) and
            (is_nil(^arg(:status)) or status == ^arg(:status))
        )
      )

      prepare(build(sort: [inserted_at: :desc], load: [:order]))
    end

    read :get_by_order do
      get?(true)
      argument(:order_id, :uuid, allow_nil?: false)
      filter(expr(order_id == ^arg(:order_id)))
    end
  end
end
