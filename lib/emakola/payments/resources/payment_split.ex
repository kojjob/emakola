defmodule Emakola.Payments.PaymentSplit do
  @moduledoc """
  Records how a single customer charge was allocated across the parties of a
  dropship sale (SP5): one row per recipient — wholesaler(s), the platform, and
  the dropshipper.

  All amounts are integers in minor currency units. Splits are immutable
  financial records: there is no destroy action; a refund reversal is a status
  transition (`:settled -> :reversed`), mirroring `SupplierLedgerEntry`.

  The tenant (`store_id`) is the order's store (the dropshipper). For a
  `:wholesaler` allocation, `recipient_store_id` points to the wholesaler's
  store and `subaccount_code` is its payout destination; `:platform` rows have
  neither (settlement stays in the platform main account).
  """

  use Ash.Resource,
    domain: Emakola.Payments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("payment_splits")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :payment_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :role, :atom do
      constraints(one_of: [:wholesaler, :dropshipper, :platform, :merchant])
      allow_nil?(false)
      public?(true)
    end

    # Destination store for the allocation. Nil for the platform's own cut.
    attribute :recipient_store_id, :uuid do
      public?(true)
    end

    # Ties a wholesaler allocation back to the supplier it settles. Nil otherwise.
    attribute :supplier_id, :uuid do
      public?(true)
    end

    # Gateway subaccount the money settles to. Nil for the platform main account.
    attribute :subaccount_code, :string do
      public?(true)
    end

    attribute :amount, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :settled, :partially_reversed, :reversed])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :reversed_amount, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute :recovered_amount, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute :reserved_recovery_amount, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    # Amount withheld from this new earning and routed to the platform to
    # recover earlier refund liabilities.
    attribute :recovery_amount, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute :recovery_applied_amount, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute :recovery_reversed_amount, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute :recovery_breakdown, :map do
      allow_nil?(false)
      default(%{"items" => []})
      public?(true)
    end

    attribute :paystack_split_reference, :string do
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :payment, Emakola.Payments.Payment do
      source_attribute(:payment_id)
      define_attribute?(false)
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  policies do
    # Creates are permissive (system code sets store_id; checkout runs without an actor).
    bypass action_type(:create) do
      authorize_if(always())
    end

    # Merchant actors: verify store membership for reads and updates.
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # nil actor falls through to default-deny. Settlement code uses authorize?: false.
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :store_id,
        :payment_id,
        :role,
        :recipient_store_id,
        :supplier_id,
        :subaccount_code,
        :amount,
        :recovery_amount,
        :recovery_breakdown
      ])
    end

    update :update_recovery_tracking do
      require_atomic?(false)

      accept([
        :recovered_amount,
        :reserved_recovery_amount,
        :recovery_applied_amount,
        :recovery_reversed_amount
      ])
    end

    update :mark_settled do
      require_atomic?(false)
      accept([:paystack_split_reference])
      change(set_attribute(:status, :settled))
    end

    update :record_reversal do
      require_atomic?(false)
      accept([:reversed_amount])

      change(fn changeset, _context ->
        reversed_amount = Ash.Changeset.get_attribute(changeset, :reversed_amount) || 0

        status =
          if reversed_amount >= changeset.data.amount,
            do: :reversed,
            else: :partially_reversed

        Ash.Changeset.change_attribute(changeset, :status, status)
      end)
    end

    update :mark_reversed do
      require_atomic?(false)
      accept([])

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:reversed_amount, changeset.data.amount)
        |> Ash.Changeset.change_attribute(:status, :reversed)
      end)
    end

    read :by_payment do
      argument(:payment_id, :uuid, allow_nil?: false)
      filter(expr(payment_id == ^arg(:payment_id)))
    end

    read :recoverable_by_recipient do
      argument(:recipient_store_id, :uuid, allow_nil?: false)

      filter(
        expr(
          recipient_store_id == ^arg(:recipient_store_id) and role != :platform and
            reversed_amount > recovered_amount + reserved_recovery_amount
        )
      )

      prepare(build(sort: [inserted_at: :asc]))
    end
  end
end
