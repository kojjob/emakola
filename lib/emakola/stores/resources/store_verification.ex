defmodule Emakola.Stores.StoreVerification do
  @moduledoc """
  A store's KYC submission and its review state. One row per store, created the
  first time a merchant submits identity/business details.

  Approval is the real path to the `Store.verified` trust badge (which a
  platform admin could previously only toggle by hand). Submission carries the
  structured fields plus private document storage keys (`id_document_key`,
  `business_doc_key`) — the documents are uploaded with a `private` ACL and
  shown to reviewers via short-lived presigned URLs, never public.

  Kept off the (publicly-readable) `Store` resource so it carries merchant-only
  write policies — same split as `StorePayoutAccount` / `StorePageContent`. The
  `:approve`/`:reject` actions are platform-only (see policies).
  """

  use Ash.Resource,
    domain: Emakola.Stores,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @submission_fields [:business_name, :id_type, :id_number, :id_document_key, :business_doc_key]

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

    attribute :id_type, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:ghana_card, :passport, :drivers_license, :voter_id])
    end

    attribute :id_number, :string do
      allow_nil?(false)
      sensitive?(true)
      constraints(max_length: 100)
    end

    # Private storage keys (ACL: private) — viewed by reviewers via presigned
    # URLs. Required: id_document_key. Optional: business_doc_key.
    attribute :id_document_key, :string do
      allow_nil?(false)
      sensitive?(true)
    end

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
  end
end
