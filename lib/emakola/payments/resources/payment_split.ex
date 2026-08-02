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
      constraints(one_of: [:wholesaler, :dropshipper, :platform, :merchant, :credit_partner])
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

    attribute :credit_agreement_id, :uuid do
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

    # Dispatch fee withheld from this split's reversible base, frozen at the
    # first reversal. Protection is derived from state that keeps moving (a
    # fulfillment ships, a return blames the supplier), but reversals only
    # ratchet upward — so the derivation is persisted once and every later
    # refund event reuses it instead of recomputing against newer facts.
    attribute :protected_dispatch_fee, :integer do
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

    # Which rail settles this allocation: the gateway routed it at charge
    # (:gateway_share) or the money stays in the platform main account and is
    # owed via this ledger (:internal_hold). Platform rows are always
    # :internal_hold — their cut never leaves the main account on either rail.
    attribute :settlement_method, :atom do
      constraints(one_of: [:gateway_share, :internal_hold])
      default(:gateway_share)
      allow_nil?(false)
      public?(true)
    end

    attribute :currency, :string do
      allow_nil?(false)
      default("GHS")
      public?(true)
    end

    # Claim stamp for internal-rail payouts, mirroring Payment.paid_out_at /
    # payout_id. Nil until a payout claims this allocation.
    attribute :paid_out_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :payout_id, :uuid do
      public?(true)
    end

    # Net frozen at claim time (amount - reversed_amount then). What the payout
    # actually paid, immune to later reversals moving underneath it.
    attribute :paid_amount, :integer do
      public?(true)
    end

    # No-double-claw fence: reversals that were already netted into a claim
    # (payable = amount - reversed) must not ALSO be recovered from future
    # earnings. Frozen at claim, reset on release. Gateway splits keep 0.
    attribute :netted_reversal_amount, :integer do
      allow_nil?(false)
      default(0)
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

  identities do
    # One split per (payment, role, supplier, credit agreement). Every revenue
    # number the platform reports is a sum over this table, so a checkout retry
    # must not be able to double-record an allocation. `nils_distinct?: false`
    # because supplier_id/credit_agreement_id are nil for most roles — two
    # :platform rows for the same payment must collide.
    identity :unique_allocation, [:payment_id, :role, :supplier_id, :credit_agreement_id] do
      nils_distinct?(false)
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

    # Merchant actors: store membership grants READS ONLY. The ledger's update
    # actions (mark_settled, mark_reversed, record_reversal, ...) mutate money
    # state and are system-only — every legitimate caller runs
    # `authorize?: false` from webhook/settlement code. Without this scoping, a
    # future feature exposing any PaymentSplit update would hand merchants a
    # lever over their own splits' status.
    policy [actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant), action_type(:read)] do
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
        :credit_agreement_id,
        :subaccount_code,
        :amount,
        :recovery_amount,
        :recovery_breakdown,
        :settlement_method,
        :currency
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

      # Only a pending split can settle. Without this, a replayed
      # charge.success interleaving with refund.processed could flip a
      # :reversed split back to :settled — resurrecting clawed-back money.
      # (The webhook handler filters to :pending anyway; this is the backstop.)
      validate attribute_in(:status, [:pending]) do
        message("can only settle a pending split")
      end

      change(set_attribute(:status, :settled))
    end

    # Stamps the gateway's settlement id on an already-settled split — the
    # proof that the money actually moved, distinct from "the charge was
    # accepted" (which is what :settled means). No status change.
    update :record_settlement_reference do
      require_atomic?(false)
      accept([:paystack_split_reference])

      validate attribute_in(:status, [:settled, :partially_reversed, :reversed]) do
        message("cannot stamp a settlement reference on a pending split")
      end
    end

    # Written once, by the first `RefundLiability.reconcile!/2` for a payment.
    # Pinning the fee is what makes later refund events replay the same bases.
    update :pin_dispatch_protection do
      require_atomic?(false)
      accept([:protected_dispatch_fee])
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

    # THE definition of internally-payable money — the split-level sibling of
    # Payment.outstanding_for_payout (which owns the legacy :none population;
    # the two can never overlap because a charge is entirely one split_mode).
    # Change it ONLY here.
    read :payable_internal do
      argument(:recipient_store_id, :uuid, allow_nil?: true)

      filter(
        expr(
          settlement_method == :internal_hold and role != :platform and
            status in [:settled, :partially_reversed] and is_nil(paid_out_at) and
            amount > reversed_amount and
            (is_nil(^arg(:recipient_store_id)) or
               recipient_store_id == ^arg(:recipient_store_id))
        )
      )

      prepare(build(sort: [inserted_at: :asc]))
    end
  end
end
