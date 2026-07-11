defmodule Emakola.Payments.PaymentSplitSettlementTest do
  @moduledoc """
  Webhook reconciliation for dropship splits (SP5): charge.success settles the
  PaymentSplit allocations; refund.processed reverses them for clawback.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

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

    split!(payment, store, %{
      role: :wholesaler,
      recipient_store_id: store.id,
      subaccount_code: "ACCT_w",
      amount: 1_600
    })

    split!(payment, store, %{role: :platform, amount: 840})

    split!(payment, store, %{
      role: :dropshipper,
      recipient_store_id: store.id,
      subaccount_code: "ACCT_d",
      amount: 10_560
    })

    {:ok, store: store, payment: payment}
  end

  test "charge.success settles every pending split", %{payment: payment} do
    job = %Oban.Job{
      args: %{"event" => "charge.success", "data" => %{"reference" => payment.gateway_reference}}
    }

    assert :ok = PaystackWebhookHandler.perform(job)

    assert Enum.all?(splits_for(payment), &(&1.status == :settled))
  end

  test "re-processing charge.success when the payment is already :success still settles pending splits (retry recovery)",
       %{payment: payment} do
    # Simulate a prior attempt that committed :success but failed before settling
    # the splits — they remain :pending. A webhook retry MUST recover them.
    payment
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)

    assert Enum.all?(splits_for(payment), &(&1.status == :pending))

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

    recipient_reversals =
      payment
      |> splits_for()
      |> Enum.reject(&(&1.role == :platform))
      |> Enum.map(& &1.reversed_amount)
      |> Enum.sort()

    assert recipient_reversals == [1_600, 10_560]
  end

  test "partial refunds update proportional liabilities without duplicating rows", %{
    payment: payment
  } do
    PaystackWebhookHandler.perform(%Oban.Job{
      args: %{"event" => "charge.success", "data" => %{"reference" => payment.gateway_reference}}
    })

    refund = fn amount ->
      PaystackWebhookHandler.perform(%Oban.Job{
        args: %{
          "event" => "refund.processed",
          "data" => %{
            "transaction" => %{"reference" => payment.gateway_reference},
            "amount" => amount
          }
        }
      })
    end

    assert :ok = refund.(6_500)
    assert Enum.all?(splits_for(payment), &(&1.status == :partially_reversed))

    recipient_reversals =
      payment
      |> splits_for()
      |> Enum.reject(&(&1.role == :platform))
      |> Enum.map(& &1.reversed_amount)
      |> Enum.sort()

    assert recipient_reversals == [800, 5_280]

    assert :ok = refund.(6_500)

    recipient_reversals =
      payment
      |> splits_for()
      |> Enum.reject(&(&1.role == :platform))
      |> Enum.map(& &1.reversed_amount)
      |> Enum.sort()

    assert recipient_reversals == [1_600, 10_560]
  end

  test "charge.success applies a reserved recovery", %{store: store, payment: payment} do
    liability = refundable_liability!(store, 700)

    [earning, _platform] =
      Emakola.Payments.RefundLiability.reserve!([
        %{
          role: :merchant,
          recipient_store_id: store.id,
          subaccount_code: "ACCT_d",
          amount: 500
        },
        %{role: :platform, recipient_store_id: nil, subaccount_code: nil, amount: 100}
      ])

    split!(payment, store, Map.put(earning, :role, :merchant))

    assert :ok =
             PaystackWebhookHandler.perform(%Oban.Job{
               args: %{
                 "event" => "charge.success",
                 "data" => %{"reference" => payment.gateway_reference}
               }
             })

    updated = Ash.get!(Emakola.Payments.PaymentSplit, liability.id, authorize?: false)
    assert updated.recovered_amount == 500
    assert updated.reserved_recovery_amount == 0
  end

  test "charge.failed releases a reserved recovery", %{store: store, payment: payment} do
    liability = refundable_liability!(store, 700)

    [earning, _platform] =
      Emakola.Payments.RefundLiability.reserve!([
        %{
          role: :merchant,
          recipient_store_id: store.id,
          subaccount_code: "ACCT_d",
          amount: 500
        },
        %{role: :platform, recipient_store_id: nil, subaccount_code: nil, amount: 100}
      ])

    split!(payment, store, Map.put(earning, :role, :merchant))

    assert :ok =
             PaystackWebhookHandler.perform(%Oban.Job{
               args: %{
                 "event" => "charge.failed",
                 "data" => %{"reference" => payment.gateway_reference}
               }
             })

    updated = Ash.get!(Emakola.Payments.PaymentSplit, liability.id, authorize?: false)
    assert updated.recovered_amount == 0
    assert updated.reserved_recovery_amount == 0
  end

  defp refundable_liability!(recipient, reversed_amount) do
    original_store = create_store!()
    original_payment = create_payment!(original_store)

    split!(original_payment, original_store, %{
      role: :wholesaler,
      recipient_store_id: recipient.id,
      amount: 1_000
    })
    |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed_amount})
    |> Ash.update!(authorize?: false)
  end
end
