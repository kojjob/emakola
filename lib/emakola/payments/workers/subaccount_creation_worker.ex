defmodule Emakola.Payments.Workers.SubaccountCreationWorker do
  @moduledoc """
  Turns a merchant's saved payout account into a Paystack subaccount that order
  payments can be split to (revenue rails, slice 1).

  Enqueued (async, idempotent) after a payout account is saved so the gateway
  network call never blocks the merchant's save and retries on transient failure.
  On success the account is marked `:verified` with its `subaccount_code`, which
  is what lets `OrderSettlement` route the merchant their share.

  v1 handles mobile-money payouts (the Ghana norm); bank-account subaccounts need
  a bank-name→code lookup and are deferred.
  """
  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 600, fields: [:args]]

  require Logger

  alias Emakola.Stores

  # Paystack Ghana mobile-money settlement_bank codes (List Banks, type: mobile_money).
  @provider_codes %{"mtn" => "MTN", "vodafone" => "VOD", "airteltigo" => "ATL"}

  @spec enqueue(binary()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(store_id) when is_binary(store_id) do
    %{"store_id" => store_id}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"store_id" => store_id}}) do
    case Stores.get_payout_account(store_id, authorize?: false, not_found_error?: false) do
      # Already has a subaccount — idempotent no-op.
      {:ok, %{subaccount_code: code}} when is_binary(code) ->
        :ok

      {:ok, %{payout_destination: %{"method" => "mobile_money"} = dest} = account} ->
        create_subaccount(account, dest, store_id)

      # No payout account, or a non-mobile-money (bank) destination — deferred.
      _ ->
        :ok
    end
  end

  defp create_subaccount(account, dest, store_id) do
    case provider_code(dest["provider"]) do
      nil ->
        Logger.warning(
          "[SubaccountCreationWorker] unknown MoMo provider for store #{store_id}: #{inspect(dest["provider"])}"
        )

        :ok

      settlement_bank ->
        with {:ok, store} <- Stores.get_store(store_id, authorize?: false),
             params = %{
               business_name: store.name,
               settlement_bank: settlement_bank,
               account_number: dest["number"],
               percentage_charge: 0
             },
             {:ok, %{subaccount_code: code}} <- gateway().create_subaccount(params) do
          {:ok, _} =
            Stores.record_payout_subaccount(account, %{subaccount_code: code}, authorize?: false)

          :ok
        else
          {:error, reason} ->
            Logger.error(
              "[SubaccountCreationWorker] subaccount creation failed for store #{store_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end
    end
  end

  defp provider_code(provider), do: Map.get(@provider_codes, provider)

  defp gateway do
    Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)
  end
end
