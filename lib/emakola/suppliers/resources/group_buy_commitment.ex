defmodule Emakola.Suppliers.GroupBuyCommitment do
  @moduledoc "A customer's quantity and payment state for a group-buy threshold."

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_group_buy_commitments")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:campaign_id, :uuid, allow_nil?: false, public?: true)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:customer_id, :uuid, public?: true)
    attribute(:payment_id, :uuid, public?: true)
    attribute(:quantity, :integer, allow_nil?: false, public?: true)
    attribute(:amount, :integer, allow_nil?: false, public?: true)

    attribute :status, :atom do
      allow_nil?(false)
      default(:pending)
      public?(true)
      constraints(one_of: [:pending, :paid, :cancelled, :refunding, :refunded, :refund_failed])
    end

    attribute(:refund_attempted_at, :utc_datetime_usec, public?: true)
    attribute(:refund_reference, :string, public?: true)
    attribute(:refund_error, :string, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :campaign, Emakola.Suppliers.GroupBuyCampaign do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :customer, Emakola.Customers.Customer do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :payment, Emakola.Payments.Payment do
      define_attribute?(false)
      public?(true)
    end
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:campaign_id, :store_id, :customer_id, :payment_id, :quantity, :amount, :status])
      validate(compare(:quantity, greater_than: 0))
      validate(compare(:amount, greater_than: 0))
    end

    update :mark_paid do
      require_atomic?(false)
      accept([:payment_id])
      validate(attribute_equals(:status, :pending))
      change(set_attribute(:status, :paid))
    end

    update :attach_payment do
      require_atomic?(false)
      accept([:payment_id])
      validate(attribute_equals(:status, :pending))
    end

    update :cancel do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :pending))
      change(set_attribute(:status, :cancelled))
    end

    update :mark_refunded do
      require_atomic?(false)
      accept([:refund_reference])
      validate(attribute_equals(:status, :refunding))
      change(set_attribute(:status, :refunded))
    end

    update :claim_refund do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :paid))
      change(set_attribute(:status, :refunding))
      change(set_attribute(:refund_attempted_at, &DateTime.utc_now/0))
    end

    update :reclaim_refund do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :refund_failed))
      change(set_attribute(:status, :refunding))
      change(set_attribute(:refund_attempted_at, &DateTime.utc_now/0))
    end

    update :claim_late_refund do
      require_atomic?(false)
      accept([])
      validate(attribute_in(:status, [:pending, :cancelled]))
      change(set_attribute(:status, :refunding))
      change(set_attribute(:refund_attempted_at, &DateTime.utc_now/0))
    end

    update :mark_refund_failed do
      require_atomic?(false)
      accept([:refund_error])
      validate(attribute_equals(:status, :refunding))
      change(set_attribute(:status, :refund_failed))
    end
  end
end
