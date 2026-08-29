defmodule Emakola.Orders.FulfillmentDeliveryProof do
  @moduledoc """
  A short-lived, attempt-capped customer OTP proving physical delivery.

  This is the only mechanism in the system that requires a second party to
  assent before a merchant is paid, so the caps have to mean what they say.

  ## Two counters, deliberately

  `attempts` caps guesses against ONE code and resets when a new code is sent —
  a buyer who fat-fingers a digit should not be locked out of the next code.
  `total_attempts` never resets. Without it the cap was per-code rather than
  per-proof: reissuing bought a fresh window, so at three sends per ten minutes
  an attacker had fifteen guesses per ten minutes forever, and the "5 attempts"
  cap bounded nothing.

  ## A verified proof is final

  `:reissue` used to clear `verified_at`, so the record offered no replay
  protection of its own and the only thing standing in the way was a status
  check in the caller. Verification is now terminal here too.
  """

  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  # Five guesses per code, five codes' worth of guessing in total. Beyond that
  # the order needs a human, not another code.
  @lifetime_attempt_budget 25

  postgres do
    table("fulfillment_delivery_proofs")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:fulfillment_id, :uuid, allow_nil?: false, public?: true)
    attribute(:code_hash, :string, allow_nil?: false, sensitive?: true, public?: false)
    attribute(:expires_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:attempts, :integer, allow_nil?: false, default: 0, public?: true)

    # Never reset. See the moduledoc — `attempts` alone made the cap per-code.
    attribute(:total_attempts, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:sent_to, :string, allow_nil?: false, public?: true)
    attribute(:verified_at, :utc_datetime_usec, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :fulfillment, Emakola.Orders.Fulfillment do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_fulfillment, [:fulfillment_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :issue do
      accept([:fulfillment_id, :code_hash, :expires_at, :sent_to])
    end

    update :reissue do
      require_atomic?(false)
      accept([:code_hash, :expires_at, :sent_to])

      validate(attribute_equals(:verified_at, nil),
        message: "this delivery is already confirmed"
      )

      validate(compare(:total_attempts, less_than: @lifetime_attempt_budget),
        message: "too many delivery code attempts on this order"
      )

      change(set_attribute(:attempts, 0))

      # Both predicates pushed into the UPDATE's WHERE, matching the house
      # pattern: two concurrent reissues must not both read an unspent budget.
      change(fn changeset, _context ->
        Ash.Changeset.filter(
          changeset,
          expr(is_nil(verified_at) and total_attempts < ^@lifetime_attempt_budget)
        )
      end)
    end

    update :record_attempt do
      require_atomic?(true)
      change(atomic_update(:attempts, expr(attempts + 1)))
      change(atomic_update(:total_attempts, expr(total_attempts + 1)))
    end

    update :verify do
      require_atomic?(false)
      accept([])
      change(set_attribute(:verified_at, &DateTime.utc_now/0))
      change(Emakola.Orders.Changes.ReleaseProtectionHoldOnVerify)
    end
  end
end
