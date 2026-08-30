defmodule Emakola.Stores.StorePayoutAccountTest do
  @moduledoc """
  A store's payout identity for trustless dropship settlement (SP1): the
  Paystack subaccount a split routes money to, and whether it is verified.
  Kept off the (publicly-readable) Store resource so payout data stays
  merchant-only.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Stores
  alias Emakola.Stores.StorePayoutAccount

  setup do
    {:ok, store: create_store!()}
  end

  defp momo(number) do
    %{
      "method" => "mobile_money",
      "provider" => "mtn",
      "number" => number,
      "account_name" => "Ama"
    }
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

  describe "wallet proof (payout_proven_at)" do
    test "record_payout_proof stamps the moment the merchant answered the OTP", %{store: store} do
      account = create_account!(store, %{payout_destination: momo("0244000000")})
      assert is_nil(account.payout_proven_at)

      {:ok, proven} =
        account
        |> Ash.Changeset.for_update(:record_payout_proof, %{})
        |> Ash.update(authorize?: false)

      assert %DateTime{} = proven.payout_proven_at
    end
  end

  describe "changing the destination voids the proof (the one-way latch bug)" do
    setup %{store: store} do
      account =
        store
        |> create_account!(%{payout_destination: momo("0244000000")})
        |> then(
          &Ash.update!(Ash.Changeset.for_update(&1, :record_payout_proof, %{}), authorize?: false)
        )
        |> then(
          &Ash.update!(
            Ash.Changeset.for_update(&1, :record_subaccount, %{subaccount_code: "ACCT_old"}),
            authorize?: false
          )
        )

      assert account.verification_status == :verified
      assert account.subaccount_code == "ACCT_old"
      assert %DateTime{} = account.payout_proven_at

      %{account: account}
    end

    test "swapping the MoMo number resets status, proof and subaccount", %{account: account} do
      {:ok, updated} =
        Stores.update_payout_account(account, %{payout_destination: momo("0209999999")},
          authorize?: false
        )

      assert updated.verification_status == :unverified,
             "a verified account must not survive being pointed at a different wallet"

      assert is_nil(updated.payout_proven_at)

      assert is_nil(updated.subaccount_code),
             "the old subaccount settles to the old number; the worker must build a new one"
    end

    test "switching from MoMo to bank also voids the proof", %{account: account} do
      {:ok, updated} =
        Stores.update_payout_account(
          account,
          %{payout_destination: %{"method" => "bank", "account_number" => "1234567890"}},
          authorize?: false
        )

      assert updated.verification_status == :unverified
      assert is_nil(updated.payout_proven_at)
    end

    test "re-saving the identical destination leaves the proof intact", %{account: account} do
      {:ok, updated} =
        Stores.update_payout_account(account, %{payout_destination: momo("0244000000")},
          authorize?: false
        )

      assert updated.verification_status == :verified
      assert %DateTime{} = updated.payout_proven_at
      assert updated.subaccount_code == "ACCT_old"
    end
  end

  describe "domain code interfaces (payout onboarding)" do
    test "create_payout_account persists the payout destination", %{store: store} do
      {:ok, account} =
        Stores.create_payout_account(
          %{
            store_id: store.id,
            payout_destination: %{"method" => "mobile_money", "number" => "0240000000"}
          },
          authorize?: false
        )

      assert account.store_id == store.id
      assert account.verification_status == :unverified
      assert account.payout_destination["number"] == "0240000000"
    end

    test "update_payout_account changes the payout destination", %{store: store} do
      account = create_account!(store, %{payout_destination: %{"method" => "mobile_money"}})

      {:ok, updated} =
        Stores.update_payout_account(
          account,
          %{payout_destination: %{"method" => "bank", "account_number" => "1234567890"}},
          authorize?: false
        )

      assert updated.payout_destination["method"] == "bank"
      assert updated.payout_destination["account_number"] == "1234567890"
    end

    test "get_payout_account fetches the store's account, nil when none", %{store: store} do
      assert {:ok, nil} =
               Stores.get_payout_account(store.id, authorize?: false, not_found_error?: false)

      create_account!(store, %{payout_destination: %{"number" => "0247654321"}})

      {:ok, account} = Stores.get_payout_account(store.id, authorize?: false)
      assert account.payout_destination["number"] == "0247654321"
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
