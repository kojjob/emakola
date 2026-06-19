defmodule Emakola.Payments.PaymentSplitSettlementTest do
  @moduledoc """
  Webhook reconciliation for dropship splits (SP5): charge.success settles the
  PaymentSplit allocations; refund.processed reverses them for clawback.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  alias Emakola.Payments.Workers.PaystackWebhookHandler

  defp split!(payment, store, attrs) do
    Emakola.Payments.create_payment_split!(
      Map.merge(%{store_id: store.id, payment_id: payment.id}, Map.new(attrs)),
      authorize?: false
    )
  end

  defp splits_for(payment) do
    {:ok, splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)
    splits
  end

  setup do
    store = create_store!()

    payment =
      create_payment!(store,
        amount: 13_000,
        split_mode: :dropship_split,
        gateway_reference: "PAY-split-#{System.unique_integer([:positive])}"
      )

    split!(payment, store, %{role: :wholesaler, subaccount_code: "ACCT_w", amount: 1_600})
    split!(payment, store, %{role: :platform, amount: 840})
    split!(payment, store, %{role: :dropshipper, subaccount_code: "ACCT_d", amount: 10_560})

    {:ok, store: store, payment: payment}
  end

  test "charge.success settles every pending split", %{payment: payment} do
    job = %Oban.Job{
      args: %{"event" => "charge.success", "data" => %{"reference" => payment.gateway_reference}}
    }

    assert :ok = PaystackWebhookHandler.perform(job)

    assert Enum.all?(splits_for(payment), &(&1.status == :settled))
  end

  test "refund.processed reverses the splits for clawback", %{payment: payment} do
    # First settle via a successful charge.
    PaystackWebhookHandler.perform(%Oban.Job{
      args: %{"event" => "charge.success", "data" => %{"reference" => payment.gateway_reference}}
    })

    refund_job = %Oban.Job{
      args: %{
        "event" => "refund.processed",
        "data" => %{
          "transaction" => %{"reference" => payment.gateway_reference},
          "amount" => 13_000
        }
      }
    }

    assert :ok = PaystackWebhookHandler.perform(refund_job)

    assert Enum.all?(splits_for(payment), &(&1.status == :reversed))
  end
end
