defmodule Emakola.Orders do
  @moduledoc """
  The Orders domain — orders, line items, fulfillments, and refunds.
  """
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  json_api do
    prefix("/api/v1")
  end

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
      define(:create_custom_line_item, action: :create_custom)
    end

    resource Emakola.Orders.PayLink do
      define(:create_pay_link, action: :create)
      define(:get_pay_link_by_code, action: :get_by_code, args: [:code])
      define(:cancel_pay_link, action: :cancel)
      define(:mark_pay_link_paid, action: :mark_paid)
      define(:list_pay_links_for_admin, action: :list_for_admin)
    end

    resource Emakola.Orders.SusuPlan do
      define(:create_susu_plan, action: :create)
      define(:get_susu_plan_by_code, action: :get_by_code, args: [:code])
      define(:list_susu_plans_for_admin, action: :list_for_admin)
      define(:activate_susu_plan, action: :activate)
      define(:record_susu_contribution, action: :record_contribution)
      define(:complete_susu_plan, action: :complete)
      define(:cancel_susu_plan, action: :cancel)
      define(:expire_susu_plan, action: :expire)
      define(:extend_susu_plan_deadline, action: :extend_deadline)
      define(:update_susu_plan_delivery, action: :update_delivery)
      define(:mark_susu_plan_nudged, action: :mark_nudged)
      define(:mark_susu_plan_warned_7d, action: :mark_warned_7d)
      define(:mark_susu_plan_warned_1d, action: :mark_warned_1d)
    end

    resource Emakola.Orders.Fulfillment do
      define(:list_fulfillments_by_order, action: :list_by_order, args: [:order_id])
      define(:mark_fulfillment_notified, action: :mark_notified)
      define(:mark_fulfillment_shipped, action: :mark_shipped)
      define(:mark_fulfillment_delivered, action: :mark_delivered)
      define(:cancel_fulfillment, action: :cancel)
      define(:supplier_accept_fulfillment, action: :supplier_accept)
      define(:supplier_decline_fulfillment, action: :supplier_decline)
      define(:rotate_fulfillment_supplier_link, action: :rotate_supplier_link)
      define(:record_fulfillment_send_failure, action: :record_send_failure)
      define(:self_attest_fulfillment_delivered, action: :self_attest_delivered)
      define(:list_unverified_deliveries, action: :list_unverified_deliveries)
      define(:escalate_fulfillment, action: :escalate)
    end

    resource Emakola.Orders.FulfillmentDeliveryProof do
      define(:issue_fulfillment_delivery_proof, action: :issue)
    end

    # Coupon resource moved to Emakola.Marketing on 2026-04-26.
    # See docs/PLAN-domain-restructuring-2026-04-26.md

    resource Emakola.Orders.Return do
      define(:request_return, action: :request_return)
      define(:approve_return, action: :approve)
      define(:deny_return, action: :deny)
      define(:reopen_return, action: :reopen)
      define(:mark_return_refunded, action: :mark_refunded)
      define(:list_returns_by_store, action: :list_by_store, args: [:store_id])
      define(:get_return_by_order, action: :get_by_order, args: [:order_id])
      define(:list_returns_by_customer, action: :list_by_customer, args: [:customer_id])

      define(:list_returns_by_customer_and_store,
        action: :list_by_customer_and_store,
        args: [:customer_id, :store_id]
      )
    end

    resource(Emakola.Orders.AbandonedCheckout)
  end
end
