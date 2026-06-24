defmodule Emakola.Payments.Workers.SubaccountCreationWorkerTest do
  @moduledoc """
  Turns a saved MoMo payout account into a Paystack subaccount (revenue rails
  slice 1): maps provider → settlement_bank, records the code as :verified,
  no-ops for bank/already-created, retries on gateway failure.
  """
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo
  import Mox

  alias Emakola.Factory
  alias Emakola.Payments.Workers.SubaccountCreationWorker, as: Worker
  alias Emakola.Stores

  setup :verify_on_exit!

  # Route the worker through the real Paystack gateway so it hits PaystackClientMock
  # (the test default :payment_gateway is the always-succeeds hand stub).
  setup do
    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)
    :ok
  end

  defp payout!(store, dest) do
    {:ok, account} =
      Stores.create_payout_account(%{store_id: store.id, payout_destination: dest},
        authorize?: false
      )

    account
  end

  defp reload(store) do
    {:ok, account} =
      Stores.get_payout_account(store.id, authorize?: false, not_found_error?: false)

    account
  end

  test "enqueue/1 inserts a job" do
    assert {:ok, _} = Worker.enqueue("store-1")
    assert_enqueued(worker: Worker, args: %{"store_id" => "store-1"})
  end

  test "creates a Paystack subaccount for a MoMo payout and marks it verified" do
    store = Factory.create_store!(%{name: "Kente Kingdom"})

    payout!(store, %{
      "method" => "mobile_money",
      "provider" => "mtn",
      "number" => "0244123456",
      "account_name" => "Kwame"
    })

    expect(Emakola.Payments.PaystackClientMock, :create_subaccount, fn params ->
      assert params.settlement_bank == "MTN"
      assert params.account_number == "0244123456"
      assert params.percentage_charge == 0
      assert params.business_name == "Kente Kingdom"
      {:ok, %{"status" => true, "data" => %{"subaccount_code" => "ACCT_xyz"}}}
    end)

    assert :ok = perform_job(Worker, %{"store_id" => store.id})

    account = reload(store)
    assert account.verification_status == :verified
    assert account.subaccount_code == "ACCT_xyz"
  end

  test "no-ops for a non-mobile-money payout (bank deferred) without calling the gateway" do
    store = Factory.create_store!()

    payout!(store, %{
      "method" => "bank",
      "bank_name" => "GCB",
      "account_number" => "1234567890",
      "account_name" => "X"
    })

    assert :ok = perform_job(Worker, %{"store_id" => store.id})
    assert reload(store).verification_status == :unverified
  end

  test "no-ops when a subaccount already exists" do
    store = Factory.create_store!()

    account =
      payout!(store, %{"method" => "mobile_money", "provider" => "mtn", "number" => "0244"})

    {:ok, _} =
      Stores.record_payout_subaccount(account, %{subaccount_code: "ACCT_existing"},
        authorize?: false
      )

    assert :ok = perform_job(Worker, %{"store_id" => store.id})
  end

  test "returns an error when the gateway fails so Oban retries" do
    store = Factory.create_store!()
    payout!(store, %{"method" => "mobile_money", "provider" => "vodafone", "number" => "0500"})

    expect(Emakola.Payments.PaystackClientMock, :create_subaccount, fn _ -> {:error, :timeout} end)

    assert {:error, _} = perform_job(Worker, %{"store_id" => store.id})
    assert reload(store).verification_status == :unverified
  end
end
