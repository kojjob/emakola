defmodule Emakola.Payments.Gateways.Paystack do
  @moduledoc """
  Paystack payment gateway integration.

  Implements the Gateway behaviour for Paystack's API:
  - Transaction initialization
  - Transaction verification
  - Refund processing
  - Webhook signature verification (HMAC SHA512)

  All amounts are in minor units (pesewas for GHS, kobo for NGN).

  The HTTP calls are delegated to PaystackClient (or a Mox mock in tests)
  so this module only handles parameter mapping and response normalisation.
  """

  @behaviour Emakola.Payments.Gateway

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

    body = maybe_put_split(body, params[:split])

    case paystack_client().initialize_transaction(body) do
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
    case paystack_client().verify_transaction(reference) do
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

    case paystack_client().create_refund(body) do
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
  def create_subaccount(params) do
    case paystack_client().create_subaccount(params) do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok, %{subaccount_code: data["subaccount_code"], raw: data}}

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

  # Wraps caller-supplied flat shares into Paystack's split structure. The
  # platform main account keeps whatever is not assigned to a subaccount
  # (= the platform fee). No split key is added when shares are absent.
  defp maybe_put_split(body, nil), do: body
  defp maybe_put_split(body, []), do: body

  defp maybe_put_split(body, subaccounts) when is_list(subaccounts) do
    Map.put(body, :split, %{type: "flat", bearer_type: "account", subaccounts: subaccounts})
  end

  defp generate_reference(store_id) do
    prefix = if store_id, do: String.slice(to_string(store_id), 0..7), else: "noid"
    timestamp = System.system_time(:second)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "PAY-#{prefix}-#{timestamp}-#{random}"
  end

  # Paystack transaction status values. Unknown statuses are mapped to :unknown
  # rather than dynamically created atoms (Iron Law #10: atom exhaustion DoS).
  defp map_status("success"), do: :success
  defp map_status("failed"), do: :failed
  defp map_status("abandoned"), do: :failed
  defp map_status("reversed"), do: :failed
  defp map_status(_other), do: :unknown

  # Paystack refund status values. Same atom-exhaustion rationale as map_status/1.
  defp map_refund_status("processed"), do: :processed
  defp map_refund_status("pending"), do: :pending
  defp map_refund_status("failed"), do: :failed
  defp map_refund_status(_other), do: :unknown

  # Reads the Paystack secret key. Resolution order:
  #
  #   1. `config :emakola, :paystack_secret_key, "..."`                          (runtime override — prod)
  #   2. `config :emakola, Emakola.Payments.PaystackClient, secret_key: "..."`  (compile-time default — dev/test)
  #
  # The flat path is checked first so that runtime.exs (and tests using
  # `Application.put_env/3`) can override the compile-time default without
  # touching the nested client config.
  defp secret_key do
    case Application.get_env(:emakola, :paystack_secret_key) do
      value when is_binary(value) and value != "" ->
        value

      _ ->
        client_config = Application.get_env(:emakola, Emakola.Payments.PaystackClient, [])

        Keyword.get(client_config, :secret_key) ||
          raise "Paystack secret key not configured. " <>
                  "Set :paystack_secret_key at the application level " <>
                  "or :secret_key under Emakola.Payments.PaystackClient."
    end
  end

  defp paystack_client do
    Application.get_env(:emakola, :paystack_client, Emakola.Payments.PaystackClient)
  end
end
