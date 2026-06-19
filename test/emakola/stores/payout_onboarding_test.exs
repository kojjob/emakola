defmodule Emakola.Stores.PayoutOnboardingTest do
  @moduledoc """
  SP1: a merchant connects a Mobile Money payout destination, which creates a
  verified gateway subaccount so the store can receive dropship split settlements.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory
  import Mox

  alias Emakola.Stores.PayoutOnboarding

  defmodule FailingGateway do
    def create_subaccount(_params), do: {:error, {:gateway_error, :timeout}}
  end

  # Captures the params passed to the gateway (runs in the test process, so the
  # message lands in the test mailbox for assert_received).
  defmodule CapturingGateway do
    def create_subaccount(params) do
      send(self(), {:create_subaccount, params})
      {:ok, %{subaccount_code: "ACCT_capture", raw: %{}}}
    end
  end

  @gh_momo_banks [
    %{"slug" => "mtn-mobile-money", "name" => "MTN", "code" => "MTN", "type" => "mobile_money"},
    %{
      "slug" => "vod-mobile-money",
      "name" => "Vodafone",
      "code" => "VOD",
      "type" => "mobile_money"
    },
    %{
      "slug" => "atl-mobile-money",
      "name" => "AirtelTigo",
      "code" => "ATL",
      "type" => "mobile_money"
    }
  ]

  setup do
    # Onboarding resolves settlement_bank via a live List Banks lookup; stub it
    # so these tests need no real keys (returns the real GH MoMo codes).
    stub(Emakola.Payments.PaystackClientMock, :list_banks, fn _params ->
      {:ok, %{"status" => true, "data" => @gh_momo_banks}}
    end)

    {:ok, store: create_store!(name: "Wholesaler Co")}
  end

  test "connects MoMo: persists the destination and records a verified subaccount", %{
    store: store
  } do
    params = %{provider: "mtn", number: "0240000000", account_name: "Ama Mensah"}

    assert {:ok, account} = PayoutOnboarding.connect_momo(store, params)
    assert account.verification_status == :verified
    assert is_binary(account.subaccount_code)
    assert account.payout_destination["provider"] == "mtn"
    assert account.payout_destination["number"] == "0240000000"
    assert account.payout_destination["account_name"] == "Ama Mensah"
  end

  test "gateway failure leaves the account persisted but unverified", %{store: store} do
    params = %{provider: "mtn", number: "0240000000", account_name: "Ama Mensah"}

    assert {:error, _reason} =
             PayoutOnboarding.connect_momo(store, params, gateway: FailingGateway)

    {:ok, account} = Emakola.Stores.get_payout_account(store.id, authorize?: false)
    assert account.verification_status == :unverified
    assert account.payout_destination["number"] == "0240000000"
  end

  test "re-connecting updates the destination and re-verifies", %{store: store} do
    PayoutOnboarding.connect_momo(store, %{
      provider: "mtn",
      number: "0240000000",
      account_name: "Ama"
    })

    assert {:ok, account} =
             PayoutOnboarding.connect_momo(store, %{
               provider: "vodafone",
               number: "0201111111",
               account_name: "Ama Mensah"
             })

    assert account.payout_destination["provider"] == "vodafone"
    assert account.payout_destination["number"] == "0201111111"
    assert account.verification_status == :verified
  end

  test "passes the live-resolved settlement_bank code to create_subaccount", %{store: store} do
    stub(Emakola.Payments.PaystackClientMock, :list_banks, fn _params ->
      {:ok,
       %{
         "status" => true,
         "data" => [
           %{
             "slug" => "mtn-mobile-money",
             "name" => "MTN",
             "code" => "MTN_FROM_LIVE",
             "type" => "mobile_money"
           }
         ]
       }}
    end)

    params = %{provider: "mtn", number: "0240000000", account_name: "Ama"}
    PayoutOnboarding.connect_momo(store, params, gateway: CapturingGateway)

    assert_received {:create_subaccount,
                     %{settlement_bank: "MTN_FROM_LIVE", account_number: "0240000000"}}
  end
end
