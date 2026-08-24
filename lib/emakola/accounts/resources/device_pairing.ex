defmodule Emakola.Accounts.DevicePairing do
  @moduledoc """
  A short-lived, single-use request to sign a second device in.

  Merchants read poorly and a password is the worst control we ask them for, so
  "sign in on the desktop, scan with the phone" is worth having. But it creates
  a property nothing else in this system has: for as long as the code is on
  screen, **possession of an image is a session**. Every rule here exists to
  keep that window as small as possible.

    * Only a SHA-256 digest of the token is stored, never the token. Note the
      deliberate divergence from `Emakola.Orders.FulfillmentDeliveryProof`,
      which bcrypts its code: a 6-digit OTP has ~20 bits of entropy, so guessing
      is feasible and each attempt should be expensive. A pairing token is 32
      random bytes — there is nothing to slow down, and bcrypt's per-row salt
      would make the lookup the scanning phone needs impossible, since it
      presents the token and nothing else.
    * 90 seconds, absolute, from issue. Long enough to walk a phone over; short
      enough that a photograph is worthless by the time it leaves the screen.
    * Single-use, consumed under a row lock so two redemptions cannot both win.
    * `:confirmed` is reachable only from the desktop that minted it. Without
      that step the flow is phishable in reverse — an attacker shows *their*
      code, the merchant scans, and the attacker's browser is signed in as the
      merchant. Short TTLs and single-use do nothing against that; only a human
      confirming on an already-trusted screen does.

  Policies forbid everything: this resource is reached solely through
  `Emakola.Accounts.DevicePairings`, which owns the lifecycle.
  """

  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("device_pairings")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Which merchant a redemption would authenticate as.
    attribute(:merchant_id, :uuid, allow_nil?: false, public?: true)

    attribute(:token_digest, :string, allow_nil?: false, sensitive?: true, public?: false)
    attribute(:expires_at, :utc_datetime_usec, allow_nil?: false, public?: true)

    attribute :status, :atom do
      allow_nil?(false)
      default(:pending)
      public?(true)
      constraints(one_of: [:pending, :scanned, :confirmed, :consumed, :rejected])
    end

    # A coarse description of the phone, captured when it scans, so the desktop
    # can name what it is being asked to authorise. Never trusted for anything
    # but display.
    attribute(:scanned_by, :string, public?: true, constraints: [max_length: 200])

    attribute(:scanned_at, :utc_datetime_usec, public?: true)
    attribute(:confirmed_at, :utc_datetime_usec, public?: true)
    attribute(:consumed_at, :utc_datetime_usec, public?: true)

    timestamps()
  end

  identities do
    # The digest is the lookup key: a phone presents the token and nothing else.
    identity(:unique_token_digest, [:token_digest])
  end

  relationships do
    belongs_to :merchant, Emakola.Accounts.Merchant do
      define_attribute?(false)
      public?(true)
    end
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :issue do
      accept([:merchant_id, :token_digest, :expires_at])
    end

    update :mark_scanned do
      accept([:scanned_by])
      change(set_attribute(:status, :scanned))
      change(set_attribute(:scanned_at, &DateTime.utc_now/0))
    end

    update :confirm do
      accept([])
      change(set_attribute(:status, :confirmed))
      change(set_attribute(:confirmed_at, &DateTime.utc_now/0))
    end

    update :consume do
      accept([])
      change(set_attribute(:status, :consumed))
      change(set_attribute(:consumed_at, &DateTime.utc_now/0))
    end

    update :reject do
      accept([])
      change(set_attribute(:status, :rejected))
    end
  end
end
