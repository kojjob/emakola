defmodule Emakola.Orders do
  @moduledoc """
  The Orders domain — orders, line items, fulfillments, and refunds.
  """
  use Ash.Domain

  resources do
    resource Emakola.Orders.Order do
      define(:create_order, action: :create)
      define(:list_orders_by_store, action: :list_by_store, args: [:store_id])
      define(:list_orders_by_status, action: :list_by_status, args: [:store_id, :status])
    end

    resource Emakola.Orders.LineItem do
      define(:create_line_item, action: :create)
    end
  end
end
