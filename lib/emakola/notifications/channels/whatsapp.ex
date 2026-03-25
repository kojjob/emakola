defmodule Emakola.Notifications.Channels.WhatsApp do
  @moduledoc """
  WhatsApp Business Cloud API client for order notifications.

  Sends template messages via the WhatsApp Cloud API at
  `https://graph.facebook.com/v18.0/{PHONE_NUMBER_ID}/messages`.

  Template messages must be pre-approved by Meta. This module formats
  the API request with template parameters; actual template names are
  registered in the WhatsApp Business Manager console.

  ## Configuration

      config :emakola, Emakola.Notifications.Channels.WhatsApp,
        api_token: System.get_env("WHATSAPP_API_TOKEN"),
        phone_number_id: System.get_env("WHATSAPP_PHONE_NUMBER_ID")

  ## Usage

  The module is accessed through the behaviour so it can be mocked in tests:

      whatsapp_channel().send_order_confirmation(order, customer_phone: "+233244123456")
  """

  @behaviour Emakola.Notifications.Channels.WhatsAppBehaviour

  require Logger

  @base_url "https://graph.facebook.com/v18.0"

  # ── Public API ─────────────────────────────────────────────────

  @impl true
  def send_order_confirmation(order, opts \\ []) do
    phone = Keyword.fetch!(opts, :customer_phone)

    params = [
      %{type: "text", text: order.order_number},
      %{type: "text", text: store_name(opts)},
      %{type: "text", text: format_total(order)}
    ]

    send_template(phone, "order_confirmation", params, opts)
  end

  @impl true
  def send_shipping_update(order, opts \\ []) do
    phone = Keyword.fetch!(opts, :customer_phone)
    tracking_number = Keyword.get(opts, :tracking_number, "N/A")
    carrier = Keyword.get(opts, :carrier, "")

    params = [
      %{type: "text", text: order.order_number},
      %{type: "text", text: store_name(opts)},
      %{type: "text", text: carrier},
      %{type: "text", text: tracking_number}
    ]

    send_template(phone, "order_shipped", params, opts)
  end

  @impl true
  def send_delivery_confirmation(order, opts \\ []) do
    phone = Keyword.fetch!(opts, :customer_phone)

    params = [
      %{type: "text", text: order.order_number},
      %{type: "text", text: store_name(opts)}
    ]

    send_template(phone, "order_delivered", params, opts)
  end

  # ── Message Building ───────────────────────────────────────────

  @doc """
  Builds the JSON body for a WhatsApp Cloud API template message.

  Returns a map ready for JSON encoding. Useful for testing message
  formatting without making HTTP calls.
  """
  def build_template_message(to, template_name, parameters, language \\ "en") do
    %{
      messaging_product: "whatsapp",
      to: normalize_phone(to),
      type: "template",
      template: %{
        name: template_name,
        language: %{code: language},
        components: [
          %{
            type: "body",
            parameters: parameters
          }
        ]
      }
    }
  end

  # ── HTTP Client ────────────────────────────────────────────────

  defp send_template(phone, template_name, parameters, _opts) do
    body = build_template_message(phone, template_name, parameters)
    url = "#{@base_url}/#{phone_number_id()}/messages"

    headers = [
      {"authorization", "Bearer #{api_token()}"},
      {"content-type", "application/json"}
    ]

    Logger.info("[WhatsApp] Sending template '#{template_name}' to #{normalize_phone(phone)}")

    case http_client().post(url, json: body, headers: headers) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, %{status: status, body: resp_body, template: template_name}}

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error("[WhatsApp] API error #{status}: #{inspect(resp_body)}")

        {:error, %{status: status, body: resp_body}}

      {:error, reason} ->
        Logger.error("[WhatsApp] HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp normalize_phone(phone) do
    phone
    |> to_string()
    |> String.replace(~r/[^0-9]/, "")
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

  defp store_name(opts), do: Keyword.get(opts, :store_name, "")

  defp api_token do
    config()[:api_token] || ""
  end

  defp phone_number_id do
    config()[:phone_number_id] || ""
  end

  defp config do
    Application.get_env(:emakola, __MODULE__, [])
  end

  defp http_client do
    Application.get_env(:emakola, :http_client, Req)
  end
end
