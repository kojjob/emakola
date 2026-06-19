defmodule Emakola.Stores.PayoutOnboardingTest do
  @moduledoc """
  SP1: a merchant connects a Mobile Money payout destination, which creates a
  verified gateway subaccount so the store can receive dropship split settlements.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Stores.PayoutOnboarding

  defmodule FailingGateway do
    def create_subaccount(_params), do: {:error, {:gateway_error, :timeout}}
  end

  setup do
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
end
