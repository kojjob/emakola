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
      define(:list_orders_admin, action: :list_admin, args: [:store_id])
      define(:get_order_by_id, action: :get_by_id, args: [:id])
      define(:get_order_for_admin, action: :get_for_admin, args: [:id, :store_id])
      define(:list_orders_by_customer, action: :list_by_customer, args: [:customer_id, :store_id])
      define(:get_order_by_number, action: :get_by_order_number, args: [:order_number, :store_id])
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

    resource Emakola.Orders.Fulfillment do
      define(:list_fulfillments_by_order, action: :list_by_order, args: [:order_id])
      define(:mark_fulfillment_notified, action: :mark_notified)
      define(:mark_fulfillment_shipped, action: :mark_shipped)
      define(:mark_fulfillment_delivered, action: :mark_delivered)
      define(:cancel_fulfillment, action: :cancel)
    end

    # Coupon resource moved to Emakola.Marketing on 2026-04-26.
    # See docs/PLAN-domain-restructuring-2026-04-26.md

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
