defmodule Emakola.Payments.HubtelClient do
  @moduledoc """
  HTTP client for the Hubtel Merchant Account API.

  Wraps the generic HTTPClient to provide Hubtel-specific operations
  (create invoice, check status). Config is read from:

      config :emakola, Emakola.Payments.HubtelClient,
        client_id: "...",
        client_secret: "...",
        base_url: "https://api.hubtel.com"

  In tests, swap this module for `Emakola.Payments.HubtelClientMock`
  via `config :emakola, :hubtel_client, HubtelClientMock`.
  """

  @behaviour Emakola.Payments.HubtelClientBehaviour

  @impl true
  def create_invoice(params) do
    http_client().post(
      "#{base_url()}/v2/pos/onlinecheckout/items/initiate",
      json: params,
      headers: auth_headers()
    )
  end

  @impl true
  def check_invoice_status(client_reference) do
    http_client().get(
      "#{base_url()}/v2/pos/onlinecheckout/items/#{client_reference}/status",
      headers: auth_headers()
    )
  end

  # -- Private helpers -------------------------------------------------------

  defp auth_headers do
    encoded = Base.encode64("#{client_id()}:#{client_secret()}")

    [
      {"Authorization", "Basic #{encoded}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp config do
    Application.get_env(:emakola, __MODULE__, [])
  end

  defp client_id do
    Keyword.get_lazy(config(), :client_id, fn ->
      Application.get_env(:emakola, :hubtel_client_id) ||
        raise "Hubtel client ID not configured"
    end)
  end

  defp client_secret do
    Keyword.get_lazy(config(), :client_secret, fn ->
      Application.get_env(:emakola, :hubtel_client_secret) ||
        raise "Hubtel client secret not configured"
    end)
  end

  defp base_url do
    Keyword.get(config(), :base_url, "https://api.hubtel.com")
  end

  defp http_client do
    Application.get_env(:emakola, :http_client, Emakola.HTTPClient.Req)
  end
end
