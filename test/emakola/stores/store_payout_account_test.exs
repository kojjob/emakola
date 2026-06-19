defmodule Emakola.Stores.StorePayoutAccountTest do
  @moduledoc """
  A store's payout identity for trustless dropship settlement (SP1): the
  Paystack subaccount a split routes money to, and whether it is verified.
  Kept off the (publicly-readable) Store resource so payout data stays
  merchant-only.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  alias Emakola.Stores.StorePayoutAccount

  setup do
    {:ok, store: create_store!()}
  end

  defp create_account!(store, attrs \\ %{}) do
    params = Map.merge(%{store_id: store.id}, Map.new(attrs))

    StorePayoutAccount
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(authorize?: false)
  end

  describe "create" do
    test "defaults to the paystack provider and an unverified status", %{store: store} do
      account = create_account!(store, %{payout_destination: %{"momo_number" => "0240000000"}})

      assert account.store_id == store.id
      assert account.payout_provider == :paystack
      assert account.verification_status == :unverified
      assert is_nil(account.subaccount_code)
      assert account.payout_destination == %{"momo_number" => "0240000000"}
    end

    test "allows only one payout account per store", %{store: store} do
      create_account!(store)

      assert {:error, _} =
               StorePayoutAccount
               |> Ash.Changeset.for_create(:create, %{store_id: store.id})
               |> Ash.create(authorize?: false)
    end
  end

  describe "record_subaccount" do
    test "stores the gateway subaccount code and marks the account verified", %{store: store} do
      account = create_account!(store)

      {:ok, updated} =
        account
        |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: "ACCT_xyz"})
        |> Ash.update(authorize?: false)

      assert updated.subaccount_code == "ACCT_xyz"
      assert updated.verification_status == :verified
    end
  end

  describe "get_by_store" do
    test "fetches the payout account for a store", %{store: store} do
      create_account!(store, %{payout_destination: %{"momo_number" => "0241111111"}})

      {:ok, account} =
        StorePayoutAccount
        |> Ash.Query.for_read(:get_by_store, %{store_id: store.id})
        |> Ash.read_one(authorize?: false)

      assert account.payout_destination == %{"momo_number" => "0241111111"}
    end

    test "returns nil when the store has no payout account", %{store: store} do
      {:ok, account} =
        StorePayoutAccount
        |> Ash.Query.for_read(:get_by_store, %{store_id: store.id})
        |> Ash.read_one(authorize?: false)

      assert is_nil(account)
    end
  end
end
