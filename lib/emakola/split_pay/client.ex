defmodule Emakola.SplitPay.Client do
  @moduledoc """
  Makola as a SplitPay tenant. Ships dark: the client is enabled only
  when SPLITPAY_API_URL and SPLITPAY_API_KEY are both configured, so
  nothing changes for existing charge paths until the flag is real.
  """

  def enabled? do
    is_binary(config()[:base_url]) and is_binary(config()[:api_key])
  end

  def webhook_secret, do: config()[:webhook_secret]

  def create_charge(params, idempotency_key) do
    request =
      [
        method: :post,
        url: config()[:base_url] <> "/v1/charges",
        auth: {:bearer, config()[:api_key]},
        headers: [{"idempotency-key", idempotency_key}],
        json: params,
        retry: false
      ] ++ (config()[:req_options] || [])

    case Req.request(request) do
      {:ok, %{status: 201, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {:splitpay_error, status, body}}
      {:error, reason} -> {:error, {:splitpay_unreachable, reason}}
    end
  end

  defp config, do: Application.get_env(:emakola, __MODULE__, [])
end
