defmodule EmakolaWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug using Hammer (v7).

  Supports per-IP, per-token, and per-org rate limiting.
  Returns 429 with Retry-After header when the limit is exceeded.

  Key priority (default): Bearer token > X-Org-ID header > client IP address.

  ## Options

    * `:limit` - max requests per window (default: 100)
    * `:window_ms` - window duration in milliseconds (default: 60_000)
    * `:key` - keying strategy; pass `key: :ip` to force IP-only keying regardless
      of request headers (required for pre-auth endpoints where attacker-controlled
      headers would otherwise mint a fresh bucket per request). Omit (or pass any
      other value) to keep the default token > org > IP priority.
  """
  import Plug.Conn
  require Logger

  @default_limit 100
  @default_window_ms 60_000

  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, @default_limit),
      window_ms: Keyword.get(opts, :window_ms, @default_window_ms),
      key: Keyword.get(opts, :key, :default)
    }
  end

  def call(conn, %{limit: limit, window_ms: window_ms} = opts) do
    if Application.get_env(:emakola, :disable_rate_limit, false) do
      conn
    else
      do_rate_limit(conn, limit, window_ms, Map.get(opts, :key, :default))
    end
  end

  defp do_rate_limit(conn, limit, window_ms, key_mode) do
    key = rate_limit_key(conn, key_mode)

    case check_rate(key, limit, window_ms) do
      {:allow, count} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(max(limit - count, 0)))
        |> put_resp_header("x-ratelimit-reset", to_string(reset_timestamp(window_ms)))

      {:deny, retry_after_ms} ->
        retry_after = ceil(retry_after_ms / 1000)

        Logger.warning("Rate limit exceeded for #{key}")

        Emakola.Security.record(%{
          event_type: :rate_limit_exceeded,
          ip: format_ip(conn.remote_ip),
          path: conn.request_path,
          identifier: key,
          metadata: %{"limit" => limit}
        })

        conn
        |> put_resp_header("retry-after", to_string(retry_after))
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> send_rate_limit_response(retry_after)
        |> halt()
    end
  end

  # sobelow_skip ["XSS.SendResp"]
  defp send_rate_limit_response(conn, retry_after) do
    safe_retry = Integer.to_string(retry_after)

    if accepts_html?(conn) do
      conn
      |> put_resp_header("content-type", "text/html; charset=utf-8")
      |> send_resp(
        429,
        """
        <!DOCTYPE html>
        <html>
        <head><title>Too Many Requests</title></head>
        <body style="font-family: sans-serif; text-align: center; padding: 50px;">
          <h1>Too Many Requests</h1>
          <p>You have made too many requests. Please try again in #{safe_retry} seconds.</p>
          <p><a href="javascript:history.back()">Go back</a></p>
        </body>
        </html>
        """
      )
    else
      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(
        429,
        Jason.encode!(%{
          error: "rate_limit_exceeded",
          message: "Too many requests. Please retry after #{safe_retry} seconds.",
          retry_after: retry_after
        })
      )
    end
  end

  defp accepts_html?(conn) do
    case get_req_header(conn, "accept") do
      [accept | _] -> String.contains?(accept, "text/html")
      _ -> false
    end
  end

  defp rate_limit_key(conn, :ip), do: "ip:#{format_ip(conn.remote_ip)}"

  defp rate_limit_key(conn, _default) do
    cond do
      token = get_api_token(conn) -> "token:#{token_digest(token)}"
      org_id = get_org_id(conn) -> "org:#{org_id}"
      true -> "ip:#{format_ip(conn.remote_ip)}"
    end
  end

  # Hash the bearer token so the rate-limit bucket stays stable per token while the
  # raw credential never reaches the log line or the security_events store.
  defp token_digest(token) do
    :crypto.hash(:sha256, token) |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end

  defp get_api_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp get_org_id(conn) do
    case get_req_header(conn, "x-org-id") do
      [org_id] -> org_id
      _ -> nil
    end
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_ip(ip), do: to_string(:inet.ntoa(ip))

  defp check_rate(key, limit, window_ms) do
    case Emakola.RateLimit.check_rate("rate_limit:#{key}", limit, window_ms) do
      {:allow, count} -> {:allow, count}
      {:deny, retry_after} -> {:deny, retry_after}
    end
  end

  defp reset_timestamp(window_ms) do
    DateTime.utc_now()
    |> DateTime.add(window_ms, :millisecond)
    |> DateTime.to_unix()
  end
end
