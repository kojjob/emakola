defmodule EmakolaWeb.RemoteIpTest do
  @moduledoc """
  Behind the Fly proxy the direct peer is Fly's internal address, so the real
  client IP arrives in X-Forwarded-For. The endpoint must resolve it into
  conn.remote_ip before anything keys on it (rate limiting, the Hubtel IP
  allowlist, security logging) — otherwise every client shares the proxy's IP.
  """
  use EmakolaWeb.ConnCase, async: true

  test "resolves the real client IP from X-Forwarded-For", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("x-forwarded-for", "203.0.113.7")
      |> get(~p"/api/health")

    assert conn.remote_ip == {203, 0, 113, 7}
  end
end
