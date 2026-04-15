defmodule EmakolaWeb.Plugs.HubtelAllowlistTest do
  @moduledoc """
  Tests for the Hubtel IP allowlist plug.

  Because Hubtel does not sign webhooks, the only server-side trust boundary
  for their payment status events is source-IP verification. These tests pin
  the security contract:

    * Allowed IPs pass through unchanged
    * Blocked IPs halt with 403 and never reach the controller
    * The fail-closed default: no rules configured = reject everything
    * A bypass flag exists for dev/test convenience
    * Misconfigured rules (invalid strings) log + fail-closed at startup
  """
  use EmakolaWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  alias EmakolaWeb.Plugs.HubtelAllowlist

  # ── Helpers ────────────────────────────────────────────────────────

  defp conn_with_ip(ip) do
    build_conn(:post, "/webhooks/hubtel", %{})
    |> Map.put(:remote_ip, ip)
  end

  defp setup_allowlist(rules, opts \\ []) do
    bypass? = Keyword.get(opts, :bypass, false)

    original_rules = Application.get_env(:emakola, :hubtel_webhook_allowlist)
    original_bypass = Application.get_env(:emakola, :hubtel_webhook_allowlist_disabled)

    Application.put_env(:emakola, :hubtel_webhook_allowlist, rules)
    Application.put_env(:emakola, :hubtel_webhook_allowlist_disabled, bypass?)

    on_exit(fn ->
      if original_rules == nil do
        Application.delete_env(:emakola, :hubtel_webhook_allowlist)
      else
        Application.put_env(:emakola, :hubtel_webhook_allowlist, original_rules)
      end

      if original_bypass == nil do
        Application.delete_env(:emakola, :hubtel_webhook_allowlist_disabled)
      else
        Application.put_env(:emakola, :hubtel_webhook_allowlist_disabled, original_bypass)
      end
    end)

    :ok
  end

  # ── Allowed requests pass through ──────────────────────────────────

  describe "allowed IPs" do
    test "exact-match IP passes through" do
      setup_allowlist(["203.0.113.5"])

      conn =
        {203, 0, 113, 5}
        |> conn_with_ip()
        |> HubtelAllowlist.call(HubtelAllowlist.init([]))

      refute conn.halted
      assert conn.status == nil
    end

    test "CIDR-range IP passes through" do
      setup_allowlist(["10.0.0.0/24"])

      conn =
        {10, 0, 0, 42}
        |> conn_with_ip()
        |> HubtelAllowlist.call(HubtelAllowlist.init([]))

      refute conn.halted
    end

    test "multiple rules — matches second rule" do
      setup_allowlist(["1.2.3.4", "5.6.7.0/28", "9.9.9.9"])

      conn =
        {5, 6, 7, 10}
        |> conn_with_ip()
        |> HubtelAllowlist.call(HubtelAllowlist.init([]))

      refute conn.halted
    end
  end

  # ── Blocked requests return 403 ────────────────────────────────────

  describe "blocked IPs" do
    test "non-listed IP halts with 403" do
      setup_allowlist(["203.0.113.5"])

      log =
        capture_log(fn ->
          conn =
            {1, 2, 3, 4}
            |> conn_with_ip()
            |> HubtelAllowlist.call(HubtelAllowlist.init([]))

          assert conn.halted
          assert conn.status == 403

          body = Jason.decode!(conn.resp_body)
          assert body["error"] == "forbidden"
          assert is_binary(body["message"])
        end)

      assert log =~ "[hubtel-allowlist] blocked"
    end

    test "IP just outside a CIDR range is blocked" do
      setup_allowlist(["10.0.0.0/24"])

      conn =
        {10, 0, 1, 0}
        |> conn_with_ip()
        |> capture_log_call()

      assert conn.halted
      assert conn.status == 403
    end

    test "IPv6 remote_ip is always blocked (helper rejects non-IPv4)" do
      setup_allowlist(["0.0.0.0/0"])

      conn =
        {0, 0, 0, 0, 0, 0, 0, 1}
        |> conn_with_ip()
        |> capture_log_call()

      assert conn.halted
      assert conn.status == 403
    end
  end

  # ── Fail-closed default ────────────────────────────────────────────

  describe "fail-closed default" do
    test "empty allowlist blocks all requests" do
      setup_allowlist([])

      conn =
        {1, 2, 3, 4}
        |> conn_with_ip()
        |> capture_log_call()

      assert conn.halted
      assert conn.status == 403
    end

    test "missing allowlist config blocks all requests" do
      original = Application.get_env(:emakola, :hubtel_webhook_allowlist)
      Application.delete_env(:emakola, :hubtel_webhook_allowlist)
      Application.put_env(:emakola, :hubtel_webhook_allowlist_disabled, false)

      on_exit(fn ->
        if original do
          Application.put_env(:emakola, :hubtel_webhook_allowlist, original)
        end
      end)

      conn =
        {1, 2, 3, 4}
        |> conn_with_ip()
        |> capture_log_call()

      assert conn.halted
      assert conn.status == 403
    end

    test "invalid allowlist entries log error and fail closed" do
      setup_allowlist(["1.2.3.4", "bogus-ip", "10.0.0.0/33"])

      log =
        capture_log(fn ->
          conn =
            {1, 2, 3, 4}
            |> conn_with_ip()
            |> HubtelAllowlist.call(HubtelAllowlist.init([]))

          # The valid rule (1.2.3.4) is discarded when any rule fails parsing —
          # misconfiguration should be loud, not silently partial.
          assert conn.halted
          assert conn.status == 403
        end)

      assert log =~ "invalid allowlist entries"
    end
  end

  # ── Bypass flag ────────────────────────────────────────────────────

  describe "bypass flag" do
    test "bypass flag lets any IP through regardless of allowlist" do
      setup_allowlist([], bypass: true)

      conn =
        {1, 2, 3, 4}
        |> conn_with_ip()
        |> HubtelAllowlist.call(HubtelAllowlist.init([]))

      refute conn.halted
    end

    test "bypass flag does not affect bodies or assigns" do
      setup_allowlist(["9.9.9.9"], bypass: true)

      conn =
        {1, 2, 3, 4}
        |> conn_with_ip()
        |> HubtelAllowlist.call(HubtelAllowlist.init([]))

      refute conn.halted
      assert conn.resp_body == nil
    end
  end

  # Wraps a call in capture_log so the test output isn't polluted with
  # expected warning lines for the blocked cases above.
  defp capture_log_call(conn) do
    result = make_ref()
    pid = self()

    capture_log(fn ->
      out = HubtelAllowlist.call(conn, HubtelAllowlist.init([]))
      send(pid, {result, out})
    end)

    receive do
      {^result, out} -> out
    after
      1000 -> flunk("plug never returned")
    end
  end
end
