defmodule Emakola.Notifications.Channels.SMS do
  @moduledoc """
  SMS gateway client for order notifications.

  Sends SMS messages via a configurable HTTP API (compatible with
  Hubtel SMS, Africa's Talking, or similar providers).

  ## Configuration

      config :emakola, Emakola.Notifications.Channels.SMS,
        api_key: System.get_env("SMS_API_KEY"),
        sender_id: System.get_env("SMS_SENDER_ID") || "Emakola",
        api_url: System.get_env("SMS_API_URL") || "https://api.sms-gateway.example.com/v1/messages"

  ## Usage

      sms_channel().send_sms("+233244123456", "Your order has shipped!", store_id: store.id)
      sms_channel().send_order_sms(order, customer_phone: "+233244123456", store_name: "My Shop")
  """

  @behaviour Emakola.Notifications.Channels.SMSBehaviour

  require Logger

  # ── Public API ─────────────────────────────────────────────────

  @impl true
  def send_sms(phone, message, _opts \\ []) do
    body = build_sms_payload(phone, message)

    Logger.info("[SMS] Sending to #{normalize_phone(phone)}: #{String.slice(message, 0..49)}...")

    case http_client().post(api_url(), json: body, headers: auth_headers()) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, %{status: status, body: resp_body, to: normalize_phone(phone)}}

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error("[SMS] API error #{status}: #{inspect(resp_body)}")
        {:error, %{status: status, body: resp_body}}

      {:error, reason} ->
        Logger.error("[SMS] HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def send_order_sms(order, opts \\ []) do
    phone = Keyword.fetch!(opts, :customer_phone)
    store_name = Keyword.get(opts, :store_name, "")

    message =
      "Hi! Your order #{order.order_number} from #{store_name} has been placed. " <>
        "Total: #{format_total(order)}. We'll keep you updated!"

    send_sms(phone, message, opts)
  end

  # ── Message Building ───────────────────────────────────────────

  @doc """
  Builds the JSON payload for the SMS API.

  Returns a map ready for JSON encoding. Useful for testing message
  formatting without making HTTP calls.
  """
  def build_sms_payload(phone, message) do
    %{
      from: sender_id(),
      to: normalize_phone(phone),
      content: message
    }
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp normalize_phone(phone) do
    phone
    |> to_string()
    |> String.replace(~r/[^0-9+]/, "")
  end

  defp format_total(order) do
    symbol = currency_symbol(order.currency)
    amount = format_amount(order.total)
    "#{symbol}#{amount}"
  end

  defp format_amount(minor_units) when is_integer(minor_units) do
    major = div(minor_units, 100)
    minor = rem(abs(minor_units), 100)
    "#{major}.#{String.pad_leading(Integer.to_string(minor), 2, "0")}"
  end

  defp format_amount(_), do: "0.00"

  defp currency_symbol("GHS"), do: "GH\u20B5"
  defp currency_symbol("NGN"), do: "\u20A6"
  defp currency_symbol("USD"), do: "$"
  defp currency_symbol(_), do: ""

  defp auth_headers do
    [
      {"authorization", "Bearer #{api_key()}"},
      {"content-type", "application/json"}
    ]
  end

  defp api_key do
    config()[:api_key] || ""
  end

  defp sender_id do
    config()[:sender_id] || "Emakola"
  end

  defp api_url do
    config()[:api_url] || "https://api.sms-gateway.example.com/v1/messages"
  end

  defp config do
    Application.get_env(:emakola, __MODULE__, [])
  end

  defp http_client do
    Application.get_env(:emakola, :http_client, Req)
  end
end
