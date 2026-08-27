defmodule Emakola.Stores.DirectoryStanding do
  @moduledoc """
  The featuring worker's ledger: one row per store holding its computed
  eligibility, merit score with breakdown, assigned slot — and the fields
  staff and (one day) billing own.

  Deliberately a separate resource rather than columns on `Store`, for the
  same reason `StorePayoutAccount` is: the Store read policy is effectively
  public, and `disqualifiers: [:conduct]` or an override reason must never
  be loadable by an anonymous storefront read. The three cache columns ON
  Store carry only what public reads need — score, eligible, slot.

  Ownership is enforced at the data layer, not by discipline:

    * the worker's `:record` upsert lists ONLY the computed fields in
      `upsert_fields`, so a nightly run can never clobber an override;
    * `:override` is the only writer of the staff fields;
    * nothing writes `paid_placement_*` — the seam stays dark until the
      earned-floor/paid-boost decision is implemented for real.

  All actions are platform/system-only, called with `authorize?: false`
  from surfaces that gate on `:manage_stores` — the same convention as the
  Store lifecycle actions and `StoreVerification.approve/reject`.
  """

  use Ash.Resource,
    domain: Emakola.Stores,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("store_directory_standings")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :eligible, :boolean do
      allow_nil?(false)
      default(false)
    end

    attribute :disqualifiers, {:array, :atom} do
      allow_nil?(false)
      default([])
      constraints(items: [one_of: [:abandoned, :incomplete, :no_payout, :conduct]])
    end

    attribute :score, :integer do
      allow_nil?(false)
      default(0)
      constraints(min: 0, max: 1000)
    end

    attribute :score_breakdown, :map do
      allow_nil?(false)
      default(%{})
    end

    attribute :slot, :atom do
      allow_nil?(true)
      constraints(one_of: [:spotlight, :rising, :editors_pick, :promoted])
    end

    attribute(:computed_at, :utc_datetime_usec)

    # ── Staff-owned. The worker's upsert never lists these. ──
    attribute :override_slot, :atom do
      allow_nil?(true)
      constraints(one_of: [:spotlight, :rising, :editors_pick, :promoted])
    end

    attribute :override_excluded, :boolean do
      allow_nil?(false)
      default(false)
    end

    attribute(:override_reason, :string)
    attribute(:override_until, :utc_datetime_usec)
    attribute(:override_by_id, :uuid)
    attribute(:override_at, :utc_datetime_usec)

    # ── The paid seam. Nothing writes these yet, deliberately. ──
    attribute :paid_placement_weight, :integer do
      allow_nil?(false)
      default(0)
    end

    attribute(:paid_placement_until, :utc_datetime_usec)

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      allow_nil?(false)
    end
  end

  identities do
    identity(:unique_store, [:store_id])
  end

  actions do
    defaults([:read])

    # The nightly worker's write. The upsert_fields list IS the ownership
    # boundary — override_* and paid_placement_* are absent, so a recompute
    # can never clobber a human's decision or the billing seam.
    create :record do
      accept([
        :store_id,
        :eligible,
        :disqualifiers,
        :score,
        :score_breakdown,
        :slot,
        :computed_at
      ])

      upsert?(true)
      upsert_identity(:unique_store)

      upsert_fields([:eligible, :disqualifiers, :score, :score_breakdown, :slot, :computed_at])
    end

    update :override do
      accept([
        :override_slot,
        :override_excluded,
        :override_reason,
        :override_until,
        :override_by_id,
        :override_at
      ])
    end
  end

  policies do
    # Everything here is platform/system-only. A standing carries the
    # disqualifier list and staff reasoning; neither belongs to a merchant
    # actor, a customer, or an anonymous read. Surfaces that legitimately
    # need it (platform admin, the worker) use authorize?: false behind
    # their own :manage_stores gate.
    policy always() do
      forbid_if(always())
    end
  end
end
