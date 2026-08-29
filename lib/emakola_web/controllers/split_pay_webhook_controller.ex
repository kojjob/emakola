defmodule EmakolaWeb.SplitPayWebhookController do
  @moduledoc """
  Inbound SplitPay events. Authentication is the t=..,v1=HMAC-SHA256
  signature over the raw body, verified against the configured signing
  secret (fails closed when unset). charge.succeeded confirms the order
  named by external_reference; every other valid delivery is a logged
  no-op — SplitPay's ledger is the money authority, Makola only reacts.
  """

  use EmakolaWeb, :controller

  require Ash.Query
  require Logger

  def handle(conn, params) do
    with secret when is_binary(secret) <- Emakola.SplitPay.Client.webhook_secret(),
         raw_body when is_binary(raw_body) <- conn.assigns[:raw_body],
         :ok <- verify_signature(secret, raw_body, signature(conn)) do
      process(params["type"], params["data"])
      send_resp(conn, 200, "ok")
    else
      _ -> send_resp(conn, 401, "unauthorized")
    end
  end

  defp signature(conn) do
    case get_req_header(conn, "splitpay-signature") do
      [header | _] -> header
      [] -> nil
    end
  end

  defp verify_signature(secret, raw_body, header) when is_binary(header) do
    parsed =
      header
      |> String.split(",")
      |> Map.new(fn pair ->
        case String.split(pair, "=", parts: 2) do
          [key, value] -> {key, value}
          _malformed -> {pair, nil}
        end
      end)

    with %{"t" => timestamp, "v1" => presented} when is_binary(presented) <- parsed do
      expected =
        :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{raw_body}")
        |> Base.encode16(case: :lower)

      if Plug.Crypto.secure_compare(expected, presented),
        do: :ok,
        else: {:error, :invalid_signature}
    else
      _ -> {:error, :invalid_signature}
    end
  end

  defp verify_signature(_secret, _raw_body, _header), do: {:error, :invalid_signature}

  defp process("charge.succeeded", %{"external_reference" => reference})
       when is_binary(reference) do
    case Emakola.Orders.Order
         |> Ash.Query.filter(order_number == ^reference)
         |> Ash.read_one(authorize?: false) do
      {:ok, %{status: :pending} = order} ->
        case order |> Ash.Changeset.for_update(:confirm, %{}) |> Ash.update(authorize?: false) do
          {:ok, confirmed} ->
            try do
              Emakola.Notifications.Dispatcher.dispatch(confirmed, :order_confirmed)
            rescue
              _ -> :ok
            end

            :ok

          {:error, reason} ->
            Logger.error("[splitpay] could not confirm order #{reference}: #{inspect(reason)}")
            :ok
        end

      _missing_or_already_confirmed ->
        Logger.warning(
          "[splitpay] charge.succeeded for unknown/settled order #{inspect(reference)}"
        )

        :ok
    end
  end

  defp process(_type, _data), do: :ok
end
