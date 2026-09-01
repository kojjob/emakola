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

    test "allows blob media for the scroll-film scrub engine" do
      conn = conn(:get, "/") |> ContentSecurityPolicy.call([])

      [csp] = get_resp_header(conn, "content-security-policy")

      assert csp =~ "media-src 'self' blob:"
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

    test "script-src is nonce-based with no 'unsafe-inline' (the real XSS vector is closed)" do
      conn = conn(:get, "/") |> ContentSecurityPolicy.call([])

      [csp] = get_resp_header(conn, "content-security-policy")
      assert csp =~ ~r/script-src [^;]*'nonce-/
      refute csp =~ ~r/script-src [^;]*'unsafe-inline'/
    end

    test "style-src is split into -attr (permanent) and -elem (deferred hardening target)" do
      conn = conn(:get, "/") |> ContentSecurityPolicy.call([])

      [csp] = get_resp_header(conn, "content-security-policy")

      # Inline style ATTRIBUTES (style="…") cannot be nonced (CSP nonces only
      # cover <style> elements). They stay on 'unsafe-inline' permanently.
      assert csp =~ "style-src-attr 'unsafe-inline'"

      # Inline <style> ELEMENTS remain on 'unsafe-inline' until they are nonced
      # (deferred). Invariant: no nonce on style-src-elem — per CSP a nonce
      # disables 'unsafe-inline', which would block every un-nonced <style>
      # block in the app. This refute guards against a premature flip.
      assert csp =~ ~r/style-src-elem [^;]*'unsafe-inline'/
      refute csp =~ ~r/style-src-elem [^;]*nonce-/
    end
  end

  test "img-src allows blob: so LiveView upload previews render" do
    # Every upload preview is a blob: object URL. Without it merchants stared
    # at blank squares while their photos uploaded.
    conn = conn(:get, "/") |> ContentSecurityPolicy.call([])

    [csp] = get_resp_header(conn, "content-security-policy")
    assert csp =~ ~r/img-src [^;]*blob:/
  end
end
