defmodule Emakola.Payments.InternalPayoutWebhookTest do
  @moduledoc """
  Transfer webhooks finalize allocation-basis payouts: failure/reversal
  releases every claimed split back to payable (fresh rows re-read via
  by_payout — CONTRACT 4); success is terminal. Mirrors the legacy
  payment-release semantics exactly.
  """
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  alias Emakola.Payments.{PaymentSplit, PayoutService}
  alias Emakola.Payments.Workers.PaystackWebhookHandler

  defp payable_setup!(amount) do
    store = create_store!()

    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      payout_destination: %{
        "method" => "mobile_money",
        "provider" => "mtn",
        "number" => "0244000222",
        "account_name" => "Webhook Test"
      }
    })
    |> Ash.create!(authorize?: false)

    payment = create_payment!(store)

    split =
      PaymentSplit
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        payment_id: payment.id,
        role: :merchant,
        recipient_store_id: store.id,
        amount: amount,
        settlement_method: :internal_hold
      })
      |> Ash.create!(authorize?: false)
      |> Ash.Changeset.for_update(:mark_settled, %{})
      |> Ash.update!(authorize?: false)

    {:ok, payout} = PayoutService.prepare_internal_payout(store.id)
    {store, split, payout}
  end

  defp transfer_event!(payout, status) do
    event = %{
      "event" => "transfer.#{status}",
      "data" => %{"reference" => payout.transfer_reference, "status" => status}
    }

    perform_job(PaystackWebhookHandler, event)
  end

  test "transfer.failed releases the claimed splits back to payable" do
    {store, split, payout} = payable_setup!(9_000)

    assert :ok = transfer_event!(payout, "failed")

    assert Ash.get!(Emakola.Payments.Payout, payout.id, authorize?: false).status == :failed

    released = Ash.get!(PaymentSplit, split.id, authorize?: false)
    assert is_nil(released.paid_out_at)
    assert is_nil(released.payout_id)

    # Re-claimable: a fresh approval claims it again, exactly once.
    {:ok, second} = PayoutService.prepare_internal_payout(store.id)
    assert second.amount == 9_000
  end

  test "transfer.success marks paid and leaves claims in place" do
    {_store, split, payout} = payable_setup!(4_000)

    assert :ok = transfer_event!(payout, "success")

    assert Ash.get!(Emakola.Payments.Payout, payout.id, authorize?: false).status == :paid
    assert Ash.get!(PaymentSplit, split.id, authorize?: false).payout_id == payout.id
  end

  test "webhook replay after release is a no-op (idempotent)" do
    {_store, _split, payout} = payable_setup!(2_500)
    assert :ok = transfer_event!(payout, "failed")
    assert :ok = transfer_event!(payout, "failed")
    assert Ash.get!(Emakola.Payments.Payout, payout.id, authorize?: false).status == :failed
  end
end
