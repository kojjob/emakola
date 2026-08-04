defmodule Emakola.Suppliers.PreorderDeposit do
  @moduledoc "Customer deposit and refund audit state for a protected preorder commitment."
  use Ash.Resource, domain: Emakola.Suppliers, data_layer: AshPostgres.DataLayer

  postgres do
    table("preorder_deposits")
    repo(Emakola.Repo)
    identity_wheres_to_sql(unique_payment: "payment_id IS NOT NULL")
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:preorder_id, :uuid, allow_nil?: false, public?: true)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:customer_id, :uuid, allow_nil?: false, public?: true)
    attribute(:payment_id, :uuid, public?: true)
    attribute(:quantity, :integer, allow_nil?: false, public?: true)
    attribute(:amount, :integer, allow_nil?: false, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :pending,
      public?: true,
      constraints: [one_of: [:pending, :paid, :cancelled, :refunding, :refunded, :refund_failed]]
    )

    attribute(:refund_claimed_at, :utc_datetime_usec, public?: true)
    attribute(:refund_reference, :string, public?: true)
    attribute(:refund_error, :string, public?: true)
    timestamps()
  end

  identities do
    identity(:unique_payment, [:payment_id], where: expr(not is_nil(payment_id)))
  end

  actions do
    defaults([:read])

    create :create do
      accept([:preorder_id, :store_id, :customer_id, :quantity, :amount])
    end

    update :attach_payment do
      require_atomic?(false)
      accept([:payment_id])
    end

    update :paid do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :pending))
      change(set_attribute(:status, :paid))
    end

    update :cancel do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :pending))
      change(set_attribute(:status, :cancelled))
    end

    update :claim_refund do
      require_atomic?(false)
      accept([:refund_claimed_at])
      validate(attribute_in(:status, [:paid, :refund_failed]))
      change(set_attribute(:status, :refunding))
    end

    update :refunded do
      require_atomic?(false)
      accept([:refund_reference])
      validate(attribute_equals(:status, :refunding))
      change(set_attribute(:status, :refunded))
    end

    update :refund_failed do
      require_atomic?(false)
      accept([:refund_error])
      validate(attribute_equals(:status, :refunding))
      change(set_attribute(:status, :refund_failed))
    end
  end
end
