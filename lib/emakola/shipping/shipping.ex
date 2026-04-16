defmodule Emakola.Shipping do
  @moduledoc "Shipping domain — delivery zones and shipping rates for store fulfilment configuration."
  use Ash.Domain

  resources do
    resource Emakola.Shipping.DeliveryZone do
      define(:create_delivery_zone, action: :create)
      define(:list_delivery_zones, action: :list_by_store, args: [:store_id])
    end
  end
end
