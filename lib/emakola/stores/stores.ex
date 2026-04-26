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
      define(:update_store_settings, action: :update_settings)
    end
  end
end
