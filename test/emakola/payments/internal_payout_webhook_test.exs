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

  # PR #373 review: a paid-then-reversed allocation payout must reopen every
  # SupplierLedgerEntry it had marked :paid — the gateway clawed the money
  # back, so a :paid entry at this point is a false payment record.
  test "transfer.reversed after :paid reopens a paid supplier entry and releases the split" do
    {store, split, payout} = payable_setup!(6_000)

    assert :ok = transfer_event!(payout, "success")
    assert Ash.get!(Emakola.Payments.Payout, payout.id, authorize?: false).status == :paid

    supplier = create_supplier!(store)
    order = create_order!(store)
    fulfillment = create_fulfillment!(order, store)

    entry =
      create_supplier_ledger_entry!(supplier, fulfillment, store)
      |> Ash.Changeset.for_update(:claim_for_platform_settlement, %{
        payment_split_id: split.id,
        source: :platform_payout
      })
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:mark_platform_paid, %{})
      |> Ash.update!(authorize?: false)

    assert entry.status == :paid

    assert :ok = transfer_event!(payout, "reversed")

    reopened = Ash.get!(Emakola.Suppliers.SupplierLedgerEntry, entry.id, authorize?: false)
    assert reopened.status == :owed
    assert reopened.settlement_source == :platform_payout
    assert is_nil(reopened.paid_at)

    released = Ash.get!(PaymentSplit, split.id, authorize?: false)
    assert is_nil(released.paid_out_at)
    assert is_nil(released.payout_id)

    # Replay is idempotent — same terminal state, no crash on the second pass.
    assert :ok = transfer_event!(payout, "reversed")

    assert Ash.get!(Emakola.Suppliers.SupplierLedgerEntry, entry.id, authorize?: false).status ==
             :owed
  end

  test "a transfer.success replay heals a supplier entry stranded :owed after the first delivery" do
    {store, split, payout} = payable_setup!(3_000)

    # First delivery lands (no supplier entry exists yet, so
    # mark_supplier_ledger_entries_paid/1 is a no-op) — the payout is now
    # terminal :paid, same as if a transient failure had stranded the mark.
    assert :ok = transfer_event!(payout, "success")
    assert Ash.get!(Emakola.Payments.Payout, payout.id, authorize?: false).status == :paid

    # Simulate the stranded state directly: a supplier ledger entry claimed
    # against this split's payout settlement, but never marked paid.
    supplier = create_supplier!(store)
    order = create_order!(store)
    fulfillment = create_fulfillment!(order, store)

    entry =
      create_supplier_ledger_entry!(supplier, fulfillment, store)
      |> Ash.Changeset.for_update(:claim_for_platform_settlement, %{
        payment_split_id: split.id,
        source: :platform_payout
      })
      |> Ash.update!(authorize?: false)

    assert entry.status == :owed

    # Replay of transfer.success must re-run the healing, not short-circuit.
    assert :ok = transfer_event!(payout, "success")

    assert Ash.get!(Emakola.Suppliers.SupplierLedgerEntry, entry.id, authorize?: false).status ==
             :paid
  end
end
