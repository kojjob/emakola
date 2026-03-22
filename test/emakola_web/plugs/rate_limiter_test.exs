defmodule EmakolaWeb.Plugs.RateLimiterTest do
  use EmakolaWeb.ConnCase, async: false

  alias EmakolaWeb.Plugs.RateLimiter

  @opts RateLimiter.init(limit: 5, window_ms: 60_000)

  describe "init/1" do
    test "uses default values" do
      opts = RateLimiter.init([])
      assert opts.limit == 100
      assert opts.window_ms == 60_000
    end

    test "accepts custom values" do
      opts = RateLimiter.init(limit: 50, window_ms: 30_000)
      assert opts.limit == 50
      assert opts.window_ms == 30_000
    end
  end

  describe "rate limiting by IP" do
    test "allows requests under limit" do
      unique_ip = {192, 168, System.unique_integer([:positive]) |> rem(255), 1}

      conn =
        build_conn()
        |> Map.put(:remote_ip, unique_ip)
        |> RateLimiter.call(@opts)

      refute conn.halted
      assert get_resp_header(conn, "x-ratelimit-limit") == ["5"]
    end

    test "blocks requests over limit with 429" do
      unique_ip = {10, 0, System.unique_integer([:positive]) |> rem(255), 1}
      opts = RateLimiter.init(limit: 2, window_ms: 60_000)

      # Make 2 allowed requests
      for _ <- 1..2 do
        conn = build_conn() |> Map.put(:remote_ip, unique_ip) |> RateLimiter.call(opts)
        refute conn.halted
      end

      # Third should be blocked
      conn = build_conn() |> Map.put(:remote_ip, unique_ip) |> RateLimiter.call(opts)
      assert conn.halted
      assert conn.status == 429
      assert get_resp_header(conn, "retry-after") != []

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "rate_limit_exceeded"
      assert is_binary(body["message"])
      assert is_integer(body["retry_after"])
    end

    test "different IPs have separate limits" do
      ip_a = {10, 10, System.unique_integer([:positive]) |> rem(255), 1}
      ip_b = {10, 11, System.unique_integer([:positive]) |> rem(255), 1}
      opts = RateLimiter.init(limit: 1, window_ms: 60_000)

      conn_a = build_conn() |> Map.put(:remote_ip, ip_a) |> RateLimiter.call(opts)
      refute conn_a.halted

      # Different IP should still be allowed
      conn_b = build_conn() |> Map.put(:remote_ip, ip_b) |> RateLimiter.call(opts)
      refute conn_b.halted
    end
  end

  describe "rate limiting by token" do
    test "uses bearer token as rate limit key" do
      token = "test_token_#{System.unique_integer([:positive])}"

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> RateLimiter.call(@opts)

      refute conn.halted
    end

    test "different tokens have separate limits" do
      token_a = "token_a_#{System.unique_integer([:positive])}"
      token_b = "token_b_#{System.unique_integer([:positive])}"
      opts = RateLimiter.init(limit: 1, window_ms: 60_000)

      conn_a =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token_a}")
        |> RateLimiter.call(opts)

      refute conn_a.halted

      conn_b =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token_b}")
        |> RateLimiter.call(opts)

      refute conn_b.halted
    end
  end

  describe "rate limiting by org" do
    test "uses X-Org-ID header as rate limit key" do
      org_id = "org_#{System.unique_integer([:positive])}"

      conn =
        build_conn()
        |> put_req_header("x-org-id", org_id)
        |> RateLimiter.call(@opts)

      refute conn.halted
    end

    test "different orgs have separate limits" do
      org_a = "org_a_#{System.unique_integer([:positive])}"
      org_b = "org_b_#{System.unique_integer([:positive])}"
      opts = RateLimiter.init(limit: 1, window_ms: 60_000)

      conn_a =
        build_conn()
        |> put_req_header("x-org-id", org_a)
        |> RateLimiter.call(opts)

      refute conn_a.halted

      conn_b =
        build_conn()
        |> put_req_header("x-org-id", org_b)
        |> RateLimiter.call(opts)

      refute conn_b.halted
    end
  end

  describe "response headers" do
    test "includes rate limit headers on success" do
      unique_ip = {172, 16, System.unique_integer([:positive]) |> rem(255), 1}

      conn =
        build_conn()
        |> Map.put(:remote_ip, unique_ip)
        |> RateLimiter.call(@opts)

      assert get_resp_header(conn, "x-ratelimit-limit") == ["5"]
      assert [remaining] = get_resp_header(conn, "x-ratelimit-remaining")
      assert String.to_integer(remaining) >= 0
      assert [reset] = get_resp_header(conn, "x-ratelimit-reset")
      assert String.to_integer(reset) > 0
    end

    test "remaining decreases with each request" do
      unique_ip = {172, 17, System.unique_integer([:positive]) |> rem(255), 1}

      conn1 =
        build_conn()
        |> Map.put(:remote_ip, unique_ip)
        |> RateLimiter.call(@opts)

      conn2 =
        build_conn()
        |> Map.put(:remote_ip, unique_ip)
        |> RateLimiter.call(@opts)

      [remaining1] = get_resp_header(conn1, "x-ratelimit-remaining")
      [remaining2] = get_resp_header(conn2, "x-ratelimit-remaining")

      assert String.to_integer(remaining1) > String.to_integer(remaining2)
    end

    test "includes retry-after on 429" do
      unique_ip = {10, 1, System.unique_integer([:positive]) |> rem(255), 1}
      opts = RateLimiter.init(limit: 1, window_ms: 60_000)

      build_conn() |> Map.put(:remote_ip, unique_ip) |> RateLimiter.call(opts)

      conn = build_conn() |> Map.put(:remote_ip, unique_ip) |> RateLimiter.call(opts)
      assert conn.status == 429
      [retry_after] = get_resp_header(conn, "retry-after")
      assert String.to_integer(retry_after) > 0
    end

    test "429 response has JSON content type" do
      unique_ip = {10, 2, System.unique_integer([:positive]) |> rem(255), 1}
      opts = RateLimiter.init(limit: 1, window_ms: 60_000)

      build_conn() |> Map.put(:remote_ip, unique_ip) |> RateLimiter.call(opts)

      conn = build_conn() |> Map.put(:remote_ip, unique_ip) |> RateLimiter.call(opts)
      assert get_resp_header(conn, "content-type") == ["application/json"]
    end
  end

  describe "edge cases" do
    test "handles missing authorization header" do
      conn = build_conn() |> RateLimiter.call(@opts)
      refute conn.halted
    end

    test "handles malformed authorization header" do
      conn =
        build_conn()
        |> put_req_header("authorization", "InvalidFormat")
        |> RateLimiter.call(@opts)

      refute conn.halted
    end

    test "handles Basic auth header (not Bearer)" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
        |> RateLimiter.call(@opts)

      # Should fall through to IP-based limiting
      refute conn.halted
    end

    test "key priority: token > org > ip" do
      token = "priority_token_#{System.unique_integer([:positive])}"
      opts = RateLimiter.init(limit: 1, window_ms: 60_000)

      # First request with token + org - uses token key
      conn1 =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("x-org-id", "some-org")
        |> RateLimiter.call(opts)

      refute conn1.halted

      # Second request with same token - should be denied (limit=1)
      conn2 =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("x-org-id", "some-org")
        |> RateLimiter.call(opts)

      assert conn2.halted
      assert conn2.status == 429
    end

    test "halted conn does not continue pipeline" do
      unique_ip = {10, 3, System.unique_integer([:positive]) |> rem(255), 1}
      opts = RateLimiter.init(limit: 1, window_ms: 60_000)

      build_conn() |> Map.put(:remote_ip, unique_ip) |> RateLimiter.call(opts)

      conn = build_conn() |> Map.put(:remote_ip, unique_ip) |> RateLimiter.call(opts)
      assert conn.halted
      assert conn.state == :sent
    end

    test "429 response body is valid JSON with required fields" do
      unique_ip = {10, 4, System.unique_integer([:positive]) |> rem(255), 1}
      opts = RateLimiter.init(limit: 1, window_ms: 60_000)

      build_conn() |> Map.put(:remote_ip, unique_ip) |> RateLimiter.call(opts)

      conn = build_conn() |> Map.put(:remote_ip, unique_ip) |> RateLimiter.call(opts)
      body = Jason.decode!(conn.resp_body)

      assert Map.has_key?(body, "error")
      assert Map.has_key?(body, "message")
      assert Map.has_key?(body, "retry_after")
    end

    test "limit of zero blocks all requests" do
      unique_ip = {10, 5, System.unique_integer([:positive]) |> rem(255), 1}
      opts = RateLimiter.init(limit: 0, window_ms: 60_000)

      conn = build_conn() |> Map.put(:remote_ip, unique_ip) |> RateLimiter.call(opts)
      assert conn.halted
      assert conn.status == 429
    end
  end
end
