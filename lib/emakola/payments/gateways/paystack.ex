defmodule Emakola.Payments.Gateways.Paystack do
  @moduledoc """
  Paystack payment gateway integration.

  Implements the Gateway behaviour for Paystack's API:
  - Transaction initialization (card, mobile_money, bank channels)
  - Transaction verification
  - Refund processing
  - Webhook signature verification (HMAC SHA512)

  All amounts are in minor units (pesewas for GHS, kobo for NGN).

  ## Channel-specific payments

  Pass `channel` in params to restrict payment to a specific channel:
  - `"mobile_money"` — MTN MoMo, Vodafone Cash, AirtelTigo
  - `"card"` — Visa, Mastercard
  - `"bank"` — Bank transfer

  For mobile money, also pass:
  - `mobile_money_provider` — `"mtn"`, `"vod"`, or `"tgo"`
  - `phone` — Ghana phone number (10 digits starting with 0, or +233 format)
  """

  @behaviour Emakola.Payments.Gateway

  @base_url "https://api.paystack.co"

  @valid_channels ~w(mobile_money card bank)
  @valid_momo_providers ~w(mtn vod tgo)

  @impl true
  def initiate_payment(params) do
    with :ok <- validate_channel_params(params) do
      do_initiate_payment(params)
    end
  end

  defp do_initiate_payment(params) do
    reference = generate_reference(params[:store_id])

    metadata =
      %{
        order_id: params[:order_id],
        store_id: params[:store_id]
      }
      |> maybe_add_mobile_money_metadata(params)

    body =
      %{
        amount: params.amount,
        email: params.email,
        currency: params[:currency] || "GHS",
        reference: reference,
        callback_url: params[:callback_url],
        metadata: metadata
      }
      |> maybe_add_channels(params)

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

  # -- Channel & validation helpers ------------------------------------------

  defp validate_channel_params(%{channel: "mobile_money"} = params) do
    with :ok <- validate_momo_provider(params[:mobile_money_provider]),
         :ok <- validate_phone(params[:phone]) do
      :ok
    end
  end

  defp validate_channel_params(_params), do: :ok

  defp validate_momo_provider(provider) when provider in @valid_momo_providers, do: :ok

  defp validate_momo_provider(nil),
    do: {:error, {:validation_error, "mobile_money_provider is required"}}

  defp validate_momo_provider(_invalid),
    do:
      {:error,
       {:validation_error, "invalid mobile_money_provider; must be one of: mtn, vod, tgo"}}

  defp validate_phone(nil),
    do: {:error, {:validation_error, "phone is required for mobile money payments"}}

  defp validate_phone(phone) do
    normalized = normalize_ghana_phone(phone)

    if Regex.match?(~r/^0\d{9}$/, normalized) do
      :ok
    else
      {:error,
       {:validation_error,
        "invalid phone number; must be 10 digits starting with 0 (Ghana format)"}}
    end
  end

  @doc false
  def normalize_ghana_phone(phone) when is_binary(phone) do
    phone = String.trim(phone)

    cond do
      String.starts_with?(phone, "+233") ->
        "0" <> String.slice(phone, 4..-1//1)

      String.starts_with?(phone, "233") and String.length(phone) == 12 ->
        "0" <> String.slice(phone, 3..-1//1)

      true ->
        phone
    end
  end

  defp maybe_add_channels(body, %{channel: channel}) when channel in @valid_channels do
    Map.put(body, :channels, [channel])
  end

  defp maybe_add_channels(body, _params), do: body

  defp maybe_add_mobile_money_metadata(metadata, %{channel: "mobile_money"} = params) do
    metadata
    |> maybe_put(:mobile_money_provider, params[:mobile_money_provider])
    |> maybe_put(:phone, params[:phone] && normalize_ghana_phone(params[:phone]))
  end

  defp maybe_add_mobile_money_metadata(metadata, _params), do: metadata

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

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
