defmodule EmakolaWeb.Plugs.CanonicalHost do
  @moduledoc """
  301-redirects configured alias hosts (e.g. `emakola.com`, `www.*`, the Fly
  default `emakola.fly.dev`) to the canonical apex, preserving path + query, so
  visitors and SEO link equity consolidate on the one indexed host.

  **Ships dark.** The redirect host list comes from
  `config :emakola, :canonical_redirect_hosts, [...]` and defaults to `[]`, so
  the plug is a pure pass-through until configured. That lets it be wired into
  the `:browser` pipeline now and switched on by config only **after** the
  emakola.io DNS + TLS cutover (redirecting to a host without a valid cert would
  break visitors). Hosts not in the list — the apex itself, merchant subdomains,
  custom domains — always pass through untouched.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    if conn.host in redirect_hosts(opts) do
      target = apex(opts) <> path_with_query(conn)

      conn
      |> put_resp_header("location", target)
      |> send_resp(301, "")
      |> halt()
    else
      conn
    end
  end

  defp redirect_hosts(opts) do
    Keyword.get(opts, :hosts) || Application.get_env(:emakola, :canonical_redirect_hosts, [])
  end

  defp apex(opts), do: Keyword.get(opts, :apex) || EmakolaWeb.Endpoint.url()

  defp path_with_query(%{request_path: path, query_string: ""}), do: path
  defp path_with_query(%{request_path: path, query_string: q}), do: path <> "?" <> q
end
