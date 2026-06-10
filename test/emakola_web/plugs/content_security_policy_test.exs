defmodule EmakolaWeb.Plugs.ContentSecurityPolicyTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn, only: [get_resp_header: 2]

  alias EmakolaWeb.Plugs.ContentSecurityPolicy

  describe "init/1" do
    test "passes options through unchanged" do
      assert ContentSecurityPolicy.init([]) == []
      assert ContentSecurityPolicy.init(key: :value) == [key: :value]
    end
  end

  describe "call/2" do
    test "sets content-security-policy response header" do
      conn = conn(:get, "/") |> ContentSecurityPolicy.call([])

      assert [csp] = get_resp_header(conn, "content-security-policy")
      assert is_binary(csp)
      assert byte_size(csp) > 0
    end

    test "CSP header contains a nonce" do
      conn = conn(:get, "/") |> ContentSecurityPolicy.call([])

      [csp] = get_resp_header(conn, "content-security-policy")
      assert csp =~ ~r/nonce-[A-Za-z0-9_-]+/
    end

    test "assigns csp_nonce to conn" do
      conn = conn(:get, "/") |> ContentSecurityPolicy.call([])

      assert is_binary(conn.assigns[:csp_nonce])
      assert byte_size(conn.assigns[:csp_nonce]) > 0
    end

    test "nonce in header matches nonce in assigns" do
      conn = conn(:get, "/") |> ContentSecurityPolicy.call([])

      nonce = conn.assigns[:csp_nonce]
      [csp] = get_resp_header(conn, "content-security-policy")
      assert csp =~ "nonce-#{nonce}"
    end

    test "nonce is unique per request" do
      conn1 = conn(:get, "/") |> ContentSecurityPolicy.call([])
      conn2 = conn(:get, "/") |> ContentSecurityPolicy.call([])

      refute conn1.assigns[:csp_nonce] == conn2.assigns[:csp_nonce]
    end

    test "CSP header contains required security directives" do
      conn = conn(:get, "/") |> ContentSecurityPolicy.call([])

      [csp] = get_resp_header(conn, "content-security-policy")
      assert csp =~ "default-src 'self'"
      assert csp =~ "frame-ancestors 'none'"
      assert csp =~ "object-src 'none'"
      assert csp =~ "form-action 'self'"
    end
  end
end
