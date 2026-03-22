defmodule Emakola.Payments.Gateways.Hubtel do
  @moduledoc """
  Hubtel payment gateway integration for mobile money payments in Ghana.

  Handles MTN MoMo, Vodafone Cash, and AirtelTigo Money via Hubtel's
  Receive Money API.

  CRITICAL: All internal amounts are in pesewas (minor units).
  Hubtel API expects cedis (major units). We convert:
    - To Hubtel:   pesewas / 100.0  → cedis
    - From Hubtel:  round(cedis * 100)  → pesewas
  """

  @behaviour Emakola.Payments.Gateway

  @base_url "https://api.hubtel.com"

  # ── Callbacks ──────────────────────────────────────────────────

  @impl true
  def initiate_payment(params) do
    reference = generate_reference(params.store_id)
    amount_cedis = pesewas_to_cedis(params.amount)

    body = %{
      "Amount" => amount_cedis,
      "Title" => "Order #{params.order_reference}",
      "Description" => params[:description] || "Payment for order",
      "ClientReference" => reference,
      "CallbackUrl" => params.callback_url,
      "ReturnUrl" => params.return_url,
      "Channel" => params[:channel] || "mtn-gh"
    }

    case http_client().post(api_url("/v2/receive/mobile-money"),
           headers: auth_headers(),
           json: body
         ) do
      {:ok, %{"ResponseCode" => "0000", "Data" => data}} ->
        {:ok,
         %{
           checkout_url: data["CheckoutUrl"],
           checkout_id: data["CheckoutId"],
           reference: data["ClientReference"] || reference
         }}

      {:ok, %{"ResponseCode" => code} = resp} ->
        {:error, %{code: code, message: resp["Message"] || "Hubtel error"}}

      {:error, reason} ->
        {:error, %{code: "HTTP_ERROR", message: "HTTP request failed", details: reason}}
    end
  end

  @impl true
  def verify_payment(reference) do
    case http_client().get(api_url("/v2/payment/#{reference}/status"), headers: auth_headers()) do
      {:ok, %{"ResponseCode" => "0000", "Data" => data}} ->
        {:ok,
         %{
           status: data["Status"],
           amount: cedis_to_pesewas(data["Amount"]),
           reference: data["ClientReference"] || reference
         }}

      {:ok, %{"ResponseCode" => code} = resp} ->
        {:error, %{code: code, message: resp["Message"] || "Hubtel error"}}

      {:error, reason} ->
        {:error, %{code: "HTTP_ERROR", message: "HTTP request failed", details: reason}}
    end
  end

  @impl true
  def process_refund(reference, amount_pesewas) do
    amount_cedis = pesewas_to_cedis(amount_pesewas)

    body = %{
      "ClientReference" => reference,
      "Amount" => amount_cedis,
      "Reason" => "Customer refund"
    }

    case http_client().post(api_url("/v2/refund"), headers: auth_headers(), json: body) do
      {:ok, %{"ResponseCode" => "0000", "Data" => data}} ->
        {:ok,
         %{
           refund_id: data["RefundId"],
           amount: cedis_to_pesewas(data["Amount"])
         }}

      {:ok, %{"ResponseCode" => code} = resp} ->
        {:error, %{code: code, message: resp["Message"] || "Hubtel error"}}

      {:error, reason} ->
        {:error, %{code: "HTTP_ERROR", message: "HTTP request failed", details: reason}}
    end
  end

  @impl true
  def verify_webhook(body, _headers) do
    # Hubtel doesn't use webhook signatures. Instead, we verify by
    # calling the payment status check API to confirm the transaction.
    with {:ok, parsed} <- Jason.decode(body),
         reference when is_binary(reference) <- parsed["ClientReference"],
         {:ok, %{status: status}} when status in ["Paid", "Success"] <- verify_payment(reference) do
      :ok
    else
      _ -> {:error, :invalid_signature}
    end
  end

  # ── Private Helpers ──────────────────────────────────────────────

  defp pesewas_to_cedis(pesewas) when is_integer(pesewas) do
    pesewas / 100.0
  end

  defp cedis_to_pesewas(cedis) when is_number(cedis) do
    round(cedis * 100)
  end

  defp generate_reference(store_id) do
    prefix = store_id |> String.slice(0, 6)
    timestamp = System.system_time(:second)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "HUB-#{prefix}-#{timestamp}-#{random}"
  end

  defp auth_headers do
    client_id = Application.get_env(:emakola, :hubtel_client_id)
    client_secret = Application.get_env(:emakola, :hubtel_client_secret)
    encoded = Base.encode64("#{client_id}:#{client_secret}")

    [
      {"authorization", "Basic #{encoded}"},
      {"content-type", "application/json"}
    ]
  end

  defp api_url(path) do
    base = Application.get_env(:emakola, :hubtel_base_url, @base_url)
    "#{base}#{path}"
  end

  defp http_client do
    Application.get_env(:emakola, :http_client, Emakola.HTTPClient.Req)
  end
end
