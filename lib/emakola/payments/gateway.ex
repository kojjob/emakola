defmodule Emakola.Payments.Gateway do
  @moduledoc """
  Behaviour for payment gateway integrations (Paystack, Hubtel, etc.)
  All amounts are in minor units (pesewas for GHS, kobo for NGN).
  """

  @callback initiate_payment(map()) :: {:ok, map()} | {:error, term()}
  @callback verify_payment(String.t()) :: {:ok, map()} | {:error, term()}
  @callback process_refund(String.t(), integer()) :: {:ok, map()} | {:error, term()}
  @callback verify_webhook(binary(), map()) :: :ok | {:error, :invalid_signature}

  @doc """
  Create a payout subaccount for a merchant. Used by dropship split settlement
  so a charge can be routed directly to a wholesaler/dropshipper. Gateways
  without split support may return `{:error, :not_supported}`.
  """
  @callback create_subaccount(map()) :: {:ok, map()} | {:error, term()}

  @doc """
  Create a transfer recipient (a payout destination) and initiate a transfer to
  it. Used by the payout-execution engine to disburse the balance the platform
  holds for un-split orders. Gateways without transfer support may return
  `{:error, :not_supported}`.
  """
  @callback create_transfer_recipient(map()) :: {:ok, map()} | {:error, term()}
  @callback initiate_transfer(map()) :: {:ok, map()} | {:error, term()}
end
