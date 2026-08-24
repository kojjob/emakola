defmodule Emakola.Marketing do
  @moduledoc """
  The Marketing domain — coupons, discount codes, and (future)
  campaigns. Extracted from `Emakola.Orders` on 2026-04-26 because
  coupons are a marketing/growth concept rather than a transactional
  one. See `docs/PLAN-domain-restructuring-2026-04-26.md` for context.

  The `coupons` database table is unchanged; only the resource module
  namespace moves.
  """

  use Ash.Domain

  resources do
    resource(Emakola.Marketing.Campaign)
    resource(Emakola.Marketing.CampaignRecipient)

    resource Emakola.Marketing.Coupon do
      define(:create_coupon, action: :create)
      define(:update_coupon, action: :update)
      define(:list_coupons_by_store, action: :list_by_store, args: [:store_id])
      define(:find_coupon_by_code, action: :find_by_code, args: [:store_id, :code])
      define(:deactivate_coupon, action: :deactivate)
      define(:increment_coupon_usage, action: :increment_usage)
      define(:list_active_public_coupons, action: :list_active_public, args: [:store_id])
    end
  end
end
