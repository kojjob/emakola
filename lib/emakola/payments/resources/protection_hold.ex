defmodule Emakola.Payments.ProtectionHold do
  @moduledoc """
  The buyer-protection escrow ledger — one row per protected payment.

  `amount`, `fee`, `net` are snapshotted at creation (invariant `fee + net ==
  amount`). State machine: `:held -> :released | :refunded`. A complaint
  freezes the auto-release timer without changing `status` — `frozen_at` is
  a flag, not a state.
  """

  use Ash.Resource,
    domain: Emakola.Payments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("protection_holds")
    repo(Emakola.Repo)

    custom_indexes do
      # all_tenants?: true — without it Ash prefixes the tenant attribute
      # (store_id), which is useless for the hourly cron sweep's cross-tenant
      # query (Emakola.Payments.Workers.ProtectionSweepWorker), the only
      # consumer of this index.
      index([:status, :release_after], all_tenants?: true)
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:payment_id, :uuid, allow_nil?: false, public?: true)
    attribute(:order_id, :uuid, allow_nil?: false, public?: true)
    attribute(:amount, :integer, allow_nil?: false, public?: true)
    attribute(:fee, :integer, allow_nil?: false, public?: true)
    attribute(:net, :integer, allow_nil?: false, public?: true)

    attribute :status, :atom do
      allow_nil?(false)
      default(:held)
      public?(true)
      constraints(one_of: [:held, :released, :refunded])
    end

    attribute(:frozen_at, :utc_datetime_usec, public?: true)
    attribute(:release_after, :utc_datetime_usec, public?: true)
    attribute(:released_at, :utc_datetime_usec, public?: true)

    attribute :release_reason, :atom do
      public?(true)
      constraints(one_of: [:delivery_otp, :buyer_confirmed, :auto_timer, :staff])
    end

    attribute :complaint_reason, :atom do
      public?(true)
      constraints(one_of: [:not_received, :not_as_described, :other])
    end

    attribute(:complaint_text, :string, public?: true, constraints: [max_length: 1000])

    attribute :resolution, :atom do
      public?(true)
      constraints(one_of: [:merchant_refunded, :released_by_staff, :refunded_by_staff])
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
    # One hold per payment — idempotent hold creation for the webhook-confirmed
    # payment-success path (Task 5+): retrying the create is safe because a
    # second attempt for the same payment_id simply errors.
    identity(:unique_payment, [:payment_id])
  end

  policies do
    bypass action_type(:action) do
      authorize_if(always())
    end

    # Merchant store-membership for create/update (mirrors PayLink); internal
    # callers (webhook confirmation, release engine, staff actions, and the
    # platform staff protection queue's cross-tenant reads — TC-2 Task 12)
    # opt in via authorize?: false at the call site, matching the established
    # platform-admin convention (e.g. `Platform.StoreLive.Index`,
    # `Platform.ModerationLive.Index`) rather than an actor-based policy.
    policy action_type([:create, :update]) do
      forbid_unless(actor_present())
      forbid_unless(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :payment_id, :order_id, :amount, :fee, :net])

      # fee + net == amount is a hard invariant on the snapshot — these are
      # plain accepted attributes (not action arguments), so read them off
      # the changeset directly.
      change(fn changeset, _ctx ->
        amount = Ash.Changeset.get_attribute(changeset, :amount)
        fee = Ash.Changeset.get_attribute(changeset, :fee)
        net = Ash.Changeset.get_attribute(changeset, :net)

        if is_integer(amount) and is_integer(fee) and is_integer(net) and fee + net != amount do
          Ash.Changeset.add_error(changeset,
            field: :amount,
            message: "fee + net must equal amount"
          )
        else
          changeset
        end
      end)
    end

    update :release do
      accept([:release_reason, :resolution])
      validate(attribute_in(:status, [:held]))
      change(set_attribute(:status, :released))
      change(set_attribute(:released_at, &DateTime.utc_now/0))
    end

    update :mark_refunded do
      accept([:resolution])
      validate(attribute_in(:status, [:held]))
      change(set_attribute(:status, :refunded))
    end

    # A complaint freezes the auto-release timer without changing `status` —
    # the hold stays :held. A second complaint on an already-frozen hold must
    # go through :update_complaint instead (one active complaint per hold).
    update :freeze do
      accept([:complaint_reason, :complaint_text])
      validate(attribute_in(:status, [:held]))
      validate(absent(:frozen_at), message: "hold already has an active complaint")
      change(set_attribute(:frozen_at, &DateTime.utc_now/0))
    end

    update :update_complaint do
      accept([:complaint_reason, :complaint_text])
      validate(present(:frozen_at), message: "hold is not frozen")
    end

    # Internal — clears a complaint freeze once staff resolve it.
    update :unfreeze do
      accept([])
      change(set_attribute(:frozen_at, nil))
    end

    update :set_release_after do
      accept([:release_after])
      validate(attribute_in(:status, [:held]))
    end

    read :get_by_payment do
      get?(true)
      argument(:payment_id, :uuid, allow_nil?: false)
      filter(expr(payment_id == ^arg(:payment_id)))
    end
  end
end
