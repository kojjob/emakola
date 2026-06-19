defmodule Emakola.Stores.PayoutOnboarding do
  @moduledoc """
  SP1 — connects a store's Mobile Money payout destination to a verified gateway
  subaccount, so the store can receive dropship split settlements.

  `connect_momo/3` persists the destination on the store's `StorePayoutAccount`,
  asks the gateway to create a subaccount for it, and records the returned code
  (which marks the account verified). If the gateway call fails, the destination
  is kept but the account stays unverified so the merchant can retry.

  The gateway is injectable via `opts[:gateway]` for testing; it defaults to the
  configured payment gateway.
  """

  alias Emakola.Payments.SettlementBanks
  alias Emakola.Stores.StorePayoutAccount

  def connect_momo(store, params, opts \\ []) do
    gateway = Keyword.get(opts, :gateway, configured_gateway())

    destination = %{
      "provider" => params.provider,
      "number" => params.number,
      "account_name" => params.account_name
    }

    with {:ok, account} <- upsert_account(store, destination),
         {:ok, %{subaccount_code: code}} <-
           gateway.create_subaccount(subaccount_params(store, params)) do
      record_subaccount(account, code)
    end
  end

  defp upsert_account(store, destination) do
    case Emakola.Stores.get_payout_account(store.id, not_found_error?: false, authorize?: false) do
      {:ok, nil} ->
        StorePayoutAccount
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          payout_destination: destination
        })
        |> Ash.create(authorize?: false)

      {:ok, account} ->
        account
        |> Ash.Changeset.for_update(:update, %{payout_destination: destination})
        |> Ash.update(authorize?: false)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp record_subaccount(account, code) do
    account
    |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: code})
    |> Ash.update(authorize?: false)
  end

  defp subaccount_params(store, params) do
    %{
      business_name: params.account_name || store.name,
      settlement_bank: SettlementBanks.settlement_code(params.provider),
      account_number: params.number,
      percentage_charge: 0
    }
  end

  defp configured_gateway do
    Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)
  end
end
