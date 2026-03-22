defmodule Emakola.Payments.Gateways.Paystack do
  @moduledoc """
  Paystack payment gateway integration.

  Implements the Gateway behaviour for Paystack's API:
  - Transaction initialization
  - Transaction verification
  - Refund processing
  - Webhook signature verification (HMAC SHA512)

  All amounts are in minor units (pesewas for GHS, kobo for NGN).
  """

  @behaviour Emakola.Payments.Gateway

  @base_url "https://api.paystack.co"

  @impl true
  def initiate_payment(params) do
    reference = generate_reference(params[:store_id])

    body = %{
      amount: params.amount,
      email: params.email,
      currency: params[:currency] || "GHS",
      reference: reference,
      callback_url: params[:callback_url],
      metadata: %{
        order_id: params[:order_id],
        store_id: params[:store_id]
      }
    }

    case http_client().post("#{@base_url}/transaction/initialize",
           json: body,
           headers: auth_headers()
         ) do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok,
         %{
           authorization_url: data["authorization_url"],
           access_code: data["access_code"],
           reference: data["reference"]
         }}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, {:paystack_error, message}}

      {:error, reason} ->
        {:error, {:gateway_error, reason}}
    end
  end

  @impl true
  def verify_payment(reference) do
    case http_client().get("#{@base_url}/transaction/verify/#{reference}",
           headers: auth_headers()
         ) do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok,
         %{
           status: map_status(data["status"]),
           amount: data["amount"],
           currency: data["currency"],
           reference: data["reference"],
           gateway_response: data["gateway_response"],
           channel: data["channel"],
           paid_at: data["paid_at"],
           raw: data
         }}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, {:paystack_error, message}}

      {:error, reason} ->
        {:error, {:gateway_error, reason}}
    end
  end

  @impl true
  def process_refund(reference, amount) do
    body = %{
      transaction: reference,
      amount: amount
    }

    case http_client().post("#{@base_url}/refund",
           json: body,
           headers: auth_headers()
         ) do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok,
         %{
           amount: data["amount"],
           status: map_refund_status(data["status"]),
           reference: get_in(data, ["transaction", "reference"]) || reference,
           refund_reference: data["refund_reference"],
           raw: data
         }}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, {:paystack_error, message}}

      {:error, reason} ->
        {:error, {:gateway_error, reason}}
    end
  end

  @impl true
  def verify_webhook(body, headers) do
    secret = secret_key()
    provided_signature = headers["x-paystack-signature"]

    if is_nil(provided_signature) do
      {:error, :invalid_signature}
    else
      computed =
        :crypto.mac(:hmac, :sha512, secret, body)
        |> Base.encode16(case: :lower)

      if Plug.Crypto.secure_compare(computed, provided_signature) do
        :ok
      else
        {:error, :invalid_signature}
      end
    end
  end

  # -- Private helpers -------------------------------------------------------

  defp generate_reference(store_id) do
    prefix = if store_id, do: String.slice(to_string(store_id), 0..7), else: "noid"
    timestamp = System.system_time(:second)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "PAY-#{prefix}-#{timestamp}-#{random}"
  end

  defp map_status("success"), do: :success
  defp map_status("failed"), do: :failed
  defp map_status("abandoned"), do: :failed
  defp map_status(other), do: String.to_atom(other)

  defp map_refund_status("processed"), do: :processed
  defp map_refund_status("pending"), do: :pending
  defp map_refund_status("failed"), do: :failed
  defp map_refund_status(other), do: String.to_atom(other)

  defp auth_headers do
    [{"Authorization", "Bearer #{secret_key()}"}, {"Content-Type", "application/json"}]
  end

  defp secret_key do
    Application.get_env(:emakola, :paystack_secret_key) ||
      raise "Paystack secret key not configured. Set :paystack_secret_key in config."
  end

  defp http_client do
    Application.get_env(:emakola, :http_client, Emakola.HTTPClient.Req)
  end
end
