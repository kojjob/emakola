defmodule Emakola.Fulfillment do
  @moduledoc """
  The Fulfillment domain — post-payment entitlements and delivery state.

  Owns the resources that record *what was delivered to whom* after an
  order is paid, separately from the order itself:

    * `Emakola.Fulfillment.DownloadGrant` — customer entitlements to
      download specific `Emakola.Catalog.DigitalFile` rows.

  Future phases add `LicenseGrant`, `CourseEnrollment`, `StreamingGrant`,
  and `PrintOrder` here. The `Emakola.Fulfillment.Dispatcher` switchboard
  (not a resource — a pure module under this namespace) routes work to
  the right pipeline.
  """
  use Ash.Domain

  resources do
    resource Emakola.Fulfillment.DownloadGrant do
      define(:get_download_grant, action: :get_by_id, args: [:id])
      define(:list_grants_by_customer, action: :list_by_customer, args: [:customer_id, :store_id])
    end
  end
end
