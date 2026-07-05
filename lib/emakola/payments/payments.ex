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
      define(:list_refunded_payments, action: :list_refunded)
      define(:mark_payment_paid_out, action: :mark_paid_out)
      define(:release_payment_from_payout, action: :release_from_payout)
      define(:list_payments_by_payout, action: :by_payout, args: [:payout_id])
    end

    resource Emakola.Payments.PaymentSplit do
      define(:create_payment_split, action: :create)
      define(:list_payment_splits, action: :by_payment, args: [:payment_id])
    end

    resource Emakola.Payments.Payout do
      define(:create_payout, action: :create)
      define(:get_payout, action: :read, get_by: [:id])
      define(:mark_payout_processing, action: :mark_processing)
      define(:mark_payout_paid, action: :mark_paid)
      define(:mark_payout_failed, action: :mark_failed)
      define(:mark_payout_reversed, action: :mark_reversed)
      define(:list_payouts_by_store, action: :by_store, args: [:store_id])
      define(:list_recent_payouts, action: :list_recent)

      define(:get_payout_by_transfer_reference,
        action: :by_transfer_reference,
        args: [:transfer_reference]
      )
    end
  end
end
