defmodule Emakola.Payments.Payout do
  @moduledoc """
  A single merchant disbursement and its lifecycle — the platform paying out the
  balance it holds from un-split (`split_mode: :none`) orders.

  Lifecycle: `:pending` (created, approved) → `:processing` (transfer initiated at
  the gateway) → `:paid` | `:failed` (confirmed via `transfer.success` /
  `transfer.failed` webhooks).

  All amounts are integers in minor currency units (pesewas). `transfer_reference`
  is our unique idempotency key for the Paystack transfer — it is what the webhook
  reconciles against, and what guarantees a transfer can never fire twice.
  """

  use Ash.Resource,
    domain: Emakola.Payments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("payouts")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
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
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :processing, :paid, :failed, :reversed])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    # Which engine owns this payout: :payments claims un-split Payment rows
    # (legacy); :allocations claims internal-rail PaymentSplit rows. The two
    # populations are disjoint by construction (Payment.split_mode partition).
    attribute :basis, :atom do
      constraints(one_of: [:payments, :allocations])
      default(:payments)
      allow_nil?(false)
      public?(true)
    end

    # Paystack transfer recipient code, set when the transfer is initiated.
    attribute :recipient_code, :string do
      public?(true)
    end

    # Paystack transfer code, set when the transfer is initiated.
    attribute :transfer_code, :string do
      public?(true)
    end

    # Our unique idempotency key for the gateway transfer + webhook reconciliation.
    attribute :transfer_reference, :string do
      public?(true)
    end

    attribute :failure_reason, :string do
      public?(true)
    end

    attribute :gateway_response, :map do
      sensitive?(true)
    end

    attribute :metadata, :map do
      default(%{})
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      source_attribute(:store_id)
      define_attribute?(false)
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  policies do
    # Creates are permissive (system code sets store_id; approval runs authorize?: false).
    bypass action_type(:create) do
      authorize_if(always())
    end

    # Merchant actors: store membership grants READS ONLY (mirrors
    # PaymentSplit's policy shape). The lifecycle transitions
    # (mark_processing, mark_paid, ...) mutate money state and are
    # system-only — every legitimate caller runs `authorize?: false` from
    # worker/webhook code.
    policy [actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant), action_type(:read)] do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # nil actor falls through to default-deny. Platform code uses authorize?: false.
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :amount, :currency, :transfer_reference, :metadata, :basis])
    end

    update :mark_processing do
      require_atomic?(false)
      accept([:recipient_code, :transfer_code])

      validate attribute_in(:status, [:pending]) do
        message("can only process a pending payout")
      end

      change(set_attribute(:status, :processing))
    end

    update :mark_paid do
      require_atomic?(false)
      accept([:gateway_response])

      validate attribute_in(:status, [:pending, :processing]) do
        message("can only mark a pending or processing payout as paid")
      end

      change(set_attribute(:status, :paid))
    end

    update :mark_failed do
      require_atomic?(false)
      accept([:failure_reason, :gateway_response])

      validate attribute_in(:status, [:pending, :processing]) do
        message("can only fail a pending or processing payout")
      end

      change(set_attribute(:status, :failed))
    end

    # A reversal can arrive AFTER a success (the gateway clawed the money back), so
    # this is the one transition allowed out of :paid.
    update :mark_reversed do
      require_atomic?(false)
      accept([:failure_reason, :gateway_response])

      validate attribute_in(:status, [:pending, :processing, :paid]) do
        message("can only reverse a pending, processing or paid payout")
      end

      change(set_attribute(:status, :reversed))
    end

    read :by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :by_transfer_reference do
      argument(:transfer_reference, :string, allow_nil?: false)
      get?(true)
      filter(expr(transfer_reference == ^arg(:transfer_reference)))
    end

    # Cross-store recent payouts for the platform finance page.
    read :list_recent do
      prepare(build(sort: [inserted_at: :desc], limit: 50))
    end

    # Bounded, newest-first payout history for a single store's money-surfaces
    # UI (merchant-facing) — distinct from `by_store`'s unbounded list.
    read :recent_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc], limit: 20))
    end

    # Narrow metadata merge — does not touch status/amount/gateway fields.
    # Used to stamp a shared `approval_ref` across both payout bases created
    # by one finance approval click (money-surfaces grouping), without
    # opening a general-purpose payout update.
    update :stamp_approval_ref do
      require_atomic?(false)
      argument(:metadata, :map, allow_nil?: false)

      change(fn changeset, _context ->
        merged =
          Map.merge(
            changeset.data.metadata || %{},
            Ash.Changeset.get_argument(changeset, :metadata)
          )

        Ash.Changeset.change_attribute(changeset, :metadata, merged)
      end)
    end
  end
end
