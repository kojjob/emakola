defmodule Emakola.Payments.PaystackClient do
  @moduledoc """
  HTTP client for the Paystack API.

  Wraps the generic HTTPClient to provide Paystack-specific operations
  (initialize, verify, refund). Config is read from:

      config :emakola, Emakola.Payments.PaystackClient,
        secret_key: "sk_...",
        base_url: "https://api.paystack.co"

  In tests, swap this module for `Emakola.Payments.PaystackClientMock`
  via `config :emakola, :paystack_client, PaystackClientMock`.
  """

  @behaviour Emakola.Payments.PaystackClientBehaviour

  @impl true
  def initialize_transaction(params) do
    http_client().post(
      "#{base_url()}/transaction/initialize",
      json: params,
      headers: auth_headers()
    )
  end

  @impl true
  def verify_transaction(reference) do
    http_client().get(
      "#{base_url()}/transaction/verify/#{reference}",
      headers: auth_headers()
    )
  end

  @impl true
  def create_refund(params) do
    http_client().post(
      "#{base_url()}/refund",
      json: params,
      headers: auth_headers()
    )
  end

  @impl true
  def create_subaccount(params) do
    http_client().post(
      "#{base_url()}/subaccount",
      json: params,
      headers: auth_headers()
    )
  end

  @impl true
  def create_transfer_recipient(params) do
    http_client().post(
      "#{base_url()}/transferrecipient",
      json: params,
      headers: auth_headers()
    )
  end

  @impl true
  def initiate_transfer(params) do
    http_client().post(
      "#{base_url()}/transfer",
      json: params,
      headers: auth_headers()
    )
  end

  # -- Private helpers -------------------------------------------------------

  defp auth_headers do
    [{"Authorization", "Bearer #{secret_key()}"}, {"Content-Type", "application/json"}]
  end

  defp config do
    Application.get_env(:emakola, __MODULE__, [])
  end

  defp secret_key do
    Keyword.get_lazy(config(), :secret_key, fn ->
      Application.get_env(:emakola, :paystack_secret_key) ||
        raise "Paystack secret key not configured"
    end)
  end

  defp base_url do
    Keyword.get(config(), :base_url, "https://api.paystack.co")
  end

  defp http_client do
    Application.get_env(:emakola, :http_client, Emakola.HTTPClient.Req)
  end
end
