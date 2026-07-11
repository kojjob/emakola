defmodule EmakolaWeb.Plugs.HubtelAllowlist do
  @moduledoc """
  IP allowlist plug for the `/webhooks/hubtel` endpoint.

  Hubtel does not sign webhooks, so the only server-side trust boundary for
  their payment status events is source-IP verification. This plug enforces
  that boundary by matching `conn.remote_ip` against a configured list of
  IPv4 addresses or CIDR ranges.

  ## Configuration

  Rules are read from application config at request time (so env-driven
  runtime config in `runtime.exs` is respected without a recompile):

      # config/runtime.exs
      config :emakola, :hubtel_webhook_allowlist,
        (System.get_env("HUBTEL_WEBHOOK_ALLOWLIST") || "")
        |> String.split(",", trim: true)

  A bypass flag is available for dev/test environments where exercising
  real IPs is impractical:

      # config/test.exs
      config :emakola, :hubtel_webhook_allowlist_disabled, true

  ## Fail-closed semantics

  The plug **fails closed** — any of the following conditions blocks the
  request with 403:

    * `:hubtel_webhook_allowlist` is unset
    * `:hubtel_webhook_allowlist` is an empty list
    * `:hubtel_webhook_allowlist` contains invalid entries (all rules
      discarded, not just the bad ones — misconfiguration should be loud)
    * `conn.remote_ip` is IPv6 (Hubtel is IPv4-only)
    * `conn.remote_ip` is IPv4 but does not match any rule

  The only request that passes is one with an IPv4 `remote_ip` that matches
  at least one parsed rule, **or** a request arriving while the bypass flag
  is set.

  ## Response shape for blocked requests

  Returns `403 Forbidden` with a JSON body:

      {"error":"forbidden","message":"..."}

  The `conn` is halted so subsequent plugs and the controller never run.
  """
  import Plug.Conn
  require Logger

  alias EmakolaWeb.IPAllowlist

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if bypass?() do
      conn
    else
      enforce(conn)
    end
  end

  defp bypass? do
    Application.get_env(:emakola, :hubtel_webhook_allowlist_disabled, false) == true
  end

  defp enforce(conn) do
    case load_rules() do
      {:ok, []} ->
        block(conn, "allowlist is empty")

      {:ok, rules} ->
        if IPAllowlist.allowed?(conn.remote_ip, rules) do
          conn
        else
          block(conn, "remote_ip=#{format_ip(conn.remote_ip)} not in allowlist")
        end

      {:error, invalid} ->
        Logger.error(
          "[hubtel-allowlist] invalid allowlist entries: #{inspect(invalid)} — " <>
            "rejecting ALL requests until configuration is corrected"
        )

        block(conn, "allowlist misconfigured")
    end
  end

  defp load_rules do
    case Application.get_env(:emakola, :hubtel_webhook_allowlist) do
      list when is_list(list) -> IPAllowlist.parse_all(list)
      nil -> {:ok, []}
      _other -> {:error, ["non-list value"]}
    end
  end

  # The response body is a Jason encoding of static literals. `reason` is logged only.
  # sobelow_skip ["XSS.SendResp"]
  defp block(conn, reason) do
    Logger.warning(
      "[hubtel-allowlist] blocked webhook request: #{reason}",
      remote_ip: format_ip(conn.remote_ip)
    )

    body =
      Jason.encode!(%{
        error: "forbidden",
        message: "Webhook source IP is not authorised."
      })

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(403, body)
    |> halt()
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_ip(ip) when is_tuple(ip), do: to_string(:inet.ntoa(ip))
  defp format_ip(other), do: inspect(other)
end
