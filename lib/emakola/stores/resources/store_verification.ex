defmodule Emakola.Stores.StoreVerification do
  @moduledoc """
  A store's business-details submission and its review state. One row per
  store, created the first time a merchant sends their trading name for review.

  **No documents are collected.** L.I. 2523 (in force 9 June 2026) makes it an
  offence to request, retain or visually inspect a Ghana Card, so the ID fields
  went first. The "business paper" upload (MMDA licence, tax receipt) went with
  it: it landed in the same public bucket as every product photo, and a sole
  trader's licence is their name, address and TIN — identity by another name.
  Identity comes from proving control of the payout wallet on `/admin/payouts`,
  which the telco has already KYC'd.

  The `id_type` / `id_number` / `id_document_key` / `business_doc_key` columns
  are retained, unwritable and never rendered, solely as the audit trail for
  submissions made under the retired flows. `documents_purged_at` records when
  `Emakola.Stores.VerificationDocumentPurge` deleted the stored objects.

  Kept off the (publicly-readable) `Store` resource so it carries merchant-only
  write policies — same split as `StorePayoutAccount` / `StorePageContent`. The
  `:approve`/`:reject` actions are platform-only (see policies).
  """

  use Ash.Resource,
    domain: Emakola.Stores,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @submission_fields [:business_name]

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
    attribute :documents_purged_at, :utc_datetime_usec do
      public?(true)
    end

    # Retired with the business-paper upload: unwritable, never rendered, kept
    # only so the purge knows which object to delete and the audit trail stays
    # whole.
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

    # Purge bookkeeping is a platform data-retention action, never merchant-callable.
    policy action(:mark_documents_purged) do
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

    # Records that every stored document this row pointed at has been deleted.
    # The keys stay as the audit trail; the objects do not.
    update :mark_documents_purged do
      require_atomic?(false)
      accept([])
      change(set_attribute(:documents_purged_at, &DateTime.utc_now/0))
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
    # Rows that still point at a stored object of either kind. Sweeps every
    # status: the old flow only cleaned up on merchant resubmit.
    read :list_with_stored_documents do
      filter(
        expr(
          (not is_nil(id_document_key) or not is_nil(business_doc_key)) and
            is_nil(documents_purged_at)
        )
      )
    end
  end
end
