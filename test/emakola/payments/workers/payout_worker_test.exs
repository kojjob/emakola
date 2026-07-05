defmodule Emakola.Payments.Workers.PayoutWorkerTest do
  @moduledoc """
  Executes a pending Payout: creates a Paystack transfer recipient from the
  store's MoMo details, initiates the transfer (idempotent via the payout's
  transfer_reference), and records the outcome. No-ops once paid/processing.
  """
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo
  import Mox

  alias Emakola.Factory
  alias Emakola.Payments
  alias Emakola.Payments.Workers.PayoutWorker, as: Worker

  setup :verify_on_exit!

  # Route the worker through the real Paystack gateway so it hits PaystackClientMock.
  setup do
    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)
    :ok
  end

  defp momo_account!(store) do
    {:ok, _} =
      Emakola.Stores.create_payout_account(
        %{
          store_id: store.id,
          payout_destination: %{
            "method" => "mobile_money",
            "provider" => "mtn",
            "number" => "0244123456",
            "account_name" => "Kwame Owusu"
          }
        },
        authorize?: false
      )
  end

  defp pending_payout!(store, amount \\ 80_000) do
    Payments.create_payout!(
      %{store_id: store.id, amount: amount, transfer_reference: "po_ref_#{store.id}"},
      authorize?: false
    )
  end

  defp reload(payout), do: Payments.get_payout!(payout.id, authorize?: false)

  test "enqueue/1 inserts a job" do
    assert {:ok, _} = Worker.enqueue("payout-1")
    assert_enqueued(worker: Worker, args: %{"payout_id" => "payout-1"})
  end

  test "creates a recipient, initiates the transfer, and marks the payout processing" do
    store = Factory.create_store!(%{name: "Kente Kingdom"})
    momo_account!(store)
    payout = pending_payout!(store, 80_000)

    expect(Emakola.Payments.PaystackClientMock, :create_transfer_recipient, fn params ->
      assert params.type == "mobile_money"
      assert params.bank_code == "MTN"
      assert params.account_number == "0244123456"
      {:ok, %{"status" => true, "data" => %{"recipient_code" => "RCP_x"}}}
    end)

    expect(Emakola.Payments.PaystackClientMock, :initiate_transfer, fn params ->
      assert params.source == "balance"
      assert params.amount == 80_000
      assert params.recipient == "RCP_x"
      assert params.reference == payout.transfer_reference
      assert params.currency == "GHS"
      {:ok, %{"status" => true, "data" => %{"transfer_code" => "TRF_x", "status" => "pending"}}}
    end)

    assert :ok = perform_job(Worker, %{"payout_id" => payout.id})

    updated = reload(payout)
    assert updated.status == :processing
    assert updated.recipient_code == "RCP_x"
    assert updated.transfer_code == "TRF_x"
  end

  test "no-ops when the payout is already paid (no gateway calls)" do
    store = Factory.create_store!()
    momo_account!(store)
    payout = pending_payout!(store)
    {:ok, paid} = Payments.mark_payout_paid(payout, %{}, authorize?: false)

    assert :ok = perform_job(Worker, %{"payout_id" => paid.id})
    assert reload(paid).status == :paid
  end

  test "leaves the payout pending and retries on a transient gateway error" do
    store = Factory.create_store!()
    momo_account!(store)
    payout = pending_payout!(store)

    expect(Emakola.Payments.PaystackClientMock, :create_transfer_recipient, fn _ ->
      {:error, :timeout}
    end)

    assert {:error, _} = perform_job(Worker, %{"payout_id" => payout.id})
    assert reload(payout).status == :pending
  end

  test "marks the payout failed on a definitive Paystack rejection" do
    store = Factory.create_store!()
    momo_account!(store)
    payout = pending_payout!(store)

    expect(Emakola.Payments.PaystackClientMock, :create_transfer_recipient, fn _ ->
      {:ok, %{"status" => true, "data" => %{"recipient_code" => "RCP_x"}}}
    end)

    expect(Emakola.Payments.PaystackClientMock, :initiate_transfer, fn _ ->
      {:ok, %{"status" => false, "message" => "Insufficient balance"}}
    end)

    assert :ok = perform_job(Worker, %{"payout_id" => payout.id})

    updated = reload(payout)
    assert updated.status == :failed
    assert updated.failure_reason =~ "Insufficient balance"
  end

  test "marks the payout failed when the store has no MoMo destination" do
    store = Factory.create_store!()
    payout = pending_payout!(store)

    assert :ok = perform_job(Worker, %{"payout_id" => payout.id})
    assert reload(payout).status == :failed
  end
end
