defmodule EmakolaWeb.WebhookController do
  @moduledoc """
  Handles incoming payment gateway webhooks.

  Each gateway endpoint enqueues an Oban worker for async processing
  and returns 200 immediately to avoid timeout issues with the gateway.
  """

  use EmakolaWeb, :controller

  alias Emakola.Payments.Gateways.Paystack
  alias Emakola.Payments.Workers.HubtelWebhookHandler
  alias Emakola.Payments.Workers.PaystackWebhookHandler

  @doc """
  Receives Hubtel payment webhooks.

  Hubtel does not sign webhooks, so source-IP allowlisting is enforced at
  the router level via `EmakolaWeb.Plugs.HubtelAllowlist` in the
  `:hubtel_webhook_auth` pipeline. By the time a request reaches this
  action, the remote_ip has already been verified against the configured
  allowlist (`:hubtel_webhook_allowlist`).

  Inside the action, we enqueue an Oban worker that additionally verifies
  the transaction by calling Hubtel's status check API before updating
  payment/order records — defense in depth against compromised allowlisted
  hosts.
  """
  def hubtel(conn, params) do
    %{
      "client_reference" => params["ClientReference"] || params["client_reference"],
      "response_code" => params["ResponseCode"] || params["response_code"],
      "amount" => params["Amount"] || params["amount"],
      "status" => params["Status"] || params["status"]
    }
    |> HubtelWebhookHandler.new()
    |> Oban.insert()

    conn
    |> put_status(200)
    |> json(%{status: "ok"})
  end

  @doc """
  Receives Paystack payment webhooks.

  Paystack signs webhooks with HMAC-SHA512. We verify the signature
  before enqueuing the event for processing.
  """
  def paystack(conn, _params) do
    with {:ok, raw_body} <- read_raw_body(conn),
         headers <- extract_paystack_headers(conn),
         :ok <- Paystack.verify_webhook(raw_body, headers) do
      event = Jason.decode!(raw_body)

      %{"event" => event["event"], "data" => event["data"]}
      |> PaystackWebhookHandler.new()
      |> Oban.insert!()

      json(conn, %{status: "ok"})
    else
      {:error, :invalid_signature} ->
        conn
        |> put_status(401)
        |> json(%{error: "invalid_signature"})
    end
  end

  defp read_raw_body(conn) do
    case conn.assigns[:raw_body] do
      nil ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        {:ok, body}

      raw_body when is_list(raw_body) ->
        {:ok, Enum.join(raw_body)}

      raw_body when is_binary(raw_body) ->
        {:ok, raw_body}
    end
  end

  defp extract_paystack_headers(conn) do
    signature =
      conn
      |> Plug.Conn.get_req_header("x-paystack-signature")
      |> List.first()

    %{"x-paystack-signature" => signature}
  end
end
