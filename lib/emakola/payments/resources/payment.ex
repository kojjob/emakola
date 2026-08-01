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

    # A chunk payment toward a susu plan (TC-3) — mutually exclusive with
    # `order_id` at create (see the `:create` action's validation). Nil
    # until completion, when `:attach_order` stamps a payment's `order_id`
    # onto every contribution.
    attribute :susu_plan_id, :uuid do
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

    # Whether this charge is split across dropship parties at the gateway.
    attribute :split_mode, :atom do
      constraints(one_of: [:none, :dropship_split, :platform_fee])
      default(:none)
      allow_nil?(false)
      public?(true)
    end

    # The Paystack split code used to route this charge, when split_mode is :dropship_split.
    attribute :split_code, :string do
      public?(true)
    end

    # Set when this charge's held balance has been included in a merchant Payout
    # (only relevant for un-split `split_mode: :none` charges). Stamping it removes
    # the charge from the outstanding-payout backlog so it can never be paid twice.
    attribute :paid_out_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :payout_id, :uuid do
      public?(true)
    end

    attribute :payout_held, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    attribute :payout_hold_reason, :string do
      public?(true)
    end

    attribute :payout_released_at, :utc_datetime_usec do
      public?(true)
    end

    # Buyer Protection: when set, PayoutService pays this instead of `amount`
    # — the merchant's protected charges pay out net-of-fee once their
    # ProtectionHold releases (Task 5).
    attribute :payable_amount, :integer do
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
        :susu_plan_id,
        :amount,
        :currency,
        :gateway,
        :gateway_reference,
        :gateway_response,
        :customer_email,
        :metadata,
        :split_mode,
        :split_code,
        :payout_held,
        :payout_hold_reason
      ])

      # Mutual exclusion only — NOT "at least one required". Group-buy
      # escrow payments and protected-preorder deposit payments (see
      # `Emakola.Suppliers.GroupBuys`/`ProtectedPreorders`) legitimately
      # create with both nil; neither concept applies to those payment
      # kinds, and dozens of existing tests rely on that parentless
      # default. A payment simply must never be tied to an order AND a
      # susu plan at once.
      validate(present([:order_id, :susu_plan_id], at_most: 1),
        message: "cannot be tied to both an order and a susu plan"
      )
    end

    # Susu completion (Task 5) stamps `order_id` onto every contribution
    # once a plan finishes and its order is created. Only legal once: the
    # payment must already be parented to a susu plan (not an order) and
    # must not already have an order attached — refuses re-stamping so a
    # worker retry can't silently reparent a payment.
    update :attach_order do
      require_atomic?(false)
      accept([:order_id])

      validate(fn changeset, _context ->
        cond do
          is_nil(changeset.data.susu_plan_id) ->
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :susu_plan_id,
               message: "can only attach an order to a susu-plan payment"
             )}

          not is_nil(changeset.data.order_id) ->
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :order_id,
               message: "already has an order attached"
             )}

          true ->
            :ok
        end
      end)
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

      # `refunded_amount` is the cumulative total refunded so far (the caller
      # accumulates). A partial refund keeps the payment :success so later
      # partials can still be recorded; only a FULLY refunded payment becomes
      # :refunded.
      change(fn changeset, _context ->
        refunded = Ash.Changeset.get_attribute(changeset, :refunded_amount) || 0

        if refunded >= changeset.data.amount do
          Ash.Changeset.change_attribute(changeset, :status, :refunded)
        else
          changeset
        end
      end)
    end

    # Stamp a charge as covered by a Payout so it drops out of the outstanding
    # backlog and can never be paid out twice.
    update :mark_paid_out do
      require_atomic?(false)
      accept([:payout_id])
      change(set_attribute(:paid_out_at, &DateTime.utc_now/0))
    end

    # Return a charge to the outstanding backlog when its payout failed/reversed,
    # so the balance is re-paid via a fresh payout instead of being buried.
    update :release_from_payout do
      require_atomic?(false)
      accept([])
      change(set_attribute(:paid_out_at, nil))
      change(set_attribute(:payout_id, nil))
    end

    update :release_payout_hold do
      require_atomic?(false)
      # `payable_amount` is optional here: buyer-protection release (Task 5)
      # passes the hold's snapshotted net; the group-buy escrow release
      # (group_buys.ex) calls this with no arguments and is unaffected.
      accept([:payable_amount])
      change(set_attribute(:payout_held, false))
      change(set_attribute(:payout_released_at, &DateTime.utc_now/0))
    end

    # Susu completion (TC-3 Task 5): a protected contribution's hold is NOT
    # released here — it converts into an ordinary buyer-protection hold
    # instead (`payout_held` stays true). The accompanying `ProtectionHold`
    # row this pairs with is released later through TC-2's normal
    # delivery-confirmed machinery (`ProtectionRelease.release/2,3`), the
    # same as any other protected order.
    #
    # Guarded the same way `:attach_order` is: only a payment currently
    # `susu_plan`-held may convert. Without this, any payment (order-parented
    # or otherwise) could be relabeled `buyer_protection` with no
    # `ProtectionHold` row behind it — a mislabeled payment with no release
    # path (release lookups key off `payout_hold_reason`, not a hold's
    # existence) — or an already-converted payment could be flipped a
    # second time.
    update :mark_buyer_protection_hold do
      require_atomic?(false)
      accept([])

      validate(fn changeset, _context ->
        cond do
          is_nil(changeset.data.susu_plan_id) ->
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :susu_plan_id,
               message: "can only convert a susu-plan payment's hold to buyer protection"
             )}

          changeset.data.payout_hold_reason != "susu_plan" ->
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :payout_hold_reason,
               message: "can only convert a payment currently held for \"susu_plan\""
             )}

          changeset.data.payout_held != true ->
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :payout_held,
               message: "payment is not currently held"
             )}

          true ->
            :ok
        end
      end)

      change(set_attribute(:payout_hold_reason, "buyer_protection"))
    end

    read :by_payout do
      argument(:payout_id, :uuid, allow_nil?: false)
      filter(expr(payout_id == ^arg(:payout_id)))
    end

    # THE definition of money the platform holds and still owes a merchant:
    # the charge succeeded, was not split at source (split-at-source pays the
    # merchant directly via their subaccount), is not under a payout hold, and
    # has not already been covered by a payout. This predicate decides what
    # gets paid out AND what /platform/finance reports as owed — it used to be
    # four hand-copied filters that could drift apart; change it ONLY here.
    read :outstanding_for_payout do
      argument(:store_id, :uuid, allow_nil?: true)

      filter(
        expr(
          status == :success and split_mode == :none and payout_held == false and
            is_nil(paid_out_at) and
            (is_nil(^arg(:store_id)) or store_id == ^arg(:store_id))
        )
      )
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

    # An order can carry several Payment rows: a customer whose first attempt
    # fails retries checkout and is charged again, leaving the failed row
    # behind. Only a CAPTURED charge can be refunded — `:success`, or
    # `:refunded` once refunds consumed it — never a `:pending`/`:failed`
    # attempt. Oldest first, so callers taking the first row always pick the
    # same charge: the one that settled the order and whose splits a refund
    # reverses.
    read :captured_by_order do
      argument(:order_id, :uuid, allow_nil?: false)

      filter(expr(order_id == ^arg(:order_id) and status in [:success, :refunded]))

      prepare(build(sort: [inserted_at: :asc]))
    end

    # Platform refund oversight — refunded payments across all stores
    # (Payment is global?: true; called with authorize?: false from the admin).
    read :list_refunded do
      filter(expr(status == :refunded))
      prepare(build(sort: [inserted_at: :desc], load: [:store], limit: 100))
    end

    read :failed_in_period do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:from, :utc_datetime, allow_nil?: false)
      argument(:to, :utc_datetime, allow_nil?: false)

      filter(
        expr(
          store_id == ^arg(:store_id) and
            status == :failed and
            inserted_at >= ^arg(:from) and
            inserted_at < ^arg(:to)
        )
      )
    end
  end
end
