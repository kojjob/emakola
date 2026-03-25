defmodule Emakola.Payments.HubtelClientBehaviour do
  @moduledoc """
  Behaviour for the Hubtel API client.

  Defines the contract for Hubtel HTTP operations so the real client
  can be swapped for a Mox mock in tests without touching the lower-level
  HTTPClient behaviour.
  """

  @callback create_invoice(map()) :: {:ok, map()} | {:error, term()}
  @callback check_invoice_status(String.t()) :: {:ok, map()} | {:error, term()}
end
