defmodule Emakola.Notifications.Channels.WhatsApp do
  @moduledoc """
  WhatsApp Business Cloud API client for order notifications.

  Sends template messages via the WhatsApp Cloud API at
  `https://graph.facebook.com/{api_version}/{PHONE_NUMBER_ID}/messages`.
  The version is configurable so we can update without a redeploy when
  Meta deprecates a Graph API version.

  Template messages must be pre-approved by Meta. This module formats
  the API request with template parameters; actual template names are
  registered in the WhatsApp Business Manager console.

  ## Configuration

      config :emakola, Emakola.Notifications.Channels.WhatsApp,
        api_token: System.get_env("WHATSAPP_API_TOKEN"),
        phone_number_id: System.get_env("WHATSAPP_PHONE_NUMBER_ID"),
        api_version: System.get_env("WHATSAPP_API_VERSION") || "v21.0"

  ## Usage

  The module is accessed through the behaviour so it can be mocked in tests:

      whatsapp_channel().send_order_confirmation(order, customer_phone: "+233244123456")
  """

  @behaviour Emakola.Notifications.Channels.WhatsAppBehaviour
  @behaviour Emakola.Notifications.WhatsAppProvider

  require Logger

  @default_api_version "v21.0"
  @base_host "https://graph.facebook.com"

  # Per-store WhatsApp rate limit. Meta enforces its own per-phone-number
  # limits; ours sits underneath as a safety net catching notification
  # loops or runaway workers. 200/hour matches typical transactional
  # volume for a small-merchant catalog.
  @rate_limit 200
  @rate_window_ms :timer.hours(1)

  # Positional body-parameter order for each Meta-registered template.
  # Cloud API placeholders ({{1}}..{{n}}) are positional, but the
  # WhatsAppProvider behaviour hands us a params MAP — so every template
  # needs an explicit key order. Keep in sync with the params built in
  # Emakola.Notifications.Templates and with the templates registered in
  # the WhatsApp Business Manager console.
  @order_param_order [:order_number, :store_name, :total, :currency]

  @template_param_order %{
    "order_placed" => @order_param_order,
    "order_confirmed" => @order_param_order,
    "order_shipped" => @order_param_order,
    "order_delivered" => @order_param_order,
    "order_cancelled" => @order_param_order,
    "supplier_fulfillment" => [:order_number, :supplier_name, :items, :ship_to],
    "auth_code" => [:code],
    "announcement" => [:title]
  }

  # ── Public API ─────────────────────────────────────────────────

  @doc """
  Sends a template message from a params map (WhatsAppProvider bridge).

  Notification workers call `whatsapp_provider().send_message/4` with the
  param maps built by `Emakola.Notifications.Templates`. The map is
  converted to the Cloud API's positional body parameters using the
  template's declared key order; unknown templates are rejected rather
  than sent with a guessed parameter order, and a missing key raises.
  """
  @impl Emakola.Notifications.WhatsAppProvider
  def send_message(to, template_name, params, opts) when is_map(params) do
    case Map.fetch(@template_param_order, template_name) do
      {:ok, keys} ->
        parameters =
          Enum.map(keys, fn key ->
            %{type: "text", text: to_string(Map.fetch!(params, key))}
          end)

        send_template(to, template_name, parameters, opts)

      :error ->
        Logger.error(
          "[WhatsApp] unknown template '#{template_name}'; " <>
            "no declared parameter order — not sending"
        )

        {:error, {:unknown_template, template_name}}
    end
  end

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

  defp send_template(phone, template_name, parameters, opts) do
    case rate_limit_check(opts) do
      :allow ->
        do_send_template(phone, template_name, parameters)

      :deny ->
        store_id = Keyword.get(opts, :store_id)

        Logger.warning(
          "[WhatsApp] rate limit exceeded for store=#{inspect(store_id)} " <>
            "(#{@rate_limit} per #{div(@rate_window_ms, 60_000)}m); dropping message"
        )

        {:error, :rate_limited}
    end
  end

  defp do_send_template(phone, template_name, parameters) do
    body = build_template_message(phone, template_name, parameters)
    url = "#{@base_host}/#{api_version()}/#{phone_number_id()}/messages"

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

  defp rate_limit_check(opts) do
    cond do
      Keyword.get(opts, :bypass_rate_limit, false) ->
        :allow

      store_id = Keyword.get(opts, :store_id) ->
        case Emakola.RateLimit.check_rate(
               "whatsapp:store:#{store_id}",
               @rate_limit,
               @rate_window_ms
             ) do
          {:allow, _count} -> :allow
          {:deny, _limit} -> :deny
        end

      true ->
        Logger.warning("[WhatsApp] no :store_id in opts; rate limit not applied")
        :allow
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

  defp api_version do
    config()[:api_version] || @default_api_version
  end

  defp config do
    Application.get_env(:emakola, __MODULE__, [])
  end

  defp http_client do
    Application.get_env(:emakola, :http_client, Req)
  end
end
