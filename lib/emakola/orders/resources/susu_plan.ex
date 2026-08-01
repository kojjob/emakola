defmodule Emakola.Orders.SusuPlan do
  @moduledoc """
  A merchant-created susu (rotating savings / lay-away) plan: buyers pay
  flexible MoMo "chunks" toward a snapshotted `total_amount` by a `deadline`.
  Two flavors, same as `PayLink`:

    * `:catalog` — points at a variant, `quantity` reserved once the plan
      activates.
    * `:custom` — negotiated `title` + `total_amount`.

  Lifecycle: `:pending` (created, not yet started) → `:active` (first
  contribution received) → `:completed` (contributed_amount reaches
  total_amount) | `:expired` (deadline passed while active) | `:cancelled`
  (buyer or merchant walks away). Money movement, stock reservation, and
  order creation are handled by later tasks in this feature — this resource
  only owns the plan's own state machine.
  """

  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("susu_plans")
    repo(Emakola.Repo)
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:code, :string, allow_nil?: false, public?: true)

    attribute(:type, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:catalog, :custom]]
    )

    attribute(:variant_id, :uuid, public?: true)
    attribute(:quantity, :integer, allow_nil?: false, default: 1, public?: true)
    attribute(:title, :string, public?: true, constraints: [max_length: 200])
    attribute(:total_amount, :integer, allow_nil?: false, public?: true)
    attribute(:min_chunk, :integer, allow_nil?: false, default: 1_000, public?: true)
    attribute(:deadline, :utc_datetime_usec, allow_nil?: false, public?: true)

    # Snapshotted at create from the same config source
    # Emakola.Payments.OrderSettlement.platform_fee_rate_bps/0 reads
    # (:emakola, :platform_fee_rate_bps, default 200) — completion apportions
    # the fee across contributions using THIS value, never a live re-read, so
    # a mid-plan config change can't retroactively change what a buyer
    # already agreed to pay towards.
    attribute(:fee_rate_bps, :integer, allow_nil?: false, public?: true)

    attribute(:collect_delivery, :boolean, allow_nil?: false, default: true, public?: true)

    attribute :status, :atom do
      allow_nil?(false)
      default(:pending)
      public?(true)
      constraints(one_of: [:pending, :active, :completed, :expired, :cancelled])
    end

    attribute(:customer_id, :uuid, public?: true)
    attribute(:contributed_amount, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:delivery_address, :map, public?: true, filterable?: false)

    # Set by SusuStock.reserve/1 (a later task) at activation; read by
    # SusuStock.release/1 on expiry/cancel to decide whether there is
    # anything to give back.
    attribute(:stock_reserved, :boolean, allow_nil?: false, default: false, public?: true)

    # Notification dedup timestamps (a later task's nudge/warning worker) —
    # nullable, never set here.
    attribute(:last_nudged_at, :utc_datetime_usec, public?: true)
    attribute(:warned_7d_at, :utc_datetime_usec, public?: true)
    attribute(:warned_1d_at, :utc_datetime_usec, public?: true)

    attribute(:note, :string, public?: true, constraints: [max_length: 500])
    attribute(:created_by_user_id, :uuid, public?: true)
    timestamps()
  end

  identities do
    # all_tenants?: true — code must be unique across every store, not just
    # within one. The buyer-facing lookup (get_by_code, below) has no store
    # context to disambiguate with; without this, ash_postgres would default
    # to a (store_id, code) index and two stores could mint the same code.
    identity(:unique_code, [:code], all_tenants?: true)
  end

  policies do
    bypass action_type(:action) do
      authorize_if(always())
    end

    # Merchant store-membership for create/cancel/etc; public buyer reads and
    # webhook/internal updates opt in via authorize?: false at call sites —
    # the same posture as PayLink/Order.
    policy action_type([:create, :update]) do
      forbid_unless(actor_present())
      forbid_unless(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  validations do
    validate(present([:variant_id]),
      where: [attribute_equals(:type, :catalog)],
      message: "catalog plans need a product variant"
    )

    validate(present([:title]),
      where: [attribute_equals(:type, :custom)],
      message: "custom plans need a title"
    )

    validate(compare(:total_amount, greater_than_or_equal_to: 100),
      message: "must be at least 100 (GH₵1.00)"
    )

    validate(compare(:quantity, greater_than: 0))
    validate(compare(:min_chunk, greater_than: 0))
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :store_id,
        :type,
        :variant_id,
        :quantity,
        :title,
        :total_amount,
        :min_chunk,
        :deadline,
        :collect_delivery,
        :note,
        :created_by_user_id
      ])

      # Scoped to :create only (not the resource-wide validations block)
      # because :expire legitimately transitions a plan whose deadline is
      # already in the past, and a global "deadline > now" validation would
      # reject that.
      validate(compare(:deadline, greater_than: &DateTime.utc_now/0),
        message: "must be in the future"
      )

      change(Emakola.Orders.Changes.GenerateShortCode)

      change(fn changeset, _ctx ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :fee_rate_bps,
          Application.get_env(:emakola, :platform_fee_rate_bps, 200)
        )
      end)

      # A catalog plan's variant_id must belong to the same store as the
      # plan — mirrors PayLink's identical guard (see pay_link.ex).
      change(fn changeset, _ctx ->
        with :catalog <- Ash.Changeset.get_attribute(changeset, :type),
             variant_id when not is_nil(variant_id) <-
               Ash.Changeset.get_attribute(changeset, :variant_id),
             store_id when not is_nil(store_id) <-
               Ash.Changeset.get_attribute(changeset, :store_id),
             {:ok, variant} <-
               Ash.get(Emakola.Catalog.Variant, variant_id, authorize?: false) do
          if variant.store_id == store_id do
            changeset
          else
            Ash.Changeset.add_error(changeset,
              field: :variant_id,
              message: "does not belong to this store"
            )
          end
        else
          {:error, _} ->
            Ash.Changeset.add_error(changeset, field: :variant_id, message: "not found")

          _ ->
            changeset
        end
      end)
    end

    # No store context here by design — a buyer opens `/susu/:code` before
    # anything is known about which store it belongs to. `get?(true)` relies
    # on `code` being unique across every tenant (see the `all_tenants?: true`
    # identity above); without that, two stores minting the same code would
    # make this raise "expected at most one result" instead of resolving.
    read :get_by_code do
      get?(true)
      argument(:code, :string, allow_nil?: false)
      filter(expr(code == ^arg(:code)))
    end

    # Merchant admin listing — tenant-scoped by the caller-supplied `tenant:`
    # (attribute multitenancy filters to that store automatically). Mirrors
    # PayLink's `:list_for_admin`; no extra aggregate needed here (unlike
    # PayLink's `paid_orders_count`) — a plan's own contributed_amount/
    # total_amount/status attributes already carry everything the admin
    # progress + funnel columns need.
    read :list_for_admin do
      prepare(build(sort: [inserted_at: :desc]))
    end

    update :activate do
      accept([:customer_id, :delivery_address])
      validate(attribute_in(:status, [:pending]))
      change(set_attribute(:status, :active))
    end

    update :record_contribution do
      accept([])
      argument(:amount_delta, :integer, allow_nil?: false)
      validate(attribute_in(:status, [:active]))

      # Defense in depth: SusuChunks.confirm_chunk/1 (TC-3 Task 3) is the
      # only caller today and already enforces a positive, non-overshooting
      # delta under the plan's FOR UPDATE lock — but this action has no
      # other caller-side guard against a negative delta silently
      # decrementing money, so the action itself must refuse one too.
      validate(compare(:amount_delta, greater_than: 0))

      change(atomic_update(:contributed_amount, expr(contributed_amount + ^arg(:amount_delta))))
    end

    update :complete do
      accept([])
      validate(attribute_in(:status, [:active]))

      validate(compare(:contributed_amount, is_equal: :total_amount),
        message: "can only complete once fully contributed"
      )

      change(set_attribute(:status, :completed))
    end

    update :cancel do
      accept([])
      validate(attribute_in(:status, [:pending, :active]))
      change(set_attribute(:status, :cancelled))
    end

    update :expire do
      accept([])
      validate(attribute_in(:status, [:active]))
      change(set_attribute(:status, :expired))
    end

    update :extend_deadline do
      require_atomic?(false)
      accept([:deadline])
      validate(attribute_in(:status, [:active]))

      validate(fn changeset, _context ->
        old_deadline = changeset.data.deadline
        new_deadline = Ash.Changeset.get_attribute(changeset, :deadline)

        if new_deadline && old_deadline && DateTime.compare(new_deadline, old_deadline) == :gt do
          :ok
        else
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :deadline,
             message: "must be later than the current deadline"
           )}
        end
      end)
    end

    update :update_delivery do
      accept([:delivery_address])
      validate(attribute_in(:status, [:active]))
    end

    # Written by SusuStock.reserve/1 and SusuStock.release/1 (Task 4) — the
    # set/read flag that tells release/1 whether there's anything to give
    # stock back for. Not a status-machine transition, so no status guard.
    update :mark_stock_reserved do
      accept([])
      change(set_attribute(:stock_reserved, true))
    end

    update :clear_stock_reserved do
      accept([])
      change(set_attribute(:stock_reserved, false))
    end

    # Written by `Emakola.Payments.Workers.SusuNudgeWorker`'s daily sweep
    # (TC-3 Task 8) — the three dedup timestamps that make each nudge/warning
    # fire at most once per plan. Plain timestamp stamps, not status-machine
    # transitions, so none carry a status guard (mirrors the stock-reserved
    # actions above).
    update :mark_nudged do
      accept([])
      change(set_attribute(:last_nudged_at, &DateTime.utc_now/0))
    end

    update :mark_warned_7d do
      accept([])
      change(set_attribute(:warned_7d_at, &DateTime.utc_now/0))
    end

    update :mark_warned_1d do
      accept([])
      change(set_attribute(:warned_1d_at, &DateTime.utc_now/0))
    end
  end

  @doc "Can a buyer start this plan? Only while pending and before the deadline."
  # Plain-map patterns with an explicit :__struct__ key, NOT `%__MODULE__{}`:
  # Ash defines this module's struct via Spark DSL hooks, and on the release
  # image's Elixir (Dockerfile pins 1.18.3) `%__MODULE__{}` expands before the
  # struct exists — MIX_ENV=prod compile fails while dev/test/CI (1.20) pass.
  # Same class of failure as the `PayLink.usable?/1` hotfix.
  def usable_for_start?(%{__struct__: __MODULE__, status: :pending, deadline: deadline}) do
    DateTime.compare(deadline, DateTime.utc_now()) != :lt
  end

  def usable_for_start?(%{__struct__: __MODULE__}), do: false

  @doc "Amount still owed toward the plan's total."
  def remaining(%{
        __struct__: __MODULE__,
        total_amount: total_amount,
        contributed_amount: contributed_amount
      }) do
    total_amount - contributed_amount
  end

  @doc """
  Min/max bounds for the next chunk: `min_chunk <= amount <= remaining`,
  except `min` collapses down to `remaining` once `remaining < min_chunk` —
  otherwise the last little bit owed could never be paid (nothing between
  `min_chunk` and `remaining` would be valid), so the range collapses to the
  single value that lands exactly on the total.
  """
  def chunk_bounds(%{__struct__: __MODULE__, min_chunk: min_chunk} = plan) do
    remaining = remaining(plan)
    %{min: min(min_chunk, remaining), max: remaining}
  end
end
