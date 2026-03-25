defmodule Emakola.Payments.PaystackClientBehaviour do
  @moduledoc """
  Behaviour for the Paystack API client.

  Defines the contract for Paystack HTTP operations so the real client
  can be swapped for a Mox mock in tests without touching the lower-level
  HTTPClient behaviour.
  """

  @callback initialize_transaction(map()) :: {:ok, map()} | {:error, term()}
  @callback verify_transaction(String.t()) :: {:ok, map()} | {:error, term()}
  @callback create_refund(map()) :: {:ok, map()} | {:error, term()}
end
