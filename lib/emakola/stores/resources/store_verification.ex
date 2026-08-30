defmodule Emakola.Stores.StoreVerification do
  @moduledoc """
  A store's business verification submission and its review state. One row per
  store, created the first time a merchant submits business details.

  **This resource does not establish identity.** L.I. 2523 (National Identity
  Register (Amendment) Regulations, 2026, in force 9 June 2026) makes it an
  offence for an organisation to request, retain, reproduce or visually inspect
  a Ghana Card for identity verification. Only biometric authentication against
  the National Identity Register, or match-on-card with an NIA-approved device,
  is permitted — and Makola is not a Regulation 7 service, so no such check is
  required of it.

  Identity therefore comes from proving control of the payout wallet
  (`StorePayoutAccount`), which the telco has already KYC'd against a Ghana Card
  under Bank of Ghana rules.

  What survives here is *business* verification: a trading name plus an optional
  supporting document (`business_doc_key` — an MMDA licence, tax receipt or
  certificate of incorporation). Those are not national identity cards and remain
  lawful to collect; they are also what the BoG merchant-tier ladder asks for.

  The `id_type` / `id_number` / `id_document_key` columns are retained, unwritable
  and never rendered, solely as the audit trail for submissions made under the
  retired flow. `quarantined_at` records when the stored document was moved to
  the private vault pending deletion.

  Kept off the (publicly-readable) `Store` resource so it carries merchant-only
  write policies — same split as `StorePayoutAccount` / `StorePageContent`. The
  `:approve`/`:reject` actions are platform-only (see policies).
  """

  use Ash.Resource,
    domain: Emakola.Stores,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @submission_fields [:business_name, :business_doc_key]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("store_verifications")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :atom do
      allow_nil?(false)
      default(:pending)
      constraints(one_of: [:pending, :approved, :rejected])
      public?(true)
    end

    attribute :business_name, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    # ── Retired national-ID fields ───────────────────────────────────────
    # Unlawful to request under L.I. 2523. Kept nullable and out of every
    # action's accept list so historic rows stay auditable while no new value
    # can ever be written. Never rendered to staff or merchants.
    attribute :id_type, :atom do
      constraints(one_of: [:ghana_card, :passport, :drivers_license, :voter_id])
    end

    attribute :id_number, :string do
      sensitive?(true)
      constraints(max_length: 100)
    end

    attribute :id_document_key, :string do
      sensitive?(true)
    end

    # When the retired ID document was moved to the private vault pending
    # deletion. Nil for rows that never carried one.
    attribute :quarantined_at, :utc_datetime_usec do
      public?(true)
    end

    # Optional supporting business document (ACL: private) — an MMDA licence,
    # tax receipt or certificate of incorporation. Not a national identity card.
    attribute :business_doc_key, :string do
      sensitive?(true)
    end

    # Why a submission was rejected — shown to the merchant so they can fix and
    # resubmit. Nil while pending/approved.
    attribute :review_reason, :string do
      public?(true)
    end

    attribute :submitted_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :reviewed_at, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_store_verification, [:store_id])
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      source_attribute(:store_id)
      define_attribute?(false)
    end
  end

  policies do
    # Reads: storefront/platform/merchant-page code uses authorize?: false; a
    # Merchant actor falls through to the store-access policy below.
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    # Review actions are platform-only — callable solely via authorize?: false
    # from the platform admin (gated there by :manage_merchants). Forbidding
    # every actor means a merchant can't approve their own submission, even
    # though the merchant policy below would otherwise admit the update.
    policy action([:approve, :reject]) do
      forbid_if(always())
    end

    # Quarantine is a platform data-retention action, never merchant-callable.
    policy action(:quarantine_id_document) do
      forbid_if(always())
    end

    # Merchant submit/resubmit/read: must have access to the owning store.
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read])

    create :submit do
      accept([:store_id | @submission_fields])
      change(set_attribute(:status, :pending))
      change(set_attribute(:submitted_at, &DateTime.utc_now/0))
    end

    update :resubmit do
      require_atomic?(false)
      accept(@submission_fields)
      change(set_attribute(:status, :pending))
      change(set_attribute(:review_reason, nil))
      change(set_attribute(:submitted_at, &DateTime.utc_now/0))
    end

    update :approve do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :approved))
      change(set_attribute(:reviewed_at, &DateTime.utc_now/0))
    end

    update :reject do
      require_atomic?(false)
      accept([])
      argument(:reason, :string, allow_nil?: false)
      change(set_attribute(:status, :rejected))
      change(set_attribute(:review_reason, arg(:reason)))
      change(set_attribute(:reviewed_at, &DateTime.utc_now/0))
    end

    # Records that the retired ID document has been moved to the private vault.
    # The storage key is kept so the pending deletion has something to target.
    update :quarantine_id_document do
      require_atomic?(false)
      accept([])
      change(set_attribute(:quarantined_at, &DateTime.utc_now/0))
    end

    read :get_by_store do
      get?(true)
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
    end

    read :list_for_review do
      argument(:status, :atom, allow_nil?: true)
      filter(expr(is_nil(^arg(:status)) or status == ^arg(:status)))
      prepare(build(sort: [submitted_at: :asc]))
    end

    # Rows still holding a retired ID document that has not yet been vaulted.
    read :list_unquarantined_id_documents do
      filter(expr(not is_nil(id_document_key) and is_nil(quarantined_at)))
      prepare(build(sort: [inserted_at: :asc]))
    end
  end
end
