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
      define(:get_order_by_id, action: :get_by_id, args: [:id])
      define(:confirm_order, action: :confirm)
      define(:start_processing_order, action: :start_processing)
      define(:mark_order_shipped, action: :mark_shipped)
      define(:mark_order_delivered, action: :mark_delivered)
      define(:cancel_order, action: :cancel)
      define(:update_order_notes, action: :update_notes)
    end

    resource Emakola.Orders.LineItem do
      define(:create_line_item, action: :create)
    end

    resource Emakola.Orders.Coupon do
      define(:create_coupon, action: :create)
      define(:list_coupons_by_store, action: :list_by_store, args: [:store_id])
      define(:find_coupon_by_code, action: :find_by_code, args: [:store_id, :code])
      define(:deactivate_coupon, action: :deactivate)
      define(:increment_coupon_usage, action: :increment_usage)
      define(:list_active_public_coupons, action: :list_active_public, args: [:store_id])
    end

    resource Emakola.Orders.Return do
      define(:request_return, action: :request_return)
      define(:approve_return, action: :approve)
      define(:deny_return, action: :deny)
      define(:mark_return_refunded, action: :mark_refunded)
      define(:list_returns_by_store, action: :list_by_store, args: [:store_id])
      define(:get_return_by_order, action: :get_by_order, args: [:order_id])
    end
  end
end
