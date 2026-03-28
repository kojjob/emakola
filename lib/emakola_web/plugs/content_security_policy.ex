defmodule EmakolaWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Plug that sets Content-Security-Policy headers with per-request nonces.

  Generates a cryptographically random nonce for each request and sets it on
  `conn.assigns.csp_nonce`. This nonce is used by Phoenix LiveView for its
  inline scripts and can be referenced in templates via `@csp_nonce`.

  The CSP policy is enforced (not report-only) with a per-request nonce
  for LiveView inline scripts. See `build_policy/1` for the full directive list.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    nonce = generate_nonce()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", build_policy(nonce))
  end

  defp generate_nonce do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp build_policy(nonce) do
    directives = [
      "default-src 'self'",
      "script-src 'self' 'nonce-#{nonce}'",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "img-src 'self' data: https:",
      "font-src 'self' https://fonts.gstatic.com https://fonts.googleapis.com",
      "connect-src 'self' wss: ws:",
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'",
      "object-src 'none'"
    ]

    Enum.join(directives, "; ")
  end
end
