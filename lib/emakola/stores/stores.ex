defmodule Emakola.Stores do
  @moduledoc """
  The Stores domain — the multi-tenant anchor.

  Extracted from `Emakola.Accounts` on 2026-04-26. The `Store` resource
  itself moved here; `StoreMembership` (the merchant↔store bridge)
  stays in Accounts since it's identity-related.

  See `docs/PLAN-domain-restructuring-2026-04-26.md` Step 3 for the
  rationale and call-site list.

  The `stores` database table is unchanged; only the resource module
  namespace moves.
  """

  use Ash.Domain

  resources do
    resource Emakola.Stores.Store do
      define(:create_store, action: :create)
      define(:get_store, action: :read, get_by: [:id])
      define(:get_store_by_slug, action: :get_by_slug, args: [:slug])
      define(:update_store_settings, action: :update_settings)
      define(:update_store_directory_meta, action: :update_directory_meta)
      define(:list_stores_by_slugs, action: :list_by_slugs, args: [:slugs])
      define(:list_stores_for_admin, action: :list_for_admin, args: [:search])
      # Platform lifecycle — call with `authorize?: false` (gated in the LiveView).
      define(:suspend_store, action: :suspend)
      define(:block_store, action: :block)
      define(:archive_store, action: :archive)
      define(:reactivate_store, action: :reactivate)
    end

    resource Emakola.Stores.StorePayoutAccount do
      define(:get_payout_account, action: :get_by_store, args: [:store_id])
      define(:create_payout_account, action: :create)
      define(:update_payout_account, action: :update)
      define(:record_payout_subaccount, action: :record_subaccount)
    end

    resource Emakola.Stores.StorePageContent do
      define(:get_page_content, action: :get_by_store, args: [:store_id])
      define(:create_page_content, action: :create)
      define(:update_page_content, action: :update)
    end

    resource Emakola.Stores.StoreVerification do
      define(:get_store_verification, action: :get_by_store, args: [:store_id])
      define(:list_verifications_for_review, action: :list_for_review)
      define(:submit_store_verification, action: :submit)
      define(:resubmit_store_verification, action: :resubmit)
      # Platform-only review actions — call with `authorize?: false` (gated in the LiveView).
      define(:approve_store_verification, action: :approve)
      define(:reject_store_verification, action: :reject)
    end

    resource Emakola.Stores.StoreDomain do
      define(:create_store_domain, action: :create)
      define(:get_store_domain_by_host, action: :get_by_host, args: [:host])
      define(:list_store_domains, action: :list_for_store, args: [:store_id])
      define(:update_store_domain, action: :update)
      define(:destroy_store_domain, action: :destroy)

      define(:claim_custom_domain, action: :claim_custom)
      define(:claim_custom_domain_alias, action: :claim_custom_alias)
      define(:request_domain_verification, action: :request_verification)
      define(:record_domain_check, action: :record_check)
      define(:mark_domain_active, action: :mark_active)
      define(:expire_store_domain, action: :expire)
      define(:make_domain_primary, action: :make_primary)
      define(:list_verifying_domains, action: :list_verifying)
      define(:list_custom_domains_for_review, action: :list_custom_for_review)
      define(:get_primary_custom_domain_by_slug, action: :get_primary_by_slug, args: [:slug])
    end
  end
end
