defmodule Emakola.Orders.Fulfillment do
  @moduledoc """
  Fulfillment resource — a per-supplier (or merchant-owned) shipment group
  within an order.

  When a cart mixes items from multiple dropship suppliers and the merchant's
  own stock, checkout splits the order into one fulfillment per distinct
  `supplier_id` (plus one merchant-owned group where `supplier_id` is nil).
  Each fulfillment tracks its own status lifecycle and tracking number.

  Statuses: pending -> notified -> shipped -> delivered, with cancel allowed
  from any non-terminal state.

  A supplier acting on their own link adds two moves. Accepting is a
  *timestamp* (`accepted_at`) and deliberately does not touch `status` —
  nothing queries on it, and `is_nil(accepted_at)` survives a re-notify in a
  way `status == :notified` does not. Declining IS a status (`:declined`),
  because a blocked order is something the merchant must see and act on, and
  reusing `:cancelled` would drop the group out of the merchant's action row
  exactly when they need to re-source it.
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
    table("fulfillments")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :order_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    # nil supplier_id denotes the merchant-fulfilled (own-stock) group.
    attribute :supplier_id, :uuid do
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :notified, :shipped, :delivered, :cancelled, :declined])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :tracking_number, :string do
      public?(true)
      constraints(max_length: 100)
    end

    attribute :notified_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :notified_via, :atom do
      constraints(one_of: [:whatsapp, :sms, :manual])
      public?(true)
    end

    # Set when the supplier taps "I have it" on their action link.
    #
    # IMPORTANT: "accepted" is TWO states — `:pending` + accepted_at and
    # `:notified` + accepted_at — because the merchant may send the link before
    # SupplierNotificationWorker runs. Every UI and query site must key on
    # `accepted_at` FIRST and `status` second, or it will nag a supplier who
    # has already agreed.
    attribute :accepted_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :declined_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :decline_reason, :atom do
      constraints(one_of: [:out_of_stock, :price_too_low, :cannot_deliver])
      public?(true)
    end

    # The SLA clock. A stored deadline rather than one derived at read time,
    # and where it starts from is the whole point:
    #
    #   NOT notified_at — that is the symptom. It is written only when a
    #   provider returned {:ok, _}, and with placeholder WhatsApp credentials in
    #   production it is never written, so the clock would never start.
    #
    #   NOT inserted_at — fulfilments are created at CHECKOUT, before payment.
    #   A clock from there chases suppliers about carts nobody bought.
    #
    # Stamped at Order.:confirm instead — the moment somebody actually paid.
    # NULL means no clock, which is both the merchant's own-stock group and
    # every row that predates this.
    attribute :respond_by, :utc_datetime_usec do
      public?(true)
    end

    attribute :escalation_level, :integer do
      allow_nil?(false)
      default(0)
      constraints(min: 0, max: 3)
      public?(true)
    end

    attribute :escalated_at, :utc_datetime_usec do
      public?(true)
    end

    # How this fulfilment reached :delivered, and it matters because delivery
    # is what starts the merchant's payout clock.
    #
    # true  — a second party assented: the buyer read out their OTP.
    # false — the merchant attested to their own delivery. Kept as an escape
    #         hatch (there is no auto-release timer, so a merchant whose buyer
    #         never answers would otherwise wait 30 days for staff), but it must
    #         never look identical to a proven one.
    attribute :delivery_verified, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    attribute :delivery_attested_by_id, :uuid do
      public?(true)
    end

    attribute :delivery_attested_at, :utc_datetime_usec do
      public?(true)
    end

    # Why the failed send is recorded on the fulfilment rather than left in
    # oban_jobs: a dead-lettered job is invisible to the merchant, so the
    # fulfilment sits :pending forever and nobody is told the supplier never
    # heard. A LABEL only — the provider response body can carry phone numbers
    # and Meta account ids, which is why the channel itself logs "provider
    # response omitted". Cleared on a successful notify, so anything visible is
    # always a current problem.
    attribute :last_send_error, :string do
      constraints(max_length: 64)
      public?(true)
    end

    attribute :last_send_error_at, :utc_datetime_usec do
      public?(true)
    end

    # Bumping this invalidates every supplier action link ever minted for this
    # fulfillment. It is the revocation mechanism for a capability URL the
    # merchant pasted into WhatsApp and now wants dead, and it is why no
    # separate token table is needed. Never leaves the boundary.
    attribute :supplier_link_version, :integer do
      allow_nil?(false)
      default(1)
      public?(false)
    end

    # Snapshot of the supplier dispatch fee charged at checkout, integer
    # pesewas — the max across the supplier's offers in the cart, resolved
    # once inside the checkout transaction. Never recomputed from the offer
    # afterward, so later offer edits don't change an already-placed order.
    attribute(:dispatch_fee, :integer, allow_nil?: false, default: 0, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :order, Emakola.Orders.Order do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :supplier, Emakola.Suppliers.Supplier do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    has_many :line_items, Emakola.Orders.LineItem

    has_one :delivery_proof, Emakola.Orders.FulfillmentDeliveryProof do
      destination_attribute(:fulfillment_id)
      public?(true)
    end
  end

  policies do
    # Generic actions (action :name) — internal helpers, no policy
    bypass action_type(:action) do
      authorize_if(always())
    end

    # Creates require Merchant with store access. CheckoutService creates
    # fulfillments without an actor and opts in via `authorize?: false`.
    policy action_type(:create) do
      forbid_unless(actor_present())
      forbid_unless(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Merchant actors: verify store membership (for reads + writes)
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Customer actors: row-scoped reads — only fulfillments for their own orders within their store.
    policy actor_attribute_equals(:__struct__, Emakola.Customers.Customer) do
      authorize_if(
        expr(exists(order, customer_id == ^actor(:id)) and store_id == ^actor(:store_id))
      )
    end

    # nil actor falls through to default-deny.
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :order_id, :supplier_id, :status, :dispatch_fee])
    end

    # ── Status transitions ──
    # Uses the reusable StatusGuard validation. See
    # Emakola.Validations.StatusGuard for docs.

    update :mark_notified do
      require_atomic?(false)
      accept([:notified_via])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending], message: "can only notify a pending fulfillment"}
      )

      change({Emakola.Orders.Changes.RequireStatusIn, from: [:pending]})

      change(set_attribute(:status, :notified))
      change(set_attribute(:notified_at, &DateTime.utc_now/0))

      # A visible error must always be a CURRENT problem.
      change(set_attribute(:last_send_error, nil))
      change(set_attribute(:last_send_error_at, nil))
    end

    # Records that the supplier could not be reached. Deliberately does not
    # touch status: nothing was delivered, so the fulfilment is still pending
    # someone's attention — it is now just pending it visibly.
    update :record_send_failure do
      require_atomic?(false)
      accept([:last_send_error])

      change(set_attribute(:last_send_error_at, &DateTime.utc_now/0))
    end

    # :declined is included on purpose — a supplier saying "no stock" does not
    # stop the merchant sourcing the item elsewhere and shipping it themselves.
    # The supplier's own page still renders :declined as terminal.
    update :mark_shipped do
      require_atomic?(false)
      accept([:tracking_number])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending, :notified, :declined],
         message: "can only ship a pending, notified or declined fulfillment"}
      )

      change({Emakola.Orders.Changes.RequireStatusIn, from: [:pending, :notified, :declined]})

      change(set_attribute(:status, :shipped))
    end

    # Starts the SLA clock. Its own action so the filter below can make a
    # second confirm — the webhook and the merchant's button can both land —
    # unable to push an existing deadline later.
    update :start_sla_clock do
      require_atomic?(false)
      accept([:respond_by])

      change(fn changeset, _context ->
        Ash.Changeset.filter(changeset, expr(is_nil(respond_by)))
      end)
    end

    # RequireStatusIn applied to a counter instead of a status. Two runs racing
    # — an Oban retry overlapping the next cron tick — both read the same level
    # and both try to write the next one; the second matches zero rows and the
    # caller treats StaleRecord as "someone else did it", so nothing is sent
    # twice.
    update :escalate do
      require_atomic?(false)
      accept([])
      argument(:to_level, :integer, allow_nil?: false)

      change(fn changeset, _context ->
        to_level = Ash.Changeset.get_argument(changeset, :to_level)

        changeset
        |> Ash.Changeset.force_change_attribute(:escalation_level, to_level)
        |> Ash.Changeset.filter(
          expr(escalation_level == ^(to_level - 1) and status in [:pending, :notified])
        )
      end)

      change(set_attribute(:escalated_at, &DateTime.utc_now/0))
    end

    # ── Supplier-driven transitions (the /supply/:token action link) ──

    # Accept stamps a timestamp and leaves status alone — see the attribute
    # comment on :accepted_at for why that asymmetry is load-bearing.
    update :supplier_accept do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending, :notified], message: "can only accept a pending or notified fulfillment"}
      )

      change({Emakola.Orders.Changes.RequireStatusIn, from: [:pending, :notified]})

      # Idempotent. The link is a capability, so replay is the design: a
      # supplier tapping "I have it" twice must not slide the timestamp, which
      # would reset any downstream clock hung off it.
      change(fn changeset, _context ->
        case Ash.Changeset.get_data(changeset, :accepted_at) do
          nil ->
            Ash.Changeset.force_change_attribute(changeset, :accepted_at, DateTime.utc_now())

          _already_accepted ->
            changeset
        end
      end)
    end

    # Allowed after an accept: a supplier who said yes at 9am and found the
    # shelf empty at noon must be able to say so.
    update :supplier_decline do
      require_atomic?(false)
      accept([:decline_reason])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending, :notified],
         message: "can only decline a pending or notified fulfillment"}
      )

      change({Emakola.Orders.Changes.RequireStatusIn, from: [:pending, :notified]})

      change(set_attribute(:status, :declined))
      change(set_attribute(:declined_at, &DateTime.utc_now/0))
    end

    # No from: guard — a leaked link must be revocable in any state.
    update :rotate_supplier_link do
      require_atomic?(true)
      accept([])

      change(atomic_update(:supplier_link_version, expr(supplier_link_version + 1)))
    end

    update :mark_delivered do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:shipped], message: "can only mark as delivered from shipped"}
      )

      change({Emakola.Orders.Changes.RequireStatusIn, from: [:shipped]})

      change(set_attribute(:status, :delivered))
      change(set_attribute(:delivery_verified, true))
      change(Emakola.Orders.Changes.StampProtectionReleaseAfter)
    end

    # The merchant attesting to their own delivery — the only path to
    # :delivered with no counterparty. A SEPARATE action rather than a flag on
    # :mark_delivered, matching how this codebase already splits :void from
    # :void_unfulfilled and :mark_paid from :mark_platform_paid: two different
    # meanings, two different names, so neither can be reached by accident.
    #
    # It still stamps the payout clock. Removing that would turn an escape
    # hatch into a dead end, since nothing else starts the timer.
    update :self_attest_delivered do
      require_atomic?(false)
      accept([:delivery_attested_by_id])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:shipped], message: "can only mark as delivered from shipped"}
      )

      change({Emakola.Orders.Changes.RequireStatusIn, from: [:shipped]})

      change(set_attribute(:status, :delivered))
      change(set_attribute(:delivery_verified, false))
      change(set_attribute(:delivery_attested_at, &DateTime.utc_now/0))
      change(Emakola.Orders.Changes.StampProtectionReleaseAfter)
    end

    # A download has no shipment, so it can never satisfy :mark_delivered's
    # from: [:shipped] guard — :shipped also demands a tracking number. Without
    # this the group sits :pending forever, the admin shows a perpetual pending
    # shipment for a file, and at a buyer-protection store the payout hold
    # never releases because StampProtectionReleaseAfter hangs off delivery.
    #
    # from: [:pending] rather than relaxing :mark_delivered: the physical guard
    # stays exactly as strict, and this makes an Oban retry a no-op instead of
    # a crash.
    update :mark_delivered_digitally do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending], message: "can only auto-deliver a pending fulfillment"}
      )

      change(set_attribute(:status, :delivered))
      change(Emakola.Orders.Changes.StampProtectionReleaseAfter)
    end

    update :cancel do
      require_atomic?(false)
      accept([])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:pending, :notified, :shipped, :declined],
         message: "can only cancel an active fulfillment (not delivered or already cancelled)"}
      )

      change(
        {Emakola.Orders.Changes.RequireStatusIn, from: [:pending, :notified, :shipped, :declined]}
      )

      change(set_attribute(:status, :cancelled))
    end

    # Staff worklist: deliveries nobody but the merchant vouched for. The
    # platform protection queue's existing two lists cannot catch these —
    # a self-attested delivery is not frozen (no complaint) and not stale
    # (the timer DID start), so without this it looks exactly like a clean one.
    read :list_unverified_deliveries do
      filter(expr(status == :delivered and delivery_verified == false))

      prepare(fn query, _context ->
        Ash.Query.sort(query, delivery_attested_at: :desc)
      end)
    end

    read :list_by_order do
      argument(:order_id, :uuid, allow_nil?: false)

      filter(expr(order_id == ^arg(:order_id)))

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.Query.load([:supplier, :line_items])
      end)
    end
  end
end
