defmodule Emakola.Payments do
  @moduledoc "The Payments domain — gateway integrations, transactions, refunds."
  use Ash.Domain

  resources do
    resource Emakola.Payments.Payment do
      define(:create_payment, action: :create)
      define(:get_payment_by_reference, action: :by_gateway_reference, args: [:gateway_reference])
      define(:list_payments_by_store, action: :by_store, args: [:store_id])

      define(:list_payments_by_store_with_status,
        action: :by_store_with_status,
        args: [:store_id]
      )

      define(:get_payment_by_order, action: :get_by_order, args: [:order_id])
    end
  end
end
