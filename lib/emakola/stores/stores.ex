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
    end

    resource Emakola.Stores.StorePayoutAccount do
      define(:get_payout_account, action: :get_by_store, args: [:store_id])
    end
  end
end
