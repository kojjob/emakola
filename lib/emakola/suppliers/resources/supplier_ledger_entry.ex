defmodule Emakola.Suppliers.SupplierLedgerEntry do
  @moduledoc """
  Payout ledger entry recording what a store owes a supplier for a single
  dropship fulfillment.

  One entry is created per supplier fulfillment at checkout, capturing the
  total supplier cost (`amount_owed`, minor units). Entries start `:owed` and
  transition to `:paid` once the merchant settles with the supplier. Entries
  are financial records — there is no destroy action.
  """

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("supplier_ledger_entries")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :supplier_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :fulfillment_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :amount_owed, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 0)
    end

    attribute :status, :atom do
      constraints(one_of: [:owed, :paid, :voided])
      default(:owed)
      allow_nil?(false)
      public?(true)
    end

    attribute :paid_at, :utc_datetime_usec do
      public?(true)
    end

    # Which flow settled this obligation: the merchant's manual "mark paid"
    # (:manual, the default — every pre-existing entry), a gateway-rail
    # wholesaler split whose money already moved at charge time
    # (:split_gateway), or an internal-rail split awaiting its allocation
    # payout (:platform_payout). Once claimed away from :manual, the manual
    # flow can never touch this entry again — see
    # `claim_for_platform_settlement` — so the same supplier debt can't be
    # both platform-settled and manually payable.
    attribute :settlement_source, :atom do
      constraints(one_of: [:manual, :platform_payout, :split_gateway])
      default(:manual)
      allow_nil?(false)
      public?(true)
    end

    # The wholesaler PaymentSplit that claimed this entry, if any. Nil for
    # :manual entries.
    attribute :payment_split_id, :uuid do
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_fulfillment_ledger, [:fulfillment_id])
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      source_attribute(:store_id)
    end

    belongs_to :supplier, Emakola.Suppliers.Supplier do
      define_attribute?(false)
      source_attribute(:supplier_id)
    end

    belongs_to :fulfillment, Emakola.Orders.Fulfillment do
      define_attribute?(false)
      source_attribute(:fulfillment_id)
    end
  end

  policies do
    # Merchant actors: verify store membership for all actions.
    # System code uses authorize?: false explicitly.
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :supplier_id, :fulfillment_id, :amount_owed, :status])
    end

    update :mark_paid do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:owed], message: "only an owed entry can be marked paid"}
      )

      # A claimed entry (settlement_source != :manual) is being settled by the
      # platform — the manual flow must never touch it, or the supplier gets
      # paid twice: once by the platform settlement, once by this button.
      validate(attribute_equals(:settlement_source, :manual),
        message: "claimed by platform settlement — cannot be marked paid manually"
      )

      change(set_attribute(:status, :paid))
      change(set_attribute(:paid_at, &DateTime.utc_now/0))

      # The two validations above read the in-memory struct the caller
      # loaded — fine for a normal call, but a concurrent
      # claim_for_platform_settlement (charge.success webhook) can land
      # between that read and this write. Pushing the same predicate into
      # the UPDATE's WHERE clause makes the database the serialization
      # point: if the row no longer matches (claimed out from under this
      # caller), zero rows are affected and Ash returns a StaleRecord error
      # instead of writing a stale :paid over a now-claimed entry — the one
      # path to the double-pay this resource's claim/mark_paid split is
      # supposed to prevent. Same mechanism as
      # Emakola.Orders.Changes.RequireStatusIn and Coupon's :increment_usage.
      change(fn changeset, _context ->
        Ash.Changeset.filter(changeset, expr(status == :owed and settlement_source == :manual))
      end)
    end

    # The platform settlement claims this obligation so the same supplier debt
    # can never exist twice (manual "mark paid" refuses a claimed entry).
    update :claim_for_platform_settlement do
      require_atomic?(false)
      accept([:payment_split_id])

      argument(:source, :atom,
        allow_nil?: false,
        constraints: [one_of: [:platform_payout, :split_gateway]]
      )

      validate(attribute_in(:status, [:owed]), message: "only an owed entry can be claimed")
      validate(attribute_equals(:settlement_source, :manual), message: "already claimed")

      change(fn changeset, _context ->
        Ash.Changeset.change_attribute(
          changeset,
          :settlement_source,
          Ash.Changeset.get_argument(changeset, :source)
        )
      end)

      # Atomic counterpart to the two validations above — see the matching
      # comment on :mark_paid. Without this, a concurrent mark_paid (merchant
      # admin click) can claim the manual write in between this action's read
      # and write, landing settlement_source: :platform_payout on top of a
      # status the manual flow just marked :paid.
      change(fn changeset, _context ->
        Ash.Changeset.filter(changeset, expr(status == :owed and settlement_source == :manual))
      end)
    end

    update :mark_platform_paid do
      require_atomic?(false)
      accept([])
      validate(attribute_in(:status, [:owed]), message: "already settled")
      change(set_attribute(:status, :paid))
      change(set_attribute(:paid_at, &DateTime.utc_now/0))
    end

    # Refund<->supplier coupling: a claimed-but-unpaid entry (:platform_payout,
    # :owed) whose wholesaler split fully reverses can no longer be settled by
    # a payout that will never carry that money, and the manual flow is
    # permanently locked out once claimed — so it's neither payable nor
    # collectible. Voiding closes it out honestly instead of leaving a debt
    # stuck forever. `status` is a plain `:string` column with no DB check
    # constraint, so adding `:voided` is an Ash-only enum change — no
    # migration required.
    update :void do
      require_atomic?(false)
      accept([])

      validate(attribute_in(:status, [:owed]), message: "only an owed entry can be voided")

      validate(attribute_equals(:settlement_source, :platform_payout),
        message: "only a platform_payout claim can be voided"
      )

      change(set_attribute(:status, :voided))
    end

    # Reversal<->supplier coupling: a `transfer.reversed` arriving AFTER an
    # allocation payout was already `:paid` means the gateway clawed the
    # money back — every SupplierLedgerEntry that payout's transfer.success
    # had marked `:paid` is now a false payment record. Reopening puts the
    # debt back in play (status: :owed, paid_at: nil) WITHOUT touching
    # settlement_source — it stays claimed by the platform (:platform_payout)
    # so the manual "mark paid" flow still can't touch it; only a fresh
    # allocation payout can settle it again. Same conditional-write mechanism
    # as :mark_paid/:claim_for_platform_settlement: the WHERE clause is the
    # serialization point, so a concurrent reopen (webhook replay) or a
    # concurrent :mark_platform_paid (a different payout's transfer.success
    # landing at the same instant) can't interleave into a corrupt state.
    update :reopen_platform_paid do
      require_atomic?(false)
      accept([])

      validate(attribute_in(:status, [:paid]), message: "only a paid entry can be reopened")

      validate(attribute_equals(:settlement_source, :platform_payout),
        message: "only a platform_payout claim can be reopened"
      )

      change(set_attribute(:status, :owed))
      change(set_attribute(:paid_at, nil))

      change(fn changeset, _context ->
        Ash.Changeset.filter(
          changeset,
          expr(status == :paid and settlement_source == :platform_payout)
        )
      end)
    end

    read :list_by_supplier do
      argument(:supplier_id, :uuid, allow_nil?: false)

      filter(expr(supplier_id == ^arg(:supplier_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :by_fulfillment do
      argument(:fulfillment_id, :uuid, allow_nil?: false)
      filter(expr(fulfillment_id == ^arg(:fulfillment_id)))
    end

    read :by_payment_split do
      argument(:payment_split_id, :uuid, allow_nil?: false)
      filter(expr(payment_split_id == ^arg(:payment_split_id)))
    end
  end
end
