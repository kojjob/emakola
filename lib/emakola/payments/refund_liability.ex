defmodule Emakola.Payments.RefundLiability do
  @moduledoc """
  Reconciles cumulative payment refunds into the existing split ledger.

  Each recipient's reversal is proportional to its original allocation. The
  `PaymentSplit.reversed_amount` is the recoverable balance source of truth,
  making partial refunds cumulative without duplicating the allocation ledger.
  """

  def reconcile!(payment, splits) do
    Enum.each(splits, fn split ->
      reversed_amount = proportional_amount(split.amount, payment.refunded_amount, payment.amount)

      if reversed_amount > split.reversed_amount do
        split
        |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed_amount})
        |> Ash.update!(authorize?: false)
      end
    end)
  end

  defp proportional_amount(_allocation, 0, _payment_total), do: 0

  defp proportional_amount(allocation, refunded, payment_total) do
    min(allocation, div(allocation * refunded, payment_total))
  end
end
