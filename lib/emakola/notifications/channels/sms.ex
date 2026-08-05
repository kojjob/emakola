defmodule Emakola.Notifications.Channels.SMS do
  @moduledoc """
  SMS gateway client for order notifications.

  Sends SMS messages via a configurable HTTP API (compatible with
  Hubtel SMS, Africa's Talking, or similar providers).

  ## Configuration

      config :emakola, Emakola.Notifications.Channels.SMS,
        api_key: System.get_env("SMS_API_KEY"),
        sender_id: System.get_env("SMS_SENDER_ID") || "Makola",
        api_url: System.get_env("SMS_API_URL") || "https://api.sms-gateway.example.com/v1/messages"

  Set `provider: :arkesel` (SMS_PROVIDER=arkesel in prod) to speak Arkesel's
  v2 API natively: `api-key` auth header (not Bearer), the
  `sender/message/recipients` payload shape, and the Arkesel endpoint as the
  default `api_url`. The `:generic` default keeps the Bearer + from/to/content
  contract for Hubtel-SMS-compatible gateways.

  ## Usage

      sms_channel().send_sms("+233244123456", "Your order has shipped!", store_id: store.id)
      sms_channel().send_order_sms(order, customer_phone: "+233244123456", store_name: "My Shop")
  """

  @behaviour Emakola.Notifications.SMSProvider

  alias Emakola.Privacy

  require Logger

  # Per-store SMS rate limit. 100/hour catches accidental notification
  # loops (e.g., a worker stuck retrying) while allowing legitimate
  # bursts. Bypass via opts: `[bypass_rate_limit: true]` for tests.
  @rate_limit 100
  @rate_window_ms :timer.hours(1)

  # ── Public API ─────────────────────────────────────────────────

  @impl true
  def send_sms(phone, message, opts \\ []) do
    case rate_limit_check(opts) do
      :allow ->
        do_send_sms(phone, message)

      :deny ->
        store_id = Keyword.get(opts, :store_id)

        Logger.warning(
          "[SMS] rate limit exceeded for store=#{Privacy.safe_uuid(store_id)} " <>
            "(#{@rate_limit} per #{div(@rate_window_ms, 60_000)}m); dropping message"
        )

        {:error, :rate_limited}
    end
  end

  defp do_send_sms(phone, message) do
    body = build_sms_payload(phone, message)

    Logger.info("[SMS] Sending message to #{Privacy.mask_phone(phone)}")

    case http_client().post(api_url(), json: body, headers: auth_headers()) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, %{status: status, body: resp_body, to: normalize_phone(phone)}}

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error("[SMS] API error #{status}; provider response omitted")
        {:error, %{status: status, body: resp_body}}

      {:error, reason} ->
        Logger.error("[SMS] HTTP error type=#{Privacy.error_type(reason)}")
        {:error, reason}
    end
  end

  defp rate_limit_check(opts) do
    cond do
      Keyword.get(opts, :bypass_rate_limit, false) ->
        :allow

      store_id = Keyword.get(opts, :store_id) ->
        case Emakola.RateLimit.check_rate("sms:store:#{store_id}", @rate_limit, @rate_window_ms) do
          {:allow, _count} -> :allow
          {:deny, _limit} -> :deny
        end

      true ->
        # No store_id passed — can't rate-limit safely; allow but log.
        Logger.warning("[SMS] no :store_id in opts; rate limit not applied")
        :allow
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
    case provider() do
      :arkesel ->
        %{
          sender: sender_id(),
          message: message,
          recipients: [normalize_phone(phone)]
        }

      _generic ->
        %{
          from: sender_id(),
          to: normalize_phone(phone),
          content: message
        }
    end
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
    major = minor_units |> div(100) |> Emakola.Money.group_thousands()
    minor = rem(abs(minor_units), 100)
    "#{major}.#{String.pad_leading(Integer.to_string(minor), 2, "0")}"
  end

  defp format_amount(_), do: "0.00"

  defp currency_symbol("GHS"), do: "GH\u20B5"
  defp currency_symbol("NGN"), do: "\u20A6"
  defp currency_symbol("USD"), do: "$"
  defp currency_symbol(_), do: ""

  defp auth_headers do
    case provider() do
      :arkesel ->
        [
          {"api-key", api_key()},
          {"content-type", "application/json"}
        ]

      _generic ->
        [
          {"authorization", "Bearer #{api_key()}"},
          {"content-type", "application/json"}
        ]
    end
  end

  defp api_key do
    config()[:api_key] || ""
  end

  defp sender_id do
    config()[:sender_id] || "Makola"
  end

  @arkesel_api_url "https://sms.arkesel.com/api/v2/sms/send"

  defp api_url do
    config()[:api_url] || default_api_url(provider())
  end

  defp default_api_url(:arkesel), do: @arkesel_api_url
  defp default_api_url(_generic), do: "https://api.sms-gateway.example.com/v1/messages"

  defp provider do
    config()[:provider] || :generic
  end

  defp config do
    Application.get_env(:emakola, __MODULE__, [])
  end

  defp http_client do
    Application.get_env(:emakola, :http_client, Req)
  end
end
